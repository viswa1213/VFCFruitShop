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
      // Log for debugging, then normalize the error into a Map
      debugPrint(
        '[Razorpay] payment error code=${r.code} message=${r.message}',
      );
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
    // Extract RGB components from ARGB representation using the modern API
    final rgb = primary.toARGB32() & 0x00FFFFFF;
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

    // Open checkout inside a try/catch to capture sync errors thrown by the
    // native SDK (some SDK failures throw non-Exception objects). If open
    // throws, convert the error into a Map so callers get a consistent shape.
    try {
      _razorpay!.open(options);
    } catch (e, st) {
      // Map some common native error types to friendly messages.
      final typeName = e.runtimeType.toString();
      String friendlyMessage = e.toString();
      if (typeName.contains('NotInitialized') ||
          typeName.contains('NoInitializer')) {
        friendlyMessage =
            'Razorpay native SDK not initialized. Try a full rebuild (flutter clean && flutter run) and ensure the plugin is correctly installed for your platform.';
      } else if (typeName.contains('MissingPluginException')) {
        friendlyMessage =
            'Razorpay plugin is missing on the native platform. Ensure you rebuilt the app after adding the plugin.';
      }
      final errMap = {
        'status': 'error',
        'message': friendlyMessage,
        'raw': e.toString(),
        'type': typeName,
        'stack': st.toString(),
      };
      // Ensure completer receives a failure so callers awaiting the future
      // receive this normalized error as well.
      if (!completer.isCompleted) completer.completeError(errMap);
      _razorpay?.clear();
      _razorpay = null;
      // Also throw so callers that rely on thrown errors see something.
      throw errMap;
    }

    // When done, detach handlers to avoid leaks. Normalize any non-Map error
    // coming out of the completer to a Map with useful details.
    try {
      final result = await completer.future;
      _razorpay?.clear();
      _razorpay = null;
      return result;
    } catch (e, st) {
      _razorpay?.clear();
      _razorpay = null;
      if (e is Map) {
        // Already normalized by the SDK handler or above - rethrow to preserve
        // original stack trace where possible.
        rethrow;
      }
      final errMap = {
        'status': 'error',
        'message': e.toString(),
        'type': e.runtimeType.toString(),
        'stack': st.toString(),
      };
      throw errMap;
    }
  }
}
