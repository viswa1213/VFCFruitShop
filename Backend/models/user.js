const mongoose = require("mongoose");
const addressSchema = require("./schemas/address");

const cartItemSchema = new mongoose.Schema(
  {
    name: String,
    price: Number,
    quantity: { type: Number, default: 1 },
    measure: { type: Number, default: 1 },
    unit: { type: String, default: 'kg' },
    image: String,
    lineTotal: Number,
  },
  { _id: false }
);

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    // Top-level phone added so profile can store primary mobile separate from address.phone
    phone: { type: String, match: [/^\d{10,15}$/u, 'Phone must be 10-15 digits'] },
    cart: { type: [cartItemSchema], default: [] },
    favorites: { type: [String], default: [] },
    address: { type: addressSchema, default: {} },
    settings: {
      themeMode: { type: String, enum: ['light', 'dark', 'system'], default: 'system' },
      accentColor: { type: String },
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("user", userSchema);
