const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");
const pool = require("./db");

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get("/api/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");

    res.json({
      status: "healthy",
      application: "AWS DevOps Assessment",
      database: "connected"
    });
  } catch (error) {
    console.error("Database health check failed:", error.message);

    res.status(500).json({
      status: "unhealthy",
      application: "AWS DevOps Assessment",
      database: "disconnected"
    });
  }
});

app.get("/api/users", async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT id, name, email FROM users ORDER BY id"
    );

    res.json(rows);
  } catch (error) {
    console.error("Failed to fetch users:", error.message);

    res.status(500).json({
      error: "Failed to fetch users"
    });
  }
});

app.get("/", (req, res) => {
  res.json({
    message: "AWS DevOps Assessment Backend",
    status: "running"
  });
});

app.get('/health', (req, res) => res.status(200).json({ status: 'ok' }));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Backend running on port ${PORT}`);
});
