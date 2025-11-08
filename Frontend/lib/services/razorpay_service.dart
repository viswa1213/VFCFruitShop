import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  RazorpayService._();
  static final RazorpayService instance = RazorpayService._();

  Razorpay? _razorpay;

  void _ensureInit() {
    _razorpay ??= Razorpay();
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  String? get keyId => dotenv.env['RAZORPAY_KEY_ID'];

  /// Opens Razorpay checkout and returns a result map when completed.
  /// For production, create orders and verify signature on your backend.
  Future<Map<String, dynamic>> pay({
    required BuildContext context,
    required int amountPaise,
    String currency = 'INR',
    String? orderId,
    String name = 'Fruit Shop',
    String description = 'Order Payment',
    String? prefillContact,
    String? prefillEmail,
  }) async {
    _ensureInit();
    final key = keyId;
    if (key == null || key.isEmpty) {
      throw Exception('Missing RAZORPAY_KEY_ID in .env');
    }

    final completer = Completer<Map<String, dynamic>>();

    void onSuccess(PaymentSuccessResponse r) {
      if (!completer.isCompleted) {
        completer.complete({
          'status': 'success',
          'paymentId': r.paymentId,
          'orderId': r.orderId,
          'signature': r.signature,
        });
      }
    }

    void onError(PaymentFailureResponse r) {
      if (!completer.isCompleted) {
        completer.completeError({
          'status': 'error',
          'code': r.code,
          'message': r.message,
        });
      }
    }

    void onExternalWallet(ExternalWalletResponse r) {
      // Optional: handle external wallet selection
      // Not completing the completer here; success will come via success callback
    }

    _razorpay!
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, onError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);

    final primary = Theme.of(context).colorScheme.primary;
    // Extract RGB from ARGB integer to avoid deprecated color channel accessors
    final rgb = primary.value & 0x00FFFFFF;
    final colorHex = '#${rgb.toRadixString(16).padLeft(6, '0')}';

    final options = {
      'key': key,
      'amount': amountPaise, // in paise
      'currency': currency,
      'name': name,
      'description': description,
      if (orderId != null) 'order_id': orderId,
      'prefill': {
        if (prefillContact != null) 'contact': prefillContact,
        if (prefillEmail != null) 'email': prefillEmail,
      },
      'theme': {'color': colorHex},
    };

    _razorpay!.open(options);

    // When done, detach handlers to avoid leaks
    try {
      final result = await completer.future;
      _razorpay?.clear();
      _razorpay = null;
      return result;
    } catch (e) {
      _razorpay?.clear();
      _razorpay = null;
      rethrow;
    }
  }
}
