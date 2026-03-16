import express from "express";
import session from "express-session";

// --- Konfiguration aus Umgebungsvariablen ---
const APP_NAME = process.env.APP_NAME || "App";
const PORT = parseInt(process.env.PORT || "3000");
const CLIENT_ID = process.env.CLIENT_ID;
const CLIENT_SECRET = process.env.CLIENT_SECRET;
const KEYCLOAK_URL = process.env.KEYCLOAK_URL; // Docker-intern (Server-zu-Server)
const KEYCLOAK_PUBLIC_URL = process.env.KEYCLOAK_PUBLIC_URL; // Browser-URL
const REALM = process.env.REALM || "mustertech";
const APP_URL = process.env.APP_URL; // Öffentliche URL dieser App

// OIDC-Endpoints
const AUTH_ENDPOINT = `${KEYCLOAK_PUBLIC_URL}/realms/${REALM}/protocol/openid-connect/auth`;
const TOKEN_ENDPOINT = `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token`;
const END_SESSION_ENDPOINT = `${KEYCLOAK_PUBLIC_URL}/realms/${REALM}/protocol/openid-connect/logout`;

// --- Session-Verwaltung ---
const store = new session.MemoryStore();
const keycloakSessionMap = new Map(); // Keycloak-Session-ID → Express-Session-ID

const app = express();
app.use(express.urlencoded({ extended: false }));
app.use(
  session({
    name: `${CLIENT_ID}.sid`,
    store,
    secret: "logout-demo-secret",
    resave: false,
    saveUninitialized: false,
  })
);

function log(category, message) {
  const time = new Date().toISOString().substring(11, 19);
  console.log(`[${time}] [${APP_NAME}] [${category}] ${message}`);
}

// --- HTML-Hilfsfunktion ---
function page(title, body) {
  return `<!DOCTYPE html>
<html lang="de"><head>
  <meta charset="utf-8">
  <title>${title} – ${APP_NAME}</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 600px; margin: 50px auto; padding: 0 20px; color: #333; }
    h1 { margin-bottom: 4px; }
    .subtitle { color: #666; margin-top: 0; margin-bottom: 24px; }
    .card { padding: 16px 20px; border-radius: 8px; margin: 20px 0; }
    .logged-in { background: #d4edda; border: 1px solid #c3e6cb; }
    .logged-out { background: #fff3cd; border: 1px solid #ffc107; }
    .btn { display: inline-block; padding: 10px 24px; color: #fff; text-decoration: none; border-radius: 4px; font-size: 14px; }
    .btn-login { background: #28a745; }
    .btn-login:hover { background: #218838; }
    .btn-logout { background: #dc3545; }
    .btn-logout:hover { background: #c82333; }
    code { background: #e9ecef; padding: 2px 6px; border-radius: 3px; font-size: 13px; }
    dt { font-weight: 600; margin-top: 8px; }
    dd { margin-left: 0; color: #555; }
  </style>
</head><body>
  <h1>${APP_NAME}</h1>
  <p class="subtitle">Port ${PORT} &middot; Client <code>${CLIENT_ID}</code></p>
  ${body}
</body></html>`;
}

// --- Routes ---

// Startseite
app.get("/", (req, res) => {
  const user = req.session.user;
  if (user) {
    res.send(
      page(
        "Eingeloggt",
        `
      <div class="card logged-in">
        <dl>
          <dt>Benutzer</dt><dd>${user.name} (${user.email})</dd>
          <dt>Keycloak-Session-ID</dt><dd><code>${req.session.keycloakSid}</code></dd>
          <dt>Express-Session-ID</dt><dd><code>${req.sessionID}</code></dd>
        </dl>
      </div>
      <a class="btn btn-logout" href="/logout">Logout</a>`
      )
    );
  } else {
    res.send(
      page(
        "Nicht eingeloggt",
        `
      <div class="card logged-out">
        <p>Nicht eingeloggt. Bitte melde dich über Keycloak an.</p>
      </div>
      <a class="btn btn-login" href="/login">Login mit Keycloak</a>`
      )
    );
  }
});

// Login – Weiterleitung zu Keycloak
app.get("/login", (req, res) => {
  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: `${APP_URL}/callback`,
    response_type: "code",
    scope: "openid profile email",
  });
  res.redirect(`${AUTH_ENDPOINT}?${params}`);
});

