const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  category: { 
    type: String,
    enum: ['fruit', 'juice', 'other', 'soft_drink'],
    required: true,
  },
  price: { type: Number, required: true },
  unit: { type: String, default: 'kg' },
  stock: { type: Number, default: 0 },
  image: { type: String }, // could be URL or asset key
  description: { type: String },
  active: { type: Boolean, default: true },
}, { timestamps: true });

module.exports = mongoose.model('product', productSchema);
