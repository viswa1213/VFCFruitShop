const User = require("../models/user");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

exports.register = async (req, res) => {
  try {
    console.log("Register request received:", req.body);
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: "Please provide name, email and password" });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      console.log("Registration failed: user exists:", email);
      return res.status(400).json({ message: "User already exists" });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const user = new User({ name, email, password: hashedPassword });
    await user.save();

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: "7d" });

    console.log("User registered:", user.email);
    return res.status(201).json({ token, user: { id: user._id, name: user.name, email: user.email } });
  } catch (error) {
    console.error("Registration error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

exports.login = async (req, res) => {
  try {
    console.log("Login request received:", req.body);
    const { email, password } = req.body;

    if (!email || !password) return res.status(400).json({ message: "Please provide email and password" });

    const user = await User.findOne({ email });
    if (!user) {
      console.log("Login failed: user not found:", email);
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      console.log("Login failed: invalid password for:", email);
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: "7d" });

    console.log("User logged in:", email);
    return res.status(200).json({ token, user: { id: user._id, name: user.name, email: user.email } });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
