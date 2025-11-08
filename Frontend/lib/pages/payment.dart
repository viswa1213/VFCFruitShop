import 'package:flutter/material.dart';
import 'package:fruit_shop/services/razorpay_service.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:fruit_shop/services/payment_api.dart';
import 'package:fruit_shop/services/user_data_api.dart';
// Typed models
import 'package:fruit_shop/models/order_item.dart';
import 'package:fruit_shop/models/pricing.dart';
import 'package:fruit_shop/models/payment_info.dart';
import 'package:fruit_shop/models/address.dart';
import 'package:fruit_shop/models/order.dart';

class PaymentPage extends StatefulWidget {
  final double totalAmount;
  final String paymentMethod;
  final String? upiId;
  final String? cardNumber;
  final Map<String, dynamic>? orderContext;

  const PaymentPage({
    super.key,
    required this.totalAmount,
    required this.paymentMethod,
    this.upiId,
    this.cardNumber,
    this.orderContext,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String referenceNumber = "TXN${DateTime.now().millisecondsSinceEpoch}";
  bool _isPaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment"),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Total amount
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text(
                  "Total Amount",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  "₹${widget.totalAmount.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment details
            if (widget.paymentMethod == "UPI") ...[
              const Text(
                "Scan to Pay",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Image.asset("assets/images/QR.jpeg", height: 200, width: 200),
              const SizedBox(height: 10),
              Text("UPI ID: ${widget.upiId ?? 'Not provided'}"),
              Text(
                "Ref No: $referenceNumber",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else if (widget.paymentMethod == "Card") ...[
              const Text(
                "Pay with Card",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Card: **** **** **** ${widget.cardNumber?.substring(widget.cardNumber!.length - 4) ?? 'XXXX'}",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "Ref No: $referenceNumber",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else if (widget.paymentMethod == 'Razorpay') ...[
              const Text(
                "Razorpay Checkout",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("You'll be redirected to Razorpay's secure checkout."),
              Text(
                "Ref No: $referenceNumber",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else ...[
              const Text(
                "Cash on Delivery",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Pay the amount in cash when your order arrives."),
              Text(
                "Ref No: $referenceNumber",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],

            const Spacer(),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPaying
                    ? null
                    : () async {
                        if (widget.paymentMethod == 'Razorpay') {
                          await _payWithRazorpay();
                          return;
                        }
                        if (widget.paymentMethod == "Cash on Delivery") {
                          _showSuccessCod();
                        } else {
                          _showSuccess();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Confirm Payment",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess() {
    // Navigate straight to Orders tab after successful payment
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: {'initialTab': 1},
    );
  }

  void _showSuccessCod() {
    // For COD, skip any extra dialogs and go to Orders directly
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: {'initialTab': 1},
    );
  }

  Future<void> _payWithRazorpay() async {
    if (_isPaying) return;
    setState(() => _isPaying = true);
    try {
      final amountPaise = (widget.totalAmount * 100).round();
      // 1) Ask backend to create an order
      final createdOrder = await PaymentApi.createRazorpayOrder(
        amountPaise: amountPaise,
        receipt: referenceNumber,
      );

      // 2) Open Razorpay with order_id
      if (!mounted) return;
      final result = await RazorpayService.instance.pay(
        context: context,
        amountPaise: amountPaise,
        description: 'Payment $referenceNumber',
        orderId: (createdOrder['id'] as String?),
      );
      if (!mounted) return;

      // 3) Verify signature on backend
      final verified = await PaymentApi.verifyRazorpaySignature(
        orderId:
            (result['orderId'] as String?) ?? (createdOrder['id'] as String),
        paymentId: (result['paymentId'] as String?) ?? '',
        signature: (result['signature'] as String?) ?? '',
      );

      if (!mounted) return;

      if (!verified) {
        if (!mounted) return;
        AppSnack.showError(context, 'Payment verification failed');
        return;
      }

      // 4) Persist order using the orderContext
      final ctx = widget.orderContext ?? const {};
      final rawItems = (ctx['cartItems'] as List?)?.cast<Map>() ?? const [];
      final items = rawItems.map((item) {
        final price = (item['price'] as num).toDouble();
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final measure = (item['measure'] as num?)?.toDouble() ?? 1.0;
        final lineTotal = price * measure * qty;
        return OrderItem(
          name: item['name']?.toString(),
          price: price,
          quantity: qty,
          measure: measure,
          unit: (item['unit'] as String?) ?? 'kg',
          lineTotal: lineTotal,
          image: item['image']?.toString(),
        );
      }).toList();

      final pricing = (ctx['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
      double subtotal = (pricing['subtotal'] as num?)?.toDouble() ?? 0.0;
      double discount = (pricing['discount'] as num?)?.toDouble() ?? 0.0;
      double deliveryFee = (pricing['deliveryFee'] as num?)?.toDouble() ?? 0.0;
      double total = (pricing['total'] as num?)?.toDouble() ?? 0.0;
      if (subtotal == 0 || total == 0) {
        subtotal = items.fold<double>(0.0, (s, it) {
          final line = (it.lineTotal != null)
              ? (it.lineTotal as num).toDouble()
              : (it.price ?? 0).toDouble() *
                    (it.measure ?? 1).toDouble() *
                    (it.quantity ?? 1).toDouble();
          return s + line;
        });
        total = (subtotal - discount + deliveryFee).clamp(0, double.infinity);
      }

      // Build order model for persistence
      final orderModel = OrderModel(
        items: items,
        pricing: Pricing(
          subtotal: subtotal,
          discount: discount,
          deliveryFee: deliveryFee,
          total: total,
        ),
        payment: PaymentInfo(
          method: 'Razorpay',
          status: 'paid',
          razorpayPaymentId: result['paymentId']?.toString(),
        ),
        address: (ctx['address'] is Map)
            ? Address.fromJson((ctx['address'] as Map).cast<String, dynamic>())
            : null,
        deliverySlot: ctx['deliverySlot']?.toString(),
      );

      // Persist to backend (DB) only (no local storage)
      try {
        final result = await UserDataApi.createOrder(orderModel.toJson());
        if (result == null || (result.startsWith('ERROR:'))) {
          if (!mounted) return;
          final msg = (result is String && result.startsWith('ERROR:'))
              ? result.replaceFirst('ERROR:', '')
              : 'Unable to save order';
          AppSnack.showError(context, 'Failed to save order ($msg)');
          return;
        }
        // Clear server cart after successful order creation
        try {
          await UserDataApi.setCart(const []);
        } catch (_) {}
      } catch (e) {
        if (!mounted) return;
        AppSnack.showError(context, 'Failed to save order (${e.toString()})');
        return;
      }

      if (!mounted) return;

      AppSnack.showSuccess(context, 'Payment success: ${result['paymentId']}');
      // Go straight to Orders page
      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Razorpay Failed');
    } finally {
      // Ensure cleanup
      RazorpayService.instance.dispose();
      if (mounted) setState(() => _isPaying = false);
    }
  }
}
