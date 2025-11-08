import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AddressStorage {
  static const _kSavedAddress = 'saved_address_v1';

  static Future<void> save(Map<String, dynamic> address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSavedAddress, jsonEncode(address));
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kSavedAddress);
    if (str == null || str.isEmpty) return null;
    try {
      final data = jsonDecode(str) as Map<String, dynamic>;
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedAddress);
  }
}