// Callback – Authorization Code gegen Tokens tauschen
app.get("/callback", async (req, res) => {
  const { code } = req.query;
  if (!code) return res.status(400).send("Fehlender Authorization Code");

  const tokenRes = await fetch(TOKEN_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      code,
      redirect_uri: `${APP_URL}/callback`,
    }),
  });

  if (!tokenRes.ok) {
    const error = await tokenRes.text();
    log("LOGIN", `Token-Austausch fehlgeschlagen: ${error}`);
    return res.status(500).send("Token-Austausch fehlgeschlagen");
  }

  const tokens = await tokenRes.json();
  const payload = JSON.parse(
    Buffer.from(tokens.id_token.split(".")[1], "base64url").toString()
  );

  req.session.user = {
    name: payload.name || payload.preferred_username,
    email: payload.email,
    sub: payload.sub,
  };
  req.session.keycloakSid = payload.sid;
  req.session.idToken = tokens.id_token;
  keycloakSessionMap.set(payload.sid, req.sessionID);

  log("LOGIN", `${payload.name} eingeloggt (KC-Session: ${payload.sid})`);
  req.session.save((err) => {
    if (err) log("LOGIN", `Session-Speicherfehler: ${err.message}`);
    res.redirect("/");
  });
});

// RP-Initiated Logout – Logout über Keycloak auslösen
app.get("/logout", (req, res) => {
  const idToken = req.session.idToken;
  const sid = req.session.keycloakSid;
  const userName = req.session.user?.name;

  req.session.destroy(() => {
    if (sid) keycloakSessionMap.delete(sid);
    log("LOGOUT", `${userName} hat Logout ausgelöst`);

    const params = new URLSearchParams({ post_logout_redirect_uri: APP_URL });
    if (idToken) {
      params.set("id_token_hint", idToken);
    } else {
      params.set("client_id", CLIENT_ID);
    }
    res.redirect(`${END_SESSION_ENDPOINT}?${params}`);
  });
});

// ============================================================
// Frontchannel-Logout (GET)
// Wird vom Browser des Users in einem versteckten iframe aufgerufen.
// Keycloak sendet sid und iss als Query-Parameter.
// ============================================================
app.get("/frontchannel-logout", (req, res) => {
  const { sid, iss } = req.query;
  log("FRONTCHANNEL-LOGOUT", `Empfangen – sid=${sid}, iss=${iss}`);

  if (sid) {
    const expressSessionId = keycloakSessionMap.get(sid);
    if (expressSessionId) {
      store.destroy(expressSessionId, () => {
        log("FRONTCHANNEL-LOGOUT", `Session zerstört für sid=${sid}`);
      });
      keycloakSessionMap.delete(sid);
    } else {
      log(
        "FRONTCHANNEL-LOGOUT",
        `Keine passende Session gefunden für sid=${sid}`
      );
    }
  }

  // Leere Antwort – wird im versteckten iframe geladen
  res.set("Cache-Control", "no-store");
  res.send("<html><body></body></html>");
});

// ============================================================
// Backchannel-Logout (POST)
// Wird direkt von Keycloak (Server-zu-Server) aufgerufen.
// Der Body enthält einen logout_token (JWT).
// ============================================================
app.post("/backchannel-logout", (req, res) => {
  const logoutToken = req.body.logout_token;
  if (!logoutToken) {
    log("BACKCHANNEL-LOGOUT", "Kein logout_token im Request-Body");
    return res.sendStatus(400);
  }

  try {
    // Logout-Token dekodieren (vereinfacht – in Produktion: Signatur prüfen!)
    const payload = JSON.parse(
      Buffer.from(logoutToken.split(".")[1], "base64url").toString()
    );
    log(
      "BACKCHANNEL-LOGOUT",
      `Empfangen – sid=${payload.sid}, sub=${payload.sub}, events=${JSON.stringify(payload.events)}`
    );

    if (payload.sid) {
      const expressSessionId = keycloakSessionMap.get(payload.sid);
      if (expressSessionId) {
        store.destroy(expressSessionId, () => {
          log("BACKCHANNEL-LOGOUT", `Session zerstört für sid=${payload.sid}`);
        });
        keycloakSessionMap.delete(payload.sid);
      } else {
        log(
          "BACKCHANNEL-LOGOUT",
          `Keine passende Session gefunden für sid=${payload.sid}`
        );
      }
    }

    res.sendStatus(200);
  } catch (err) {
    log("BACKCHANNEL-LOGOUT", `Fehler beim Verarbeiten: ${err.message}`);
    res.sendStatus(400);
  }
});

// --- Server starten ---
app.listen(PORT, () => {
  log("START", `läuft auf Port ${PORT}`);
  log("START", `OIDC-Client: ${CLIENT_ID}`);
  log("START", `Keycloak (intern): ${KEYCLOAK_URL}`);
  log("START", `Keycloak (Browser): ${KEYCLOAK_PUBLIC_URL}`);
  log("START", `App-URL: ${APP_URL}`);
});
