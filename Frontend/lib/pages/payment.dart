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
import 'package:fruit_shop/utils/responsive.dart';
import 'package:fruit_shop/widgets/animated_sections.dart';

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
    final responsive = Responsive.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Payment",
          style: TextStyle(
            fontSize: responsive.fontSize(20, 22),
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, Color.lerp(primary, Colors.white, 0.2)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
        child: Column(
          children: [
            // Total amount card
            FadeInSlide(
              offset: const Offset(0, -20),
              duration: const Duration(milliseconds: 600),
              child: _buildAmountCard(responsive, primary),
            ),
            SizedBox(height: responsive.spacing(24, 32)),
            // Payment details
            FadeInSlide(
              offset: const Offset(-30, 0),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 100),
              child: _buildPaymentDetails(responsive, primary),
            ),
            SizedBox(height: responsive.spacing(32, 40)),
            // Confirm Button
            FadeInSlide(
              offset: const Offset(0, 30),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 200),
              child: _buildConfirmButton(responsive, primary),
            ),
            SizedBox(height: responsive.spacing(20, 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(Responsive responsive, Color primary) {
    return Container(
      padding: EdgeInsets.all(responsive.isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.1),
            primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total Amount",
                style: TextStyle(
                  fontSize: responsive.fontSize(16, 18),
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: responsive.spacing(8, 12)),
              Text(
                "₹${widget.totalAmount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: responsive.fontSize(32, 36),
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payment, color: primary, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails(Responsive responsive, Color primary) {
    return Container(
      padding: EdgeInsets.all(responsive.isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (widget.paymentMethod == "UPI") ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.qr_code, color: Colors.blue, size: 32),
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            Text(
              "Scan to Pay",
              style: TextStyle(
                fontSize: responsive.fontSize(20, 22),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Image.asset(
                "assets/images/QR.jpeg",
                height: responsive.isMobile ? 200 : 250,
                width: responsive.isMobile ? 200 : 250,
              ),
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            _buildInfoRow(
              responsive,
              'UPI ID',
              widget.upiId ?? 'Not provided',
              Icons.account_circle,
            ),
            SizedBox(height: responsive.spacing(8, 12)),
            _buildInfoRow(
              responsive,
              'Reference',
              referenceNumber,
              Icons.receipt,
            ),
          ] else if (widget.paymentMethod == "Card") ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.credit_card, color: Colors.purple, size: 32),
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            Text(
              "Pay with Card",
              style: TextStyle(
                fontSize: responsive.fontSize(20, 22),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            _buildInfoRow(
              responsive,
              'Card',
              "**** **** **** ${widget.cardNumber?.substring(widget.cardNumber!.length - 4) ?? 'XXXX'}",
              Icons.credit_card,
            ),
            SizedBox(height: responsive.spacing(8, 12)),
            _buildInfoRow(
              responsive,
              'Reference',
              referenceNumber,
              Icons.receipt,
            ),
          ] else if (widget.paymentMethod == 'Razorpay') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.security, color: Colors.indigo, size: 32),
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            Text(
              "Razorpay Checkout",
              style: TextStyle(
                fontSize: responsive.fontSize(20, 22),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: responsive.spacing(12, 16)),
            Text(
              "You'll be redirected to Razorpay's secure checkout.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.fontSize(14, 16),
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            _buildInfoRow(
              responsive,
              'Reference',
              referenceNumber,
              Icons.receipt,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.money, color: Colors.orange, size: 32),
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            Text(
              "Cash on Delivery",
              style: TextStyle(
                fontSize: responsive.fontSize(20, 22),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: responsive.spacing(12, 16)),
            Text(
              "Pay the amount in cash when your order arrives.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.fontSize(14, 16),
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            _buildInfoRow(
              responsive,
              'Reference',
              referenceNumber,
              Icons.receipt,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    Responsive responsive,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(responsive.isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          SizedBox(width: responsive.spacing(12, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: responsive.fontSize(12, 14),
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: responsive.spacing(4, 6)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: responsive.fontSize(14, 16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(Responsive responsive, Color primary) {
    return Material(
      color: primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _isPaying
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: responsive.isMobile ? 16 : 18,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primary, primary.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _isPaying
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(width: responsive.spacing(12, 16)),
                    Text(
                      "Processing...",
                      style: TextStyle(
                        fontSize: responsive.fontSize(16, 18),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: responsive.spacing(12, 16)),
                    Text(
                      "Confirm Payment",
                      style: TextStyle(
                        fontSize: responsive.fontSize(16, 18),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
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
      Map<String, dynamic> createdOrder;
      try {
        createdOrder = await PaymentApi.createRazorpayOrder(
          amountPaise: amountPaise,
          receipt: referenceNumber,
        );
      } catch (err) {
        // Surface backend error message if available
        final msg = err is Exception ? err.toString() : '$err';
        if (!mounted) return;
        AppSnack.showError(context, 'Failed to create order: $msg');
        return;
      }

      // 2) Open Razorpay with order_id
      if (!mounted) return;
      Map<String, dynamic> result;
      try {
        result = await RazorpayService.instance.pay(
          context: context,
          amountPaise: amountPaise,
          description: 'Payment $referenceNumber',
          orderId: (createdOrder['id'] as String?),
        );
      } catch (err) {
        // RazorpayService completes errors as a Map via completer.completeError
        if (err is Map) {
          final message = err['message']?.toString() ?? err.toString();
          if (!mounted) return;
          AppSnack.showError(context, 'Razorpay error: $message');
        } else {
          if (!mounted) return;
          AppSnack.showError(context, 'Razorpay error: ${err.toString()}');
        }
        return;
      }
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
      // Try to show a helpful message when possible
      if (e is Map) {
        final msg = e['message']?.toString() ?? e.toString();
        AppSnack.showError(context, 'Razorpay Failed: $msg');
      } else {
        AppSnack.showError(context, 'Razorpay Failed: ${e.toString()}');
      }
    } finally {
      // Ensure cleanup
      RazorpayService.instance.dispose();
      if (mounted) setState(() => _isPaying = false);
    }
  }
}
