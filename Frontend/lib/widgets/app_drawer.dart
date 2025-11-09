import 'package:flutter/material.dart';
import 'package:fruit_shop/services/app_theme.dart';
import 'package:fruit_shop/services/user_data_api.dart';

class AppDrawer extends StatefulWidget {
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
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Map<String, dynamic>? _me;
  // reserved for potential loading indicator on header fetch

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    // no visual loader needed in drawer header; fetch quietly
    try {
      final me = await UserDataApi.getMe();
      if (!mounted) return;
      setState(() => _me = me);
    } catch (_) {
      // ignore network/auth issues; fallback to provided userData
    } finally {}
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName =
        (_me?['name']?.toString() ?? widget.userData['name']) ?? 'Guest';
    final userEmail =
        (_me?['email']?.toString() ?? widget.userData['email']) ??
        'No email provided';
    final address = (_me?['address'] as Map?)?.cast<String, dynamic>();
    final userPhone =
        (_me?['phone']?.toString() ?? address?['phone']?.toString() ?? '')
            .trim();

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
            style: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
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
                                  Text(
                                    'VFC🍎',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: onSurface,
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                ),
                              ),
                              Text(
                                userEmail,
                                style: TextStyle(
                                  color: onSurface.withOpacity(
                                    isDark ? 0.9 : 0.75,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                              if (userPhone.isNotEmpty)
                                Text(
                                  userPhone,
                                  style: TextStyle(
                                    color: onSurface.withOpacity(
                                      isDark ? 0.9 : 0.75,
                                    ),
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
                    // Use themed surface for better contrast in dark mode
                    color: Theme.of(context).colorScheme.surface,
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
                        onTap: widget.onOpenHome,
                        index: 0,
                      ),
                      item(
                        icon: Icons.shopping_cart,
                        label: 'Cart',
                        onTap: widget.onOpenCart,
                        trailing: widget.cartCount > 0
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Text(
                                  widget.cartCount.toString(),
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
                        onTap: widget.onOpenFavorites,
                        index: 2,
                      ),
                      const Divider(),
                      // Appearance section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ExpansionTile(
                          leading: Icon(Icons.color_lens, color: primary),
                          title: Text(
                            'Appearance',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                          childrenPadding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 8,
                          ),
                          children: [
                            // Accent colors only (theme mode controls removed)
                            const SizedBox(height: 4),
                            // Accent colors
                            ValueListenableBuilder<Color>(
                              valueListenable: AppTheme.accent,
                              builder: (context, color, _) {
                                final options = <Color>[
                                  primary,
                                  Colors.red.shade600,
                                  Colors.pink.shade400,
                                  Colors.purple.shade600,
                                  Colors.deepPurple.shade600,
                                  Colors.indigo.shade600,
                                  Colors.blue.shade600,
                                  Colors.lightBlue.shade600,
                                  Colors.cyan.shade600,
                                  Colors.teal.shade600,
                                  Colors.green.shade600,
                                  Colors.lightGreen.shade600,
                                  Colors.lime.shade700,
                                  Colors.amber.shade700,
                                  Colors.orange.shade700,
                                  Colors.deepOrange.shade600,
                                  Colors.brown.shade600,
                                  Colors.blueGrey.shade600,
                                ];
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
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
                        onTap: widget.onOpenProfile,
                        index: 3,
                      ),
                      item(
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: widget.onOpenSettings,
                        index: 4,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: widget.onLogout,
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
