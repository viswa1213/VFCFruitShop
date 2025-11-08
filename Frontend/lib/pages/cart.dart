import 'package:flutter/material.dart';
import 'checkout.dart'; // make sure this path is correct
import 'package:fruit_shop/services/user_data_api.dart';

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const CartPage({super.key, required this.cartItems});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Map<String, int> quantities = {};
  late List<Map<String, dynamic>> items;
  DateTime _lastChange = DateTime.now();
  bool _syncScheduled = false;

  void _scheduleSync() {
    _lastChange = DateTime.now();
    if (_syncScheduled) return;
    _syncScheduled = true;
    Future.delayed(const Duration(milliseconds: 800), () async {
      // debounce window
      if (DateTime.now().difference(_lastChange).inMilliseconds < 700) {
        _syncScheduled = false;
        _scheduleSync();
        return;
      }
      _syncScheduled = false;
      final payload = items.map((item) {
        final id = item['cartId'] as String;
        return {
          'name': item['name'],
          'image': item['image'],
          'price': item['price'],
          'measure':
              (item['measure'] as num?)?.toDouble() ??
              (item['weightKg'] as num?)?.toDouble() ??
              1.0,
          'unit': item['unit'] ?? 'kg',
          'quantity': (quantities[id] ?? (item['quantity'] as num? ?? 1))
              .toInt(),
        };
      }).toList();
      try {
        await UserDataApi.setCart(payload);
      } catch (_) {}
    });
  }

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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Your Cart",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
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
          ? const Center(
              child: Text(
                "🛒 Your cart is empty",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
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

                      return Dismissible(
                        key: ValueKey<String>(fruit['cartId'] as String),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          setState(() {
                            items.removeAt(index);
                            quantities.remove(id);
                          });
                          _scheduleSync();
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(10),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                fruit['image'],
                                width: 55,
                                height: 55,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              fruit['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "₹$priceStr /$unit · $measureStr$unit · x $qty",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (qty > 1) {
                                        quantities[id] = qty - 1;
                                      }
                                    });
                                    _scheduleSync();
                                  },
                                ),
                                Text(
                                  qty.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      quantities[id] = qty + 1;
                                    });
                                    _scheduleSync();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Summary Section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Subtotal",
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            "₹${total.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Delivery Fee", style: TextStyle(fontSize: 16)),
                          Text("₹2.00", style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      const Divider(height: 20, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Total",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "₹${(total + 2).toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            // Build final cart with quantities and weights applied
                            final checkoutItems = items.map((item) {
                              final id = item['cartId'] as String;
                              return {
                                ...item,
                                "quantity": quantities[id] ?? 1,
                                // keep backwards-compatible keys if present
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
                                builder: (_) =>
                                    CheckoutPage(cartItems: checkoutItems),
                              ),
                            );
                          },
                          child: const Text(
                            "Proceed to Checkout",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
