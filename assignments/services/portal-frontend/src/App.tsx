import { useAuth } from 'react-oidc-context';
import './App.css';
import { ApiDemo } from './components/ApiDemo';

function App() {
  const auth = useAuth();

  // Loading state
  if (auth.isLoading) {
    return (
      <div className="app">
        <h1>Mustertech Portal</h1>
        <p>Lädt...</p>
      </div>
    );
  }

  // Error state
  if (auth.error) {
    return (
      <div className="app">
        <h1>Mustertech Portal</h1>
        <p className="error">Fehler: {auth.error.message}</p>
        <button onClick={() => auth.signinRedirect()}>
          Erneut versuchen
        </button>
      </div>
    );
  }

  // Authenticated state
  if (auth.isAuthenticated && auth.user) {
    return (
      <div className="app">
        <header>
          <h1>Mustertech Portal</h1>
          <div className="user-info">
            <span>Willkommen, {auth.user.profile.name || auth.user.profile.preferred_username}!</span>
            <button onClick={() => auth.signoutRedirect()}>
              Abmelden
            </button>
          </div>
        </header>

        <main>
          <section className="card">
            <h2>Ihr Profil</h2>
            <table>
              <tbody>
                <tr>
                  <td><strong>Name:</strong></td>
                  <td>{auth.user.profile.name}</td>
                </tr>
                <tr>
                  <td><strong>E-Mail:</strong></td>
                  <td>{auth.user.profile.email}</td>
                </tr>
                <tr>
                  <td><strong>Username:</strong></td>
                  <td>{auth.user.profile.preferred_username}</td>
                </tr>
              </tbody>
            </table>
          </section>

          <section className="card">
            <h2>Token-Informationen</h2>
            <details>
              <summary>Access Token anzeigen</summary>
              <pre className="token">{auth.user.access_token}</pre>
            </details>
            <details>
              <summary>ID Token Claims anzeigen</summary>
              <pre className="token">
                {JSON.stringify(auth.user.profile, null, 2)}
              </pre>
            </details>
          </section>
            <ApiDemo />
        </main>
      </div>
    );
  }

  // Not authenticated
  return (
    <div className="app">
      <h1>Mustertech Portal</h1>
      <p>Willkommen beim Mitarbeiterportal der Mustertech GmbH.</p>
      <p>Bitte melden Sie sich an, um fortzufahren.</p>
      <button onClick={() => auth.signinRedirect()}>
        Anmelden mit Keycloak
      </button>
    </div>
  );
}

export default App;
