import 'package:flutter/material.dart';
import 'package:fruit_shop/pages/admin_invoice_preview_clean.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruit_shop/services/image_resolver.dart';

class AdminBillDetailPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const AdminBillDetailPage({super.key, required this.items});

  @override
  State<AdminBillDetailPage> createState() => _AdminBillDetailPageState();
}

class _BillItem {
  final String id;
  final String name;
  final String? image;
  double price;
  int qty;
  double measure; // for kg / L
  String unit;

  _BillItem({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    this.qty = 1,
    this.measure = 0.0,
    this.unit = '',
  });

  double get subtotal {
    if (unit == 'g') return price * (measure / 1000.0);
    if (unit == 'kg' || unit == 'L') return price * measure;
    return price * qty;
  }
}

class _AdminBillDetailPageState extends State<AdminBillDetailPage> {
  late List<_BillItem> _items;
  bool _creating = false;
  // For undo on clear
  List<Map<String, dynamic>> _backupItems = [];

  // Invoice metadata controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController(
    text: '5',
  );

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((m) {
      return _BillItem(
        id: (m['productId'] ?? m['id'] ?? m['_id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        price: (m['price'] is num)
            ? (m['price'] as num).toDouble()
            : double.tryParse((m['price'] ?? '0').toString()) ?? 0.0,
        image: m['image']?.toString(),
        qty: (m['qty'] is int)
            ? m['qty'] as int
            : int.tryParse((m['qty'] ?? '1').toString()) ?? 1,
        measure: (m['measure'] is num)
            ? (m['measure'] as num).toDouble()
            : double.tryParse((m['measure'] ?? '0').toString()) ?? 0.0,
        unit: (m['unit'] ?? '').toString(),
      );
    }).toList();
    // sensible defaults and load saved metadata
    _businessNameController.text = 'My Shop';
    _loadSavedMetadata();
  }

  Future<void> _loadSavedMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _businessNameController.text =
            prefs.getString('admin_businessName') ??
            _businessNameController.text;
        _taxRateController.text =
            prefs.getString('admin_taxRate') ?? _taxRateController.text;
      });
    } catch (_) {}
  }

  Future<void> _saveMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_businessName', _businessNameController.text);
      await prefs.setString('admin_taxRate', _taxRateController.text);
      if (mounted) AppSnack.showInfo(context, 'Saved business name & tax rate');
    } catch (e) {
      if (mounted) AppSnack.showError(context, 'Failed to save metadata: $e');
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (s, it) => s + it.subtotal);
  double get _tax {
    final rate = double.tryParse(_taxRateController.text) ?? 0.0;
    return _subtotal * (rate / 100.0);
  }

  double get _total => _subtotal + _tax;

  void _changeQty(int idx, int delta) {
    setState(() {
      final it = _items[idx];
      it.qty = (it.qty + delta).clamp(1, 999);
    });
  }

  void _changeMeasure(int idx, double delta) {
    setState(() {
      final it = _items[idx];
      it.measure = (it.measure + delta).clamp(0.1, 9999.0);
    });
  }

  void _remove(int idx) {
    setState(() => _items.removeAt(idx));
  }

  Future<void> _clearAll() async {
    if (_items.isEmpty) {
      AppSnack.showInfo(context, 'Cart is already empty');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Clear cart'),
        content: const Text('Remove all items from the current bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (!mounted) return;
      // backup items for undo
      _backupItems = _items
          .map(
            (it) => {
              'id': it.id,
              'name': it.name,
              'image': it.image,
              'price': it.price,
              'qty': it.qty,
              'measure': it.measure,
              'unit': it.unit,
            },
          )
          .toList();
      setState(() => _items.clear());

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Cleared'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted) return;
              setState(() {
                _items = _backupItems
                    .map(
                      (m) => _BillItem(
                        id: m['id']?.toString() ?? '',
                        name: m['name']?.toString() ?? '',
                        price: (m['price'] is num)
                            ? (m['price'] as num).toDouble()
                            : double.tryParse(m['price']?.toString() ?? '0') ??
                                  0.0,
                        image: m['image']?.toString(),
                        qty: (m['qty'] is int)
                            ? m['qty'] as int
                            : int.tryParse(m['qty']?.toString() ?? '1') ?? 1,
                        measure: (m['measure'] is num)
                            ? (m['measure'] as num).toDouble()
                            : double.tryParse(
                                    m['measure']?.toString() ?? '0',
                                  ) ??
                                  0.0,
                        unit: (m['unit'] ?? '').toString(),
                      ),
                    )
                    .toList();
                _backupItems = [];
              });
            },
          ),
        ),
      );
    }
  }

  Future<void> _createOrder() async {
    // Instead of creating a server-side order, create a local invoice and show preview.
    if (_items.isEmpty) {
      AppSnack.showInfo(context, 'No items to bill');
      return;
    }
    setState(() => _creating = true);

    final invoiceId = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final taxRate = double.tryParse(_taxRateController.text) ?? 0.0;
    final taxAmount = _subtotal * (taxRate / 100);

    final invoice = {
      'id': invoiceId,
      'items': _items
          .map(
            (it) => {
              'productId': it.id,
              'name': it.name,
              'price': it.price,
              'qty': it.qty,
              if (it.measure > 0) 'measure': it.measure,
              if (it.unit.isNotEmpty) 'unit': it.unit,
            },
          )
          .toList(),
      'subtotal': _subtotal,
      'tax': taxAmount,
      'taxRate': taxRate,
      'total': _subtotal + taxAmount,
      'businessName': _businessNameController.text,
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      // Open preview page. If user saves (returns true), treat as created.
      final created = await Navigator.of(context).push<bool?>(
        MaterialPageRoute(
          builder: (_) => AdminInvoicePreviewPage(invoice: invoice),
        ),
      );

      // Guard against using BuildContext after async gap
      if (!mounted) return;

      if (created == true) {
        // clear the local cart before returning to the bills page
        if (mounted) setState(() => _items.clear());
        AppSnack.showInfo(context, 'Invoice created: $invoiceId');
        Navigator.of(context).pop(true);
        return;
      }
    } catch (e) {
      if (mounted) AppSnack.showError(context, 'Failed to create invoice: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Current Bill')),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final isNarrow = constraints.maxWidth < 800;

          final metadataCard = Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _businessNameController,
                    decoration: const InputDecoration(
                      labelText: 'Business name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _taxRateController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Tax rate (%)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _saveMetadata,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          final itemsList = _items.isEmpty
              ? Center(
                  child: Text(
                    'No items in bill',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (ctx, i) {
                    final it = _items[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (it.image != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: ResolvedImage(
                              it.image,
                              width: isNarrow ? 72 : 96,
                              height: isNarrow ? 56 : 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (it.measure > 0 && it.unit.isNotEmpty)
                                (() {
                                  final priceLabel = it.unit == 'g'
                                      ? '₹${it.price.toStringAsFixed(2)} / kg'
                                      : '₹${it.price.toStringAsFixed(2)} / ${it.unit}';
                                  final qtyLabel = it.unit == 'g'
                                      ? '${it.measure.toStringAsFixed(0)} g'
                                      : '${it.measure} ${it.unit}';
                                  return Text(
                                    '$priceLabel x $qtyLabel = ₹${it.subtotal.toStringAsFixed(2)}',
                                  );
                                }())
                              else
                                Text(
                                  '₹${it.price.toStringAsFixed(2)} x ${it.qty} = ₹${it.subtotal.toStringAsFixed(2)}',
                                ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => it.unit.isNotEmpty
                                  ? _changeMeasure(i, 1.0)
                                  : _changeQty(i, 1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => it.unit.isNotEmpty
                                  ? _changeMeasure(i, -1.0)
                                  : _changeQty(i, -1),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(i),
                        ),
                      ],
                    );
                  },
                );

          final summary = Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text('₹${_subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tax (5%)'),
                    Text('₹${_tax.toStringAsFixed(2)}'),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '₹${_total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _clearAll,
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _creating ? null : _createOrder,
                        child: _creating
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Create Order'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  metadataCard,
                  const SizedBox(height: 6),
                  Expanded(child: itemsList),
                  const SizedBox(height: 12),
                  summary,
                ],
              ),
            );
          }

          // wide layout: list left, summary right
          // wide layout: metadata + list left, summary right
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      metadataCard,
                      const SizedBox(height: 8),
                      Expanded(child: itemsList),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(width: 360, child: summary),
              ],
            ),
          );
        },
      ),
    );
  }
}
