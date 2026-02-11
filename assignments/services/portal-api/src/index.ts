import express from 'express';
import cors from 'cors';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
import dotenv from 'dotenv';

dotenv.config({ path: '../.env' });

const app = express();
const PORT = process.env.API_PORT || 3001;

const KEYCLOAK_URL = process.env.VITE_KEYCLOAK_URL || 'http://localhost:8080';
const KEYCLOAK_PUBLIC_URL = process.env.KEYCLOAK_PUBLIC_URL || KEYCLOAK_URL;
const REALM = process.env.VITE_KEYCLOAK_REALM || 'mustertech';

// JWKS Client für Token-Validierung
const client = jwksClient({
  jwksUri: `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/certs`,
  cache: true,
  rateLimit: true,
});

// Middleware
app.use(cors());
app.use(express.json());

// Token-Validierung Middleware
const validateToken = async (
  req: express.Request,
  res: express.Response,
  next: express.NextFunction
) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const token = authHeader.split(' ')[1];

  try {
    // Token Header dekodieren um kid zu erhalten
    const decoded = jwt.decode(token, { complete: true });
    if (!decoded || !decoded.header.kid) {
      return res.status(401).json({ error: 'Invalid token format' });
    }

    // Public Key vom JWKS Endpoint holen
    const key = await client.getSigningKey(decoded.header.kid);
    const publicKey = key.getPublicKey();

    // Token verifizieren
    const verified = jwt.verify(token, publicKey, {
      algorithms: ['RS256'],
      issuer: `${KEYCLOAK_PUBLIC_URL}/realms/${REALM}`,
    });

    (req as any).user = verified;
    next();
  } catch (error) {
    console.error('Token validation error:', error);
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Rollen-Check Middleware
const requireRole = (role: string) => {
  return (
    req: express.Request,
    res: express.Response,
    next: express.NextFunction
  ) => {
    const user = (req as any).user;
    const roles = user?.realm_access?.roles || [];

    if (!roles.includes(role)) {
      return res.status(403).json({ error: `Role '${role}' required` });
    }
    next();
  };
};

// Permission-Check Middleware (Authorization Services / UMA)
const requirePermission = (resource: string, scope: string, fallbackRole: string) => {
  return async (
    req: express.Request,
    res: express.Response,
    next: express.NextFunction
  ) => {
    if (process.env.AUTHORIZATION_ENABLED !== 'true') {
      return requireRole(fallbackRole)(req, res, next);
    }

    const authHeader = req.headers.authorization;
    if (!authHeader) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.split(' ')[1];

    try {
      const params = new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:uma-ticket',
        audience: 'portal-api',
        permission: `${resource}#${scope}`,
        response_mode: 'decision',
      });

      const response = await fetch(
        `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            Authorization: `Bearer ${token}`,
          },
          body: params.toString(),
        }
      );

      if (!response.ok) {
        return res.status(403).json({ error: `Permission '${resource}#${scope}' denied` });
      }

      const data = (await response.json()) as { result: boolean };
      if (data.result === true) {
        return next();
      }

      return res.status(403).json({ error: `Permission '${resource}#${scope}' denied` });
    } catch (error) {
      console.error('Authorization check error:', error);
      return res.status(403).json({ error: 'Authorization check failed' });
    }
  };
};

// Routes

// Öffentlich
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Geschützt - alle authentifizierten User
app.get('/api/profile', validateToken, (req, res) => {
  const user = (req as any).user;
  res.json({
    sub: user.sub,
    name: user.name,
    email: user.email,
    username: user.preferred_username,
    roles: user.realm_access?.roles || [],
  });
});

// Geschützt - nur Mitarbeiter
app.get(
  '/api/urlaubsantraege',
  validateToken,
  requirePermission('urlaubsantrag', 'view', 'mitarbeiter'),
  (req, res) => {
    const user = (req as any).user;
    res.json({
      user: user.preferred_username,
      antraege: [
        { id: 1, von: '2024-07-01', bis: '2024-07-14', status: 'genehmigt' },
        { id: 2, von: '2024-12-23', bis: '2024-12-31', status: 'ausstehend' },
      ],
    });
  }
);

// Geschützt - nur Manager
app.get(
  '/api/urlaubsantraege/alle',
  validateToken,
  requirePermission('urlaubsantrag', 'approve', 'manager'),
  (req, res) => {
    res.json({
      antraege: [
        {
          id: 1,
          mitarbeiter: 'Hans Müller',
          von: '2024-07-01',
          bis: '2024-07-14',
          status: 'genehmigt',
        },
        {
          id: 2,
          mitarbeiter: 'Anna Schmidt',
          von: '2024-08-01',
          bis: '2024-08-07',
          status: 'ausstehend',
        },
      ],
    });
  }
);

// Geschützt - nur Admins
app.get(
  '/api/admin/stats',
  validateToken,
  requirePermission('admin-bereich', 'view', 'admin'),
  (req, res) => {
    res.json({
      totalUsers: 42,
      activeSessionsToday: 15,
      pendingRequests: 3,
    });
  }
);

app.listen(PORT, () => {
  console.log(`Portal API running on http://localhost:${PORT}`);
});
