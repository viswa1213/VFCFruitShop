const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const dotenv = require("dotenv");

dotenv.config();
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Basic request logger to help debug routing issues
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  next();
});

// Connect MongoDB
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("✅ MongoDB connected"))
  .catch(err => console.error("❌ MongoDB error:", err));

// Routes
app.use("/api/auth", require("./routes/authRoutes"));

app.get("/sample", (req, res) => {
  res.send("🚀 Backend is running...");
  console.log("connected");
});

// Start server
const PORT = process.env.PORT || 5001;
app.listen(PORT, () => console.log(`✅ Server running on port ${PORT}`));
