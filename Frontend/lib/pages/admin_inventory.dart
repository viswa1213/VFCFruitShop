import 'package:flutter/material.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:image_picker/image_picker.dart';

class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  bool _loading = false;
  String _category = 'all';
  String _query = '';
  List<Map<String, dynamic>> _items = [];

  static const Map<String, String> _categoryLabels = {
    'fruit': 'Fruits',
    'juice': 'Juices',
    'soft_drink': 'Soft Drinks',
    'other': 'Other Products',
  };
  static const List<String> _categoryOrder = ['fruit', 'juice', 'soft_drink', 'other'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final list = await UserDataApi.adminListProducts(
        category: _category == 'all' ? null : _category,
      );
      setState(() => _items = list);
    } catch (e) {
      AppSnack.showError(context, 'Load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((p) => (p['name'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  String _labelForCategory(String key) => _categoryLabels[key] ?? key;

  Future<void> _editNumber(BuildContext ctx, Map<String, dynamic> item, String field, String label) async {
    final controller = TextEditingController(text: (item[field] ?? '').toString());
    final saved = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    final val = double.tryParse(controller.text.trim());
    if (val == null) {
      AppSnack.showError(context, 'Invalid number');
      return;
    }
    try {
      await UserDataApi.adminUpdateProduct(item['_id'], { field: field == 'stock' ? val.toInt() : val });
      AppSnack.showSuccess(context, '$label updated');
      _load();
    } catch (e) {
      AppSnack.showError(context, 'Update failed: $e');
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item, bool value) async {
    try {
      await UserDataApi.adminUpdateProduct(item['_id'], { 'active': value });
      setState(() {
        final idx = _items.indexWhere((e) => e['_id'] == item['_id']);
        if (idx != -1) _items[idx]['active'] = value;
      });
    } catch (e) {
      AppSnack.showError(context, 'Failed to update active');
    }
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final imagePath = (p['image'] ?? '').toString();
    final resolvedImageUrl = imagePath.isEmpty
        ? null
        : (imagePath.startsWith('http')
            ? imagePath
            : '${AuthService.getBaseUrl()}$imagePath');
    final isActive = (p['active'] ?? true) == true;
    final id = p['_id']?.toString();

    Widget buildImage() {
      if (resolvedImageUrl == null || resolvedImageUrl.isEmpty) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.image_not_supported, size: 32, color: Colors.grey),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          resolvedImageUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildImage(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p['name']?.toString() ?? '',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Chip(label: Text(_labelForCategory((p['category'] ?? '').toString()))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('₹${(p['price'] ?? 0).toString()} • ${p['unit'] ?? 'unit'}'),
                      const SizedBox(height: 4),
                      Text('Stock: ${(p['stock'] ?? 0).toString()}'),
                      if ((p['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          p['description'].toString(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: id == null
                      ? null
                      : () async {
                          try {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1024,
                              imageQuality: 85,
                            );
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            await UserDataApi.adminUploadProductImage(id, bytes, filename: picked.name);
                            if (!mounted) return;
                            AppSnack.showSuccess(context, 'Image uploaded');
                            _load();
                          } catch (e) {
                            if (!mounted) return;
                            AppSnack.showError(context, 'Upload failed: $e');
                          }
                        },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload image'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editNumber(context, p, 'price', 'Price'),
                  icon: const Icon(Icons.currency_rupee),
                  label: const Text('Edit price'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editNumber(context, p, 'stock', 'Stock'),
                  icon: const Icon(Icons.inventory_2),
                  label: const Text('Edit stock'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Active'),
                    Switch(
                      value: isActive,
                      onChanged: id == null ? null : (v) => _toggleActive(p, v),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Delete product',
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: id == null
                      ? null
                      : () async {
                          final ok = await UserDataApi.adminDeleteProduct(id);
                          if (!mounted) return;
                          if (ok) {
                            AppSnack.showSuccess(context, 'Deleted');
                            _load();
                          } else {
                            AppSnack.showError(context, 'Delete failed');
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return const Center(child: Text('No products found'));
    }

    if (_category == 'all') {
      final children = <Widget>[];

      for (final key in _categoryOrder) {
        final group = filtered.where((p) => p['category'] == key).toList();
        if (group.isEmpty) continue;
        children
          ..add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _labelForCategory(key),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          )
          ..addAll(group.map(_buildProductCard));
      }

      final otherGroup = filtered
          .where((p) => !_categoryOrder.contains(p['category']))
          .toList();
      if (otherGroup.isNotEmpty) {
        children
          ..add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Miscellaneous',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          )
          ..addAll(otherGroup.map(_buildProductCard));
      }

      return ListView(children: children);
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildProductCard(filtered[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search products'),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _category,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'fruit', child: Text('Fruit')),
                DropdownMenuItem(value: 'juice', child: Text('Juice')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
                DropdownMenuItem(value: 'soft_drink', child: Text('Soft Drinks')),
              ],
              onChanged: (v) { if (v != null) { setState(() => _category = v); _load(); } },
            ),
            const Spacer(),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildProductList()),
      ],
    );
  }
}
