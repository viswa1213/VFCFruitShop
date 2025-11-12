import 'package:flutter/material.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: theme.colorScheme.onPrimary),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _me;
  bool _loading = true;
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  bool _saving = false;
  late final AnimationController _animController;
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await AuthService.getCurrentUser();
    final me = await UserDataApi.getMe();
    Map<String, dynamic> summary = const {};
    try {
      summary = await UserDataApi.adminSummary();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _me = {...?me, ...?user};
      _nameController.text = _me?['name']?.toString() ?? '';
      _aboutController.text = _me?['bio']?.toString() ?? '';
      _loading = false;
      _summary = summary;
    });
    _animController.forward(from: 0);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnack.showError(context, 'Name required');
      return;
    }
    setState(() => _saving = true);
    final ok = await UserDataApi.updateProfile(name: name);
    if (!mounted) return;
    if (ok) {
      AppSnack.showSuccess(context, 'Profile updated');
      _load();
    } else {
      AppSnack.showError(context, 'Update failed');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final email = _me?['email']?.toString() ?? '';
    final role = _me?['role']?.toString() ?? 'user';

    final theme = Theme.of(context);
    final animatedOpacity = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeTransition(
        opacity: animatedOpacity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(email, role, theme),
            const SizedBox(height: 20),
            _buildSummaryRow(theme),
            const SizedBox(height: 20),
            _buildEditCard(theme),
            const SizedBox(height: 20),
            _buildQuickActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(String email, String role, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(
                parent: _animController,
                curve: Curves.elasticOut,
              ),
            ),
            child: CircleAvatar(
              radius: 38,
              backgroundColor: theme.colorScheme.onPrimary.withValues(
                alpha: 0.15,
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Control Center',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
            icon: Icon(Icons.logout, color: theme.colorScheme.onPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme) {
    final totalProducts = (_summary['products'] ?? '—').toString();
    final totalOrders = (_summary['orders'] ?? '—').toString();
    final totalUsers = (_summary['activeUsers'] ?? '—').toString();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.inventory_2_outlined,
            label: 'Products managed',
            value: totalProducts,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.receipt_long,
            label: 'Orders processed',
            value: totalOrders,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.people_alt,
            label: 'Active users',
            value: totalUsers,
            color: theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildEditCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aboutController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'About',
                helperText: 'Share a short note that appears to other admins',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _quickAction(
                  icon: Icons.inventory_2,
                  label: 'Inventory',
                  onTap: () => Navigator.pushNamed(context, '/admin'),
                ),
                _quickAction(
                  icon: Icons.receipt_long,
                  label: 'Orders',
                  onTap: () => Navigator.pushNamed(context, '/admin'),
                ),
                _quickAction(
                  icon: Icons.people,
                  label: 'Users',
                  onTap: () => Navigator.pushNamed(context, '/admin'),
                ),
                _quickAction(
                  icon: Icons.bar_chart,
                  label: 'Analytics',
                  onTap: () =>
                      AppSnack.showInfo(context, 'Analytics coming soon'),
                ),
                _quickAction(
                  icon: Icons.settings_suggest,
                  label: 'Settings',
                  onTap: () =>
                      AppSnack.showInfo(context, 'Settings coming soon'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Sign out of your admin session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();
      if (!mounted || !context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 118,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _animController.dispose();
    super.dispose();
  }
}
