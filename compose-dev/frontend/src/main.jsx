import React from "react";
import { createRoot } from "react-dom/client";
import "./style.css";

const API_URL = "http://localhost:8080";

function App() {
  const [health, setHealth] = React.useState(null);
  const [redis, setRedis] = React.useState(null);
  const [users, setUsers] = React.useState([]);
  const [error, setError] = React.useState(null);

  React.useEffect(() => {
    async function loadData() {
      try {
        const [healthResponse, redisResponse, usersResponse] =
          await Promise.all([
            fetch(`${API_URL}/api/health`),
            fetch(`${API_URL}/api/redis`),
            fetch(`${API_URL}/api/users`)
          ]);

        const healthData = await healthResponse.json();
        const redisData = await redisResponse.json();
        const usersData = await usersResponse.json();

        if (!healthResponse.ok || !redisResponse.ok || !usersResponse.ok) {
          throw new Error("One or more services failed");
        }

        setHealth(healthData);
        setRedis(redisData);
        setUsers(usersData);
      } catch (err) {
        setError(err.message);
      }
    }

    loadData();
  }, []);

  return (
    <main className="container">
      <h1>Docker Compose Development Environment</h1>

      <p className="architecture">
        React → Node.js API → PostgreSQL + Redis
      </p>

      {error && <div className="card error">❌ {error}</div>}

      <div className="grid">
        <div className="card">
          <h2>API Health</h2>
          <p>API: {health ? "✅ Healthy" : "⏳ Checking..."}</p>
          <p>
            PostgreSQL:{" "}
            {health?.database === "connected" ? "✅ Connected" : "⏳ Checking..."}
          </p>
          <p>
            Redis:{" "}
            {health?.redis === "connected" ? "✅ Connected" : "⏳ Checking..."}
          </p>
        </div>

        <div className="card">
          <h2>Redis Test</h2>
          {redis ? (
            <>
              <p>Redis: ✅ Connected</p>
              <p>
                Key: <code>{redis.key}</code>
              </p>
              <p>
                Value: <code>{redis.value}</code>
              </p>
            </>
          ) : (
            <p>⏳ Checking Redis...</p>
          )}
        </div>
      </div>

      <div className="card">
        <h2>PostgreSQL Data</h2>

        {users.length > 0 ? (
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>Created</th>
              </tr>
            </thead>

            <tbody>
              {users.map((user) => (
                <tr key={user.id}>
                  <td>{user.id}</td>
                  <td>{user.name}</td>
                  <td>{user.email}</td>
                  <td>{user.created_at}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p>⏳ Loading PostgreSQL data...</p>
        )}
      </div>
    </main>
  );
}

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);