import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/image_resolver.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/pages/cart.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:fruit_shop/utils/responsive.dart';
import 'package:fruit_shop/widgets/animated_sections.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, String> userData;
  // Callback provided by Home so we can open the real live cart (with current items)
  // instead of constructing an empty cart locally. If null we fall back to an empty cart page.
  final VoidCallback? openCart;
  const ProfilePage({super.key, required this.userData, this.openCart});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  bool _isEditing = false;
  late final AnimationController _animController;
  late final Animation<double> _avatarScale;
  late final Animation<Offset> _slide;
  int _favorites = 0;
  bool _notifEnabled = true;
  bool _marketingEnabled = false;
  final ImagePicker _picker = ImagePicker();
  File? _avatarFile;
  String? _avatarUrl;
  // Recent orders from backend
  List<Map<String, dynamic>> _recentOrders = const [];
  bool _loadingRecent = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.userData['name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.userData['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userData['phone'] ?? '',
    );
    _addressController = TextEditingController(
      text: widget.userData['address'] ?? '',
    );
    _avatarUrl = widget.userData['avatarUrl'];

    _favorites = int.tryParse(widget.userData['favorites'] ?? '') ?? 0;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _avatarScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _refreshFromBackend();
    _refreshRecentOrders();
  }

  Future<void> _refreshFromBackend() async {
    try {
      final me = await UserDataApi.getMe();
      if (!mounted) return;
      if (me != null) {
        _nameController.text = me['name']?.toString() ?? _nameController.text;
        _emailController.text =
            me['email']?.toString() ?? _emailController.text;
        final addr = (me['address'] as Map?)?.cast<String, dynamic>();
        if (addr != null) {
          _addressController.text = [
            addr['address'],
            addr['landmark'],
            addr['city'],
            addr['state'],
            addr['pincode'],
          ].where((e) => (e ?? '').toString().isNotEmpty).join(', ');
          // Prefer top-level phone; fall back to address.phone if missing
          final phone = (me['phone']?.toString() ?? '').trim();
          _phoneController.text = phone.isNotEmpty
              ? phone
              : (addr['phone']?.toString() ?? _phoneController.text);
        } else {
          // No address object; still try to set phone from top-level
          final phone = (me['phone']?.toString() ?? '').trim();
          if (phone.isNotEmpty) {
            _phoneController.text = phone;
          }
        }
        final favs = (me['favorites'] as List?) ?? const [];
        final avatar = me['avatarUrl']?.toString();
        setState(() {
          _favorites = favs.length;
          _avatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshRecentOrders() async {
    setState(() => _loadingRecent = true);
    try {
      final orders = await UserDataApi.fetchOrders();
      // Sort by createdAt desc if present
      orders.sort((a, b) {
        final ad =
            DateTime.tryParse(
              (a['createdAt'] ?? '').toString(),
            )?.millisecondsSinceEpoch ??
            0;
        final bd =
            DateTime.tryParse(
              (b['createdAt'] ?? '').toString(),
            )?.millisecondsSinceEpoch ??
            0;
        return bd.compareTo(ad);
      });
      setState(() => _recentOrders = orders.take(3).toList());
    } catch (_) {
      // ignore errors quietly in profile; user can check Orders tab
    } finally {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
    if (_isEditing) {
      FocusScope.of(context).requestFocus(FocusNode());
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isEditing = false);
    try {
      final ok = await UserDataApi.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        widget.userData['name'] = _nameController.text.trim();
        widget.userData['phone'] = _phoneController.text.trim();
        String? uploadedUrl;
        if (_avatarFile != null) {
          try {
            final bytes = await _avatarFile!.readAsBytes();
            final segments = _avatarFile!.uri.pathSegments;
            final fileName = segments.isNotEmpty ? segments.last : 'avatar.jpg';
            uploadedUrl = await UserDataApi.uploadAvatar(
              bytes: bytes,
              filename: fileName,
            );
          } catch (e) {
            if (!mounted) return;
            AppSnack.showError(
              context,
              'Avatar upload failed: ${e.toString()}',
            );
          }
        }
        if (!mounted) return;
        if (uploadedUrl != null) {
          setState(() {
            _avatarUrl = uploadedUrl;
            _avatarFile = null;
          });
          widget.userData['avatarUrl'] = uploadedUrl;
          AppSnack.showSuccess(context, 'Profile & avatar updated');
        } else {
          AppSnack.showSuccess(context, 'Profile updated');
        }
        _refreshFromBackend();
      } else {
        AppSnack.showError(context, 'Failed to update profile');
      }
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Update failed: $e');
    }
  }

  Widget _avatarWidget(double radius) {
    // Local file has priority (picked image)
    if (_avatarFile != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white24,
        child: ClipOval(
          child: Image.file(
            _avatarFile!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                _nameController.text.isNotEmpty
                    ? _nameController.text[0].toUpperCase()
                    : 'G',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.64,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // Use ResolvedImage to handle emulator/local -> base URL rewrites
      final initials = _nameController.text.isNotEmpty
          ? _nameController.text[0].toUpperCase()
          : 'G';
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white24,
        child: ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: ResolvedImage(
              _avatarUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(radius),
              placeholder: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
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

    final initials = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : 'G';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white24,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.64,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // Avatar URL resolution moved to `ResolvedImage` widget; helper removed.

  Map<String, dynamic> _buildPopResult() {
    return {
      'avatarUrl': _avatarUrl,
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
    };
  }

  // Removed legacy favorites loader (backend hydration covers this)

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              AuthService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatarImage() async {
    try {
      final XFile? xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (xfile != null) {
        setState(() => _avatarFile = File(xfile.path));
      }
    } catch (_) {}
  }

  // Removed photo gallery section per request

  Widget _buildHeader() {
    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : 'Guest';
    final email = _emailController.text;
    return SlideTransition(
      position: _slide,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Color.lerp(
                Theme.of(context).colorScheme.primary,
                Colors.white,
                0.2,
              )!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(18),
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 30,
              top: 40,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Row(
              children: [
                ScaleTransition(
                  scale: _avatarScale,
                  child: Hero(
                    tag: 'profile_avatar_${widget.userData['email'] ?? name}',
                    child: Stack(
                      children: [
                        _avatarWidget(44),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _pickAvatarImage,
                              customBorder: const CircleBorder(),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'VFC🍎  Member',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              // If we have a cart opener from Home, pop Profile then open cart with real items.
                              if (widget.openCart != null) {
                                Navigator.pop(context, _buildPopResult());
                                widget.openCart!();
                              } else {
                                // Fallback: open an empty cart (legacy behavior)
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CartPage(cartItems: const []),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.shopping_cart, size: 18),
                            label: const Text('View Cart'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _confirmLogout,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    // Removed Orders tile to avoid redundancy
    return Row(
      children: [
        Expanded(
          child: _statTile(
            Icons.favorite,
            'Favorites',
            _favorites,
            Colors.pink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(Icons.location_on, 'Addresses', 1, Colors.blue),
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String label, int value, Color color) {
    return FadeInSlide(
      offset: const Offset(0, 20),
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: _isEditing,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: _isEditing ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRecentOrders() {
    Widget orderCard(Map<String, dynamic> o, int idx) {
      final createdAt = DateTime.tryParse((o['createdAt'] ?? '').toString());
      final pricing = (o['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
      final total = (pricing['total'] as num?)?.toDouble() ?? 0.0;
      final items = (o['items'] as List?)?.cast<Map>() ?? const [];
      final thumbs = items
          .map((e) => (e['image']?.toString()))
          .whereType<String>()
          .toList();
      final payment = (o['payment'] as Map?)?.cast<String, dynamic>() ?? {};
      final status = (payment['status']?.toString() ?? 'pending');
      final color = _statusColor(status);
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t) * (1 + idx * 0.08)),
            child: child,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.06), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (o['id'] ?? o['_id'] ?? '').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            createdAt != null ? '${createdAt.toLocal()}' : '',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_shipping, color: color, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel(status),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: thumbs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final img = thumbs[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _orderThumb(img),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/home',
                          arguments: {'initialTab': 1},
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View details'),
                      style: TextButton.styleFrom(foregroundColor: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Orders',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_loadingRecent)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_recentOrders.isEmpty)
          const Text('No recent orders')
        else
          ...List.generate(
            _recentOrders.length,
            (i) => orderCard(_recentOrders[i], i),
          ),
      ],
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'cod-pending':
        return Colors.orange;
      case 'upi-pending':
        return Colors.indigo;
      case 'card-pending':
        return Colors.purple;
      case 'failed':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'cod-pending':
        return 'COD Pending';
      case 'upi-pending':
        return 'UPI Pending';
      case 'card-pending':
        return 'Card Pending';
      case 'failed':
        return 'Failed';
      default:
        return 'Pending';
    }
  }

  Widget _quickActions() {
    Widget qa(
      IconData icon,
      String label,
      VoidCallback onTap,
      Color color,
      int idx,
    ) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t) * (1 + idx * 0.05)),
            child: child,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              border: Border.all(color: color.withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          qa(Icons.payment, 'Payments', () {}, Colors.purple, 0),
          const SizedBox(width: 10),
          qa(Icons.support_agent, 'Support', () {}, Colors.teal, 1),
          const SizedBox(width: 10),
          qa(
            Icons.emoji_events,
            'Rewards',
            () {
              AppSnack.showInfo(context, 'Rewards coming soon');
            },
            Colors.amber,
            2,
          ),
        ],
      ),
    );
  }

  // Resolve order item image: treat /uploads or relative paths as network resources via API base URL.
  Widget _orderThumb(String? path) {
    const double size = 44;
    if (path == null || path.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        width: size,
        height: size,
        alignment: Alignment.center,
        child: const Icon(
          Icons.local_grocery_store_outlined,
          color: Colors.grey,
        ),
      );
    }
    final trimmed = path.trim();
    // If already absolute URL, load network.
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _networkThumb(trimmed);
    }
    // If begins with /uploads treat as backend-hosted resource.
    if (trimmed.startsWith('/uploads')) {
      final base = AuthService.getBaseUrl();
      return _networkThumb('$base$trimmed');
    }
    // Fallback: try asset; if it fails will display placeholder.
    return Image.asset(
      trimmed,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        width: size,
        height: size,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Widget _networkThumb(String url) {
    const double size = 44;
    return ResolvedImage(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_buildPopResult());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Account',
            style: TextStyle(
              fontSize: responsive.fontSize(20, 22),
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, Color.lerp(primary, Colors.white, 0.2)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_isEditing) {
                    _saveProfile();
                  } else {
                    _toggleEdit();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _isEditing ? Icons.check_circle : Icons.edit_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshFromBackend,
          color: primary,
          child: ListView(
            padding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
            children: [
              _buildHeader(),
              SizedBox(height: responsive.spacing(14, 18)),
              _buildStatsCard(),
              SizedBox(height: responsive.spacing(14, 18)),
              _quickActions(),
              SizedBox(height: responsive.spacing(14, 18)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_isEditing),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.05),
                        Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isEditing ? 'Edit profile' : 'Profile info',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isEditing) ...[
                          _buildEditableField(
                            label: 'Full name',
                            controller: _nameController,
                            icon: Icons.person,
                          ),
                          const SizedBox(height: 10),
                          _buildEditableField(
                            label: 'Email',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            icon: Icons.email,
                          ),
                          const SizedBox(height: 10),
                          _buildEditableField(
                            label: 'Phone',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            icon: Icons.phone,
                          ),
                          const SizedBox(height: 10),
                          _buildEditableField(
                            label: 'Address',
                            controller: _addressController,
                            maxLines: 2,
                            icon: Icons.location_on,
                          ),
                        ] else ...[
                          _displayRow(
                            icon: Icons.person,
                            label: 'Name',
                            value: _nameController.text.isEmpty
                                ? 'Not set'
                                : _nameController.text,
                          ),
                          const SizedBox(height: 8),
                          _displayRow(
                            icon: Icons.email,
                            label: 'Email',
                            value: _emailController.text.isEmpty
                                ? 'Not set'
                                : _emailController.text,
                          ),
                          const SizedBox(height: 8),
                          _displayRow(
                            icon: Icons.phone,
                            label: 'Mobile',
                            value: _phoneController.text.isEmpty
                                ? 'Not set'
                                : _phoneController.text,
                          ),
                          const SizedBox(height: 8),
                          _displayRow(
                            icon: Icons.location_on,
                            label: 'Address',
                            value: _addressController.text.isEmpty
                                ? 'Not set'
                                : _addressController.text,
                            multiline: true,
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_isEditing)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      // revert changes by resetting controllers to original userData
                                      _nameController.text =
                                          widget.userData['name'] ?? '';
                                      _emailController.text =
                                          widget.userData['email'] ?? '';
                                      _phoneController.text =
                                          widget.userData['phone'] ?? '';
                                      _addressController.text =
                                          widget.userData['address'] ?? '';
                                    });
                                  },
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveProfile,
                                  child: const Text('Save changes'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Preferences
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _notifEnabled,
                      onChanged: (v) => setState(() => _notifEnabled = v),
                      title: const Text('Notifications'),
                      subtitle: const Text('Order updates and recommendations'),
                      secondary: const Icon(Icons.notifications_active),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: _marketingEnabled,
                      onChanged: (v) => setState(() => _marketingEnabled = v),
                      title: const Text('Offers & marketing'),
                      subtitle: const Text('Get seasonal deals from VFC'),
                      secondary: const Icon(Icons.local_offer),
                    ),
                  ],
                ),
              ),
              SizedBox(height: responsive.spacing(12, 16)),
              _buildRecentOrders(),
              SizedBox(height: responsive.spacing(18, 24)),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Account settings'),
                  subtitle: const Text(
                    'Manage password, payment methods and more',
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
              ),
              SizedBox(height: responsive.spacing(12, 16)),
              StaggeredAnimation(
                index: 5,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.help_outline, color: Colors.blue),
                    ),
                    title: const Text(
                      'Help & Support',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AppSnack.showInfo(context, 'Support not available');
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text('Sign out from this device'),
                  onTap: _confirmLogout,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper widget builders below class (kept simple for clarity)
extension _ProfileVisualHelpers on _ProfilePageState {
  Widget _displayRow({
    required IconData icon,
    required String label,
    required String value,
    bool multiline = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, color: primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: primary.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
