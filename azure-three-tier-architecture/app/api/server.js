const express = require("express");
const pool = require("./db");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get("/api/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");

    res.json({
      status: "healthy",
      service: "three-tier-api",
      database: "connected"
    });
  } catch (error) {
    console.error("Database health check failed:", error.message);

    res.status(503).json({
      status: "unhealthy",
      service: "three-tier-api",
      database: "disconnected"
    });
  }
});

app.get("/api/patients", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT id, name, status FROM patients ORDER BY id"
    );

    res.json(result.rows);
  } catch (error) {
    console.error("Failed to retrieve patients:", error.message);

    res.status(500).json({
      error: "Failed to retrieve patients"
    });
  }
});

app.get("/", (req, res) => {
  res.json({
    service: "three-tier-api",
    status: "running"
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`API listening on port ${PORT}`);
});