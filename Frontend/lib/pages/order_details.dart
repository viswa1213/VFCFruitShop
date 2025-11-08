import 'package:flutter/material.dart';

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
    final createdAt =
        DateTime.tryParse(order['createdAt'] ?? '') ?? DateTime.now();
    final pricing = (order['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = (order['items'] as List?)?.cast<Map>() ?? const [];
    final payment = (order['payment'] as Map?)?.cast<String, dynamic>() ?? {};
    final address = (order['address'] as Map?)?.cast<String, dynamic>() ?? {};
    final status = payment['status']?.toString();

    final subtotal = (pricing['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (pricing['discount'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (pricing['deliveryFee'] as num?)?.toDouble() ?? 0;
    final total = (pricing['total'] as num?)?.toDouble() ?? 0;
    final trackingStage = _stageFromCreated(createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order['id']}'),
        actions: [
          IconButton(
            tooltip: 'Re-order all items',
            icon: const Icon(Icons.replay),
            onPressed: () {
              final cloned = items.map((raw) {
                final item = raw.cast<String, dynamic>();
                return {
                  'name': item['name'],
                  'price': item['price'],
                  'measure': item['measure'],
                  'unit': item['unit'],
                  'image': item['image'],
                  // default quantity 1 when reordering (can adjust later)
                  'quantity': item['quantity'] ?? 1,
                };
              }).toList();
              onReorder(cloned);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'Placed On'),
            Text('${createdAt.toLocal()}'),
            const SizedBox(height: 12),
            _sectionHeader(context, 'Tracking'),
            _trackingTimeline(createdAt, trackingStage),
            const SizedBox(height: 16),
            _sectionHeader(context, 'Items'),
            ...items.map((raw) {
              final item = raw.cast<String, dynamic>();
              final name = item['name']?.toString() ?? 'Item';
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final measure = (item['measure'] as num?)?.toDouble() ?? 1.0;
              final unit = (item['unit'] as String?) ?? 'kg';
              final line = (item['lineTotal'] as num?)?.toDouble() ?? 0.0;
              final img = item['image']?.toString();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: img != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          img,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.shopping_bag),
                title: Text(name),
                subtitle: Text('Qty: $qty • $measure$unit'),
                trailing: Text(
                  '₹${line.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
            const Divider(height: 32),
            _sectionHeader(context, 'Delivery Address'),
            Text(address['name']?.toString() ?? ''),
            Text(address['address']?.toString() ?? ''),
            Text(
              '${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['pincode'] ?? ''}',
            ),
            if ((address['landmark']?.toString() ?? '').isNotEmpty)
              Text('Landmark: ${address['landmark']}'),
            Text('Phone: ${address['phone'] ?? ''}'),
            const SizedBox(height: 16),
            _sectionHeader(context, 'Payment'),
            Wrap(
              spacing: 8,
              runSpacing: -8,
              children: [
                _statusChip(status),
                Chip(
                  label: Text('Method: ${payment['method'] ?? ''}'),
                  backgroundColor: Colors.grey.shade100,
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                if (payment['paymentId'] != null)
                  Chip(
                    label: Text('Txn: ${payment['paymentId']}'),
                    backgroundColor: Colors.grey.shade100,
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            if (payment['upiId'] != null) Text('UPI: ${payment['upiId']}'),
            if (payment['cardLast4'] != null)
              Text('Card: •••• ${payment['cardLast4']}'),
            const SizedBox(height: 16),
            _sectionHeader(context, 'Pricing Breakdown'),
            _priceRow('Subtotal', subtotal),
            if (discount > 0)
              _priceRow('Discount', -discount, valueColor: Colors.green),
            _priceRow(
              'Delivery',
              deliveryFee == 0 ? 0 : deliveryFee,
              overrideLabel: deliveryFee == 0 ? 'Delivery (FREE)' : null,
            ),
            const Divider(height: 24),
            _priceRow('Total', total, isBold: true),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
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
                style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: const Text(
                  'Re-order Items',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6.0),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _priceRow(
    String label,
    double value, {
    bool isBold = false,
    Color? valueColor,
    String? overrideLabel,
  }) {
    final display = overrideLabel ?? label;
    final valueStr =
        (label == 'Discount' ? '-₹' : '₹') + value.abs().toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            display,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            valueStr,
            style: TextStyle(
              fontSize: isBold ? 17 : 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String? status) {
    final normalized = (status ?? 'pending').toLowerCase();
    Color bg;
    Color fg;
    String label;
    switch (normalized) {
      case 'paid':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'Paid';
        break;
      case 'cod-pending':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'COD Pending';
        break;
      case 'upi-pending':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade700;
        label = 'UPI Pending';
        break;
      case 'card-pending':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        label = 'Card Pending';
        break;
      case 'failed':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'Failed';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = 'Pending';
    }
    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(
        color: fg,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
    );
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
