import 'package:flutter/material.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/image_resolver.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:fruit_shop/pages/admin_inventory.dart';
import 'package:fruit_shop/pages/admin_profile.dart';
import 'package:fruit_shop/pages/admin_bills.dart';
import 'package:fruit_shop/utils/responsive.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _tab = 0;
  String? _adminName;
  String? _adminEmail;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _users = [];
  String _userRoleFilter = 'all';
  String _userSearchTerm = '';
  final TextEditingController _userSearchCtrl = TextEditingController();
  bool _sidebarExpanded = true;
  final Duration _sidebarAnimDuration = const Duration(milliseconds: 320);
  final List<_SideNavItem> _sideNavItems = const [
    _SideNavItem(
      icon: Icons.receipt_long,
      label: 'Orders',
      caption: 'Manage orders',
    ),
    _SideNavItem(
      icon: Icons.point_of_sale,
      label: 'Bills',
      caption: 'Create invoices',
    ),
    _SideNavItem(icon: Icons.people, label: 'Users', caption: 'Manage users'),
    _SideNavItem(
      icon: Icons.inventory_2,
      label: 'Inventory',
      caption: 'Products',
    ),
    _SideNavItem(
      icon: Icons.account_circle,
      label: 'Profile',
      caption: 'Settings',
    ),
  ];
  // NOTE: the actual user card renderer (was accidentally missing its
  // signature during a previous edit). Treat the following block as the
  // user-card builder which accepts a user map and list index.
  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final theme = Theme.of(context);
    final role = (user['role'] ?? 'user').toString();
    final isAdmin = role.toLowerCase() == 'admin';
    final accent = isAdmin
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;
    final phone = user['phone']?.toString();
    final statusRaw = user['status']?.toString();
    final isActive =
        user['active'] == true || statusRaw?.toLowerCase() == 'active';
    final statusLabel = isActive ? 'Active' : statusRaw ?? 'Inactive';
    final statusColor = isActive ? Colors.green : Colors.orange;
    final joined = _formatJoined(user['createdAt']);
    final email = user['email']?.toString() ?? '—';

    Widget statusChip() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.pause_circle_filled,
              size: 16,
              color: statusColor,
            ),
            const SizedBox(width: 6),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey(user['_id'] ?? 'user-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: accent.withValues(alpha: 0.18), width: 1.1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showUserDetail(user),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _userAvatar(user, accent, radius: 28),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (user['name'] ?? 'User').toString(),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              statusChip(),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _pill(
                                icon: Icons.workspace_premium,
                                text: 'Role · ${role.toUpperCase()}',
                              ),
                              if (phone != null && phone.isNotEmpty)
                                _pill(icon: Icons.phone, text: phone),
                              _pill(icon: Icons.calendar_today, text: joined),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // The action row: responsive to avoid horizontal overflow
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 420;

                              final actionButton = ElevatedButton.icon(
                                onPressed: () => _showUserDetail(user),
                                icon: const Icon(Icons.info_outline),
                                label: const Text('View details'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAdmin
                                      ? theme.colorScheme.secondaryContainer
                                      : theme.colorScheme.primaryContainer,
                                  foregroundColor: isAdmin
                                      ? theme.colorScheme.onSecondaryContainer
                                      : theme.colorScheme.onPrimaryContainer,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              );

                              final roleDropdown = DropdownButtonHideUnderline(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.dividerColor.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: DropdownButton<String>(
                                    value: role,
                                    isExpanded: true,
                                    borderRadius: BorderRadius.circular(16),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'user',
                                        child: Text('User access'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'admin',
                                        child: Text('Admin access'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        _handleUserRoleChange(user, value);
                                      }
                                    },
                                  ),
                                ),
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    actionButton,
                                    const SizedBox(height: 8),
                                    roleDropdown,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  actionButton,
                                  const SizedBox(width: 12),
                                  Expanded(child: roleDropdown),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _contrastOn(Color color) {
    return color.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
  }

  /// Builds a user avatar from possible sources:
  /// - If user['avatarUrl'] is a full http/https URL: load via NetworkImage.
  /// - If it starts with '/': prefix runtime base URL.
  /// - If it starts with 'assets/': treat as bundled asset.
  /// - Otherwise if non-empty: assume relative to server root.
  /// Falls back to initials rendered over a tinted background.
  Widget _userAvatar(
    Map<String, dynamic> user,
    Color accent, {
    double radius = 28,
  }) {
    final raw = user['avatarUrl']?.toString().trim();
    final initials = _userInitials(user);

    if (raw != null && raw.isNotEmpty) {
      // Use the ResolvedImage widget so absolute, relative and /uploads
      // paths are normalized to the configured base URL. Place it inside
      // a clipped CircleAvatar to preserve visuals and provide a fallback
      // placeholder with initials while loading or on error.
      return CircleAvatar(
        radius: radius,
        backgroundColor: accent.withValues(alpha: 0.12),
        child: ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: ResolvedImage(
              raw,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(radius),
              placeholder: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: _contrastOn(accent),
                    fontSize: radius * 0.64,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: accent.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: TextStyle(
          color: _contrastOn(accent),
          fontSize: radius * 0.64,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _loadAdminDetail() async {
    final cached = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        final name = cached?['name']?.toString().trim();
        _adminName = (name != null && name.isNotEmpty) ? name : 'Admin';
        final email = cached?['email']?.toString().trim();
        _adminEmail = (email != null && email.isNotEmpty) ? email : null;
      });
    }

    try {
      final fresh = await UserDataApi.getMe();
      if (!mounted || fresh == null) return;
      setState(() {
        final name = fresh['name']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          _adminName = name;
        }
        final email = fresh['email']?.toString().trim();
        if (email != null && email.isNotEmpty) {
          _adminEmail = email;
        }
      });
    } catch (_) {
      // Ignore network errors; cached values already shown
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _orders = await UserDataApi.adminListOrders();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _users = await UserDataApi.adminListUsers();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    Iterable<Map<String, dynamic>> results = _users;

    if (_userRoleFilter != 'all') {
      final filter = _userRoleFilter;
      results = results.where((user) {
        final role = (user['role'] ?? 'user').toString().toLowerCase();
        return role == filter;
      });
    }

    if (_userSearchTerm.isNotEmpty) {
      final needle = _userSearchTerm.toLowerCase();
      bool matchesValue(dynamic value) {
        if (value == null) return false;
        final text = value.toString().toLowerCase();
        return text.contains(needle);
      }

      results = results.where((user) {
        return matchesValue(user['name']) ||
            matchesValue(user['email']) ||
            matchesValue(user['phone']) ||
            matchesValue(user['role']);
      });
    }

    return results.toList();
  }

  String _userInitials(Map<String, dynamic> user) {
    final name = user['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(' ');
      final first = parts.isNotEmpty ? parts.first : '';
      final last = parts.length > 1 ? parts.last : '';
      final buffer = StringBuffer();
      if (first.isNotEmpty) buffer.write(first[0].toUpperCase());
      if (last.isNotEmpty) buffer.write(last[0].toUpperCase());
      final initials = buffer.toString();
      if (initials.isNotEmpty) return initials;
    }
    return 'U';
  }

  String _formatJoined(dynamic timestamp) {
    final parsed = DateTime.tryParse(timestamp?.toString() ?? '');
    if (parsed == null) return 'Joined recently';
    final d = parsed.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return 'Joined $day/$month/$year';
  }

  Future<void> _handleUserRoleChange(
    Map<String, dynamic> user,
    String newRole,
  ) async {
    final id = user['_id']?.toString();
    if (id == null) return;

    final previousRole = (user['role'] ?? 'user').toString();
    if (previousRole == newRole) return;

    void updateLocalRole(String role) {
      final idx = _users.indexWhere(
        (element) => element['_id']?.toString() == id,
      );
      if (idx != -1) {
        setState(() => _users[idx]['role'] = role);
      }
    }

    updateLocalRole(newRole);
    final ok = await UserDataApi.adminUpdateUserRole(id, newRole);
    if (!mounted) return;
    if (ok) {
      AppSnack.showSuccess(
        context,
        'Updated ${user['name'] ?? 'user'} to $newRole',
      );
    } else {
      updateLocalRole(previousRole);
      AppSnack.showError(context, 'Failed to update role');
    }
  }

  Future<void> _showUserDetail(Map<String, dynamic> user) async {
    try {
      final id = user['_id']?.toString();
      if (id == null) return;

      final data = await UserDataApi.adminGetUser(id);
      if (!mounted) return;

      final detail = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
      final ordersRaw = (data['orders'] as List?) ?? const [];
      final orders = ordersRaw
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      final name = (detail['name'] ?? user['name'] ?? 'User').toString();
      final email = (detail['email'] ?? user['email'])?.toString();
      final phone = (detail['phone'] ?? user['phone'])?.toString();
      final role = (detail['role'] ?? user['role'] ?? 'user').toString();
      final statusActive = detail['active'] == true || user['active'] == true;
      final createdAtRaw = detail['createdAt'] ?? user['createdAt'];
      final joinedLabel = _formatJoined(createdAtRaw);
      final address = (detail['address'] as Map?)?.cast<String, dynamic>();
      final totalOrders = orders.length;
      final deliveredOrders = orders
          .where(
            (o) => (o['status'] ?? '').toString().toLowerCase() == 'delivered',
          )
          .length;
      final pendingOrders = totalOrders - deliveredOrders;
      final lastOrderDate = orders.isNotEmpty
          ? DateTime.tryParse(orders.first['createdAt']?.toString() ?? '')
          : null;

      await showDialog(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final accent = role.toLowerCase() == 'admin'
              ? theme.colorScheme.secondary
              : theme.colorScheme.primary;

          Widget metricCard({
            required IconData icon,
            required String label,
            required String value,
            required Color color,
          }) {
            return Container(
              width: 150,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: color.withValues(alpha: 0.08),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          Widget orderPreview(Map<String, dynamic> order) {
            final orderId = (order['id'] ?? order['_id'] ?? '').toString();
            final status = (order['status'] ?? 'processing').toString();
            final itemsCount = ((order['items'] as List?)?.length ?? 0)
                .toString();
            final pricing =
                (order['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
            final total = (pricing['total'] as num?)?.toDouble();
            final createdAt = DateTime.tryParse(
              order['createdAt']?.toString() ?? '',
            );
            final createdLabel = createdAt != null
                ? _formatDate(createdAt)
                : '—';

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.surface.withValues(alpha: 0.6),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order #$orderId',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$itemsCount item(s) • ${total != null ? '₹${total.toStringAsFixed(2)}' : '—'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    createdLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          Widget accountStatusChip() {
            final color = statusActive ? Colors.green : Colors.orange;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusActive ? Icons.verified : Icons.pause_circle_outline,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusActive ? 'Active account' : 'Inactive account',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _userAvatar(
                            detail.isNotEmpty ? detail : user,
                            accent,
                            radius: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Close',
                                      onPressed: () => Navigator.pop(ctx),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: [
                                    _pill(
                                      icon: Icons.workspace_premium,
                                      text: 'Role · ${role.toUpperCase()}',
                                    ),
                                    if (email != null && email.isNotEmpty)
                                      _pill(
                                        icon: Icons.email_outlined,
                                        text: email,
                                      ),
                                    if (phone != null && phone.isNotEmpty)
                                      _pill(
                                        icon: Icons.phone_outlined,
                                        text: phone,
                                      ),
                                    _pill(
                                      icon: Icons.calendar_month,
                                      text: joinedLabel,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                accountStatusChip(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Account summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          metricCard(
                            icon: Icons.shopping_bag,
                            label: 'Total orders',
                            value: totalOrders.toString(),
                            color: theme.colorScheme.primary,
                          ),
                          metricCard(
                            icon: Icons.local_shipping,
                            label: 'Delivered',
                            value: deliveredOrders.toString(),
                            color: Colors.green,
                          ),
                          metricCard(
                            icon: Icons.hourglass_top,
                            label: 'In progress',
                            value: pendingOrders.toString(),
                            color: Colors.orange,
                          ),
                          metricCard(
                            icon: Icons.schedule,
                            label: 'Last order',
                            value: lastOrderDate != null
                                ? _formatDate(lastOrderDate)
                                : 'No orders yet',
                            color: theme.colorScheme.secondary,
                          ),
                        ],
                      ),
                      if (address != null && address.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Primary address',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.65,
                            ),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (address['name'] != null ||
                                  address['phone'] != null)
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (address['name'] != null)
                                            Text(
                                              address['name'].toString(),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          if (address['phone'] != null)
                                            Text(
                                              'Phone: ${address['phone']}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              if (address['name'] != null ||
                                  address['phone'] != null)
                                const Divider(height: 18),
                              Text(
                                _formatAddress(address) ?? '—',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Recent orders',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (orders.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This user has no orders yet',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      else ...[
                        for (final order in orders.take(3)) orderPreview(order),
                        if (orders.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '+ ${orders.length - 3} more orders in history',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.check),
                          label: const Text('Done'),
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
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Failed to load user detail');
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _switchTab(int index) {
    setState(() => _tab = index);
    if (index == 0) {
      _loadOrders();
    } else if (index == 1) {
      _loadUsers();
    }
  }

  void _toggleSidebar() {
    setState(() => _sidebarExpanded = !_sidebarExpanded);
  }

  Widget _buildDesktopSidebar(BuildContext context, List<_SideNavItem> items) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = _sidebarExpanded;
    final name = _adminName ?? 'Admin';
    final email = _adminEmail;
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A';

    return AnimatedContainer(
      duration: _sidebarAnimDuration,
      curve: Curves.easeOutCubic,
      width: expanded ? 256 : 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, 0.4) ?? scheme.primary,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 18 : 12,
                vertical: 20,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (expanded)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            if (email != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Tooltip(
                    message: expanded ? 'Collapse sidebar' : 'Expand sidebar',
                    child: IconButton(
                      onPressed: _toggleSidebar,
                      icon: AnimatedRotation(
                        turns: expanded ? 0 : 0.5,
                        duration: _sidebarAnimDuration,
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 18),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _buildSidebarTile(context, items[index], index, expanded),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 18 : 12,
                vertical: 18,
              ),
              child: expanded
                  ? ElevatedButton.icon(
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    )
                  : Tooltip(
                      message: 'Logout',
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _confirmLogout,
                          child: const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.logout, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarTile(
    BuildContext context,
    _SideNavItem item,
    int index,
    bool expanded,
  ) {
    final selected = _tab == index;
    final highlight = selected
        ? Colors.white.withValues(alpha: 0.20)
        : Colors.white.withValues(alpha: 0.06);

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _switchTab(index),
        child: AnimatedContainer(
          duration: _sidebarAnimDuration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 20 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: highlight,
            borderRadius: BorderRadius.circular(18),
            border: selected
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1.2,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: selected ? 0.4 : 0.16),
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, color: Colors.white, size: 22),
              ),
              if (expanded) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.caption,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  duration: _sidebarAnimDuration,
                  opacity: selected ? 1 : 0,
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 16 : 12,
        vertical: 6,
      ),
      child: expanded
          ? tile
          : Tooltip(message: item.label, verticalOffset: 36, child: tile),
    );
  }

  Drawer _buildMobileDrawer(BuildContext context, List<_SideNavItem> items) {
    final scheme = Theme.of(context).colorScheme;
    final name = _adminName ?? 'Admin';
    final email = _adminEmail;
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A';

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary,
              Color.lerp(scheme.primary, scheme.secondary, 0.4) ??
                  scheme.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          if (email != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    indent: 24,
                    endIndent: 24,
                  ),
                  itemBuilder: (ctx, index) {
                    final selected = _tab == index;
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Material(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.pop(context);
                            _switchTab(index);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: selected ? 0.35 : 0.18,
                                  ),
                                  child: Icon(item.icon, color: Colors.white),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.caption,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmLogout();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year · $hour12:$minute $ampm';
  }

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();
    Color bg;
    Color fg;
    String label;
    switch (normalized) {
      case 'shipped':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'Shipped';
        break;
      case 'delivered':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'Delivered';
        break;
      default:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'Processing';
    }
    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _statusStepper(String status) {
    const stages = ['processing', 'shipped', 'delivered'];
    final labels = {
      'processing': 'Processing',
      'shipped': 'Shipped',
      'delivered': 'Delivered',
    };
    final idx = stages
        .indexOf(status.toLowerCase())
        .clamp(0, stages.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Fulfilment progress',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (int i = 0; i < stages.length; i++) ...[
              _stepDot(i <= idx),
              if (i < stages.length - 1) _stepLine(i < idx),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final stage in stages)
              Expanded(
                child: Text(
                  labels[stage]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: stages.indexOf(stage) <= idx
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: stages.indexOf(stage) <= idx
                        ? Colors.black87
                        : Colors.black38,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepDot(bool active) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.green : Colors.grey.shade200,
        border: Border.all(
          color: active ? Colors.green : Colors.grey.shade400,
          width: 2,
        ),
      ),
    );
  }

  Widget _stepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: active ? Colors.green : Colors.grey.shade300,
      ),
    );
  }

  String? _formatAddress(Map<String, dynamic>? address) {
    if (address == null || address.isEmpty) return null;
    final parts = <String>[];

    void add(String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) parts.add(trimmed);
    }

    add(address['address']);
    add(address['landmark']);

    final city = address['city']?.toString().trim();
    final state = address['state']?.toString().trim();
    final cityStateParts = [
      city,
      state,
    ].whereType<String>().where((e) => e.isNotEmpty).toList();
    if (cityStateParts.isNotEmpty) parts.add(cityStateParts.join(', '));

    final pincode = address['pincode']?.toString().trim();
    if (pincode != null && pincode.isNotEmpty) parts.add('PIN: $pincode');

    // Fallback to legacy keys if present
    add(address['line1']);
    add(address['line2']);
    final postal = address['postalCode']?.toString().trim();
    if (postal != null && postal.isNotEmpty && pincode == null) {
      parts.add('PIN: $postal');
    }

    return parts.isEmpty ? null : parts.join('\n');
  }

  String? _resolveItemImage(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '${AuthService.getBaseUrl()}$path';
    return path; // assume asset path
  }

  Widget _orderItemAvatar(String? imagePath, String name) {
    final resolved = _resolveItemImage(imagePath);
    if (resolved == null) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
      );
    }
    if (resolved.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ResolvedImage(
          resolved,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        resolved,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final pricing = (order['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = ((order['items'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final user = (order['user'] as Map?)?.cast<String, dynamic>();
    final address = (order['address'] as Map?)?.cast<String, dynamic>();
    final payment = (order['payment'] as Map?)?.cast<String, dynamic>() ?? {};
    final total = (pricing['total'] as num?)?.toDouble() ?? 0;
    final subtotal = (pricing['subtotal'] as num?)?.toDouble();
    final deliveryFee = (pricing['deliveryFee'] as num?)?.toDouble();
    final discount = (pricing['discount'] as num?)?.toDouble();
    final coupon = pricing['coupon']?.toString();
    final method = payment['method']?.toString() ?? '—';
    final paymentStatus = payment['status']?.toString();
    final deliverySlot = order['deliverySlot']?.toString();
    final createdAt = DateTime.tryParse(order['createdAt']?.toString() ?? '');
    final status = (order['status'] ?? 'processing').toString();
    final formattedAddress = _formatAddress(address);
    final recipientName = address?['name']?.toString();
    final recipientPhone = address?['phone']?.toString();
    final id = order['id']?.toString();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${id ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Placed: ${_formatDate(createdAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user['name']?.toString() ?? 'Customer',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (user['email'] != null)
                      Text(
                        user['email'].toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusChip(status),
                const SizedBox(height: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(
                        value: 'processing',
                        child: Text('Processing'),
                      ),
                      DropdownMenuItem(
                        value: 'shipped',
                        child: Text('Shipped'),
                      ),
                      DropdownMenuItem(
                        value: 'delivered',
                        child: Text('Delivered'),
                      ),
                    ],
                    onChanged: (v) async {
                      if (v == null || v == status || id == null) return;
                      final prev = status;
                      setState(() => _orders[index]['status'] = v);
                      final ok = await UserDataApi.adminUpdateOrderStatus(
                        id,
                        v,
                      );
                      if (!mounted) return;
                      if (ok) {
                        AppSnack.showSuccess(context, 'Status updated');
                      } else {
                        setState(() => _orders[index]['status'] = prev);
                        AppSnack.showError(context, 'Failed to update');
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${items.length} item(s)',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.payment, size: 16),
                label: Text(
                  'Payment: $method${paymentStatus != null ? ' (${paymentStatus.toUpperCase()})' : ''}',
                ),
                backgroundColor: Colors.grey.shade100,
              ),
              if (deliverySlot != null && deliverySlot.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.schedule, size: 16),
                  label: Text('Slot: $deliverySlot'),
                  backgroundColor: Colors.grey.shade100,
                ),
            ],
          ),
          if (recipientName != null ||
              recipientPhone != null ||
              formattedAddress != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recipientName != null && recipientName.isNotEmpty)
                        Text(
                          recipientName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (recipientPhone != null && recipientPhone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0, bottom: 6.0),
                          child: Text(
                            'Mobile: $recipientPhone',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      if (formattedAddress != null)
                        Text(
                          formattedAddress,
                          style: const TextStyle(fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ...items.map((item) {
            final name = item['name']?.toString() ?? 'Item';
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final measure = (item['measure'] as num?)?.toDouble();
            final unit = (item['unit'] as String?) ?? 'unit';
            final lineTotal = (item['lineTotal'] as num?)?.toDouble() ?? 0;
            final image = item['image']?.toString();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _orderItemAvatar(image, name),
              title: Text(name),
              subtitle: Text(
                'Qty: $qty${measure != null ? ' • ${measure.toString()}$unit' : ''}',
              ),
              trailing: Text('₹${lineTotal.toStringAsFixed(2)}'),
            );
          }),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (subtotal != null)
                  Text('Subtotal: ₹${subtotal.toStringAsFixed(2)}'),
                if (deliveryFee != null)
                  Text(
                    'Delivery: ${deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toStringAsFixed(2)}'}',
                  ),
                if (discount != null && discount > 0)
                  Text(
                    'Discount: -₹${discount.toStringAsFixed(2)}${coupon != null ? ' ($coupon)' : ''}',
                    style: const TextStyle(color: Colors.green),
                  ),
                Text(
                  'Total: ₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          _statusStepper(status),
        ],
      ),
    );
  }

  Widget _buildOrders() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No orders yet'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (ctx, i) => _buildOrderCard(_orders[i], i),
      ),
    );
  }

  Widget _buildUsers() {
    final theme = Theme.of(context);
    final filtered = _filteredUsers;
    final totalUsers = _users.length;
    final adminCount = _users
        .where((u) => (u['role'] ?? 'user').toString().toLowerCase() == 'admin')
        .length;
    final now = DateTime.now();
    final recentCount = _users.where((user) {
      final createdAt = DateTime.tryParse(user['createdAt']?.toString() ?? '');
      if (createdAt == null) return false;
      return now.difference(createdAt).inDays <= 30;
    }).length;
    const roleFilters = [
      _RoleFilter('all', 'All users', Icons.all_inclusive),
      _RoleFilter('admin', 'Admins', Icons.workspace_premium),
      _RoleFilter('user', 'Customers', Icons.person_outline),
    ];

    Widget summaryTile({
      required IconData icon,
      required String label,
      required String value,
      required Color color,
    }) {
      return Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget emptyState = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.people_outline, size: 48, color: Colors.grey),
          SizedBox(height: 10),
          Text('No matching users'),
          SizedBox(height: 6),
          Text(
            'Try a different search or invite new members',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!));
    } else if (filtered.isEmpty) {
      body = emptyState;
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      summaryTile(
                        icon: Icons.people_alt,
                        label: 'Total users',
                        value: totalUsers.toString(),
                        color: theme.colorScheme.primary,
                      ),
                      summaryTile(
                        icon: Icons.workspace_premium,
                        label: 'Admins',
                        value: adminCount.toString(),
                        color: theme.colorScheme.secondary,
                      ),
                      summaryTile(
                        icon: Icons.new_releases,
                        label: 'Joined (30d)',
                        value: recentCount.toString(),
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _userSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name, email, phone or role',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _userSearchTerm.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear',
                      onPressed: () => _userSearchCtrl.clear(),
                      icon: const Icon(Icons.close),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final filter in roleFilters)
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter.icon,
                        size: 16,
                        color: _userRoleFilter == filter.value
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        filter.label,
                        style: TextStyle(
                          color: _userRoleFilter == filter.value
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                          fontWeight: _userRoleFilter == filter.value
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  selected: _userRoleFilter == filter.value,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() => _userRoleFilter = filter.value);
                  },
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  selectedColor: theme.colorScheme.primary.withValues(
                    alpha: 0.16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _userRoleFilter == filter.value
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Showing ${filtered.length} of $totalUsers users',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, index) =>
                  _buildUserCard(filtered[index], index),
            ),
          ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: body,
    );
  }

  @override
  void dispose() {
    _userSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // keep the search term in sync with the controller
    _userSearchCtrl.addListener(() {
      final text = _userSearchCtrl.text;
      if (text != _userSearchTerm) {
        setState(() => _userSearchTerm = text);
      }
    });

    // Load admin details and initial lists
    _loadAdminDetail();
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildOrders(), // 0 Orders
      const AdminBillsPage(), // 1 Bills
      _buildUsers(), // 2 Users
      const AdminInventoryPage(), // 3 Inventory
      const AdminProfilePage(), // 4 Profile
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final showDesktopSidebar = constraints.maxWidth >= 900;

        final responsive = Responsive.of(context);
        final primary = Theme.of(context).colorScheme.primary;
        final appBar = AppBar(
          title: Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: responsive.fontSize(20, 22),
              fontWeight: FontWeight.w800,
            ),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, Color.lerp(primary, Colors.white, 0.25)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );

        final sidebar = showDesktopSidebar
            ? _buildDesktopSidebar(context, _sideNavItems)
            : null;
        final drawer = showDesktopSidebar
            ? null
            : _buildMobileDrawer(context, _sideNavItems);

        return Scaffold(
          appBar: appBar,
          drawer: drawer,
          body: Row(
            children: [
              if (sidebar != null) sidebar,
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey<int>(_tab),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: pages[_tab],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: showDesktopSidebar
              ? null
              : BottomNavigationBar(
                  currentIndex: _tab.clamp(0, 4).toInt(),
                  onTap: _switchTab,
                  type: BottomNavigationBarType.fixed,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.receipt_long),
                      label: 'Orders',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.point_of_sale),
                      label: 'Bills',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.people),
                      label: 'Users',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.inventory_2),
                      label: 'Inventory',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.account_circle),
                      label: 'Profile',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _SideNavItem {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String caption;
}

class _RoleFilter {
  const _RoleFilter(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}
