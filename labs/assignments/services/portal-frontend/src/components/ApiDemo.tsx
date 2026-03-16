import { useState } from 'react';
import { useAuth } from 'react-oidc-context';

const API_URL = 'http://localhost:3001';

export function ApiDemo() {
  const auth = useAuth();
  const [result, setResult] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const callApi = async (endpoint: string) => {
    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await fetch(`${API_URL}${endpoint}`, {
        headers: {
          Authorization: `Bearer ${auth.user?.access_token}`,
        },
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `HTTP ${response.status}`);
      }

      const data = await response.json();
      setResult(data);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <section className="card">
      <h2>API-Aufrufe testen</h2>

      <div className="button-group">
        <button onClick={() => callApi('/api/profile')} disabled={loading}>
          Mein Profil
        </button>
        <button
          onClick={() => callApi('/api/urlaubsantraege')}
          disabled={loading}
        >
          Meine Urlaubsanträge
        </button>
        <button
          onClick={() => callApi('/api/urlaubsantraege/alle')}
          disabled={loading}
        >
          Alle Anträge (Manager)
        </button>
        <button onClick={() => callApi('/api/admin/stats')} disabled={loading}>
          Admin Stats
        </button>
      </div>

      {loading && <p>Lädt...</p>}

      {error && (
        <div className="error">
          <strong>Fehler:</strong> {error}
        </div>
      )}

      {result && (
        <pre className="token">{JSON.stringify(result, null, 2)}</pre>
      )}
    </section>
  );
}
