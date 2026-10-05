const express = require("express");
const cors = require("cors");

const { pool, initializeDatabase } = require("./db");
const tasksRouter = require("./routes/tasks");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get("/api/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");

    res.json({
      status: "healthy",
      service: "cloudtasks-api",
      database: "connected",
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      status: "unhealthy",
      database: "disconnected",
    });
  }
});

app.use("/api/tasks", tasksRouter);

initializeDatabase()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`CloudTasks API running on port ${PORT}`);
    });
  })
  .catch((error) => {
    console.error("Database initialization failed:", error);
    process.exit(1);
  });
