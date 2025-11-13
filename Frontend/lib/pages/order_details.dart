import 'package:flutter/material.dart';
import 'package:fruit_shop/services/image_resolver.dart';
import 'package:fruit_shop/utils/responsive.dart';
import 'package:fruit_shop/widgets/animated_sections.dart';

class OrderDetailsPage extends StatelessWidget {
  final Map<String, dynamic> order;
  final void Function(List<Map<String, dynamic>> items) onReorder;

  const OrderDetailsPage({
    super.key,
    required this.order,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final createdAt =
        DateTime.tryParse(order['createdAt'] ?? '') ?? DateTime.now();
    final pricing = (order['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = (order['items'] as List?)?.cast<Map>() ?? const [];
    final payment = (order['payment'] as Map?)?.cast<String, dynamic>() ?? {};
    final address = (order['address'] as Map?)?.cast<String, dynamic>() ?? {};
    final status = payment['status']?.toString();
    final statusColor = _getStatusColor(status);

    final subtotal = (pricing['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (pricing['discount'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (pricing['deliveryFee'] as num?)?.toDouble() ?? 0;
    final total = (pricing['total'] as num?)?.toDouble() ?? 0;
    final trackingStage = _stageFromCreated(createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order #${order['id']}',
          style: TextStyle(
            fontSize: responsive.fontSize(20, 22),
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final cloned = items.map((raw) {
                  final item = raw.cast<String, dynamic>();
                  return {
                    'name': item['name'],
                    'price': item['price'],
                    'measure': item['measure'],
                    'unit': item['unit'],
                    'image': item['image'],
                    'quantity': item['quantity'] ?? 1,
                  };
                }).toList();
                onReorder(cloned);
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.replay, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status Card
            FadeInSlide(
              offset: const Offset(0, -20),
              duration: const Duration(milliseconds: 600),
              child: _buildStatusCard(
                context,
                responsive,
                primary,
                status,
                statusColor,
                createdAt,
              ),
            ),
            SizedBox(height: responsive.spacing(20, 24)),
            // Tracking Section
            FadeInSlide(
              offset: const Offset(-30, 0),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 100),
              child: _buildTrackingSection(
                context,
                responsive,
                createdAt,
                trackingStage,
              ),
            ),
            SizedBox(height: responsive.spacing(20, 24)),
            // Items Section
            FadeInSlide(
              offset: const Offset(-30, 0),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 200),
              child: _buildItemsSection(context, responsive, primary, items),
            ),
            SizedBox(height: responsive.spacing(20, 24)),
            // Address Section
            FadeInSlide(
              offset: const Offset(-30, 0),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 300),
              child: _buildAddressSection(context, responsive, address),
            ),
            SizedBox(height: responsive.spacing(20, 24)),
            // Payment Section
            FadeInSlide(
              offset: const Offset(-30, 0),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 400),
              child: _buildPaymentSection(
                context,
                responsive,
                payment,
                status,
                statusColor,
              ),
            ),
            SizedBox(height: responsive.spacing(20, 24)),
            // Pricing Section
            FadeInSlide(
              offset: const Offset(-30, 0),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 500),
              child: _buildPricingSection(
                context,
                responsive,
                primary,
                subtotal,
                discount,
                deliveryFee,
                total,
              ),
            ),
            SizedBox(height: responsive.spacing(24, 32)),
            // Re-order Button
            FadeInSlide(
              offset: const Offset(0, 30),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 600),
              child: _buildReorderButton(context, responsive, primary, items),
            ),
            SizedBox(height: responsive.spacing(20, 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    Responsive responsive,
    Color primary,
    String? status,
    Color statusColor,
    DateTime createdAt,
  ) {
    return Container(
      padding: EdgeInsets.all(responsive.isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.1),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              status == 'paid' ? Icons.check_circle : Icons.pending,
              color: statusColor,
              size: 40,
            ),
          ),
          SizedBox(height: responsive.spacing(16, 20)),
          Text(
            _getStatusLabel(status),
            style: TextStyle(
              fontSize: responsive.fontSize(22, 24),
              fontWeight: FontWeight.w800,
              color: statusColor,
            ),
          ),
          SizedBox(height: responsive.spacing(8, 12)),
          Text(
            'Placed on ${createdAt.toLocal().toString().split('.')[0]}',
            style: TextStyle(
              fontSize: responsive.fontSize(14, 16),
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSection(
    BuildContext context,
    Responsive responsive,
    DateTime createdAt,
    String trackingStage,
  ) {
    return _buildSection(
      context,
      responsive,
      'Tracking',
      Icons.local_shipping,
      _trackingTimeline(createdAt, trackingStage),
    );
  }

  Widget _buildItemsSection(
    BuildContext context,
    Responsive responsive,
    Color primary,
    List<Map> items,
  ) {
    return _buildSection(
      context,
      responsive,
      'Items (${items.length})',
      Icons.shopping_bag,
      Column(
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final raw = entry.value;
          final item = raw.cast<String, dynamic>();
          final name = item['name']?.toString() ?? 'Item';
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          final measure = (item['measure'] as num?)?.toDouble() ?? 1.0;
          final unit = (item['unit'] as String?) ?? 'kg';
          final line = (item['lineTotal'] as num?)?.toDouble() ?? 0.0;
          final img = item['image']?.toString();
          return StaggeredAnimation(
            index: idx,
            duration: const Duration(milliseconds: 400),
            child: Container(
              margin: EdgeInsets.only(bottom: responsive.spacing(12, 16)),
              padding: EdgeInsets.all(responsive.isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: img != null
                        ? ResolvedImage(
                            img,
                            width: responsive.isMobile ? 70 : 80,
                            height: responsive.isMobile ? 70 : 80,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : Container(
                            width: responsive.isMobile ? 70 : 80,
                            height: responsive.isMobile ? 70 : 80,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.shopping_bag),
                          ),
                  ),
                  SizedBox(width: responsive.spacing(12, 16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: responsive.fontSize(15, 17),
                          ),
                        ),
                        SizedBox(height: responsive.spacing(4, 6)),
                        Text(
                          'Qty: $qty • $measure $unit',
                          style: TextStyle(
                            fontSize: responsive.fontSize(13, 14),
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '₹${line.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: responsive.fontSize(16, 18),
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddressSection(
    BuildContext context,
    Responsive responsive,
    Map<String, dynamic> address,
  ) {
    return _buildSection(
      context,
      responsive,
      'Delivery Address',
      Icons.location_on,
      Container(
        padding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (address['name']?.toString().isNotEmpty ?? false)
              Text(
                address['name']?.toString() ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: responsive.fontSize(16, 18),
                ),
              ),
            if (address['name']?.toString().isNotEmpty ?? false)
              SizedBox(height: responsive.spacing(8, 12)),
            if (address['address']?.toString().isNotEmpty ?? false)
              Text(
                address['address']?.toString() ?? '',
                style: TextStyle(
                  fontSize: responsive.fontSize(14, 16),
                  color: Colors.grey.shade700,
                ),
              ),
            if (address['address']?.toString().isNotEmpty ?? false)
              SizedBox(height: responsive.spacing(4, 6)),
            Text(
              '${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['pincode'] ?? ''}',
              style: TextStyle(
                fontSize: responsive.fontSize(14, 16),
                color: Colors.grey.shade700,
              ),
            ),
            if ((address['landmark']?.toString() ?? '').isNotEmpty) ...[
              SizedBox(height: responsive.spacing(4, 6)),
              Text(
                'Landmark: ${address['landmark']}',
                style: TextStyle(
                  fontSize: responsive.fontSize(14, 16),
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (address['phone']?.toString().isNotEmpty ?? false) ...[
              SizedBox(height: responsive.spacing(8, 12)),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: responsive.spacing(8, 12)),
                  Text(
                    address['phone'] ?? '',
                    style: TextStyle(
                      fontSize: responsive.fontSize(14, 16),
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection(
    BuildContext context,
    Responsive responsive,
    Map<String, dynamic> payment,
    String? status,
    Color statusColor,
  ) {
    return _buildSection(
      context,
      responsive,
      'Payment',
      Icons.payment,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              _getStatusLabel(status),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: responsive.fontSize(13, 14),
              ),
            ),
          ),
          SizedBox(height: responsive.spacing(12, 16)),
          _buildInfoRow(
            responsive,
            'Method',
            payment['method']?.toString() ?? '—',
            Icons.credit_card,
          ),
          if (payment['paymentId'] != null) ...[
            SizedBox(height: responsive.spacing(8, 12)),
            _buildInfoRow(
              responsive,
              'Transaction ID',
              payment['paymentId']?.toString() ?? '',
              Icons.receipt,
            ),
          ],
          if (payment['upiId'] != null) ...[
            SizedBox(height: responsive.spacing(8, 12)),
            _buildInfoRow(
              responsive,
              'UPI ID',
              payment['upiId']?.toString() ?? '',
              Icons.account_circle,
            ),
          ],
          if (payment['cardLast4'] != null) ...[
            SizedBox(height: responsive.spacing(8, 12)),
            _buildInfoRow(
              responsive,
              'Card',
              '•••• ${payment['cardLast4']}',
              Icons.credit_card,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPricingSection(
    BuildContext context,
    Responsive responsive,
    Color primary,
    double subtotal,
    double discount,
    double deliveryFee,
    double total,
  ) {
    return _buildSection(
      context,
      responsive,
      'Pricing Breakdown',
      Icons.receipt_long,
      Container(
        padding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            _buildPriceRow(responsive, 'Subtotal', subtotal),
            if (discount > 0) ...[
              SizedBox(height: responsive.spacing(8, 12)),
              _buildPriceRow(
                responsive,
                'Discount',
                -discount,
                isDiscount: true,
              ),
            ],
            SizedBox(height: responsive.spacing(8, 12)),
            _buildPriceRow(
              responsive,
              'Delivery',
              deliveryFee,
              overrideLabel: deliveryFee == 0 ? 'Delivery (FREE)' : null,
            ),
            SizedBox(height: responsive.spacing(12, 16)),
            Divider(height: 1, color: Colors.grey.shade300),
            SizedBox(height: responsive.spacing(12, 16)),
            _buildPriceRow(
              responsive,
              'Total',
              total,
              isTotal: true,
              primary: primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderButton(
    BuildContext context,
    Responsive responsive,
    Color primary,
    List<Map> items,
  ) {
    return Material(
      color: primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          final cloned = items.map((raw) {
            final item = raw.cast<String, dynamic>();
            return {
              'name': item['name'],
              'price': item['price'],
              'measure': item['measure'],
              'unit': item['unit'],
              'image': item['image'],
              'quantity': item['quantity'] ?? 1,
            };
          }).toList();
          onReorder(cloned);
          Navigator.pop(context);
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_shopping_cart,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: responsive.spacing(12, 16)),
              Text(
                'Re-order All Items',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.fontSize(16, 18),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    Responsive responsive,
    String title,
    IconData icon,
    Widget content,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primary, size: 20),
              ),
              SizedBox(width: responsive.spacing(12, 16)),
              Text(
                title,
                style: TextStyle(
                  fontSize: responsive.fontSize(18, 20),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.spacing(16, 20)),
          content,
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
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        SizedBox(width: responsive.spacing(12, 16)),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: responsive.fontSize(14, 16),
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: responsive.fontSize(14, 16),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(
    Responsive responsive,
    String label,
    double value, {
    bool isDiscount = false,
    bool isTotal = false,
    String? overrideLabel,
    Color? primary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          overrideLabel ?? label,
          style: TextStyle(
            fontSize: responsive.fontSize(isTotal ? 18 : 15, isTotal ? 20 : 17),
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isTotal ? Colors.grey.shade900 : Colors.grey.shade700,
          ),
        ),
        Text(
          '₹${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: responsive.fontSize(isTotal ? 22 : 16, isTotal ? 24 : 18),
            fontWeight: FontWeight.w800,
            color: isDiscount
                ? Colors.green
                : isTotal
                ? (primary ?? Colors.grey.shade900)
                : Colors.grey.shade900,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    final normalized = (status ?? 'pending').toLowerCase();
    switch (normalized) {
      case 'paid':
        return Colors.green;
      case 'cod-pending':
        return Colors.orange;
      case 'upi-pending':
      case 'card-pending':
        return Colors.indigo;
      case 'failed':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _getStatusLabel(String? status) {
    final normalized = (status ?? 'pending').toLowerCase();
    switch (normalized) {
      case 'paid':
        return 'Paid';
      case 'cod-pending':
        return 'COD Pending';
      case 'upi-pending':
        return 'UPI Pending';
      case 'card-pending':
        return 'Card Pending';
      case 'failed':
        return 'Failed';
      default:
        return 'Pending';
    }
  }

  String _stageFromCreated(DateTime createdAt) {
    final minutes = DateTime.now().difference(createdAt).inMinutes;
    if (minutes < 5) return 'Order Placed';
    if (minutes < 15) return 'Preparing';
    if (minutes < 30) return 'Out for Delivery';
    return 'Delivered';
  }

  Widget _trackingTimeline(DateTime createdAt, String currentStage) {
    final stages = const [
      'Order Placed',
      'Preparing',
      'Out for Delivery',
      'Delivered',
    ];
    final currentIndex = stages.indexOf(currentStage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < stages.length; i++) ...[
              _stepDot(i <= currentIndex),
              if (i < stages.length - 1) _stepLine(i < currentIndex),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          children: [
            for (int i = 0; i < stages.length; i++)
              Text(
                stages[i],
                style: TextStyle(
                  fontSize: 12,
                  color: i <= currentIndex ? Colors.black87 : Colors.black38,
                  fontWeight: i <= currentIndex
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepDot(bool active) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey.shade300,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? Colors.green : Colors.grey.shade400,
          width: 2,
        ),
      ),
    );
  }

  Widget _stepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: active ? Colors.green : Colors.grey.shade300,
      ),
    );
  }
}
