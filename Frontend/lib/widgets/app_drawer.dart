import 'package:flutter/material.dart';
import 'package:fruit_shop/services/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, String> userData;
  final int cartCount;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenFavorites;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onLogout;

  const AppDrawer({
    super.key,
    required this.userData,
    required this.cartCount,
    this.onOpenHome,
    this.onOpenCart,
    this.onOpenFavorites,
    this.onOpenProfile,
    this.onOpenSettings,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final userName = userData['name'] ?? 'Guest';
    final userEmail = userData['email'] ?? 'No email provided';

    Widget item({
      required IconData icon,
      required String label,
      VoidCallback? onTap,
      Widget? trailing,
      int index = 0,
    }) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(-12 * (1 - t) * (1 + index * 0.08), 0),
            child: child,
          ),
        ),
        child: ListTile(
          leading: Icon(icon, color: primary),
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: trailing,
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          hoverColor: primary.withValues(alpha: 0.06),
        ),
      );
    }

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, Color.lerp(primary, Colors.white, 0.2)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: primary,
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'V',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'VFC🍎',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color.lerp(
                                        primary,
                                        Colors.white,
                                        0.9,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Color.lerp(
                                          primary,
                                          Colors.white,
                                          0.6,
                                        )!,
                                      ),
                                    ),
                                    child: Text(
                                      'Member',
                                      style: TextStyle(
                                        color: primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                userEmail,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
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

              // Body (items)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    children: [
                      item(
                        icon: Icons.home,
                        label: 'Home',
                        onTap: onOpenHome,
                        index: 0,
                      ),
                      item(
                        icon: Icons.shopping_cart,
                        label: 'Cart',
                        onTap: onOpenCart,
                        trailing: cartCount > 0
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Text(
                                  cartCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        index: 1,
                      ),
                      item(
                        icon: Icons.favorite,
                        label: 'Favorites',
                        onTap: onOpenFavorites,
                        index: 2,
                      ),
                      const Divider(),
                      // Appearance section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ExpansionTile(
                          leading: Icon(Icons.color_lens, color: primary),
                          title: const Text(
                            'Appearance',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          childrenPadding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 8,
                          ),
                          children: [
                            // Theme mode
                            ValueListenableBuilder<ThemeMode>(
                              valueListenable: AppTheme.mode,
                              builder: (context, mode, _) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Theme',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        ChoiceChip(
                                          avatar: const Icon(
                                            Icons.wb_sunny_outlined,
                                            size: 16,
                                          ),
                                          label: const Text('Light'),
                                          selected: mode == ThemeMode.light,
                                          onSelected: (_) =>
                                              AppTheme.set(ThemeMode.light),
                                        ),
                                        ChoiceChip(
                                          avatar: const Icon(
                                            Icons.dark_mode_outlined,
                                            size: 16,
                                          ),
                                          label: const Text('Dark'),
                                          selected: mode == ThemeMode.dark,
                                          onSelected: (_) =>
                                              AppTheme.set(ThemeMode.dark),
                                        ),
                                        ChoiceChip(
                                          avatar: const Icon(
                                            Icons.phone_iphone,
                                            size: 16,
                                          ),
                                          label: const Text('System'),
                                          selected: mode == ThemeMode.system,
                                          onSelected: (_) =>
                                              AppTheme.set(ThemeMode.system),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            // Accent colors
                            ValueListenableBuilder<Color>(
                              valueListenable: AppTheme.accent,
                              builder: (context, color, _) {
                                final options = <Color>[
                                  primary,
                                  Colors.teal.shade600,
                                  Colors.orange.shade600,
                                  Colors.purple.shade600,
                                  Colors.blue.shade600,
                                ];
                                return Wrap(
                                  spacing: 10,
                                  children: options.map((c) {
                                    final selected =
                                        c.toARGB32() == color.toARGB32();
                                    return GestureDetector(
                                      onTap: () => AppTheme.setAccent(c),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: c,
                                          boxShadow: selected
                                              ? [
                                                  BoxShadow(
                                                    color: c.withValues(
                                                      alpha: 0.45,
                                                    ),
                                                    blurRadius: 10,
                                                  ),
                                                ]
                                              : null,
                                          border: Border.all(
                                            color: selected
                                                ? Colors.white
                                                : Colors.black12,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      item(
                        icon: Icons.person,
                        label: 'Profile',
                        onTap: onOpenProfile,
                        index: 3,
                      ),
                      item(
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: onOpenSettings,
                        index: 4,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: onLogout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }
}
