import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fruit_shop/pages/cart.dart';
import 'package:fruit_shop/pages/profile.dart';
import 'package:fruit_shop/pages/orders.dart';
import 'package:fruit_shop/widgets/app_drawer.dart';
import 'package:fruit_shop/pages/settings.dart';
import 'package:fruit_shop/pages/advanced_about_page.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:fruit_shop/services/favorites_storage.dart';
import 'package:fruit_shop/services/image_resolver.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/services/product_api.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/widgets/animated_sections.dart';
import 'package:fruit_shop/widgets/enhanced_ui_components.dart';

class HomePage extends StatefulWidget {
  final Map<String, String> userData;
  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  int _selectedIndex = 0;
  // Allow deep-link style selection of initial tab (e.g., Orders after placing an order)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['initialTab'] is int) {
      final tab = args['initialTab'] as int;
      if (tab >= 0 && tab <= 3) {
        // Defer setState to next frame to avoid build conflicts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedIndex = tab);
        });
      }
    }
  }

  // Data loaded from assets/data/*.json
  List<Map<String, dynamic>> fruits = [];
  List<Map<String, dynamic>> juices = [];
  List<Map<String, dynamic>> softDrinks = [];
  List<Map<String, dynamic>> otherProducts = [];
  List<Map<String, String>> _slides = [];
  // Fruit details loaded from assets/data/fruit_details.json
  Map<String, dynamic> _fruitDetails = {};
  bool _loading = true;

  // Enhanced data
  List<Map<String, dynamic>> trendingProducts = [];
  List<Map<String, dynamic>> specialOffers = [];
  Map<String, dynamic> stats = {};
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> filteredFruits = [];
  List<Map<String, dynamic>> cart = [];
  final Set<String> favorites = <String>{};
  late final AnimationController _controller;
  Timer? _cartSyncTimer;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  RangeValues _priceRange = const RangeValues(0, 1000);
  String _sort = 'none'; // 'none' | 'asc' | 'desc'
  final Set<String> _selectedCategories = <String>{};
  List<String> get _allCategories {
    final cats = <String>{
      ...fruits
          .map((f) => (f['category'] as String?) ?? '')
          .where((c) => c.isNotEmpty),
      ...juices
          .map((j) => (j['category'] as String?) ?? '')
          .where((c) => c.isNotEmpty),
      ...softDrinks
          .map((s) => (s['category'] as String?) ?? '')
          .where((c) => c.isNotEmpty),
      ...otherProducts
          .map((o) => (o['category'] as String?) ?? '')
          .where((c) => c.isNotEmpty),
    };
    final list = cats.toList();
    list.sort();
    return list;
  }

  final PageController _bannerController = PageController(
    viewportFraction: 0.92,
  );
  static const Duration _bannerInterval = Duration(seconds: 3);
  int _bannerIndex = 0;
  final Set<String> _hovered = <String>{};
  final Set<String> _pressed = <String>{};
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();

    // Initialize the AnimationController
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Start the animation
    _controller.forward();

    // Load data from assets
    _loadData();
    // Load persisted favorites so Profile page can reflect them too
    _loadFavorites();
    // Load remote cart and merge with any locally added items
    _loadRemoteCartAndMerge();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _controller.dispose(); // Dispose of the AnimationController
    _searchController.dispose(); // Dispose of the search controller
    _bannerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterFruits(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _applyFilters() {
    // Apply filters across all products (fruits + juices)
    final List<Map<String, dynamic>> allProducts = [
      ...fruits,
      ...juices,
      ...softDrinks,
      ...otherProducts,
    ];
    List<Map<String, dynamic>> data = List.from(allProducts);

    if (_searchQuery.isNotEmpty) {
      data = data
          .where(
            (fruit) => (fruit['name'] as String).toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    // Category filter
    if (_selectedCategories.isNotEmpty) {
      data = data
          .where(
            (fruit) =>
                _selectedCategories.contains((fruit['category'] as String)),
          )
          .toList();
    }

    data = data.where((fruit) {
      final p = (fruit['price'] as num).toDouble();
      return p >= _priceRange.start && p <= _priceRange.end;
    }).toList();

    if (_sort == 'asc') {
      data.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
    } else if (_sort == 'desc') {
      data.sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
    }

    // Prioritize featured items to the left while preserving existing order within groups
    final List<Map<String, dynamic>> featured = [];
    final List<Map<String, dynamic>> standard = [];
    for (final p in data) {
      if ((p['isFeatured'] ?? false) == true) {
        featured.add(p);
      } else {
        standard.add(p);
      }
    }
    data = [...featured, ...standard];

    setState(() {
      filteredFruits = data;
    });
  }

  // --- Cart sync helpers ---
  String _cartKey(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString();
    final measure = ((item['measure'] as num?)?.toDouble() ?? 1.0).toString();
    final unit = (item['unit'] ?? 'kg').toString();
    return '$name|$measure|$unit';
  }

  List<Map<String, dynamic>> _mergeCarts(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    final Map<String, Map<String, dynamic>> acc = {};
    void addAll(List<Map<String, dynamic>> src) {
      for (final it in src) {
        final key = _cartKey(it);
        final existing = acc[key];
        final qty = (it['quantity'] as num?)?.toInt() ?? 1;
        if (existing == null) {
          acc[key] = {...it, 'quantity': qty};
        } else {
          acc[key] = {
            ...existing,
            'quantity': ((existing['quantity'] as num?)?.toInt() ?? 1) + qty,
          };
        }
      }
    }

    addAll(a);
    addAll(b);
    return acc.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _loadRemoteCartAndMerge() async {
    List<Map<String, dynamic>> remote = [];
    try {
      remote = await UserDataApi.getCart();
    } catch (_) {}
    if (remote.isEmpty) return;
    final seed = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < remote.length; i++) {
      remote[i]['cartId'] ??= 'cart-$seed-$i-${remote[i]['name'] ?? 'item'}';
      remote[i]['quantity'] = (remote[i]['quantity'] as num?)?.toInt() ?? 1;
    }
    if (!mounted) return;
    setState(() {
      cart = _mergeCarts(cart, remote);
    });
  }

  void _scheduleCartSync() {
    _cartSyncTimer?.cancel();
    _cartSyncTimer = Timer(const Duration(milliseconds: 800), () async {
      final payload = cart
          .map(
            (e) => {
              'name': e['name'],
              'image': e['image'],
              'price': e['price'],
              'measure': (e['measure'] as num?)?.toDouble() ?? 1.0,
              'unit': e['unit'] ?? 'kg',
              'quantity': (e['quantity'] as num?)?.toInt() ?? 1,
            },
          )
          .toList();
      try {
        await UserDataApi.setCart(payload);
      } catch (_) {}
    });
  }

  Future<void> _loadFavorites() async {
    // Try remote first (requires auth token); fallback to local storage.
    List<String> remote = [];
    try {
      remote = await UserDataApi.getFavorites();
    } catch (_) {
      // ignore; likely unauthenticated or network issue
    }
    if (remote.isEmpty) {
      remote = (await FavoritesStorage.load()).toList();
    }
    if (!mounted) return;
    setState(() {
      favorites
        ..clear()
        ..addAll(remote);
    });
  }

  Future<void> _loadData() async {
    try {
      final products = await ProductApi.fetchProducts();
      final slides = await _loadSlidesFromAssets();

      final List<Map<String, dynamic>> normalized = products
          .map<Map<String, dynamic>>(_normalizeProduct)
          .where((p) => (p['name'] as String).isNotEmpty)
          .toList();

      final fruitList = normalized.where((p) => p['type'] == 'fruit').toList();
      final juiceList = normalized.where((p) => p['type'] == 'juice').toList();
      final softDrinkList = normalized
          .where((p) => p['type'] == 'soft_drink')
          .toList();
      final othersList = normalized
          .where((p) => !{'fruit', 'juice', 'soft_drink'}.contains(p['type']))
          .toList();

      final Map<String, dynamic> details = {
        for (final product in normalized)
          (product['name'] as String).toLowerCase(): {
            'description': product['description'] ?? '',
            'benefits': product['benefits'] ?? const [],
          },
      };

      // Load enhanced data
      List<Map<String, dynamic>> trending = [];
      List<Map<String, dynamic>> offers = [];
      Map<String, dynamic> statsData = {};

      try {
        trending = await ProductApi.fetchTrending(limit: 8);
        trending = trending.map(_normalizeProduct).toList();
      } catch (_) {}

      try {
        offers = await ProductApi.fetchOffers(limit: 6);
        offers = offers.map(_normalizeProduct).toList();
      } catch (_) {}

      try {
        statsData = await ProductApi.fetchStats();
      } catch (_) {}

      setState(() {
        fruits = fruitList;
        juices = juiceList;
        softDrinks = softDrinkList;
        otherProducts = othersList;
        filteredFruits = List<Map<String, dynamic>>.from(normalized);
        _slides = slides;
        _fruitDetails = details;
        trendingProducts = trending;
        specialOffers = offers;
        stats = statsData;
        _loading = false;
      });

      _applyFilters();
      if (_slides.length > 1) {
        _startBannerAutoPlay();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      AppSnack.showError(context, 'Failed to load products');
    }
  }

  Future<List<Map<String, String>>> _loadSlidesFromAssets() async {
    try {
      final slidesStr = await rootBundle.loadString('assets/data/slides.json');
      final List<dynamic> slidesJson = jsonDecode(slidesStr) as List<dynamic>;
      return slidesJson
          .map(
            (e) => {
              'image': (e['image'] as String?) ?? '',
              'title': (e['title'] as String?) ?? '',
            },
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> raw) {
    final name = (raw['name'] ?? '').toString();
    final type = (raw['category'] ?? 'other').toString().toLowerCase();
    final price = (raw['price'] as num?)?.toDouble() ?? 0.0;
    final unit = (raw['unit'] ?? 'kg').toString();
    final description = (raw['description'] ?? '').toString();
    final discount = (raw['discount'] as num?)?.toInt() ?? 0;
    final rating = (raw['rating'] as num?)?.toDouble() ?? 4.5;
    final sold = _asInt(raw['sold']);
    final addedAt = raw['createdAt'] ?? raw['addedAt'] ?? '';
    final measure = (raw['measure'] as num?)?.toDouble() ?? 1.0;
    final image = raw['image']?.toString();
    final benefits = (raw['benefits'] as List?)?.map((e) => e).toList();

    return {
      ...raw,
      'id': (raw['_id'] ?? raw['id'] ?? name).toString(),
      'name': name,
      'type': type,
      'category': _deriveCategoryLabel(type),
      'price': price,
      'unit': unit,
      'measure': measure,
      'description': description,
      if (benefits != null) 'benefits': benefits,
      'discount': discount,
      'rating': rating,
      'sold': sold,
      'addedAt': addedAt.toString(),
      'image': image,
    };
  }

  String _deriveCategoryLabel(String type) {
    switch (type) {
      case 'fruit':
        return 'Fruits';
      case 'juice':
        return 'Juices';
      case 'soft_drink':
        return 'Soft Drinks';
      case 'other':
        return 'Other Products';
      case 'berry':
      case 'berries':
        return 'Fruits';
      default:
        if (type.isEmpty) return 'Products';
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // _resolveProductImage no longer needed; handled by ResolvedImage

  // Small featured badge used in product cards
  Widget _featuredBadgeMini() {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Featured product',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.colorScheme.secondary.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.secondary.withValues(alpha: 0.18),
              blurRadius: 8,
              spreadRadius: 0.5,
            ),
          ],
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String? src, {BoxFit fit = BoxFit.contain}) {
    return ResolvedImage(
      src,
      fit: fit,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      placeholder: Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(
          Icons.local_grocery_store_outlined,
          color: Colors.grey,
        ),
      ),
      error: Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  void _startBannerAutoPlay() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(_bannerInterval, (_) {
      if (!mounted || _slides.isEmpty || !_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % _slides.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    });
  }

  bool get _isDefaultPriceRange =>
      _priceRange.start == 0 && _priceRange.end == 1000;
  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      !_isDefaultPriceRange ||
      _sort != 'none' ||
      _selectedCategories.isNotEmpty;

  void _clearAllFilters() {
    _searchController.clear();
    _searchQuery = '';
    _selectedCategories.clear();
    _priceRange = const RangeValues(0, 1000);
    _sort = 'none';
    _applyFilters();
  }

  Future<void> _openFilterSheet() async {
    final RangeValues initialRange = _priceRange;
    String tempSort = _sort;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        RangeValues localRange = initialRange;
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Filter & Sort',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Price range (₹)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  RangeSlider(
                    values: localRange,
                    min: 0,
                    max: 1000,
                    divisions: 20,
                    labels: RangeLabels(
                      '₹${localRange.start.round()}',
                      '₹${localRange.end.round()}',
                    ),
                    onChanged: (val) {
                      setLocal(() => localRange = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sort by price',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: tempSort == 'none',
                        onSelected: (_) => setLocal(() => tempSort = 'none'),
                      ),
                      ChoiceChip(
                        label: const Text('Low → High'),
                        selected: tempSort == 'asc',
                        onSelected: (_) => setLocal(() => tempSort = 'asc'),
                      ),
                      ChoiceChip(
                        label: const Text('High → Low'),
                        selected: tempSort == 'desc',
                        onSelected: (_) => setLocal(() => tempSort = 'desc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _priceRange = const RangeValues(0, 1000);
                              _sort = 'none';
                            });
                            _applyFilters();
                            Navigator.pop(context);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _priceRange = localRange;
                              _sort = tempSort;
                            });
                            _applyFilters();
                            Navigator.pop(context);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void addToCart(
    Map<String, dynamic> fruit, {
    double measure = 1.0,
    String unit = 'kg',
  }) {
    setState(() {
      final item = {
        ...fruit,
        'measure': measure,
        'unit': unit,
        'quantity': 1,
        'cartId':
            '${fruit['name']}-${DateTime.now().microsecondsSinceEpoch}-${cart.length}',
      };
      cart.add(item);
    });
    _scheduleCartSync();
    // Styled success snackbar via reusable helper
    final unitLabel = unit == 'L' ? 'L' : 'kg';
    final itemName = fruit['name'] as String;
    AppSnack.showSuccess(
      context,
      '$itemName ($measure$unitLabel) added to cart!',
    );
  }

  void _reorderItemsToCart(List<Map<String, dynamic>> items) {
    int added = 0;
    setState(() {
      for (final item in items) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final measure = (item['measure'] as num?)?.toDouble() ?? 1.0;
        final unit = (item['unit'] as String?) ?? 'kg';
        final base = {
          'name': item['name'],
          'image': item['image'],
          'price': item['price'],
          'measure': measure,
          'unit': unit,
        };
        // Seed quantity on the item so CartPage can initialize counts
        final cartItem = {
          ...base,
          'cartId':
              '${item['name']}-${DateTime.now().microsecondsSinceEpoch}-${cart.length}',
          'quantity': qty,
        };
        cart.add(cartItem);
        added += qty;
      }
    });
    if (added > 0) {
      _scheduleCartSync();
      AppSnack.showSuccess(context, 'Re-added $added item(s) to cart');
    }
  }

  void _showWeightSelector(Map<String, dynamic> fruit) {
    // Decide selector type depending on product category:
    final name = fruit['name'] as String;
    final isFruitItem = fruits.any((f) => (f['name'] as String) == name);
    final isSoftDrink = softDrinks.any((s) => (s['name'] as String) == name);

    // If it's neither fruit nor soft drink (e.g. juices/otherProducts) add directly.
    if (!isFruitItem && !isSoftDrink) {
      addToCart(fruit);
      return;
    }

    // Configure selector based on type
    final List<double> options = isSoftDrink ? [1.0, 2.0] : [0.25, 0.5, 1.0];
    double selected = isSoftDrink ? 1.0 : 1.0;
    final unit = isSoftDrink ? 'L' : 'kg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        // Use a local state inside the bottom sheet so buttons update immediately
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Use a local variable for the product name to keep interpolation simple
                  () {
                    final itemName = fruit['name'] as String;
                    return Text(
                      isSoftDrink
                          ? 'Select volume for $itemName'
                          : 'Select weight for $itemName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: options.map((o) {
                      String label;
                      if (isSoftDrink) {
                        label = o == 1.0 ? '1 L' : '${o.toInt()} L';
                      } else {
                        label = o == 1.0
                            ? '1 kg'
                            : (o == 0.5 ? '½ kg' : '¼ kg');
                      }
                      final isSelected = selected == o;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                            foregroundColor: isSelected
                                ? Colors.white
                                : Colors.black87,
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => setLocal(() => selected = o),
                          child: Text(label),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            addToCart(fruit, measure: selected, unit: unit);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_shopping_cart,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add to cart',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void toggleFavorite(Map<String, dynamic> fruit) async {
    final name = fruit['name'] as String;
    setState(() {
      if (favorites.contains(name)) {
        favorites.remove(name);
      } else {
        favorites.add(name);
      }
    });
    final list = favorites.toList();
    // Optimistic local persist for offline usage
    FavoritesStorage.save(list);
    // Fire-and-forget remote sync; ignore failures
    try {
      await UserDataApi.setFavorites(list);
    } catch (_) {}
  }

  Widget _cartIconWithBadge() {
    return Stack(
      children: [
        IconButton(icon: const Icon(Icons.shopping_cart), onPressed: _openCart),
        if (cart.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Text(
                cart.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openCart() async {
    final updated = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(builder: (_) => CartPage(cartItems: cart)),
    );
    if (updated != null) {
      setState(() => cart = updated);
      _scheduleCartSync();
    }
  }

  void _applyProfileResult(dynamic result) {
    if (!mounted) return;
    if (result is Map) {
      final avatar = result['avatarUrl'];
      if (avatar != null) {
        final avatarStr = avatar.toString().trim();
        if (avatarStr.isNotEmpty) {
          widget.userData['avatarUrl'] = avatarStr;
        }
      }
      final name = result['name'];
      if (name != null) {
        final nameStr = name.toString().trim();
        if (nameStr.isNotEmpty) {
          widget.userData['name'] = nameStr;
        }
      }
      final email = result['email'];
      if (email != null) {
        final emailStr = email.toString().trim();
        if (emailStr.isNotEmpty) {
          widget.userData['email'] = emailStr;
        }
      }
      if (result.containsKey('phone')) {
        final phoneStr = (result['phone'] ?? '').toString();
        widget.userData['phone'] = phoneStr;
      }
    }
    setState(() {});
  }

  // Drawer moved to a reusable widget: AppDrawer

  Widget _buildBannerCarousel() {
    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _bannerController,
              onPageChanged: (i) {
                setState(() => _bannerIndex = i);
                // reset autoplay countdown after manual swipe
                if (_slides.length > 1) {
                  _startBannerAutoPlay();
                }
              },
              itemCount: _slides.isEmpty ? 0 : _slides.length,
              itemBuilder: (context, index) {
                final slide = _slides[index];
                final img = slide['image'] ?? '';
                final title = slide['title'] ?? '';
                return AnimatedBuilder(
                  animation: _bannerController,
                  builder: (context, child) {
                    double t = 0;
                    if (_bannerController.position.haveDimensions) {
                      final page = _bannerController.page ?? 0.0;
                      t = (page - index).abs().clamp(0.0, 1.0);
                    }
                    final scale = 1.0 - (0.06 * t);
                    final opacity = 1.0 - (0.3 * t);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(img, fit: BoxFit.cover),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      title.isEmpty
                                          ? 'Fresh deals today'
                                          : title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
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
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.isEmpty ? 0 : _slides.length, (i) {
              final active = i == _bannerIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    Widget box({
      double h = 100,
      double r = 12,
      EdgeInsets m = EdgeInsets.zero,
    }) => Container(
      height: h,
      margin: m,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(r),
      ),
    );
    return ListView(
      children: [
        const SizedBox(height: 12),
        box(h: 220, m: const EdgeInsets.symmetric(horizontal: 12)),
        const SizedBox(height: 12),
        box(h: 20, m: const EdgeInsets.symmetric(horizontal: 14)),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (_, __) =>
                box(h: 210, m: const EdgeInsets.only(right: 10)),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: 5,
          ),
        ),
        const SizedBox(height: 12),
        box(h: 20, m: const EdgeInsets.symmetric(horizontal: 14)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.75,
          ),
          itemBuilder: (_, __) =>
              box(h: 200, m: const EdgeInsets.symmetric(horizontal: 12)),
          itemCount: 4,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _aboutVfcSection() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return FadeInSlide(
      offset: const Offset(0, 30),
      duration: const Duration(milliseconds: 800),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary,
                primary.withValues(alpha: 0.8),
                primary.withValues(alpha: 0.6),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(3.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with animated logo
                  _buildAnimatedHeader(primary),
                  const SizedBox(height: 16),
                  // Description with fade-in
                  _buildAnimatedDescription(),
                  const SizedBox(height: 20),
                  // Features grid with staggered animation
                  _buildFeaturesGrid(),
                  const SizedBox(height: 20),
                  // Divider with animation
                  _buildAnimatedDivider(primary),
                  const SizedBox(height: 16),
                  // Footer with CTA
                  _buildAnimatedFooter(primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(Color primary) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        // Clamp value to [0.0, 1.0] because elastic curves can overshoot
        final clampedValue = value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: 0.8 + (0.2 * clampedValue),
          child: Opacity(
            opacity: clampedValue,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, primary.withValues(alpha: 0.7)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'VFC',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About VFC',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 60,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, primary.withValues(alpha: 0.3)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedDescription() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Text(
              'VFC brings you farm-fresh fruits with uncompromising quality. We partner directly with trusted growers so you enjoy peak-season taste, transparent sourcing, and fair prices.',
              style: TextStyle(
                height: 1.5,
                fontSize: 14,
                color: Colors.grey.shade700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturesGrid() {
    final features = [
      (Icons.eco, 'Picked at peak freshness', Colors.green),
      (Icons.local_shipping, 'Fast, careful delivery', Colors.blue),
      (Icons.handshake, 'Direct from growers', Colors.orange),
      (Icons.verified, 'Quality checked', Colors.purple),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final (icon, text, color) = entry.value;
        return StaggeredAnimation(
          index: index,
          duration: const Duration(milliseconds: 600),
          child: _buildFeatureCard(icon, text, color),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureCard(IconData icon, String text, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDivider(Color primary) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: value * 0.3),
                primary.withValues(alpha: value * 0.1),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedFooter(Color primary) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From everyday staples to seasonal favorites, VFC is your go-to for better fruit—delivered.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildAnimatedCTAButton(primary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedCTAButton(Color primary) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.7 + (0.3 * value),
          child: Material(
            color: primary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdvancedAboutPage()),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
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
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Explore All',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, animValue, child) {
                        // Clamp value to [0.0, 1.0] because elastic curves can overshoot
                        final clampedAnimValue = animValue.clamp(0.0, 1.0);
                        return Transform.translate(
                          offset: Offset(5 * (1 - clampedAnimValue), 0),
                          child: Opacity(
                            opacity: clampedAnimValue,
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openProductSheet(Map<String, dynamic> fruit) {
    final name = fruit['name'] as String;
    final price = (fruit['price'] as num?)?.toDouble() ?? 0;
    final discount = (fruit['discount'] as num?)?.toInt() ?? 0;
    final double? originalValue = discount > 0
        ? price / (1 - (discount / 100))
        : null;
    final original = originalValue == null
        ? null
        : (originalValue.truncateToDouble() == originalValue
              ? originalValue.toInt()
              : originalValue.round());
    final lowerName = name.toLowerCase();
    final Map<String, dynamic>? det =
        _fruitDetails[lowerName] as Map<String, dynamic>?;
    final String aboutText = (det?['description'] as String?) ?? '';
    final List benefits = (det?['benefits'] as List?) ?? const [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Hero(
                  tag: 'img-$name',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildProductImage(fruit['image']?.toString()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (aboutText.isNotEmpty || benefits.isNotEmpty) ...[
                Text(
                  'About $name',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                if (aboutText.isNotEmpty)
                  Text(aboutText, style: const TextStyle(height: 1.35)),
                if (benefits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Benefits',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...benefits
                      .take(6)
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  b.toString(),
                                  style: const TextStyle(height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₹${price.round()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (original != null)
                        Text(
                          '₹$original',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.black38,
                          ),
                        ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showWeightSelector(fruit);
                    },
                    icon: Icon(
                      Icons.add_shopping_cart,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Add to cart',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _horizontalProducts(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    // Order featured products first without mutating the source list
    final List<Map<String, dynamic>> ordered = () {
      final f = <Map<String, dynamic>>[];
      final s = <Map<String, dynamic>>[];
      for (final p in items) {
        if ((p['isFeatured'] ?? false) == true) {
          f.add(p);
        } else {
          s.add(p);
        }
      }
      return [...f, ...s];
    }();
    return SizedBox(
      height: 210,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: ordered.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final theme = Theme.of(context);
          final fruit = ordered[index];
          final name = fruit['name'] as String;
          final keyId = 'h:$name';
          final isFav = favorites.contains(name);
          final discount = (fruit['discount'] as num?)?.toInt() ?? 0;
          final priceValue = (fruit['price'] as num?)?.toDouble() ?? 0;
          final priceLabel = priceValue.truncateToDouble() == priceValue
              ? priceValue.toInt().toString()
              : priceValue.toStringAsFixed(2);
          return MouseRegion(
            onEnter: (_) => setState(() => _hovered.add(keyId)),
            onExit: (_) => setState(() => _hovered.remove(keyId)),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: _hovered.contains(keyId) ? 1.03 : 1.0,
              child: SizedBox(
                width: 160,
                child: Card(
                  elevation: (fruit['isFeatured'] ?? false) == true ? 5 : 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: (fruit['isFeatured'] ?? false) == true
                        ? BorderSide(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.35,
                            ),
                            width: 1.2,
                          )
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    onTap: () => _openProductSheet(fruit),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Hero(
                                tag: 'img-${fruit['name']}',
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14),
                                  ),
                                  child: _buildProductImage(
                                    fruit['image']?.toString(),
                                  ),
                                ),
                              ),
                              if ((fruit['isFeatured'] ?? false) == true)
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: _featuredBadgeMini(),
                                ),
                              if (discount > 0)
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '-$discount%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: InkWell(
                                  onTap: () => toggleFavorite(fruit),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.white,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      transitionBuilder: (c, anim) =>
                                          ScaleTransition(
                                            scale: anim,
                                            child: c,
                                          ),
                                      child: Icon(
                                        isFav
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        key: ValueKey<bool>(isFav),
                                        color: isFav
                                            ? Colors.pink
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fruit['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber.shade600,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    (fruit['rating'] as num).toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₹$priceLabel',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    onPressed: () => _showWeightSelector(fruit),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _homeGrid(
    BuildContext context,
    List<Map<String, dynamic>> data, {
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    // Prioritize featured items to appear on the left/top positions.
    final ordered = () {
      final f = <Map<String, dynamic>>[];
      final s = <Map<String, dynamic>>[];
      for (final p in data) {
        if ((p['isFeatured'] ?? false) == true) {
          f.add(p);
        } else {
          s.add(p);
        }
      }
      return [...f, ...s];
    }();
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: ordered.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, index) {
          return StaggeredAnimation(
            index: index,
            duration: const Duration(milliseconds: 500),
            child: _buildEnhancedProductCard(ordered[index], index),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedProductCard(Map<String, dynamic> fruit, int index) {
    final theme = Theme.of(context);
    final name = fruit['name'] as String;
    final isFav = favorites.contains(name);
    final discount = (fruit['discount'] as num?)?.toInt() ?? 0;
    final price = (fruit['price'] as num?)?.toDouble() ?? 0;
    final rating = (fruit['rating'] as num?)?.toDouble() ?? 0.0;
    final sold = (fruit['sold'] as num?)?.toInt() ?? 0;
    final stock = (fruit['stock'] as num?)?.toInt() ?? 0;
    final isFeatured = (fruit['isFeatured'] ?? false) == true;
    final isHovered = _hovered.contains('grid-$name');
    final isPressed = _pressed.contains('grid-$name');

    final priceLabel = price.truncateToDouble() == price
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    final double? originalValue = discount > 0
        ? price / (1 - (discount / 100))
        : null;
    final String? originalLabel = originalValue == null
        ? null
        : (originalValue.truncateToDouble() == originalValue
              ? originalValue.toInt().toString()
              : originalValue.toStringAsFixed(2));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered.add('grid-$name')),
      onExit: (_) => setState(() => _hovered.remove('grid-$name')),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed.add('grid-$name')),
        onTapUp: (_) => setState(() => _pressed.remove('grid-$name')),
        onTapCancel: () => setState(() => _pressed.remove('grid-$name')),
        onTap: () => _openProductSheet(fruit),
        child: AnimatedScale(
          scale: isHovered || isPressed ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Transform.translate(
            offset: Offset(0.0, isHovered || isPressed ? -4.0 : 0.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: isFeatured
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.05),
                          theme.colorScheme.secondary.withValues(alpha: 0.02),
                        ],
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isFeatured
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: isHovered || isPressed ? 20 : 12,
                    offset: Offset(0, isHovered || isPressed ? 8 : 4),
                    spreadRadius: isHovered || isPressed ? 2 : 0,
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: isFeatured
                      ? BorderSide(
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.5,
                          ),
                          width: 1.5,
                        )
                      : BorderSide(
                          color: Colors.grey.withValues(alpha: 0.1),
                          width: 1,
                        ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Section
                    Expanded(
                      flex: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Product Image
                          Hero(
                            tag: 'img-$name',
                            child: _buildProductImage(
                              fruit['image']?.toString(),
                              fit: BoxFit.cover,
                            ),
                          ),
                          // Gradient Overlay
                          if (isHovered || isPressed)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.15),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Discount Badge
                          if (discount > 0)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: PulseAnimation(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE91E63),
                                        Color(0xFFF06292),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.pink.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_offer,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$discount% OFF',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Favorite Button
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => toggleFavorite(fruit),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, animation) {
                                      return ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      );
                                    },
                                    child: Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      key: ValueKey<bool>(isFav),
                                      color: isFav
                                          ? Colors.pink
                                          : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Featured Badge
                          if (isFeatured)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: _featuredBadgeMini(),
                            ),
                          // Stock Indicator
                          if (stock > 0 && stock < 10)
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Only $stock left',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Product Info Section
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Product Name
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Rating and Category Row
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 12,
                                          color: Colors.amber.shade700,
                                        ),
                                        const SizedBox(width: 2),
                                        Flexible(
                                          child: Text(
                                            rating.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.amber.shade900,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (sold > 0) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        '$sold sold',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      fruit['category']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Price and Add Button Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '₹$priceLabel',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                                color:
                                                    theme.colorScheme.primary,
                                                height: 1.1,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (originalLabel != null) ...[
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                '₹$originalLabel',
                                                style: TextStyle(
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  color: Colors.grey.shade500,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.1,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (fruit['unit'] != null)
                                        Text(
                                          '/${fruit['unit']}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey.shade600,
                                            height: 1.0,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Material(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () => _showWeightSelector(fruit),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add_shopping_cart_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return FadeInSlide(
      offset: const Offset(0, 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EnhancedSectionHeader(
              title: 'Quick Actions',
              subtitle: 'Fast access to your favorites',
              icon: Icons.flash_on,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnimatedActionButton(
                    icon: Icons.local_offer,
                    label: 'Offers',
                    color: Colors.red,
                    onTap: () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent * 0.25,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAnimatedActionButton(
                    icon: Icons.trending_up,
                    label: 'Trending',
                    color: Colors.orange,
                    onTap: () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent * 0.35,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAnimatedActionButton(
                    icon: Icons.favorite,
                    label: 'Favorites',
                    color: Colors.pink,
                    onTap: () {
                      setState(() => _selectedIndex = 2);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAnimatedActionButton(
                    icon: Icons.shopping_cart,
                    label: 'Cart',
                    color: Colors.blue,
                    onTap: _openCart,
                    badge: cart.length,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + (label.length * 50)),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          // Clamp value to [0.0, 1.0] because elastic curves can overshoot
          final clampedValue = value.clamp(0.0, 1.0);
          return Transform.scale(
            scale: 0.8 + (0.2 * clampedValue),
            child: Opacity(
              opacity: clampedValue,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: Offset(0, 6 * clampedValue),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(icon, color: Colors.white, size: 24),
                        if (badge != null && badge > 0)
                          Positioned(
                            right: -8,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                badge > 9 ? '9+' : '$badge',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpecialOffersSection() {
    return FadeInSlide(
      offset: const Offset(0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnhancedSectionHeader(
            title: 'Special Offers',
            subtitle: 'Limited time deals - Don\'t miss out!',
            icon: Icons.local_offer,
            action: TextButton.icon(
              onPressed: () {
                // Show all offers
                _applyFilters();
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: specialOffers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return StaggeredAnimation(
                  index: index,
                  duration: const Duration(milliseconds: 600),
                  child: _buildOfferCard(specialOffers[index], index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> product, int index) {
    final discount = (product['discount'] as num?)?.toInt() ?? 0;
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final originalPrice = discount > 0 ? price / (1 - (discount / 100)) : null;
    final isHovered = _hovered.contains('offer-$index');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered.add('offer-$index')),
      onExit: (_) => setState(() => _hovered.remove('offer-$index')),
      child: GestureDetector(
        onTap: () => _openProductSheet(product),
        child: AnimatedScale(
          scale: isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.shade50,
                  Colors.orange.shade50,
                  if (isHovered) Colors.pink.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.red.withValues(alpha: isHovered ? 0.4 : 0.2),
                width: isHovered ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: isHovered ? 0.25 : 0.15),
                  blurRadius: isHovered ? 20 : 15,
                  offset: Offset(0, isHovered ? 12 : 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: _buildProductImage(
                          product['image']?.toString(),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: PulseAnimation(
                        child: OfferBadge(discount: discount),
                      ),
                    ),
                    if (isHovered)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '₹${price.toInt()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.red,
                            ),
                          ),
                          if (originalPrice != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '₹${originalPrice.toInt()}',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingSection() {
    return FadeInSlide(
      offset: const Offset(0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnhancedSectionHeader(
            title: 'Trending Now',
            subtitle: 'Most popular products this week',
            icon: Icons.trending_up,
            action: TextButton.icon(
              onPressed: () {
                // Show all trending
                _applyFilters();
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: trendingProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return StaggeredAnimation(
                  index: index,
                  duration: const Duration(milliseconds: 600),
                  child: _buildTrendingCard(trendingProducts[index], index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingCard(Map<String, dynamic> product, int index) {
    final sold = (product['sold'] as num?)?.toInt() ?? 0;
    final rating = (product['rating'] as num?)?.toDouble() ?? 0.0;
    final isHovered = _hovered.contains('trending-$index');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered.add('trending-$index')),
      onExit: (_) => setState(() => _hovered.remove('trending-$index')),
      child: GestureDetector(
        onTap: () => _openProductSheet(product),
        child: AnimatedScale(
          scale: isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isHovered
                    ? [Colors.white, Colors.orange.shade50]
                    : [Colors.white, Colors.white],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orange.withValues(alpha: isHovered ? 0.4 : 0.2),
                width: isHovered ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: isHovered ? 0.2 : 0.1),
                  blurRadius: isHovered ? 16 : 12,
                  offset: Offset(0, isHovered ? 8 : 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: _buildProductImage(
                          product['image']?.toString(),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: PulseAnimation(child: const TrendingBadge()),
                    ),
                    if (isHovered)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.orange.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$sold sold',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${(product['price'] as num?)?.toInt() ?? 0}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Home
    if (_selectedIndex == 0) {
      if (_loading) {
        return _buildLoadingSkeleton();
      }
      return RefreshIndicator(
        onRefresh: () async {
          await _loadData();
          if (mounted) setState(() {});
        },
        child: ListView(
          controller: _scrollController,
          children: [
            FadeInSlide(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterFruits,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildBannerCarousel(),
            const SizedBox(height: 20),
            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 16),
            // Special Offers Section
            if (specialOffers.isNotEmpty) _buildSpecialOffersSection(),
            const SizedBox(height: 16),
            // Trending Products Section
            if (trendingProducts.isNotEmpty) _buildTrendingSection(),
            const SizedBox(height: 8),
            // Top Categories removed as requested
            if (_allCategories.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    ..._allCategories.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: _selectedCategories.contains(c),
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _selectedCategories.add(c);
                              } else {
                                _selectedCategories.remove(c);
                              }
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                    if (_hasActiveFilters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.clear, size: 18),
                          label: const Text('Clear filters'),
                          onPressed: _clearAllFilters,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // All Products Section
            EnhancedSectionHeader(
              title: 'All Products',
              subtitle: 'Browse our complete catalog',
              icon: Icons.store,
            ),
            if (filteredFruits.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('No products match your filters'),
                    const SizedBox(height: 8),
                    if (_hasActiveFilters)
                      OutlinedButton.icon(
                        onPressed: _clearAllFilters,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear filters'),
                      ),
                  ],
                ),
              )
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey<String>(
                    '${filteredFruits.length}-$_searchQuery-$_sort-${_selectedCategories.join(',')}-${_priceRange.start}-${_priceRange.end}',
                  ),
                  child: _homeGrid(
                    context,
                    filteredFruits,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _aboutVfcSection(),
            // Bottom padding to prevent overflow and account for bottom navigation
            SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
          ],
        ),
      );
    }
    // Orders Page
    if (_selectedIndex == 1) {
      return OrdersPage(onReorder: _reorderItemsToCart);
    }
    // Favorites (grouped by section)
    if (_selectedIndex == 2) {
      final Map<String, Map<String, dynamic>> fruitsByName = {
        for (final p in fruits) (p['name'] as String): p,
      };
      final Map<String, Map<String, dynamic>> juicesByName = {
        for (final p in juices) (p['name'] as String): p,
      };
      final Map<String, Map<String, dynamic>> softByName = {
        for (final p in softDrinks) (p['name'] as String): p,
      };
      final Map<String, Map<String, dynamic>> othersByName = {
        for (final p in otherProducts) (p['name'] as String): p,
      };

      final favFruits = <Map<String, dynamic>>[];
      final favJuices = <Map<String, dynamic>>[];
      final favSoft = <Map<String, dynamic>>[];
      final favOthers = <Map<String, dynamic>>[];

      for (final name in favorites) {
        if (fruitsByName.containsKey(name)) {
          favFruits.add(fruitsByName[name]!);
          continue;
        }
        if (juicesByName.containsKey(name)) {
          favJuices.add(juicesByName[name]!);
          continue;
        }
        if (softByName.containsKey(name)) {
          favSoft.add(softByName[name]!);
          continue;
        }
        if (othersByName.containsKey(name)) {
          favOthers.add(othersByName[name]!);
          continue;
        }
      }

      final hasAny =
          favFruits.isNotEmpty ||
          favJuices.isNotEmpty ||
          favSoft.isNotEmpty ||
          favOthers.isNotEmpty;

      if (!hasAny) {
        return const Center(child: Text('No favorites yet'));
      }

      return ListView(
        children: [
          // Removed Fresh Juices and Soft Drinks favorites sections
          if (favOthers.isNotEmpty) ...[
            _sectionHeader('Other Products'),
            _horizontalProducts(favOthers),
            const SizedBox(height: 8),
          ],
          if (favFruits.isNotEmpty) ...[
            _sectionHeader('Fruits'),
            _horizontalProducts(favFruits),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
        ],
      );
    }
    return _homeGrid(context, filteredFruits);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        userData: widget.userData,
        cartCount: cart.length,
        onOpenHome: () => Navigator.pop(context),
        onOpenCart: () {
          Navigator.pop(context);
          _openCart();
        },
        onOpenFavorites: () {
          Navigator.pop(context);
          setState(() => _selectedIndex = 2);
        },
        onOpenProfile: () async {
          Navigator.pop(context);
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfilePage(userData: widget.userData, openCart: _openCart),
            ),
          );
          _applyProfileResult(result);
        },
        onOpenSettings: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
        onLogout: () async {
          if (!mounted || !context.mounted) return;
          Navigator.pop(context); // Close drawer immediately for UX
          // Final cart sync (no debounce) to persist latest state
          final payload = cart
              .map(
                (e) => {
                  'name': e['name'],
                  'image': e['image'],
                  'price': e['price'],
                  'measure': (e['measure'] as num?)?.toDouble() ?? 1.0,
                  'unit': e['unit'] ?? 'kg',
                  'quantity': (e['quantity'] as num?)?.toInt() ?? 1,
                },
              )
              .toList();
          try {
            await UserDataApi.setCart(payload);
          } catch (_) {}
          if (!mounted) return;
          // Clear local caches to avoid cross-account mixing
          setState(() {
            cart.clear();
            favorites.clear();
          });
          try {
            await FavoritesStorage.clear();
          } catch (_) {}
          await AuthService.logout();
          if (!mounted || !context.mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        },
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Fruizo by VFC',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Builder(
          builder: (context) {
            final primary = Theme.of(context).colorScheme.primary;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, Color.lerp(primary, Colors.white, 0.2)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Filter & Sort',
            icon: const Icon(Icons.tune),
            onPressed: _openFilterSheet,
          ),
          _cartIconWithBadge(),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) async {
          if (index == 3) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProfilePage(userData: widget.userData, openCart: _openCart),
              ),
            );
            _applyProfileResult(result);
            return;
          }
          setState(() => _selectedIndex = index);
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
