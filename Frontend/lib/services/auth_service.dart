import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication API service
///
/// Base URL selection:
/// - Android emulator (default): http://10.0.2.2:5001
/// - iOS simulator/macOS (default): http://localhost:5001
/// - To use a different host/port, run with:
///   flutter run --dart-define=API_BASE_URL=http://your-host:5001
/// - Physical devices: prefer your Mac's LAN IP via API_BASE_URL (e.g., http://192.168.1.23:5001)
class AuthService {
  // Keys for persistence
  static const _kTokenKey = 'auth_token';
  static const _kUserKey = 'auth_user';

  // Determine base URL. Uses Android emulator loopback when on Android.
  static String get _baseUrl {
    // Allow compile-time override via --dart-define API_BASE_URL
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:5001' : 'http://localhost:5001';
  }

  static Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final resp = await http.post(
      _uri('/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final data = _decode(resp);
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      await _persistAuth(data);
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final resp = await http.post(
      _uri('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = _decode(resp);
    if (resp.statusCode == 200) {
      await _persistAuth(data);
    }
    return data;
  }

  /// Returns base URL chosen at runtime (helpful for diagnostics/UI)
  static String getBaseUrl() => _baseUrl;

  /// Returns standard headers including Authorization if a token exists
  static Future<Map<String, String>> authHeaders({
    Map<String, String>? extra,
  }) async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  static Map<String, dynamic> _decode(http.Response resp) {
    try {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode >= 200 && resp.statusCode < 300) return json;
      // Normalize error format
      return {
        'ok': false,
        'status': resp.statusCode,
        'message': json['message'] ?? 'Request failed (${resp.statusCode})',
        ...json,
      };
    } catch (_) {
      // Fallback: return raw body as message when not JSON
      final bodyText = resp.body.toString();
      return {
        'ok': false,
        'status': resp.statusCode,
        'message': bodyText.isNotEmpty
            ? bodyText
            : 'HTTP ${resp.statusCode} with empty body',
      };
    }
  }

  static Future<void> _persistAuth(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = data['token'] as String?;
    final user = data['user'];
    if (token != null) {
      await prefs.setString(_kTokenKey, token);
    }
    if (user != null) {
      await prefs.setString(_kUserKey, jsonEncode(user));
    }
  }

  static Future<bool> isAdmin() async {
    final user = await getCurrentUser();
    final role = user?['role']?.toString();
    return role == 'admin';
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
