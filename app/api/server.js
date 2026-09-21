const express = require("express");
const { Pool } = require("pg");

const app = express();

app.use(express.json());

const port = Number(process.env.PORT || 3000);

// PostgreSQL connection
const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
});

// Kubernetes liveness/readiness health check
app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    service: "api"
  });
});

// API health endpoint
app.get("/api/health", (_req, res) => {
  res.json({
    status: "ok",
    service: "api"
  });
});

// Basic API endpoint
app.get("/api", (_req, res) => {
  res.json({
    service: "node-api",
    message: "AKS 3-tier API is running"
  });
});

// PostgreSQL connectivity check
app.get("/api/db-check", async (_req, res) => {
  try {
    const result = await pool.query(
      "SELECT NOW() AS server_time"
    );

    res.json({
      database: "postgresql",
      connected: true,
      serverTime: result.rows[0].server_time
    });
  } catch (error) {
    console.error(
      "Database check failed:",
      error.message
    );

    res.status(503).json({
      database: "postgresql",
      connected: false
    });
  }
});

// Start API server
app.listen(port, "0.0.0.0", () => {
  console.log(`API listening on port ${port}`);
});
