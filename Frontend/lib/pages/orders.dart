import 'package:flutter/material.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/pages/order_details.dart';
import 'package:fruit_shop/services/image_resolver.dart';
import 'package:fruit_shop/utils/responsive.dart';
import 'package:fruit_shop/widgets/animated_sections.dart';

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
    final responsive = Responsive.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading orders...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: responsive.fontSize(14, 16),
              ),
            ),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: FadeInSlide(
          offset: const Offset(0, 30),
          duration: const Duration(milliseconds: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 60,
                  color: primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No orders yet',
                style: TextStyle(
                  fontSize: responsive.fontSize(22, 24),
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start shopping to see your orders here',
                style: TextStyle(
                  fontSize: responsive.fontSize(14, 16),
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Shop now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: primary,
      child: ListView.builder(
        padding: EdgeInsets.all(responsive.isMobile ? 12 : 16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          return StaggeredAnimation(
            index: index,
            duration: const Duration(milliseconds: 400),
            child: _buildOrderCard(context, index, responsive, primary),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    int index,
    Responsive responsive,
    Color primary,
  ) {
    final order = _orders[index];
    final createdAt =
        DateTime.tryParse(order['createdAt'] ?? '') ?? DateTime.now();
    final pricing = (order['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final total = (pricing['total'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (pricing['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final discount = (pricing['discount'] as num?)?.toDouble() ?? 0.0;
    final items = (order['items'] as List?)?.cast<Map>() ?? const [];
    final payment = (order['payment'] as Map?)?.cast<String, dynamic>() ?? {};
    final method = payment['method']?.toString() ?? '—';
    final status = payment['status']?.toString();
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: responsive.spacing(12, 16)),
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
      child: ExpansionTile(
        tilePadding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
        childrenPadding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                status == 'paid' ? Icons.check_circle : Icons.pending,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order['id']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: responsive.fontSize(16, 18),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    createdAt.toLocal().toString().split('.')[0],
                    style: TextStyle(
                      fontSize: responsive.fontSize(12, 14),
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(status, statusColor),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Paid via: $method',
                  style: TextStyle(
                    fontSize: responsive.fontSize(11, 12),
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '₹${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: responsive.fontSize(18, 20),
                  color: primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${items.length} item${items.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: responsive.fontSize(11, 12),
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        children: [
          Divider(height: 1, color: Colors.grey.shade300),
          SizedBox(height: responsive.spacing(12, 16)),
          ...items.map((raw) {
            final item = raw.cast<String, dynamic>();
            final name = item['name']?.toString() ?? 'Item';
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final measure = (item['measure'] as num?)?.toDouble() ?? 1.0;
            final unit = (item['unit'] as String?) ?? 'kg';
            final line = (item['lineTotal'] as num?)?.toDouble() ?? 0.0;
            final img = item['image']?.toString();
            return Container(
              margin: EdgeInsets.only(bottom: responsive.spacing(8, 12)),
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
                            width: responsive.isMobile ? 60 : 70,
                            height: responsive.isMobile ? 60 : 70,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : Container(
                            width: responsive.isMobile ? 60 : 70,
                            height: responsive.isMobile ? 60 : 70,
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
                            fontSize: responsive.fontSize(14, 16),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: $qty • $measure $unit',
                          style: TextStyle(
                            fontSize: responsive.fontSize(12, 14),
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${line.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: responsive.fontSize(16, 18),
                      color: primary,
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: responsive.spacing(12, 16)),
          Container(
            padding: EdgeInsets.all(responsive.isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Fee',
                      style: TextStyle(
                        fontSize: responsive.fontSize(14, 16),
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      deliveryFee == 0
                          ? 'FREE'
                          : '₹${deliveryFee.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: responsive.fontSize(14, 16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (discount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discount',
                        style: TextStyle(
                          fontSize: responsive.fontSize(14, 16),
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '-₹${discount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: responsive.fontSize(14, 16),
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: responsive.spacing(16, 20)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: responsive.isMobile ? 14 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
              ),
              SizedBox(width: responsive.spacing(12, 16)),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: responsive.isMobile ? 14 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Re-order'),
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
              ),
            ],
          ),
          SizedBox(height: responsive.spacing(12, 16)),
          _trackingTimeline(createdAt),
        ],
      ),
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

  Widget _statusChip(String? status, Color statusColor) {
    final normalized = (status ?? 'pending').toLowerCase();
    String label;
    switch (normalized) {
      case 'paid':
        label = 'Paid';
        break;
      case 'cod-pending':
        label = 'COD Pending';
        break;
      case 'upi-pending':
        label = 'UPI Pending';
        break;
      case 'card-pending':
        label = 'Card Pending';
        break;
      case 'failed':
        label = 'Failed';
        break;
      default:
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
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

  // _trackingChip removed (was unused)

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
