import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/pages/cart.dart';
import 'package:fruit_shop/services/favorites_storage.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, String> userData;
  const ProfilePage({super.key, required this.userData});

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
    // Load persisted favorites to reflect changes made on Home
    _loadFavoritesCount();
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

  void _saveProfile() {
    setState(() => _isEditing = false);
    // In a real app: send updates to backend / persist locally
    AppSnack.showSuccess(context, 'Profile updated');
  }

  Future<void> _loadFavoritesCount() async {
    final favs = await FavoritesStorage.load();
    if (!mounted) return;
    setState(() => _favorites = favs.length);
  }

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
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CartPage(cartItems: const []),
                              ),
                            ),
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
    // Sample recent orders; in a real app this comes from backend
    final orders = [
      {
        'id': 'VF-10234',
        'date': 'Oct 12, 2025',
        'status': 'Delivered',
        'total': 589.0,
        'thumbs': [
          'assets/images/cherry.avif',
          'assets/images/Pomegranate.avif',
        ],
      },
      {
        'id': 'VF-10188',
        'date': 'Sep 28, 2025',
        'status': 'Out for delivery',
        'total': 349.0,
        'thumbs': ['assets/images/Pomegranate.avif'],
      },
    ];

    Color statusColor(String s) {
      switch (s.toLowerCase()) {
        case 'delivered':
          return Colors.green;
        case 'out for delivery':
          return Colors.orange;
        case 'cancelled':
          return Colors.red;
        default:
          return Colors.blueGrey;
      }
    }

    Widget orderCard(Map<String, dynamic> o, int idx) {
      final color = statusColor(o['status'] as String);
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
                            o['id'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            o['date'] as String,
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
                            o['status'] as String,
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
                    itemCount: (o['thumbs'] as List).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final img = (o['thumbs'] as List)[i] as String;
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
                      'Total: ₹${(o['total'] as num).toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextButton.icon(
                      onPressed: () {},
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
        ...List.generate(orders.length, (i) => orderCard(orders[i], i)),
      ],
    );
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
      body: ListView(
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
              subtitle: const Text('Manage password, payment methods and more'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
