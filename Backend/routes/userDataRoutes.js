const express = require('express');
const auth = require('../middleware/auth');
const User = require('../models/user');

const router = express.Router();

// Get profile + cart + favorites
router.get('/me', auth, async (req, res) => {
  const user = await User.findById(req.user._id).select('-password');
  res.json({ user });
});

// Update profile basics
router.put('/profile', auth, async (req, res) => {
  const { name, phone } = req.body;
  if (name) req.user.name = name;
  if (phone) req.user.phone = phone;
  try {
    await req.user.save();
    res.json({ ok: true, user: req.user });
  } catch (e) {
    let details;
    if (e && e.errors) {
      details = Object.entries(e.errors).map(([field, err]) => ({
        field,
        kind: err.kind,
        message: err.message,
        value: err.value,
      }));
    }
    return res.status(400).json({
      message: 'Invalid profile payload',
      error: e?.message,
      validation: details,
    });
  }
});

// Replace cart
router.put('/cart', auth, async (req, res) => {
  const { cart } = req.body;
  if (!Array.isArray(cart)) return res.status(400).json({ message: 'cart must be array' });
  req.user.cart = cart;
  await req.user.save();
  res.json({ ok: true, cart: req.user.cart });
});

// Replace favorites
router.put('/favorites', auth, async (req, res) => {
  const { favorites } = req.body;
  if (!Array.isArray(favorites)) return res.status(400).json({ message: 'favorites must be array' });
  req.user.favorites = favorites;
  await req.user.save();
  res.json({ ok: true, favorites: req.user.favorites });
});

// Update address
router.put('/address', auth, async (req, res) => {
  try {
    req.user.address = req.body.address || {};
    await req.user.save();
    return res.json({ ok: true, address: req.user.address });
  } catch (e) {
    let details;
    if (e && e.errors) {
      details = Object.entries(e.errors).map(([field, err]) => ({
        field,
        kind: err.kind,
        message: err.message,
        value: err.value,
      }));
    }
    return res.status(400).json({
      message: 'Invalid address payload',
      error: e?.message,
      validation: details,
    });
  }
});

// Update settings
router.put('/settings', auth, async (req, res) => {
  req.user.settings = { ...req.user.settings, ...(req.body.settings || {}) };
  await req.user.save();
  res.json({ ok: true, settings: req.user.settings });
});

module.exports = router;
