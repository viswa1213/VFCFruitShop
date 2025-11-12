import 'package:flutter/material.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/image_resolver.dart';
import 'package:fruit_shop/utils/responsive.dart';
import 'package:fruit_shop/widgets/animated_sections.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';

import 'checkout.dart'; // make sure this path is correct

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const CartPage({super.key, required this.cartItems});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Map<String, int> quantities = {};
  late List<Map<String, dynamic>> items;
  // removed debounce fields

  List<Map<String, dynamic>> _buildPayload() {
    return items.map((item) {
      final id = item['cartId'] as String?;
      return {
        'name': item['name'],
        'image': item['image'],
        'price': item['price'],
        'measure':
            (item['measure'] as num?)?.toDouble() ??
            (item['weightKg'] as num?)?.toDouble() ??
            1.0,
        'unit': item['unit'] ?? 'kg',
        'quantity':
            (id != null
                    ? (quantities[id] ?? (item['quantity'] as num? ?? 1))
                    : (item['quantity'] as num? ?? 1))
                .toInt(),
      };
    }).toList();
  }

  Future<void> _syncImmediate() async {
    try {
      await UserDataApi.setCart(_buildPayload());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sync cart to server')),
        );
      }
    }
  }

  void _removeItemAt(int index) {
    if (index < 0 || index >= items.length) return;
    final fruit = items[index];
    final id = fruit['cartId'] as String?;
    setState(() {
      items.removeAt(index);
      if (id != null) {
        quantities.remove(id);
      }
    });
    _syncImmediate();
  }

  Widget _quantityControls(BuildContext context, String id, int qty) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (qty > 1) {
                    quantities[id] = qty - 1;
                  }
                });
                _syncImmediate();
              },
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(
                  Icons.remove_rounded,
                  color: qty > 1 ? Colors.red : Colors.grey,
                  size: 20,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              qty.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  quantities[id] = qty + 1;
                });
                _syncImmediate();
              },
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(Icons.add_rounded, color: primary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // (Removed debounced sync; we now sync immediately for simplicity)

  @override
  void initState() {
    super.initState();
    items = widget.cartItems.map((e) => Map<String, dynamic>.from(e)).toList();
    final seed = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < items.length; i++) {
      items[i]['cartId'] ??= 'cart-$seed-$i-${items[i]['name']}';
    }
    for (var item in items) {
      final id = item['cartId'] as String;
      final initialQty = (item['quantity'] as num?)?.toInt() ?? 1;
      quantities[id] = initialQty;
    }
  }

  double get total {
    double sum = 0;
    for (var item in items) {
      final id = item['cartId'] as String;
      final qty = quantities[id] ?? 1;
      final pricePerKg = (item['price'] as num).toDouble();
      final measure =
          (item['measure'] as num?)?.toDouble() ??
          (item['weightKg'] as num?)?.toDouble() ??
          1.0;
      // price field is assumed to be per unit (kg or L) depending on item['unit']
      sum += pricePerKg * measure * qty;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, items.map((e) => {...e}).toList());
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(
            "Your Cart",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: responsive.fontSize(20, 22),
            ),
          ),
          backgroundColor: primary,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: items.isEmpty
            ? _buildEmptyCart(responsive, primary)
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(responsive.isMobile ? 12 : 16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return StaggeredAnimation(
                          index: index,
                          duration: const Duration(milliseconds: 400),
                          child: _buildCartItem(
                            context,
                            index,
                            responsive,
                            primary,
                          ),
                        );
                      },
                    ),
                  ),
                  _buildBottomSummary(responsive, primary),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyCart(Responsive responsive, Color primary) {
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
                Icons.shopping_cart_outlined,
                size: 60,
                color: primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Your cart is empty",
              style: TextStyle(
                fontSize: responsive.fontSize(22, 24),
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Add some fresh fruits to get started!",
              style: TextStyle(
                fontSize: responsive.fontSize(14, 16),
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Start Shopping'),
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

  Widget _buildCartItem(
    BuildContext context,
    int index,
    Responsive responsive,
    Color primary,
  ) {
    final fruit = items[index];
    final id = fruit['cartId'] as String;
    final qty = quantities[id] ?? 1;
    final measure =
        (fruit['measure'] as num?)?.toDouble() ??
        (fruit['weightKg'] as num?)?.toDouble() ??
        1.0;
    final unit = (fruit['unit'] as String?) ?? 'kg';
    final pricePerUnit = (fruit['price'] as num).toDouble();
    final priceStr = pricePerUnit.toStringAsFixed(2);
    final measureStr = measure.toString();
    final name = (fruit['name'] ?? 'Unknown item').toString();
    final itemTotal = pricePerUnit * measure * qty;

    return Dismissible(
      key: ValueKey<String>(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.symmetric(vertical: responsive.isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        _removeItemAt(index);
        AppSnack.showSuccess(context, '$name removed from cart');
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: responsive.isMobile ? 8 : 12),
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
        child: Padding(
          padding: EdgeInsets.all(responsive.isMobile ? 12 : 16),
          child: Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: responsive.isMobile ? 80 : 100,
                  height: responsive.isMobile ? 80 : 100,
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  child: _buildProductImage(fruit),
                ),
              ),
              SizedBox(width: responsive.spacing(12, 16)),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: responsive.fontSize(16, 18),
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹$priceStr / $unit · $measureStr $unit",
                      style: TextStyle(
                        fontSize: responsive.fontSize(12, 14),
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "₹${itemTotal.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: responsive.fontSize(18, 20),
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                        ),
                        _quantityControls(context, id, qty),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSummary(Responsive responsive, Color primary) {
    return Container(
      padding: EdgeInsets.all(responsive.isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Subtotal",
                style: TextStyle(
                  fontSize: responsive.fontSize(15, 17),
                  color: Colors.grey.shade700,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "₹${total.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: responsive.fontSize(15, 17),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.spacing(8, 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Delivery Fee",
                style: TextStyle(
                  fontSize: responsive.fontSize(15, 17),
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                "₹2.00",
                style: TextStyle(
                  fontSize: responsive.fontSize(15, 17),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.spacing(12, 16)),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
          SizedBox(height: responsive.spacing(12, 16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: TextStyle(
                  fontSize: responsive.fontSize(20, 24),
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "₹${(total + 2).toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: responsive.fontSize(20, 24),
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.spacing(16, 20)),
          Material(
            color: primary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                final checkoutItems = items.map((item) {
                  final id = item['cartId'] as String;
                  return {
                    ...item,
                    "quantity": quantities[id] ?? 1,
                    "measure":
                        (item['measure'] as num?)?.toDouble() ??
                        (item['weightKg'] as num?)?.toDouble() ??
                        1.0,
                    "unit": item['unit'] ?? 'kg',
                  };
                }).toList();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutPage(cartItems: checkoutItems),
                  ),
                );
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
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Proceed to Checkout",
                        style: TextStyle(
                          fontSize: responsive.fontSize(16, 18),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _imagePlaceholder() {
  return Container(
    width: 55,
    height: 55,
    color: Colors.grey.shade200,
    alignment: Alignment.center,
    child: const Icon(Icons.local_grocery_store, color: Colors.grey),
  );
}

Widget _buildProductImage(Map<String, dynamic> fruit) {
  final raw = fruit['image'] ?? fruit['imageUrl'];
  const double size = 55;
  if (raw == null) {
    return _imagePlaceholder();
  }

  final path = raw.toString().trim();
  if (path.isEmpty) {
    return _imagePlaceholder();
  }

  final normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith('http')) {
    return ResolvedImage(
      normalized,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }

  if (normalized.startsWith('assets/')) {
    return Image.asset(
      normalized,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _imagePlaceholder(),
    );
  }

  final baseUrl = AuthService.getBaseUrl();
  final resolved = normalized.startsWith('/')
      ? '$baseUrl$normalized'
      : '$baseUrl/$normalized';

  return ResolvedImage(resolved, width: size, height: size, fit: BoxFit.cover);
}
