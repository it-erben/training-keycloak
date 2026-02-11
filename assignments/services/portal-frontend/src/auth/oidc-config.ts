import { UserManagerSettings, WebStorageStateStore } from 'oidc-client-ts';

const keycloakUrl = import.meta.env.VITE_KEYCLOAK_URL;
const realm = import.meta.env.VITE_KEYCLOAK_REALM;
const clientId = import.meta.env.VITE_KEYCLOAK_CLIENT_ID;

export const oidcConfig: UserManagerSettings = {
  authority: `${keycloakUrl}/realms/${realm}`,
  client_id: clientId,
  redirect_uri: window.location.origin + '/',
  post_logout_redirect_uri: window.location.origin + '/',
  response_type: 'code',
  scope: 'openid profile email',
  automaticSilentRenew: true,
  userStore: new WebStorageStateStore({ store: window.localStorage }),
};
