const express = require('express');
const auth = require('../middleware/auth');
const Order = require('../models/order');

const router = express.Router();

// List my orders (newest first)
router.get('/', auth, async (req, res) => {
  const orders = await Order.find({ user: req.user._id }).sort({ createdAt: -1 });
  // Normalize id field for frontend convenience
  const data = orders.map((o) => ({
    id: o._id.toString(),
    createdAt: o.createdAt,
    items: o.items,
    pricing: o.pricing,
    deliverySlot: o.deliverySlot,
    payment: o.payment,
    address: o.address,
  }));
  res.json({ orders: data });
});

// Create an order
router.post('/', auth, async (req, res) => {
  const body = req.body || {};
  try {
    console.log('[POST /api/orders] incoming body:', JSON.stringify(body));
    if (!Array.isArray(body.items) || body.items.length === 0) {
      return res.status(400).json({
        message: 'Order must include at least one item',
      });
    }
    const order = new Order({
      user: req.user._id,
      items: body.items,
      pricing: body.pricing || {},
      deliverySlot: body.deliverySlot,
      payment: body.payment || {},
      address: body.address || {},
    });
    await order.save();
    console.log('[POST /api/orders] saved order id:', order._id.toString());
    return res.status(201).json({ id: order._id.toString() });
  } catch (e) {
    console.error('[POST /api/orders] error name:', e?.name);
    console.error('[POST /api/orders] error message:', e?.message);
    let details;
    if (e && e.errors) {
      details = Object.entries(e.errors).map(([field, err]) => ({
        field,
        kind: err.kind,
        message: err.message,
        value: err.value,
      }));
      console.error('[POST /api/orders] validation details:', details);
    }
    return res.status(400).json({
      message: 'Invalid order payload',
      error: e?.message,
      validation: details,
    });
  }
});

module.exports = router;
