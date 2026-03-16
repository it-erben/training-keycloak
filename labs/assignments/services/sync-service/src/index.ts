import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config({ path: '../.env' });

const KEYCLOAK_URL = process.env.VITE_KEYCLOAK_URL || 'http://localhost:8080';
const REALM = process.env.VITE_KEYCLOAK_REALM || 'mustertech';
const CLIENT_ID = 'sync-service';
const CLIENT_SECRET = process.env.SYNC_SERVICE_CLIENT_SECRET;

async function getServiceAccountToken(): Promise<string> {
  if (!CLIENT_SECRET) {
    throw new Error(
      'SYNC_SERVICE_CLIENT_SECRET nicht gesetzt. Bitte in .env konfigurieren.'
    );
  }

  const response = await axios.post(
    `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token`,
    new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
    }),
    {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    }
  );
  return response.data.access_token;
}

async function getUsers(token: string) {
  const response = await axios.get(
    `${KEYCLOAK_URL}/admin/realms/${REALM}/users`,
    {
      headers: { Authorization: `Bearer ${token}` },
    }
  );
  return response.data;
}

async function syncUsers() {
  console.log('=================================');
  console.log('  Mustertech Sync Service');
  console.log('=================================\n');

  try {
    console.log('Hole Service Account Token...');
    const token = await getServiceAccountToken();
    console.log('Token erhalten!\n');

    console.log('Lade Benutzer aus Keycloak...');
    const users = await getUsers(token);

    console.log(`\n${users.length} Benutzer gefunden:\n`);
    users.forEach((user: any) => {
      console.log(`- ${user.username} (${user.email || 'keine E-Mail'})`);
    });

    console.log('\n[Hier würde die Synchronisation stattfinden]');
    console.log('Sync abgeschlossen.');
  } catch (error: any) {
    console.error('Fehler:', error.response?.data || error.message);
    process.exit(1);
  }
}

syncUsers();
