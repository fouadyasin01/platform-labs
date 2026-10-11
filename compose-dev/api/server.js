const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
const { createClient } = require("redis");

const app = express();
app.use(cors());
const port = 8080;

const db = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
});

const redis = createClient({
  socket: {
    host: process.env.REDIS_HOST,
    port: Number(process.env.REDIS_PORT)
  }
});

redis.on("error", (error) => {
  console.error("Redis error:", error);
});

async function checkDependencies() {
  await db.query("SELECT 1");

  if (!redis.isOpen) {
    await redis.connect();
  }

  await redis.ping();
}

app.get("/", (req, res) => {
  res.json({
    service: "api",
    status: "running"
  });
});

app.get("/api/health", async (req, res) => {
  try {
    await db.query("SELECT 1");
    const redisStatus = await redis.ping();

    res.json({
      status: "healthy",
      database: "connected",
      redis: redisStatus === "PONG" ? "connected" : "unhealthy"
    });
  } catch (error) {
    console.error("Health check failed:", error);

    res.status(503).json({
      status: "unhealthy",
      database: "unknown",
      redis: "unknown"
    });
  }
});

app.get("/api/users", async (req, res) => {
  try {
    const result = await db.query(
      "SELECT id, name, email, created_at FROM users ORDER BY id"
    );

    res.json(result.rows);
  } catch (error) {
    console.error("Database query failed:", error);
    res.status(500).json({
      error: "Failed to retrieve users"
    });
  }
});

app.get("/api/redis", async (req, res) => {
  try {
    const key = "compose:demo";

    await redis.set(key, "Redis is working");
    const value = await redis.get(key);

    res.json({
      status: "connected",
      key,
      value
    });
  } catch (error) {
    console.error("Redis operation failed:", error);
    res.status(500).json({
      error: "Redis operation failed"
    });
  }
});

async function start() {
  try {
    await checkDependencies();

    app.listen(port, () => {
      console.log(`API listening on port ${port}`);
      console.log("PostgreSQL connection: OK");
      console.log("Redis connection: OK");
    });
  } catch (error) {
    console.error("Failed to connect to dependencies:", error);
    process.exit(1);
  }
}

start();