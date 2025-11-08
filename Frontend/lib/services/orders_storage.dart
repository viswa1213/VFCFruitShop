import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local persistence for Orders using SharedPreferences.
/// Stores a JSON-encoded array of order maps under a single key.
class OrdersStorage {
  static const String _kOrdersKey = 'orders_v1';

  /// Load all saved orders as a List<Map> (most recent first).
  static Future<List<Map<String, dynamic>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kOrdersKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final List list = jsonDecode(raw) as List;
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Append a new order to storage. Newest orders are placed first.
  static Future<void> add(Map<String, dynamic> order) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadAll();
    final List<Map<String, dynamic>> updated = [order, ...existing];
    await prefs.setString(_kOrdersKey, jsonEncode(updated));
  }

  /// Replace all orders with the provided list.
  static Future<void> saveAll(List<Map<String, dynamic>> orders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOrdersKey, jsonEncode(orders));
  }

  /// Clear all saved orders.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOrdersKey);
  }
}
