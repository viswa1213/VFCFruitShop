import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fruit_shop/services/auth_service.dart';

class PaymentApi {
  static Uri _uri(String path) => Uri.parse('${AuthService.getBaseUrl()}$path');

  /// Calls backend to create a Razorpay order.
  static Future<Map<String, dynamic>> createRazorpayOrder({
    required int amountPaise,
    String currency = 'INR',
    String? receipt,
  }) async {
    final resp = await http.post(
      _uri('/api/payments/razorpay/create-order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amountPaise,
        'currency': currency,
        if (receipt != null) 'receipt': receipt,
      }),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create order: ${resp.statusCode} ${resp.body}');
  }

  /// Calls backend to verify Razorpay signature.
  static Future<bool> verifyRazorpaySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final resp = await http.post(
      _uri('/api/payments/razorpay/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      }),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (json['valid'] as bool?) ?? false;
    }
    return false;
  }
}
