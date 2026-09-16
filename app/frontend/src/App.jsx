import React, { useState } from "react";

export default function App() {
  const [result, setResult] = useState(null);

  async function checkApi() {
    try {
      const response = await fetch("/api");
      const data = await response.json();
      setResult(JSON.stringify(data, null, 2));
    } catch (error) {
      setResult(`API request failed: ${error.message}`);
    }
  }

  return (
    <main style={{ fontFamily: "Arial", maxWidth: 800, margin: "50px auto" }}>
      <h1>AKS 3-Tier Application</h1>
      <p>React frontend → Node.js API → PostgreSQL</p>

      <button onClick={checkApi}>Check API</button>

      {result && (
        <pre style={{ marginTop: 20, padding: 20, background: "#f4f4f4" }}>
          {result}
        </pre>
      )}
    </main>
  );
}
