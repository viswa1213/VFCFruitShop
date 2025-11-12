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
        final user = (data['user'] as Map?)?.cast<String, dynamic>();
        if (user != null) {
          await AuthService.syncUserCache(user);
        }
        return user;
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
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = (data['user'] as Map?)?.cast<String, dynamic>();
        if (user != null) {
          await AuthService.syncUserCache(user);
        } else {
          await AuthService.syncUserCache({
            if (name != null) 'name': name,
            if (phone != null) 'phone': phone,
          });
        }
      } catch (_) {
        await AuthService.syncUserCache({
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
        });
      }
      return true;
    }
    return false;
  }

  static Future<String?> uploadAvatar({
    required List<int> bytes,
    String filename = 'avatar.jpg',
  }) async {
    final uri = _uri('/api/user/avatar');
    final request = http.MultipartRequest('POST', uri);
    final token = await AuthService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes('avatar', bytes, filename: filename),
    );

    final resp = await request.send();
    final body = await resp.stream.bytesToString();
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final user = (data?['user'] as Map?)?.cast<String, dynamic>();
      final avatarUrl =
          data?['avatarUrl']?.toString() ?? user?['avatarUrl']?.toString();
      if (user != null) {
        await AuthService.syncUserCache(user);
      } else if (avatarUrl != null) {
        await AuthService.syncUserCache({'avatarUrl': avatarUrl});
      }
      return avatarUrl;
    }

    final message = data?['message'] ?? 'Avatar upload failed';
    throw Exception('Avatar upload failed (${resp.statusCode}): $message');
  }

  // =====================
  // ADMIN API
  // =====================

  static Future<bool> adminPing() async {
    final headers = await AuthService.authHeaders();
    final resp = await http.get(_uri('/api/admin/ping'), headers: headers);
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  // SALES
  static Future<String?> createSale(Map<String, dynamic> sale) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.post(
      _uri('/api/sales'),
      headers: headers,
      body: jsonEncode(sale),
    );
    if (resp.statusCode == 201) {
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['id']?.toString();
      } catch (_) {
        return null;
      }
    }
    throw Exception('Failed to create sale: HTTP ${resp.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> adminListProducts({
    String? category,
  }) async {
    final headers = await AuthService.authHeaders();
    final path = category == null
        ? '/api/admin/products'
        : '/api/admin/products?category=$category';
    final resp = await http.get(_uri(path), headers: headers);
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['products'] as List?) ?? const [];
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to list products: HTTP $code');
  }

  static Future<Map<String, dynamic>> adminCreateProduct(
    Map<String, dynamic> product,
  ) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.post(
      _uri('/api/admin/products'),
      headers: headers,
      body: jsonEncode(product),
    );
    final code = resp.statusCode;
    if (code == 201 || (code >= 200 && code < 300)) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Create product failed: HTTP $code ${resp.body}');
  }

  static Future<Map<String, dynamic>> adminUpdateProduct(
    String id,
    Map<String, dynamic> patch,
  ) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.put(
      _uri('/api/admin/products/$id'),
      headers: headers,
      body: jsonEncode(patch),
    );
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Update product failed: HTTP $code ${resp.body}');
  }

  static Future<Map<String, dynamic>> adminUploadProductImage(
    String id,
    List<int> bytes, {
    String filename = 'image.jpg',
  }) async {
    final uri = _uri('/api/admin/products/$id/image');
    final request = http.MultipartRequest('POST', uri);
    final token = await AuthService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
    final streamed = await request.send();
    final respBody = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return jsonDecode(respBody) as Map<String, dynamic>;
    }
    throw Exception(
      'Image upload failed: HTTP ${streamed.statusCode} $respBody',
    );
  }

  static Future<bool> adminDeleteProduct(String id) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.delete(
      _uri('/api/admin/products/$id'),
      headers: headers,
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  static Future<List<Map<String, dynamic>>> adminListOrders() async {
    final headers = await AuthService.authHeaders();
    final resp = await http.get(_uri('/api/admin/orders'), headers: headers);
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['orders'] as List?) ?? const [];
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to list orders: HTTP $code');
  }

  static Future<bool> adminUpdateOrderStatus(String id, String status) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.patch(
      _uri('/api/admin/orders/$id/status'),
      headers: headers,
      body: jsonEncode({'status': status}),
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  static Future<List<Map<String, dynamic>>> adminListUsers() async {
    final headers = await AuthService.authHeaders();
    final resp = await http.get(_uri('/api/admin/users'), headers: headers);
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['users'] as List?) ?? const [];
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to list users: HTTP $code');
  }

  static Future<Map<String, dynamic>> adminGetUser(String id) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.get(_uri('/api/admin/users/$id'), headers: headers);
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get user: HTTP $code');
  }

  static Future<bool> adminUpdateUserRole(String id, String role) async {
    final headers = await AuthService.authHeaders();
    final resp = await http.patch(
      _uri('/api/admin/users/$id/role'),
      headers: headers,
      body: jsonEncode({'role': role}),
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  static Future<Map<String, dynamic>> adminSummary() async {
    final headers = await AuthService.authHeaders();
    final resp = await http.get(_uri('/api/admin/summary'), headers: headers);
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load admin summary: HTTP $code');
  }

  // ----------------- END ADMIN ENDPOINTS -----------------
}
