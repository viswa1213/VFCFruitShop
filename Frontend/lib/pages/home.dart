import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fruit_shop/pages/cart.dart';
import 'package:fruit_shop/pages/profile.dart';
import 'package:fruit_shop/pages/orders.dart';
import 'package:fruit_shop/widgets/app_drawer.dart';
import 'package:fruit_shop/pages/settings.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:fruit_shop/services/app_theme.dart';
import 'package:fruit_shop/services/favorites_storage.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/services/auth_service.dart';

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
  // Featured content removed; no featured data list needed.
  List<Map<String, dynamic>> _bestSellersData = [];
  List<Map<String, String>> _slides = [];
  // Fruit details loaded from assets/data/fruit_details.json
  Map<String, dynamic> _fruitDetails = {};
  bool _loading = true;

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
      final productsStr = await rootBundle.loadString(
        'assets/data/products.json',
      );
      final List<dynamic> productsJson =
          jsonDecode(productsStr) as List<dynamic>;
      final List<Map<String, dynamic>> all = productsJson
          .cast<Map<String, dynamic>>();

      // Index by name for quick lookups
      final Map<String, Map<String, dynamic>> byName = {
        for (final p in all) (p['name'] as String): p,
      };

      // Featured names removed as Featured section is not used.

      // Best sellers names
      List<String> bestNames = [];
      try {
        final bestStr = await rootBundle.loadString(
          'assets/data/best_sellers.json',
        );
        bestNames = (jsonDecode(bestStr) as List<dynamic>).cast<String>();
      } catch (_) {}

      // Slides (banner)
      List<Map<String, String>> slides = [];
      try {
        final slidesStr = await rootBundle.loadString(
          'assets/data/slides.json',
        );
        final List<dynamic> slidesJson = jsonDecode(slidesStr) as List<dynamic>;
        slides = slidesJson
            .map(
              (e) => {
                'image': (e['image'] as String?) ?? '',
                'title': (e['title'] as String?) ?? '',
              },
            )
            .toList();
      } catch (_) {}
      // Juices (optional)
      List<Map<String, dynamic>> juicesList = [];
      try {
        final juicesStr = await rootBundle.loadString(
          'assets/data/juices.json',
        );
        juicesList = (jsonDecode(juicesStr) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      } catch (_) {}

      // Soft Drinks (optional)
      List<Map<String, dynamic>> softDrinksList = [];
      try {
        final sdStr = await rootBundle.loadString(
          'assets/data/soft_drinks.json',
        );
        softDrinksList = (jsonDecode(sdStr) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      } catch (_) {}

      // Other Products (optional)
      List<Map<String, dynamic>> othersList = [];
      try {
        final otStr = await rootBundle.loadString(
          'assets/data/other_products.json',
        );
        othersList = (jsonDecode(otStr) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      } catch (_) {}

      // Try to load extra product details from multiple category files
      Map<String, dynamic> details = {};
      try {
        final detStr = await rootBundle.loadString(
          'assets/data/fruit_details.json',
        );
        final Map<String, dynamic> detJson =
            jsonDecode(detStr) as Map<String, dynamic>;
        // Normalize keys to lowercase for resilient lookups
        details = {
          for (final entry in detJson.entries)
            entry.key.toLowerCase(): entry.value,
        };
      } catch (_) {}
      // Juices details
      try {
        final detStr = await rootBundle.loadString(
          'assets/data/juices_details.json',
        );
        final Map<String, dynamic> detJson =
            jsonDecode(detStr) as Map<String, dynamic>;
        details.addAll({
          for (final entry in detJson.entries)
            entry.key.toLowerCase(): entry.value,
        });
      } catch (_) {}
      // Soft drinks details
      try {
        final detStr = await rootBundle.loadString(
          'assets/data/soft_drinks_details.json',
        );
        final Map<String, dynamic> detJson =
            jsonDecode(detStr) as Map<String, dynamic>;
        details.addAll({
          for (final entry in detJson.entries)
            entry.key.toLowerCase(): entry.value,
        });
      } catch (_) {}
      // Other products details
      try {
        final detStr = await rootBundle.loadString(
          'assets/data/other_products_details.json',
        );
        final Map<String, dynamic> detJson =
            jsonDecode(detStr) as Map<String, dynamic>;
        details.addAll({
          for (final entry in detJson.entries)
            entry.key.toLowerCase(): entry.value,
        });
      } catch (_) {}

      setState(() {
        fruits = all;
        juices = juicesList;
        softDrinks = softDrinksList;
        otherProducts = othersList;
        _bestSellersData = bestNames
            .map((n) => byName[n])
            .whereType<Map<String, dynamic>>()
            .toList();
        filteredFruits = List.from([
          ...all,
          ...juicesList,
          ...softDrinksList,
          ...othersList,
        ]);
        _slides = slides;
        _fruitDetails = details;
        _loading = false;
      });
      if (_slides.length > 1) {
        _startBannerAutoPlay();
      }
    } catch (e) {
      // If anything fails, keep initial state but stop loading
      setState(() {
        _loading = false;
        filteredFruits = List.from(fruits);
      });
    }
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
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () async {
            final updated = await Navigator.push<List<Map<String, dynamic>>>(
              context,
              MaterialPageRoute(builder: (_) => CartPage(cartItems: cart)),
            );
            if (updated != null) {
              setState(() => cart = updated);
              _scheduleCartSync();
            }
          },
        ),
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

  // Drawer moved to a reusable widget: AppDrawer

  Widget _buildBannerCarousel() {
    return SizedBox(
      height: 160,
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
        box(h: 160, m: const EdgeInsets.symmetric(horizontal: 12)),
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
    // Entrance animation for the footer card (fade + slight slide + animated border)
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final beginAlign = Alignment(-0.6 + 0.2 * (1 - t), 0);
        final endAlign = Alignment(0.6 - 0.2 * (1 - t), 0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: beginAlign,
                    end: endAlign,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Color.lerp(
                        Theme.of(context).colorScheme.primary,
                        Colors.white,
                        0.25,
                      )!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  margin: const EdgeInsets.all(
                    2.0,
                  ), // gradient border thickness
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: const Text(
                                'VFC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'About VFC',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'VFC brings you farm-fresh fruits with uncompromising quality. We partner directly with trusted growers so you enjoy peak-season taste, transparent sourcing, and fair prices.',
                          style: TextStyle(height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _AboutRow(
                              icon: Icons.eco,
                              text: 'Picked at peak freshness',
                            ),
                            _AboutRow(
                              icon: Icons.local_shipping,
                              text: 'Fast, careful delivery',
                            ),
                            _AboutRow(
                              icon: Icons.handshake,
                              text: 'Direct from growers',
                            ),
                            _AboutRow(
                              icon: Icons.verified,
                              text: 'Quality checked',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'From everyday staples to seasonal favorites, VFC is your go-to for better fruit—delivered.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                _clearAllFilters();
                                AppSnack.showInfo(
                                  context,
                                  'Filters cleared. Explore all fruits',
                                );
                              },
                              icon: const Icon(
                                Icons.local_grocery_store,
                                size: 18,
                              ),
                              label: const Text('Explore All'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                side: BorderSide(
                                  color: Color.lerp(
                                    Theme.of(context).colorScheme.primary,
                                    Colors.white,
                                    0.4,
                                  )!,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
    final price = (fruit['price'] as num).toDouble();
    final discount = (fruit['discount'] as num?)?.toInt() ?? 0;
    final original = discount > 0
        ? (price / (1 - (discount / 100))).round()
        : null;
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
                    child: Image.asset(fruit['image'], fit: BoxFit.cover),
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
                      Text(
                        '₹${price.round()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
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
                    label: Text(
                      'Add to cart',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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

  // Featured section removed; featured items getter no longer needed.
  List<Map<String, dynamic>> get _bestSellers {
    if (_bestSellersData.isNotEmpty) return _bestSellersData;
    final list = List<Map<String, dynamic>>.from(fruits);
    list.sort((a, b) => (b['sold'] as int).compareTo(a['sold'] as int));
    return list.take(10).toList();
  }

  List<Map<String, dynamic>> get _newArrivals {
    final list = List<Map<String, dynamic>>.from(fruits);
    DateTime parseDate(String s) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    list.sort(
      (a, b) => parseDate(
        b['addedAt']?.toString() ?? '',
      ).compareTo(parseDate(a['addedAt']?.toString() ?? '')),
    );
    return list.take(10).toList();
  }

  List<Map<String, dynamic>> get _topRated {
    final list = List<Map<String, dynamic>>.from(fruits);
    list.sort((a, b) => (b['rating'] as num).compareTo(a['rating'] as num));
    return list.take(10).toList();
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
    return SizedBox(
      height: 210,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final fruit = items[index];
          final name = fruit['name'] as String;
          final keyId = 'h:$name';
          final isFav = favorites.contains(name);
          return MouseRegion(
            onEnter: (_) => setState(() => _hovered.add(keyId)),
            onExit: (_) => setState(() => _hovered.remove(keyId)),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: _hovered.contains(keyId) ? 1.03 : 1.0,
              child: SizedBox(
                width: 160,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                                  child: Image.asset(
                                    fruit['image'],
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              if ((fruit['discount'] as int) > 0)
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
                                      '-${fruit['discount']}%',
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
                                    '₹${fruit['price']}',
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
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: data.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final fruit = data[index];
          final name = fruit['name'] as String;
          final isFav = favorites.contains(name);
          final discount = (fruit['discount'] as num?)?.toInt() ?? 0;
          final price = (fruit['price'] as num).toDouble();
          final original = discount > 0
              ? (price / (1 - (discount / 100))).round()
              : null;

          return MouseRegion(
            onEnter: (_) => setState(() => _hovered.add(name)),
            onExit: (_) => setState(() => _hovered.remove(name)),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressed.add(name)),
              onTapUp: (_) => setState(() => _pressed.remove(name)),
              onTapCancel: () => setState(() => _pressed.remove(name)),
              onTap: () => _openProductSheet(fruit),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                scale: (_hovered.contains(name) || _pressed.contains(name))
                    ? 1.03
                    : 1.0,
                child: Stack(
                  children: [
                    Card(
                      elevation:
                          (_hovered.contains(name) || _pressed.contains(name))
                          ? 10
                          : 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Hero(
                                    tag: 'img-$name',
                                    child: Image.asset(
                                      fruit['image'],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                  color: Colors.red,
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                                if (discount > 0)
                                  Positioned(
                                    left: 10,
                                    top: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '-$discount%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: InkWell(
                                    onTap: () => toggleFavorite(fruit),
                                    child: CircleAvatar(
                                      radius: 18,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
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
                                    const SizedBox(width: 3),
                                    Text(
                                      ((fruit['rating'] as num?)?.toDouble() ??
                                              0)
                                          .toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        fruit['category']?.toString() ?? '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '₹${price.round()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (original != null)
                                          Text(
                                            '₹$original',
                                            style: const TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Colors.black38,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      onPressed: () =>
                                          _showWeightSelector(fruit),
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
                  ],
                ),
              ),
            ),
          );
        },
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
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) setState(() {});
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterFruits,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _buildBannerCarousel(),
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
            if (juices.isNotEmpty) ...[
              _sectionHeader('Fresh Juices'),
              _horizontalProducts(juices),
              const SizedBox(height: 8),
            ],
            if (softDrinks.isNotEmpty) ...[
              _sectionHeader('Soft Drinks'),
              _horizontalProducts(softDrinks),
              const SizedBox(height: 8),
            ],
            if (otherProducts.isNotEmpty) ...[
              _sectionHeader('Other Products'),
              _horizontalProducts(otherProducts),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            // Featured section removed as requested
            _sectionHeader('Best Sellers'),
            _horizontalProducts(_bestSellers),
            const SizedBox(height: 8),
            _sectionHeader('New Arrivals'),
            _horizontalProducts(_newArrivals),
            const SizedBox(height: 8),
            _sectionHeader('Top Rated'),
            _horizontalProducts(_topRated),
            const SizedBox(height: 8),
            _sectionHeader('All Products'),
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
            const SizedBox(height: 24),
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
          if (favJuices.isNotEmpty) ...[
            _sectionHeader('Fresh Juices'),
            _horizontalProducts(favJuices),
            const SizedBox(height: 8),
          ],
          if (favSoft.isNotEmpty) ...[
            _sectionHeader('Soft Drinks'),
            _horizontalProducts(favSoft),
            const SizedBox(height: 8),
          ],
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CartPage(cartItems: cart)),
          );
        },
        onOpenFavorites: () {
          Navigator.pop(context);
          setState(() => _selectedIndex = 2);
        },
        onOpenProfile: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfilePage(userData: widget.userData),
            ),
          );
        },
        onOpenSettings: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
        onLogout: () async {
          if (!mounted) return;
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
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        },
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Fruit Shop',
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
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.mode,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                tooltip: isDark ? 'Light mode' : 'Dark mode',
                icon: Icon(isDark ? Icons.wb_sunny : Icons.dark_mode),
                onPressed: AppTheme.toggle,
              );
            },
          ),
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
        onTap: (index) {
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(userData: widget.userData),
              ),
            );
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

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AboutRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
