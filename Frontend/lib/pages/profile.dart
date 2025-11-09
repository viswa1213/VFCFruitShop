import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/pages/cart.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';

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
        _favorites = favs.length;
        setState(() {});
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
        AppSnack.showSuccess(context, 'Profile updated');
        _refreshFromBackend();
      } else {
        AppSnack.showError(context, 'Failed to update profile');
      }
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Update failed: $e');
    }
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
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white24,
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : null,
                          child: _avatarFile == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'G',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
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
                                Navigator.pop(context); // close Profile
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
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
                        child: Image.asset(
                          img,
                          height: 44,
                          width: 44,
                          fit: BoxFit.cover,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
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
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                _toggleEdit();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFromBackend,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildStatsCard(),
            const SizedBox(height: 14),
            _quickActions(),
            const SizedBox(height: 14),
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
            const SizedBox(height: 12),
            _buildRecentOrders(),
            const SizedBox(height: 18),
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
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & Support'),
                onTap: () {
                  AppSnack.showInfo(context, 'Support not available');
                },
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
          ],
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
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withOpacity(0.18)),
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
                    color: primary.withOpacity(0.75),
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
