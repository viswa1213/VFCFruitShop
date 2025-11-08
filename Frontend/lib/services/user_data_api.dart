import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fruit_shop/services/auth_service.dart';

class UserDataApi {
  static Uri _uri(String path) => Uri.parse('${AuthService.getBaseUrl()}$path');

  // ORDERS
  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    final headers = await AuthService.authHeaders();
    final resp = await http.get(_uri('/api/orders'), headers: headers);
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['orders'] as List?) ?? const [];
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to fetch orders: HTTP $code');
  }

  static Future<String?> createOrder(Map<String, dynamic> order) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.post(
      _uri('/api/orders'),
      headers: headers,
      body: jsonEncode(order),
    );
    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 201) {
        return data['id']?.toString();
      }
      // Attach error context for caller with validation details if present
      final msg = data['message'] ?? 'Unknown';
      final err = data['error'];
      final validation = data['validation'];
      String details = '$msg';
      if (err != null) details = '$details | $err';
      if (validation != null) {
        try {
          details = '$details | ${jsonEncode(validation)}';
        } catch (_) {}
      }
      return 'ERROR:${resp.statusCode}:$details';
    } catch (_) {
      return 'ERROR:${resp.statusCode}:Unparseable response';
    }
  }

  // CART
  static Future<List<Map<String, dynamic>>> getCart() async {
    final headers = await AuthService.authHeaders();
    final resp = await http.get(_uri('/api/user/me'), headers: headers);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
      final list = (user['cart'] as List?) ?? const [];
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to fetch cart');
  }

  static Future<bool> setCart(List<Map<String, dynamic>> cart) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.put(
      _uri('/api/user/cart'),
      headers: headers,
      body: jsonEncode({'cart': cart}),
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  // FAVORITES
  static Future<List<String>> getFavorites() async {
    final headers = await AuthService.authHeaders();
    final resp = await http.get(_uri('/api/user/me'), headers: headers);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
      final list = (user['favorites'] as List?) ?? const [];
      return list.map((e) => e.toString()).toList();
    }
    throw Exception('Failed to fetch favorites');
  }

  static Future<bool> setFavorites(List<String> favorites) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.put(
      _uri('/api/user/favorites'),
      headers: headers,
      body: jsonEncode({'favorites': favorites}),
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  // ADDRESS
  static Future<bool> setAddress(Map<String, dynamic> address) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.put(
      _uri('/api/user/address'),
      headers: headers,
      body: jsonEncode({'address': address}),
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  // ONE-SHOT HYDRATION (profile + cart + favorites + address + settings)
  static Future<Map<String, dynamic>?> getMe() async {
    final headers = await AuthService.authHeaders();
    final resp = await http.get(_uri('/api/user/me'), headers: headers);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['user'] as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // PROFILE UPDATE (basic)
  static Future<bool> updateProfile({String? name, String? phone}) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.put(
      _uri('/api/user/profile'),
      headers: headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      }),
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }
}
