const mongoose = require('mongoose');

// Shared embedded address schema used by User and Order models.
// Keep minimal validation (all optional) to avoid rejects from partial forms; enhance later if needed.
const addressSchema = new mongoose.Schema(
  {
    name: { type: String, required: [true, 'Recipient name is required'] },
    phone: {
      type: String,
      required: [true, 'Phone is required'],
      match: [/^\d{10,15}$/u, 'Phone must be 10-15 digits'],
    },
    address: { type: String },
    landmark: { type: String },
    city: { type: String },
    state: { type: String },
    pincode: {
      type: String,
      required: [true, 'Pincode is required'],
      match: [/^\d{6}$/u, 'Pincode must be 6 digits'],
    },
    type: { type: String },
    default: { type: Boolean, default: false }, // only meaningful for User
  },
  { _id: false }
);

module.exports = addressSchema;
