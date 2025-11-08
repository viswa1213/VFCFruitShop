import 'package:flutter/material.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/pages/order_details.dart';

class OrdersPage extends StatefulWidget {
  final void Function(List<Map<String, dynamic>> items)? onReorder;
  const OrdersPage({super.key, this.onReorder});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final remote = await UserDataApi.fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = remote;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orders = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('No orders yet'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Shop now'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final createdAt =
              DateTime.tryParse(order['createdAt'] ?? '') ?? DateTime.now();
          final pricing =
              (order['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
          final total = (pricing['total'] as num?)?.toDouble() ?? 0.0;
          final deliveryFee =
              (pricing['deliveryFee'] as num?)?.toDouble() ?? 0.0;
          final discount = (pricing['discount'] as num?)?.toDouble() ?? 0.0;
          final items = (order['items'] as List?)?.cast<Map>() ?? const [];
          final payment =
              (order['payment'] as Map?)?.cast<String, dynamic>() ?? {};
          final method = payment['method']?.toString() ?? '—';
          final paymentId = payment['paymentId']?.toString();
          final status = payment['status']?.toString();

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              title: Text(
                'Order #${order['id']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${createdAt.toLocal()}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: -8,
                    children: [
                      _statusChip(status),
                      Chip(
                        label: Text('Paid via: $method'),
                        backgroundColor: Colors.grey.shade100,
                        visualDensity: VisualDensity.compact,
                        labelStyle: const TextStyle(fontSize: 12),
                      ),
                      if (paymentId != null)
                        Chip(
                          label: Text('Txn: $paymentId'),
                          backgroundColor: Colors.grey.shade100,
                          visualDensity: VisualDensity.compact,
                          labelStyle: const TextStyle(fontSize: 12),
                        ),
                      _trackingChip(createdAt),
                    ],
                  ),
                ],
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${items.length} item(s)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              children: [
                const Divider(height: 1),
                const SizedBox(height: 8),
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
                              width: 48,
                              height: 48,
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
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Delivery: ${deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toStringAsFixed(2)}'}',
                      ),
                      if (discount > 0)
                        Text(
                          'Discount: -₹${discount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.green),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('View Details'),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailsPage(
                              order: order,
                              onReorder: (itemsForReorder) {
                                if (widget.onReorder != null) {
                                  widget.onReorder!(itemsForReorder);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(
                        Icons.replay,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Re-order',
                        style: TextStyle(color: Colors.white),
                      ),
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
                        if (widget.onReorder != null) {
                          widget.onReorder!(cloned);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _trackingTimeline(createdAt),
              ],
            ),
          );
        },
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

  // Basic tracking based on elapsed time since order placement
  String _stageFromCreated(DateTime createdAt) {
    final minutes = DateTime.now().difference(createdAt).inMinutes;
    if (minutes < 5) return 'Order Placed';
    if (minutes < 15) return 'Preparing';
    if (minutes < 30) return 'Out for Delivery';
    return 'Delivered';
  }

  Widget _trackingChip(DateTime createdAt) {
    final stage = _stageFromCreated(createdAt);
    Color bg;
    Color fg;
    switch (stage) {
      case 'Order Placed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 'Preparing':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        break;
      case 'Out for Delivery':
        bg = Colors.deepPurple.shade50;
        fg = Colors.deepPurple.shade700;
        break;
      default:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
    }
    return Chip(
      label: Text(stage),
      backgroundColor: bg,
      labelStyle: TextStyle(
        color: fg,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
      avatar: const Icon(Icons.local_shipping, size: 16),
    );
  }

  Widget _trackingTimeline(DateTime createdAt) {
    final stages = const [
      'Order Placed',
      'Preparing',
      'Out for Delivery',
      'Delivered',
    ];
    final current = _stageFromCreated(createdAt);
    final currentIndex = stages.indexOf(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Tracking', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
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
