import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/product_api.dart';
// removed unused imports: responsive and animated_sections

class AdvancedAboutPage extends StatefulWidget {
  const AdvancedAboutPage({super.key});

  @override
  State<AdvancedAboutPage> createState() => _AdvancedAboutPageState();
}

class _AdvancedAboutPageState extends State<AdvancedAboutPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _loading = true;
  int _totalProducts = 0;
  int _featuredProducts = 0;
  int _categories = 0;
  int _discountedProducts = 0;
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
    });
    try {
      _baseUrl = AuthService.getBaseUrl();
      final products = await ProductApi.fetchProducts();
      final categories = <String>{};
      int featured = 0;
      int discounted = 0;
      for (final p in products) {
        final cat = (p['category'] ?? 'other').toString();
        categories.add(cat);
        if ((p['isFeatured'] ?? false) == true) featured++;
        final discount = (p['discount'] as num?)?.toDouble() ?? 0;
        if (discount > 0) discounted++;
      }
      if (!mounted) return;
      setState(() {
        _totalProducts = products.length;
        _featuredProducts = featured;
        _categories = categories.length;
        _discountedProducts = discounted;
        _loading = false;
      });
      _controller.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required int value,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Semantics(
      label: '$label: $value',
      child: AnimatedBuilder(
        animation: _fadeIn,
        builder: (context, _) {
          final t = _fadeIn.value;
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.95 + 0.05 * t,
              child: Container(
                width: 160,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.12),
                      accent.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: accent.withValues(alpha: 0.15),
                          foregroundColor: accent,
                          child: Icon(icon),
                        ),
                        const Spacer(),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: value),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Text(
                            v.toString(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
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

  Widget _animatedHeader() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 190,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WavePainter(
                  theme.colorScheme.onPrimary.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 40,
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About VFC Fruit Shop',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quality produce, crafted experiences, and data-driven freshness.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(
                        alpha: 0.85,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _animatedHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            children: [
                              _metricCard(
                                icon: Icons.shopping_basket_outlined,
                                label: 'Products',
                                value: _totalProducts,
                                color: theme.colorScheme.primary,
                              ),
                              _metricCard(
                                icon: Icons.star_rate_rounded,
                                label: 'Featured',
                                value: _featuredProducts,
                                color: theme.colorScheme.secondary,
                              ),
                              _metricCard(
                                icon: Icons.category_outlined,
                                label: 'Categories',
                                value: _categories,
                                color: theme.colorScheme.tertiary,
                              ),
                              _metricCard(
                                icon: Icons.percent,
                                label: 'Discounted',
                                value: _discountedProducts,
                                color: Colors.amber.shade700,
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _storySection(),
                          const SizedBox(height: 32),
                          _valuesSection(),
                          const SizedBox(height: 32),
                          _techSection(),
                          const SizedBox(height: 48),
                          Center(
                            child: Text(
                              'Base API: ${_baseUrl ?? '—'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadStats,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }

  Widget _storySection() {
    final theme = Theme.of(context);
    return _animatedReveal(
      title: 'Our Story',
      icon: Icons.timeline,
      child: Text(
        'Starting as a local vendor experiment, VFC Fruit Shop grew into a platform '
        'focused on freshness metrics, seasonal insights, and customer-centric delivery experiences. '
        'We blend agricultural knowledge with intuitive design to make healthy choices frictionless.',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _valuesSection() {
    final theme = Theme.of(context);
    final values = [
      ['Freshness', 'We optimise sourcing windows and cold-chain timings.'],
      ['Transparency', 'Clear pricing, origin tagging, and honest ratings.'],
      [
        'Sustainability',
        'Reducing waste through demand prediction and smart inventory.',
      ],
      ['Community', 'Empowering local growers and fair-trade practices.'],
    ];
    return _animatedReveal(
      title: 'Core Values',
      icon: Icons.favorite_outline,
      child: Column(
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v[0],
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(v[1], style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _techSection() {
    final theme = Theme.of(context);
    final techPoints = [
      'Hybrid caching layers for low-latency product catalogue access.',
      'Adaptive image loading with resolution negotiation.',
      'Analytics-driven featured product rotation.',
      'Semantic accessibility and responsive layout engine.',
    ];
    return _animatedReveal(
      title: 'Platform Highlights',
      icon: Icons.insights_outlined,
      child: Column(
        children: [
          for (final p in techPoints)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.bolt,
                    color: theme.colorScheme.secondary,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _animatedReveal({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - t)),
              child: Container(
                width: constraints.maxWidth,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          foregroundColor: theme.colorScheme.primary,
                          child: Icon(icon),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    child,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  _WavePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color, color.withValues(alpha: 0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final h = size.height;
    final w = size.width;
    for (int i = 0; i < 3; i++) {
      final amplitude = 12.0 + i * 6;
      final yOffset = h * 0.55 + i * 18;
      path.reset();
      path.moveTo(0, yOffset);
      for (double x = 0; x <= w; x += 12) {
        final y = yOffset + math.sin((x / w) * math.pi * 2 + i) * amplitude;
        path.lineTo(x, y);
      }
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.color != color;
}
