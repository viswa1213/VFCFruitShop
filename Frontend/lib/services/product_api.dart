import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:fruit_shop/services/auth_service.dart';

class ProductApi {
  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${AuthService.getBaseUrl()}$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        ...query.map((key, value) => MapEntry(key, value.toString())),
      },
    );
  }

  static Future<List<Map<String, dynamic>>> fetchProducts({
    String? category,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (category != null && category.isNotEmpty) {
      query['category'] = category;
    }
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }

    final resp = await http.get(_uri('/api/products', query));
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['products'] as List?) ?? const [];
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to load products: HTTP $code');
  }

  static Future<Map<String, dynamic>> fetchProduct(String id) async {
    final resp = await http.get(_uri('/api/products/$id'));
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['product'] as Map).cast<String, dynamic>();
    }
    throw Exception('Failed to fetch product $id: HTTP $code');
  }

  static Future<List<Map<String, dynamic>>> fetchTrending({int limit = 10}) async {
    final resp = await http.get(_uri('/api/products/trending', {'limit': limit.toString()}));
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['products'] as List?) ?? const [];
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to load trending products: HTTP $code');
  }

  static Future<List<Map<String, dynamic>>> fetchOffers({int limit = 10}) async {
    final resp = await http.get(_uri('/api/products/offers', {'limit': limit.toString()}));
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['products'] as List?) ?? const [];
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to load offers: HTTP $code');
  }

  static Future<List<Map<String, dynamic>>> fetchFeatured({int limit = 10}) async {
    final resp = await http.get(_uri('/api/products/featured', {'limit': limit.toString()}));
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['products'] as List?) ?? const [];
      return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception('Failed to load featured products: HTTP $code');
  }

  static Future<Map<String, dynamic>> fetchStats() async {
    final resp = await http.get(_uri('/api/products/stats/overview'));
    final code = resp.statusCode;
    if (code >= 200 && code < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load statistics: HTTP $code');
  }
}
