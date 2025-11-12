import 'dart:math' as math;

import 'package:flutter/material.dart';
// removed unused imports: responsive and animated_sections

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heroOpacity;
  late final Animation<double> _contentOpacity;

  final _values = const [
    (
      Icons.eco,
      'Sustainable Farming',
      'Direct sourcing from growers using water-conscious and organic-first practices.',
    ),
    (
      Icons.delivery_dining,
      'Cold Chain Delivery',
      'Refrigerated hubs keep every batch crisp from farm gate to doorstep.',
    ),
    (
      Icons.favorite_border,
      'Customer Delight',
      'Thoughtful packaging, recipe inspiration, and support that actually listens.',
    ),
  ];

  final _milestones = const [
    ('2018', 'Started with a single farmers\' market stall in Coimbatore.'),
    ('2020', 'Built the first regional cold-storage network for fruits.'),
    ('2023', 'Launched VFC app with traceability down to the orchard level.'),
    ('2025', 'Serving 120K+ monthly orders with <24h delivery across TN & KA.'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _heroOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
    );
    _contentOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _heroOpacity.value;
                return CustomPaint(
                  painter: _OrbitalPainter(
                    color: primary.withValues(alpha: 0.08 + 0.12 * t),
                    progress: t,
                  ),
                );
              },
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 240,
                backgroundColor: primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('About VFC'),
                  centerTitle: true,
                  background: FadeTransition(
                    opacity: _heroOpacity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primary,
                                Color.lerp(primary, Colors.white, 0.35)!,
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 32.0),
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                final wave =
                                    6 +
                                    12 *
                                        math.sin((_controller.value * math.pi));
                                return Transform.translate(
                                  offset: Offset(0, wave),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          'Farm-to-Fork, Reimagined',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'We partner with growers, invest in cold-chain tech, and obsess over freshness so you do not have to.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(height: 1.35),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _contentOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        context,
                        'Our Promise',
                        'Three pillars keep every delivery vibrant.',
                      ),
                      const SizedBox(height: 12),
                      _buildValueCards(context),
                      const SizedBox(height: 28),
                      _buildSectionHeader(
                        context,
                        'Impact Snapshot',
                        'Transparency is baked into our operations.',
                      ),
                      const SizedBox(height: 12),
                      _buildStatsRow(context),
                      const SizedBox(height: 28),
                      _buildSectionHeader(
                        context,
                        'Journey so far',
                        'Milestones that shaped VFC.',
                      ),
                      const SizedBox(height: 12),
                      _buildTimeline(context),
                      const SizedBox(height: 28),
                      _buildSectionHeader(
                        context,
                        'Meet the crew',
                        'Humans behind the harvest.',
                      ),
                      const SizedBox(height: 12),
                      _buildTeam(context),
                      const SizedBox(height: 36),
                      _buildFooterCta(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  double _stagger(
    double controllerValue,
    double start,
    double end, {
    Curve curve = Curves.linear,
  }) {
    if (end <= start) return controllerValue >= end ? 1 : 0;
    if (controllerValue <= start) return 0;
    if (controllerValue >= end) return 1;
    final normalized = ((controllerValue - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    final eased = curve.transform(normalized);
    return eased.clamp(0.0, 1.0);
  }

  Widget _buildValueCards(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final value = _values[index];
          final delay = 0.1 * index;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _stagger(
                _controller.value,
                0.35 + delay,
                0.75 + delay,
                curve: Curves.easeOutQuart,
              );
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - t)),
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: primary.withValues(alpha: 0.1),
                          child: Icon(value.$1, color: primary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          value.$2,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(value.$3, style: const TextStyle(height: 1.35)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemCount: _values.length,
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final stats = const [
      ('98%', 'Orders delivered within 24 hours'),
      ('37k', 'Kilograms saved from spoilage monthly'),
      ('4.8★', 'Community rating across platforms'),
    ];
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: stats.map((stat) {
          final index = stats.indexOf(stat);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _stagger(
                _controller.value,
                0.45 + 0.08 * index,
                0.9 + 0.08 * index,
                curve: Curves.easeOutCubic,
              );
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - t)),
                  child: Container(
                    width: MediaQuery.of(context).size.width < 500
                        ? double.infinity
                        : (MediaQuery.of(context).size.width - 72) / 3,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          Colors.white,
                        ],
                      ),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.$1,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stat.$2,
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _milestones.map((milestone) {
          final idx = _milestones.indexOf(milestone);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _stagger(
                _controller.value,
                0.52 + 0.08 * idx,
                1.0,
                curve: Curves.easeOutBack,
              );
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - t)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.12),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              milestone.$1,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          if (idx != _milestones.length - 1)
                            Container(
                              width: 2,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    accent.withValues(alpha: 0.25),
                                    accent.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            milestone.$2,
                            style: const TextStyle(height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTeam(BuildContext context) {
    final team = const [
      ('Aadhira', 'Sourcing', 'Keeps grower relationships thriving.'),
      ('Vikram', 'Operations', 'Runs the cold-chain like clockwork.'),
      ('Neha', 'Experience', 'Designs joyful delivery moments.'),
    ];
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final member = team[index];
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _stagger(
                _controller.value,
                0.5 + 0.08 * index,
                0.95 + 0.08 * index,
                curve: Curves.easeOutCubic,
              );
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 22 * (1 - t)),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.08),
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
                              radius: 22,
                              backgroundColor: primary.withValues(alpha: 0.12),
                              child: Text(
                                member.$1[0],
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  member.$2,
                                  style: TextStyle(
                                    color: primary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(member.$3, style: const TextStyle(height: 1.35)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemCount: team.length,
      ),
    );
  }

  Widget _buildFooterCta(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        builder: (context, t, _) {
          final clamped = t.clamp(0.0, 1.0);
          return Opacity(
            opacity: clamped,
            child: Transform.scale(
              scale: 0.96 + 0.04 * clamped,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [primary, Color.lerp(primary, Colors.white, 0.35)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partner with VFC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Growers, chefs and community kitchens collaborate with us to reduce waste and celebrate peak-season taste.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thanks! We will reach out shortly.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Get in touch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  final Color color;
  final double progress;

  _OrbitalPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = Offset(size.width / 2, size.height * 0.2);
    final maxRadius = size.width * 0.9;
    for (int i = 0; i < 3; i++) {
      final radius = maxRadius * (0.4 + 0.2 * i) * progress;
      paint.color = color.withValues(alpha: (0.18 - i * 0.04) * progress);
      canvas.drawCircle(center.translate(0, i * 18.0), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
