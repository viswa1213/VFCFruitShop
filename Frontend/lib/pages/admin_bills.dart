import 'dart:math';

import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
// auth_service not required here yet
import 'package:fruit_shop/services/image_resolver.dart';
import 'package:fruit_shop/pages/admin_bill_detail.dart';

class AdminBillsPage extends StatefulWidget {
  const AdminBillsPage({super.key});

  @override
  State<AdminBillsPage> createState() => _AdminBillsPageState();
}

class _CartItem {
  final String id;
  final String name;
  final String? image;
  int qty;
  double measure; // e.g., kilograms or litres when applicable
  String unit; // unit label like 'kg' or 'L'
  final double price;

  _CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    this.measure = 0.0,
    this.unit = '',
  }) : qty = 1;

  double get subtotal {
    if (unit == 'g') return price * (measure / 1000.0);
    if (unit == 'kg' || unit == 'L') return price * measure;
    return price * qty;
  }

  Map<String, dynamic> toJson() => {
    'productId': id,
    'name': name,
    'price': price,
    'qty': qty,
    if (measure != 0.0) 'measure': measure,
    if (unit.isNotEmpty) 'unit': unit,
  };
}

class _AdminBillsPageState extends State<AdminBillsPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  final Map<String, _CartItem> _cart = {};

  // pagination
  int _pageIndex = 0;
  final int _pageSize = 6; // 2 columns x 3 rows
  String _search = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v == null) return 0.0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final list = await UserDataApi.adminListProducts();
      if (!mounted) return;
      setState(() {
        _products = list;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Failed to load products: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _search.trim().toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_products)
        : _products.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            final cat = (p['category'] ?? '').toString().toLowerCase();
            return name.contains(q) || cat.contains(q);
          }).toList();
    _pageIndex = 0;
  }

  List<Map<String, dynamic>> get _visibleProducts {
    final list = _filtered;
    final start = _pageIndex * _pageSize;
    if (start >= list.length) return [];
    final end = min(start + _pageSize, list.length);
    return list.sublist(start, end);
  }

  void _nextPage() {
    final maxPage = (_filtered.length / _pageSize).ceil() - 1;
    if (_pageIndex < maxPage) setState(() => _pageIndex += 1);
  }

  void _prevPage() {
    if (_pageIndex > 0) setState(() => _pageIndex -= 1);
  }

  Future<void> _addToCart(Map<String, dynamic> p) async {
    final id = (p['id'] ?? p['_id'] ?? '').toString();
    if (id.isEmpty) return;
    final name = (p['name'] ?? '').toString();
    final price = _toDouble(p['price']);
    final category = (p['category'] ?? '').toString().toLowerCase();

    void upsert(_CartItem item) {
      setState(() {
        final existing = _cart[id];
        if (existing != null) {
          // both measured and same unit -> add measures
          if (item.unit.isNotEmpty && existing.unit == item.unit) {
            existing.measure = (existing.measure) + (item.measure);
          }
          // new is measured and existing has no unit -> adopt new measure/unit
          else if (item.unit.isNotEmpty &&
              existing.unit != item.unit &&
              existing.unit.isEmpty) {
            existing.measure = item.measure;
            existing.unit = item.unit;
          }
          // both measured but different compatible units (g <-> kg) -> convert and add
          else if (item.unit.isNotEmpty && existing.unit.isNotEmpty) {
            final a = existing.unit;
            final b = item.unit;
            if ((a == 'kg' && b == 'g')) {
              // convert grams to kg
              existing.measure = existing.measure + (item.measure / 1000.0);
            } else if ((a == 'g' && b == 'kg')) {
              // convert kg to grams
              existing.measure = existing.measure + (item.measure * 1000.0);
            } else {
              // incompatible units or mixed measured/count -> fallback to increment count
              existing.qty += item.qty;
            }
          } else {
            // default: increment count
            existing.qty += item.qty;
          }
        } else {
          _cart[id] = item;
        }
      });
      AppSnack.showInfo(context, 'Added "$name" to bill');
    }

    // Fruits: ask for kgs
    if (category.contains('fruit')) {
      final ctrl = TextEditingController(text: '1000');
      String selectedUnit = 'g';
      final result = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (dctx) {
          return StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                title: const Text('Enter weight'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => selectedUnit = 'kg'),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'kg',
                                  groupValue: selectedUnit,
                                  onChanged: (_) =>
                                      setState(() => selectedUnit = 'kg'),
                                ),
                                const SizedBox(width: 8),
                                const Text('Kilograms'),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => selectedUnit = 'g'),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'g',
                                  groupValue: selectedUnit,
                                  onChanged: (_) =>
                                      setState(() => selectedUnit = 'g'),
                                ),
                                const SizedBox(width: 8),
                                const Text('Grams'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(suffixText: selectedUnit),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      final raw = ctrl.text;
                      final val = double.tryParse(raw) ?? 0.0;
                      Navigator.of(
                        dctx,
                      ).pop({'value': val, 'unit': selectedUnit});
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (result == null) return;
      final val = (result['value'] as num?)?.toDouble() ?? 0.0;
      final unit = (result['unit'] as String?) ?? 'g';
      if (val <= 0) return;
      // normalize: if grams selected, store measure as grams but subtotal logic will convert
      upsert(
        _CartItem(
          id: id,
          name: name,
          price: price,
          image: p['image']?.toString(),
          measure: val,
          unit: unit,
        ),
      );
      return;
    }

    // Soft drinks: ask for litres
    if (category.contains('soft') || category.contains('drink')) {
      final ctrl = TextEditingController(text: '1');
      final confirmed = await showDialog<double?>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Enter volume (L)'),
          content: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: 'L'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dctx).pop(double.tryParse(ctrl.text) ?? 0.0),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (confirmed == null || confirmed <= 0) {
        return;
      }
      upsert(
        _CartItem(
          id: id,
          name: name,
          price: price,
          image: p['image']?.toString(),
          measure: confirmed,
          unit: 'L',
        ),
      );
      return;
    }

    // Juice: direct add (count)
    if (category.contains('juice')) {
      setState(() {
        final existing = _cart[id];
        if (existing != null) {
          existing.qty += 1;
        } else {
          _cart[id] = _CartItem(
            id: id,
            name: name,
            price: price,
            image: p['image']?.toString(),
          );
        }
      });
      AppSnack.showInfo(context, 'Added "$name" to bill');
      return;
    }

    // Default: direct add count
    setState(() {
      final existing = _cart[id];
      if (existing != null) {
        existing.qty += 1;
      } else {
        _cart[id] = _CartItem(
          id: id,
          name: name,
          price: price,
          image: p['image']?.toString(),
        );
      }
    });
    AppSnack.showInfo(context, 'Added "$name" to bill');
  }

  double get _subtotal => _cart.values.fold(0.0, (s, it) => s + it.subtotal);
  double get _tax => _subtotal * 0.05; // example 5% tax
  double get _total => _subtotal + _tax;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        // Header
        final header = Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bills',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              // Use a Flexible + Wrap so action controls can wrap on narrow widths
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isNarrow ? 140 : 220,
                        ),
                        child: TextField(
                          onChanged: (v) {
                            setState(() => _search = v);
                            _applyFilter();
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Search products',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadProducts,
                        icon: const Icon(Icons.refresh),
                      ),
                      if (_cart.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final items = _cart.values.map((c) {
                              final m = c.toJson();
                              if (c.image != null) m['image'] = c.image;
                              return m;
                            }).toList();
                            final created = await Navigator.of(context)
                                .push<bool?>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminBillDetailPage(items: items),
                                  ),
                                );
                            if (created == true) setState(() => _cart.clear());
                          },
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Go to Current Bill'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        // Products grid + pagination
        final productsList = Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isNarrow ? 1 : 2,
                  childAspectRatio: isNarrow ? 3.0 : 0.84,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _visibleProducts.length,
                itemBuilder: (ctx, i) {
                  final p = _visibleProducts[i];
                  final name = (p['name'] ?? '').toString();
                  final price = _toDouble(p['price']);
                  final img = p['image']?.toString();
                  final active = p['active'] == true;
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ResolvedImage(
                                img,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.green.withValues(alpha: 0.08)
                                      : Colors.grey.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  active ? 'Active' : 'Hidden',
                                  style: TextStyle(
                                    color: active
                                        ? Colors.green
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _addToCart(p),
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // pagination controls
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _prevPage,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Prev'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Page ${_pageIndex + 1} of ${max(1, (_filtered.length / _pageSize).ceil())}',
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _nextPage,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: isNarrow
                          ? SingleChildScrollView(
                              controller: _scrollController,
                              child: Column(
                                children: [
                                  // products grid (shrink-wrapped for outer scroll)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 8,
                                    ),
                                    child: GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 1,
                                            childAspectRatio: 3.0,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                          ),
                                      itemCount: _visibleProducts.length,
                                      itemBuilder: (ctx, i) {
                                        final p = _visibleProducts[i];
                                        final name = (p['name'] ?? '')
                                            .toString();
                                        final price = _toDouble(p['price']);
                                        final img = p['image']?.toString();
                                        final active = p['active'] == true;
                                        return Card(
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 96,
                                                  height: 72,
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    child: ResolvedImage(
                                                      img,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      fit: BoxFit.cover,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        '₹${price.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: active
                                                            ? Colors.green
                                                                  .withValues(
                                                                    alpha: 0.08,
                                                                  )
                                                            : Colors.grey
                                                                  .withValues(
                                                                    alpha: 0.06,
                                                                  ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        active
                                                            ? 'Active'
                                                            : 'Hidden',
                                                        style: TextStyle(
                                                          color: active
                                                              ? Colors.green
                                                              : Colors
                                                                    .grey
                                                                    .shade700,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    ElevatedButton(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            foregroundColor:
                                                                Colors.white,
                                                          ),
                                                      onPressed: () =>
                                                          _addToCart(p),
                                                      child: const Text('Add'),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // pagination controls
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextButton.icon(
                                          onPressed: _prevPage,
                                          icon: const Icon(Icons.chevron_left),
                                          label: const Text('Prev'),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          'Page ${_pageIndex + 1} of ${max(1, (_filtered.length / _pageSize).ceil())}',
                                        ),
                                        const SizedBox(width: 16),
                                        TextButton.icon(
                                          onPressed: _nextPage,
                                          icon: const Icon(Icons.chevron_right),
                                          label: const Text('Next'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: productsList),
                                const SizedBox(width: 16),
                                // Right-side summary card (desktop) with quick actions
                                Container(
                                  width: 360,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Bill',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text('Items: ${_cart.length}'),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Subtotal'),
                                          Text(
                                            '₹${_subtotal.toStringAsFixed(2)}',
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Tax (5%)'),
                                          Text('₹${_tax.toStringAsFixed(2)}'),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            '₹${_total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  setState(() => _cart.clear()),
                                              child: const Text('Clear'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
