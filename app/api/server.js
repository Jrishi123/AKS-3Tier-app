const express = require("express");
const { Pool } = require("pg");

const app = express();
app.use(express.json());

const port = Number(process.env.PORT || 3000);

const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "api" });
});

app.get("/api", (_req, res) => {
  res.json({
    service: "node-api",
    message: "AKS 3-tier API is running"
  });
});

app.get("/api/db-check", async (_req, res) => {
  try {
    const result = await pool.query("SELECT NOW() AS server_time");
    res.json({
      database: "postgresql",
      connected: true,
      serverTime: result.rows[0].server_time
    });
  } catch (error) {
    console.error("Database check failed:", error.message);
    res.status(503).json({
      database: "postgresql",
      connected: false
    });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`API listening on port ${port}`);
});
