import axios from 'axios';
import readlineSync from 'readline-sync';
import dotenv from 'dotenv';

dotenv.config({ path: '../.env' });

const KEYCLOAK_URL = process.env.VITE_KEYCLOAK_URL || 'http://localhost:8080';
const REALM = process.env.VITE_KEYCLOAK_REALM || 'mustertech';
const CLIENT_ID = 'management-cli';

interface DeviceAuthResponse {
  device_code: string;
  user_code: string;
  verification_uri: string;
  verification_uri_complete: string;
  expires_in: number;
  interval: number;
}

interface TokenResponse {
  access_token: string;
  id_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
}

async function startDeviceFlow(): Promise<DeviceAuthResponse> {
  const response = await axios.post(
    `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth/device`,
    new URLSearchParams({
      client_id: CLIENT_ID,
      scope: 'openid profile email',
    }),
    {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    }
  );
  return response.data;
}

async function pollForToken(
  deviceCode: string,
  interval: number
): Promise<TokenResponse> {
  while (true) {
    await new Promise((resolve) => setTimeout(resolve, interval * 1000));

    try {
      const response = await axios.post(
        `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token`,
        new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
          client_id: CLIENT_ID,
          device_code: deviceCode,
        }),
        {
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        }
      );
      return response.data;
    } catch (error: any) {
      if (error.response?.data?.error === 'authorization_pending') {
        process.stdout.write('.');
        continue;
      }
      if (error.response?.data?.error === 'slow_down') {
        interval += 5;
        continue;
      }
      throw error;
    }
  }
}

async function main() {
  console.log('=================================');
  console.log('  Mustertech Admin CLI');
  console.log('=================================\n');

  try {
    // Device Flow starten
    console.log('Starte Authentifizierung...\n');
    const deviceAuth = await startDeviceFlow();

    console.log('Bitte öffnen Sie folgende URL im Browser:\n');
    console.log(`  ${deviceAuth.verification_uri_complete}\n`);
    console.log(`Oder gehen Sie zu ${deviceAuth.verification_uri}`);
    console.log(`und geben Sie den Code ein: ${deviceAuth.user_code}\n`);

    readlineSync.question(
      'Drücken Sie Enter, nachdem Sie sich angemeldet haben...'
    );

    console.log('\nWarte auf Autorisierung');
    const tokens = await pollForToken(
      deviceAuth.device_code,
      deviceAuth.interval
    );
    console.log('\n\nErfolgreich angemeldet!\n');

    // Benutzerinfo aus dem ID Token (enthält Identitätsdaten)
    const idParts = tokens.id_token.split('.');
    const identity = JSON.parse(
      Buffer.from(idParts[1], 'base64').toString()
    );

    console.log('Benutzer:', identity.name || identity.preferred_username);
    console.log('E-Mail:', identity.email);

    // Rollen aus dem Access Token (enthält Berechtigungsdaten)
    const accessParts = tokens.access_token.split('.');
    const access = JSON.parse(
      Buffer.from(accessParts[1], 'base64').toString()
    );

    console.log(
      'Rollen:',
      access.realm_access?.roles?.join(', ') || 'keine'
    );
    console.log(
      '\nAccess Token (erste 50 Zeichen):',
      tokens.access_token.substring(0, 50) + '...'
    );
  } catch (error: any) {
    console.error('Fehler:', error.response?.data || error.message);
    process.exit(1);
  }
}

main();
