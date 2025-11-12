import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/image_resolver.dart';
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const Map<String, String> _categoryLabels = {
    'fruit': 'Fruits',
    'juice': 'Juices',
    'soft_drink': 'Soft Drinks',
    'other': 'Other Products',
    'grocery': 'Grocery',
  };
  static const List<String> _categoryOrder = [
    'fruit',
    'juice',
    'soft_drink',
    'other',
    'grocery',
  ];
  static const Set<String> _intValueFields = {'stock', 'sold'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final list = await UserDataApi.adminListProducts(
        category: _category == 'all' ? null : _category,
      );
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    Iterable<Map<String, dynamic>> list = _items;
    if (_category != 'all') {
      final filterKey = _category.toLowerCase();
      list = list.where(
        (p) => (p['category'] ?? '').toString().toLowerCase() == filterKey,
      );
    }
    if (_query.isEmpty) {
      return List<Map<String, dynamic>>.from(list);
    }
    final q = _query.toLowerCase();
    return list
        .where((p) => (p['name'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  String _labelForCategory(String key) {
    final normalized = key.toLowerCase();
    return _categoryLabels[normalized] ?? key;
  }

  String _formatShortDate(DateTime? dt) {
    if (dt == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year.toString();
    return '$day $month $year';
  }

  Future<void> _editNumber(
    BuildContext ctx,
    Map<String, dynamic> item,
    String field,
    String label,
  ) async {
    final controller = TextEditingController(
      text: (item[field] ?? '').toString(),
    );
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
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (saved != true) return;
    final input = controller.text.trim();
    final val = double.tryParse(input);
    if (val == null) {
      AppSnack.showError(context, 'Invalid number');
      return;
    }
    if (field == 'rating' && (val < 0 || val > 5)) {
      AppSnack.showError(context, 'Rating must be between 0 and 5');
      return;
    }
    if (field == 'discount' && (val < 0 || val > 100)) {
      AppSnack.showError(context, 'Discount must be between 0 and 100');
      return;
    }
    if (_intValueFields.contains(field) && val < 0) {
      AppSnack.showError(context, '$label cannot be negative');
      return;
    }
    if (field == 'defaultMeasure' && val <= 0) {
      AppSnack.showError(context, 'Default measure must be greater than zero');
      return;
    }
    dynamic payloadValue;
    if (_intValueFields.contains(field)) {
      payloadValue = val.round();
    } else {
      payloadValue = val;
    }
    try {
      await UserDataApi.adminUpdateProduct(item['_id'], {field: payloadValue});
      if (!mounted) return;
      AppSnack.showSuccess(context, '$label updated');
      _load();
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Update failed: $e');
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item, bool value) async {
    try {
      await UserDataApi.adminUpdateProduct(item['_id'], {'active': value});
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((e) => e['_id'] == item['_id']);
        if (idx != -1) _items[idx]['active'] = value;
      });
      AppSnack.showSuccess(
        context,
        value ? 'Product published' : 'Product hidden',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Failed to update active');
    }
  }

  Future<void> _toggleFeatured(Map<String, dynamic> item, bool value) async {
    try {
      await UserDataApi.adminUpdateProduct(item['_id'], {'isFeatured': value});
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere(
          (element) => element['_id'] == item['_id'],
        );
        if (idx != -1) _items[idx]['isFeatured'] = value;
      });
      AppSnack.showSuccess(
        context,
        value ? 'Added to featured products' : 'Removed from featured',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Failed to update featured flag');
    }
  }

  Future<void> _openCreateProductSheet() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();
    final unitController = TextEditingController(text: 'kg');
    final stockController = TextEditingController(text: '0');
    final ratingController = TextEditingController();
    final discountController = TextEditingController();
    final soldController = TextEditingController();
    final defaultMeasureController = TextEditingController(text: '1');
    final controllers = <TextEditingController>[
      nameController,
      priceController,
      descController,
      unitController,
      stockController,
      ratingController,
      discountController,
      soldController,
      defaultMeasureController,
    ];
    String category = _category == 'all' ? 'fruit' : _category;
    Uint8List? imageBytes;
    String? imageName;
    bool saving = false;
    bool isFeatured = false;
    DateTime? addedAt;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> pick(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 1024,
                  imageQuality: 85,
                );
                if (picked == null) return;
                final bytes = await picked.readAsBytes();
                setSheetState(() {
                  imageBytes = bytes;
                  imageName = picked.name;
                });
              } catch (e) {
                if (!mounted) return;
                AppSnack.showError(context, 'Image pick failed: $e');
              }
            }

            final theme = Theme.of(ctx);
            return AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Add product',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () {
                                      if (Navigator.of(ctx).canPop()) {
                                        Navigator.of(ctx).pop(false);
                                      }
                                    },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: saving
                              ? null
                              : () => pick(ImageSource.gallery),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            height: 170,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                                ],
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: imageBytes == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 32,
                                        ),
                                        SizedBox(height: 8),
                                        Text('Tap to add product image'),
                                      ],
                                    )
                                  : Image.memory(
                                      imageBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            final compact = constraints.maxWidth < 640;
                            final primaryFields = <Widget>[
                              SizedBox(
                                width: compact ? double.infinity : 280,
                                child: TextField(
                                  controller: nameController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                    prefixIcon: Icon(
                                      Icons.shopping_basket_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: compact ? double.infinity : 180,
                                child: TextField(
                                  controller: priceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Price (₹)',
                                    prefixIcon: Icon(Icons.currency_rupee),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: compact ? double.infinity : 160,
                                child: TextField(
                                  controller: unitController,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit',
                                    prefixIcon: Icon(Icons.straighten),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: compact ? double.infinity : 160,
                                child: TextField(
                                  controller: stockController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Stock',
                                    prefixIcon: Icon(
                                      Icons.inventory_2_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: compact ? double.infinity : 220,
                                child: DropdownButtonFormField<String>(
                                  initialValue: category,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'fruit',
                                      child: Text('Fruit'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'juice',
                                      child: Text('Juice'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'soft_drink',
                                      child: Text('Soft Drink'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'other',
                                      child: Text('Other Product'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'grocery',
                                      child: Text('Grocery'),
                                    ),
                                  ],
                                  onChanged: saving
                                      ? null
                                      : (v) => setSheetState(
                                          () => category = v ?? 'fruit',
                                        ),
                                ),
                              ),
                            ];

                            final advancedFields = <Widget>[
                              SizedBox(
                                width: compact ? double.infinity : 160,
                                child: TextField(
                                  controller: ratingController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Rating',
                                    prefixIcon: Icon(Icons.star_rate_rounded),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: compact ? double.infinity : 160,
                                child: TextField(
                                  controller: discountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Discount (%)',
                                    prefixIcon: Icon(
                                      Icons.local_offer_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: compact ? double.infinity : 160,
                                child: TextField(
                                  controller: soldController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Sold count',
                                    prefixIcon: Icon(Icons.trending_up),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: compact ? double.infinity : 160,
                                child: TextField(
                                  controller: defaultMeasureController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Default measure',
                                    prefixIcon: Icon(Icons.straighten),
                                  ),
                                ),
                              ),
                            ];

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final field in primaryFields) ...[
                                    field,
                                    const SizedBox(height: 12),
                                  ],
                                  for (final field in advancedFields) ...[
                                    field,
                                    const SizedBox(height: 12),
                                  ],
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: primaryFields,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: advancedFields,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star_rate_rounded,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Feature this product',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text('Showcase in highlighted sections'),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isFeatured,
                                onChanged: saving
                                    ? null
                                    : (value) => setSheetState(
                                        () => isFeatured = value,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Added date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      addedAt == null
                                          ? 'Uses creation timestamp'
                                          : _formatShortDate(addedAt),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final now = DateTime.now();
                                        final picked = await showDatePicker(
                                          context: ctx,
                                          initialDate: addedAt ?? now,
                                          firstDate: DateTime(now.year - 5),
                                          lastDate: DateTime(now.year + 5),
                                        );
                                        if (picked != null) {
                                          setSheetState(
                                            () => addedAt = DateTime(
                                              picked.year,
                                              picked.month,
                                              picked.day,
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.edit_calendar_outlined),
                                label: Text(
                                  addedAt == null ? 'Set date' : 'Change',
                                ),
                              ),
                              if (addedAt != null)
                                IconButton(
                                  tooltip: 'Clear date',
                                  onPressed: saving
                                      ? null
                                      : () =>
                                            setSheetState(() => addedAt = null),
                                  icon: const Icon(Icons.close),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => pick(ImageSource.camera),
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Use camera'),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final name = nameController.text.trim();
                                      final price = double.tryParse(
                                        priceController.text.trim(),
                                      );
                                      final stockVal = int.tryParse(
                                        stockController.text.trim(),
                                      );
                                      final unit =
                                          unitController.text.trim().isEmpty
                                          ? 'unit'
                                          : unitController.text.trim();
                                      final ratingText = ratingController.text
                                          .trim();
                                      final discountText = discountController
                                          .text
                                          .trim();
                                      final soldText = soldController.text
                                          .trim();
                                      final defaultMeasureText =
                                          defaultMeasureController.text.trim();
                                      double? ratingVal;
                                      if (ratingText.isNotEmpty) {
                                        ratingVal = double.tryParse(ratingText);
                                        if (ratingVal == null ||
                                            ratingVal < 0 ||
                                            ratingVal > 5) {
                                          AppSnack.showError(
                                            context,
                                            'Rating must be between 0 and 5',
                                          );
                                          return;
                                        }
                                      }
                                      double? discountVal;
                                      if (discountText.isNotEmpty) {
                                        discountVal = double.tryParse(
                                          discountText,
                                        );
                                        if (discountVal == null ||
                                            discountVal < 0 ||
                                            discountVal > 100) {
                                          AppSnack.showError(
                                            context,
                                            'Discount must be between 0 and 100',
                                          );
                                          return;
                                        }
                                      }
                                      int? soldVal;
                                      if (soldText.isNotEmpty) {
                                        final parsed = double.tryParse(
                                          soldText,
                                        );
                                        if (parsed == null || parsed < 0) {
                                          AppSnack.showError(
                                            context,
                                            'Sold count cannot be negative',
                                          );
                                          return;
                                        }
                                        soldVal = parsed.round();
                                      }
                                      double? defaultMeasureVal;
                                      if (defaultMeasureText.isNotEmpty) {
                                        defaultMeasureVal = double.tryParse(
                                          defaultMeasureText,
                                        );
                                        if (defaultMeasureVal == null ||
                                            defaultMeasureVal <= 0) {
                                          AppSnack.showError(
                                            context,
                                            'Default measure must be greater than zero',
                                          );
                                          return;
                                        }
                                      }
                                      if (name.isEmpty || price == null) {
                                        AppSnack.showError(
                                          context,
                                          'Name and price are required',
                                        );
                                        return;
                                      }
                                      setSheetState(() => saving = true);
                                      try {
                                        final payload = <String, dynamic>{
                                          'name': name,
                                          'price': price,
                                          'category': category,
                                          'unit': unit,
                                          'description': descController.text
                                              .trim(),
                                        };
                                        if (stockVal != null) {
                                          payload['stock'] = stockVal;
                                        }
                                        if (ratingVal != null) {
                                          payload['rating'] = ratingVal;
                                        }
                                        if (discountVal != null) {
                                          payload['discount'] = discountVal;
                                        }
                                        if (soldVal != null) {
                                          payload['sold'] = soldVal;
                                        }
                                        if (defaultMeasureVal != null) {
                                          payload['defaultMeasure'] =
                                              defaultMeasureVal;
                                        }
                                        payload['isFeatured'] = isFeatured;
                                        if (addedAt != null) {
                                          payload['addedAt'] = addedAt!
                                              .toUtc()
                                              .toIso8601String();
                                        }
                                        final created =
                                            await UserDataApi.adminCreateProduct(
                                              payload,
                                            );
                                        final newId =
                                            (created['_id'] ?? created['id'])
                                                ?.toString();
                                        if (newId != null &&
                                            imageBytes != null) {
                                          try {
                                            await UserDataApi.adminUploadProductImage(
                                              newId,
                                              imageBytes!,
                                              filename:
                                                  imageName ?? 'product.jpg',
                                            );
                                          } catch (uploadError) {
                                            if (!mounted) return;
                                            AppSnack.showError(
                                              context,
                                              'Image upload failed: $uploadError',
                                            );
                                          }
                                        }
                                        if (!mounted || !ctx.mounted) return;
                                        Navigator.of(ctx).pop(true);
                                      } catch (e) {
                                        if (!mounted) return;
                                        AppSnack.showError(
                                          context,
                                          'Create failed: $e',
                                        );
                                        setSheetState(() => saving = false);
                                      }
                                    },
                              icon: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(saving ? 'Saving…' : 'Save product'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
    } else {
      for (final controller in controllers) {
        controller.dispose();
      }
    }

    if (!mounted) return;
    if (created == true) {
      AppSnack.showSuccess(context, 'Product created');
      _load();
    }
  }

  Widget _buildFilterBar(int filteredCount, int activeCount) {
    final theme = Theme.of(context);
    final totalCount = _items.length;
    Widget buildMetric(IconData icon, String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              '$label: $value',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final compact = constraints.maxWidth < 720;

            final filterControls = <Widget>[
              SizedBox(
                width: compact ? double.infinity : 280,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search products',
                  ),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'fruit', child: Text('Fruit')),
                    DropdownMenuItem(value: 'juice', child: Text('Juice')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                    DropdownMenuItem(
                      value: 'soft_drink',
                      child: Text('Soft Drinks'),
                    ),
                    DropdownMenuItem(value: 'grocery', child: Text('Grocery')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _category = v);
                    _load();
                  },
                ),
              ),
            ];

            final metrics = Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                buildMetric(Icons.inventory_2_outlined, 'Total', '$totalCount'),
                buildMetric(
                  Icons.visibility_outlined,
                  'Active',
                  '$activeCount',
                ),
                buildMetric(
                  Icons.filter_alt_outlined,
                  'Showing',
                  '$filteredCount',
                ),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Inventory',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...filterControls
                          .expand(
                            (widget) => [widget, const SizedBox(height: 12)],
                          )
                          .toList()
                        ..removeLast(),
                    ],
                  )
                else
                  Row(
                    children: [
                      filterControls[0],
                      const SizedBox(width: 16),
                      filterControls[1],
                    ],
                  ),
                const SizedBox(height: 16),
                metrics,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p, int index) {
    final theme = Theme.of(context);
    final imagePath = (p['image'] ?? '').toString().trim();
    final isActive = (p['active'] ?? true) == true;
    final isFeatured = (p['isFeatured'] ?? false) == true;
    final id = p['_id']?.toString();
    final name = p['name']?.toString() ?? '';
    final rating = (p['rating'] as num?)?.toDouble();
    final discount = (p['discount'] as num?)?.toDouble();
    final sold = (p['sold'] as num?)?.toInt();
    final defaultMeasure = (p['defaultMeasure'] as num?)?.toDouble();
    final addedAtRaw = p['addedAt'] ?? p['createdAt'];
    final addedAt = DateTime.tryParse(addedAtRaw?.toString() ?? '');

    Future<void> uploadImage() async {
      if (id == null) return;
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          imageQuality: 85,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        await UserDataApi.adminUploadProductImage(
          id,
          bytes,
          filename: picked.name,
        );
        if (!mounted) return;
        AppSnack.showSuccess(context, 'Image uploaded');
        _load();
      } catch (e) {
        if (!mounted) return;
        AppSnack.showError(context, 'Upload failed: $e');
      }
    }

    final priceValue = (p['price'] as num?)?.toDouble() ?? 0;
    final priceText = priceValue % 1 == 0
        ? priceValue.toStringAsFixed(0)
        : priceValue.toStringAsFixed(2);
    final unit = (p['unit'] ?? 'unit').toString();
    final stock = (p['stock'] as num?)?.toInt() ?? 0;
    final description = (p['description'] ?? '').toString();

    Widget infoPill(IconData icon, String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(text, style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    String serverImageUrl(String path) {
      final normalized = path.startsWith('/') ? path : '/$path';
      return '${AuthService.getBaseUrl()}$normalized';
    }

    final String? assetImagePath =
        imagePath.isNotEmpty && imagePath.startsWith('assets/')
        ? imagePath
        : null;
    final String? networkImageUrl = imagePath.isEmpty
        ? null
        : imagePath.startsWith('http')
        ? imagePath
        : (assetImagePath == null ? serverImageUrl(imagePath) : null);
    final bool hasImage = assetImagePath != null || networkImageUrl != null;

    Widget imageWidget() {
      return GestureDetector(
        onTap: id == null ? null : uploadImage,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            width: 96,
            height: 96,
            child: () {
              if (assetImagePath != null) {
                return Image.asset(
                  assetImagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                );
              }
              if (networkImageUrl != null) {
                return ResolvedImage(
                  networkImageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.image, size: 28),
                  SizedBox(height: 6),
                  Text('Add image', style: TextStyle(fontSize: 12)),
                ],
              );
            }(),
          ),
        ),
      );
    }

    Widget statusBadge(bool active) {
      final color = active
          ? theme.colorScheme.primary.withValues(alpha: 0.15)
          : theme.colorScheme.error.withValues(alpha: 0.12);
      final textColor = active
          ? theme.colorScheme.primary
          : theme.colorScheme.error;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          active ? 'Active' : 'Hidden',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    Widget featuredBadge() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rate_rounded,
              size: 14,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              'Featured',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    Widget actionIcon({
      required IconData icon,
      required String tooltip,
      VoidCallback? onPressed,
      Color? color,
    }) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, color: color ?? theme.colorScheme.onSurfaceVariant),
          onPressed: onPressed,
        ),
      );
    }

    final stats = <Widget>[
      infoPill(Icons.currency_rupee, '₹$priceText · $unit'),
      infoPill(Icons.inventory_2_outlined, 'Stock: $stock'),
      if (rating != null)
        infoPill(
          Icons.star_rate_rounded,
          'Rating: ${rating.toStringAsFixed(1)}',
        ),
      if (discount != null && discount > 0)
        infoPill(
          Icons.local_offer_outlined,
          'Discount: ${discount.toStringAsFixed(discount % 1 == 0 ? 0 : 1)}%',
        ),
      if (sold != null) infoPill(Icons.trending_up, 'Sold: $sold'),
      if (defaultMeasure != null)
        infoPill(
          Icons.straighten,
          'Default: ${defaultMeasure % 1 == 0 ? defaultMeasure.toStringAsFixed(0) : defaultMeasure.toString()} $unit',
        ),
      if (addedAt != null)
        infoPill(Icons.history, 'Added ${_formatShortDate(addedAt)}'),
    ];

    return TweenAnimationBuilder<double>(
      key: ValueKey('inv-card-${id ?? name}'),
      tween: Tween(begin: 0.95, end: 1),
      duration: Duration(milliseconds: 280 + (index % 6) * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 10),
        elevation: isActive ? 2 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  imageWidget(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                statusBadge(isActive),
                                if (isFeatured) ...[
                                  const SizedBox(width: 6),
                                  featuredBadge(),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _labelForCategory((p['category'] ?? '').toString()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (stats.isNotEmpty)
                          Wrap(spacing: 12, runSpacing: 8, children: stats),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: id == null ? null : uploadImage,
                    icon: Icon(
                      hasImage ? Icons.refresh_outlined : Icons.add_a_photo,
                    ),
                    label: Text(hasImage ? 'Replace image' : 'Add image'),
                  ),
                  actionIcon(
                    icon: Icons.currency_rupee,
                    tooltip: 'Edit price',
                    onPressed: () => _editNumber(context, p, 'price', 'Price'),
                  ),
                  actionIcon(
                    icon: Icons.inventory_2,
                    tooltip: 'Edit stock',
                    onPressed: () => _editNumber(context, p, 'stock', 'Stock'),
                  ),
                  actionIcon(
                    icon: Icons.star_rate_rounded,
                    tooltip: 'Edit rating',
                    onPressed: () =>
                        _editNumber(context, p, 'rating', 'Rating'),
                  ),
                  actionIcon(
                    icon: Icons.local_offer_outlined,
                    tooltip: 'Edit discount',
                    onPressed: () =>
                        _editNumber(context, p, 'discount', 'Discount'),
                  ),
                  actionIcon(
                    icon: Icons.trending_up,
                    tooltip: 'Edit sold count',
                    onPressed: () => _editNumber(context, p, 'sold', 'Sold'),
                  ),
                  actionIcon(
                    icon: Icons.straighten,
                    tooltip: 'Edit default measure',
                    onPressed: () => _editNumber(
                      context,
                      p,
                      'defaultMeasure',
                      'Default measure',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isActive ? 'Visible' : 'Hidden',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 4),
                        Switch.adaptive(
                          value: isActive,
                          onChanged: id == null
                              ? null
                              : (value) => _toggleActive(p, value),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isFeatured ? 'Featured' : 'Standard',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 4),
                        Switch.adaptive(
                          value: isFeatured,
                          onChanged: id == null
                              ? null
                              : (value) => _toggleFeatured(p, value),
                        ),
                      ],
                    ),
                  ),
                  actionIcon(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete product',
                    color: theme.colorScheme.error,
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
      ),
    );
  }

  Widget _buildProductList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    final children = <Widget>[];
    var index = 0;

    if (_category == 'all') {
      for (final key in _categoryOrder) {
        final group = filtered
            .where((p) => (p['category'] ?? '').toString().toLowerCase() == key)
            .toList();
        if (group.isEmpty) continue;
        children.add(
          Padding(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 6,
              left: 8,
              right: 8,
            ),
            child: Text(
              _labelForCategory(key),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        );
        for (final product in group) {
          children.add(_buildProductCard(product, index++));
        }
      }

      final otherGroup = filtered.where((p) {
        final cat = (p['category'] ?? '').toString().toLowerCase();
        return !_categoryOrder.contains(cat);
      }).toList();
      if (otherGroup.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 6,
              left: 8,
              right: 8,
            ),
            child: Text(
              'Miscellaneous',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        );
        for (final product in otherGroup) {
          children.add(_buildProductCard(product, index++));
        }
      }
    } else {
      for (final product in filtered) {
        children.add(_buildProductCard(product, index++));
      }
    }

    if (children.isEmpty) {
      children.add(
        SizedBox(
          height: 320,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.search_off_outlined, size: 40),
                SizedBox(height: 8),
                Text('No products match your filters'),
              ],
            ),
          ),
        ),
      );
    }

    final listKey = ValueKey(
      'inventory-$_category-${filtered.length}-${_query.hashCode}',
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: RefreshIndicator(
        key: listKey,
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 140),
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_searchController.text != _query) {
      _searchController.value = TextEditingValue(
        text: _query,
        selection: TextSelection.collapsed(offset: _query.length),
      );
    }

    final filteredCount = _filtered.length;
    final activeCount = _items
        .where((e) => (e['active'] ?? true) == true)
        .length;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildFilterBar(filteredCount, activeCount),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildProductList(),
              ),
            ),
          ],
        ),
        Positioned(
          right: 28,
          bottom: 28,
          child: FloatingActionButton.extended(
            onPressed: _openCreateProductSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add product'),
          ),
        ),
      ],
    );
  }
}
