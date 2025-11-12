import 'package:flutter/material.dart';
import 'package:fruit_shop/services/app_theme.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/image_resolver.dart';
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

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _me;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final me = await UserDataApi.getMe();
      if (!mounted) return;
      setState(() => _me = me);
    } catch (_) {
      // ignore network/auth issues; fallback to provided userData
    }
  }

  String? _resolveAvatarUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      final trimmed = path.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final uri = Uri.parse(trimmed);
        final devHosts = {'10.0.2.2', '127.0.0.1', 'localhost'};
        if (devHosts.contains(uri.host)) {
          final base = Uri.parse(AuthService.getBaseUrl());
          final replaced = uri.replace(
            scheme: base.scheme,
            host: base.host,
            port: base.hasPort ? base.port : null,
          );
          return replaced.toString();
        }
        return trimmed;
      }
      final base = AuthService.getBaseUrl();
      if (trimmed.startsWith('/')) return '$base$trimmed';
      return '$base/$trimmed';
    } catch (_) {
      return path;
    }
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
    final rawAvatar = (_me?['avatarUrl'] ?? widget.userData['avatarUrl'])
        ?.toString();
    final avatarUrl = _resolveAvatarUrl(rawAvatar);

    Widget item({
      required IconData icon,
      required String label,
      VoidCallback? onTap,
      Widget? trailing,
      int index = 0,
    }) {
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final delay = 0.1 * index;
          final t = (_animationController.value - delay).clamp(0.0, 1.0);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - t)),
              child: child,
            ),
          );
        },
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
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final t = _animationController.value.clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: 0.9 + 0.1 * t,
                      child: Opacity(opacity: t, child: child),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: primary,
                            child: avatarUrl == null
                                ? Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : 'V',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : ClipOval(
                                    child: SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: ResolvedImage(
                                        avatarUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        borderRadius: BorderRadius.circular(26),
                                        placeholder: Container(
                                          color: Colors.transparent,
                                          child: Center(
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
                                        ),
                                      ),
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
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                                    color: onSurface.withValues(
                                      alpha: isDark ? 0.9 : 0.75,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                                if (userPhone.isNotEmpty)
                                  Text(
                                    userPhone,
                                    style: TextStyle(
                                      color: onSurface.withValues(
                                        alpha: isDark ? 0.9 : 0.75,
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
              ),

              // Body (items)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
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
                            const SizedBox(height: 4),
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
                                    final selected = c == color;
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
