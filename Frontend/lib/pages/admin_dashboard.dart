import 'package:flutter/material.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:fruit_shop/pages/admin_inventory.dart';
import 'package:fruit_shop/pages/admin_profile.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _tab = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _users = [];
  String? _error;
  String _categoryFilter = 'fruit';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() { _loading = true; _error = null; });
    try {
      _products = await UserDataApi.adminListProducts(category: _categoryFilter);
    } catch (e) {
      _error = e.toString();
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      _orders = await UserDataApi.adminListOrders();
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadUsers() async {
    setState(() { _loading = true; _error = null; });
    try {
      _users = await UserDataApi.adminListUsers();
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _switchTab(int index) {
    setState(() => _tab = index);
    if (index == 0) {
      _loadProducts();
    } else if (index == 1) {
      _loadOrders();
    } else if (index == 2) {
      _loadUsers();
    }
  }

  Future<void> _createProduct() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();
    String category = _categoryFilter;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: const [
                  DropdownMenuItem(value: 'fruit', child: Text('Fruit')),
                  DropdownMenuItem(value: 'juice', child: Text('Juice')),
                  DropdownMenuItem(value: 'other', child: Text('Other Product')),
                  DropdownMenuItem(value: 'soft_drink', child: Text('Soft Drink')),
                ],
                onChanged: (v) => category = v ?? 'fruit',
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim());
              if (name.isEmpty || price == null) {
                AppSnack.showError(context, 'Name & price required');
                return;
              }
              try {
                await UserDataApi.adminCreateProduct({
                  'name': name,
                  'price': price,
                  'category': category,
                  'description': descController.text.trim(),
                });
                if (!mounted) return;
                AppSnack.showSuccess(context, 'Product added');
                if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                _loadProducts();
              } catch (e) {
                if (!mounted) return;
                AppSnack.showError(context, 'Create failed: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildProducts() {
    return Column(
      children: [
        Row(
          children: [
            DropdownButton<String>(
              value: _categoryFilter,
              items: const [
                DropdownMenuItem(value: 'fruit', child: Text('Fruit')),
                DropdownMenuItem(value: 'juice', child: Text('Juice')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
                DropdownMenuItem(value: 'soft_drink', child: Text('Soft Drinks')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _categoryFilter = v);
                _loadProducts();
              },
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _createProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (ctx, i) {
                        final p = _products[i];
                        return Card(
                          child: ListTile(
                            title: Text(p['name'] ?? ''),
                            subtitle: Text('${p['category']} • ₹${(p['price'] ?? 0).toString()}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final id = p['_id']?.toString();
                                if (id == null) return;
                                final ok = await UserDataApi.adminDeleteProduct(id);
                                if (!mounted) return;
                                if (ok) {
                                  AppSnack.showSuccess(context, 'Deleted');
                                  _loadProducts();
                                } else {
                                  AppSnack.showError(context, 'Delete failed');
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildOrders() {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!))
      : ListView.builder(
                itemCount: _orders.length,
        itemBuilder: (ctx, i) {
                  final o = _orders[i];
                  final pricing = o['pricing'] as Map<String, dynamic>?;
                  final total = pricing?['total'] ?? 0;
                  final user = o['user'] as Map<String, dynamic>?;
                  final status = (o['status'] ?? 'processing').toString();
                  return Card(
                    child: ListTile(
                      title: Text('Order ${o['id']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${user?['email']} • ₹$total'),
                          Row(
                            children: [
                              const Text('Status: '),
                              DropdownButton<String>(
                                value: status,
                                items: const [
                                  DropdownMenuItem(value: 'processing', child: Text('Processing')),
                                  DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                                  DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                                ],
                                onChanged: (v) async {
                                  if (v == null) return;
                                  final id = o['id']?.toString();
                                  if (id == null) return;
                                  // optimistic
                                  setState(() => _orders[i]['status'] = v);
                                  final ok = await UserDataApi.adminUpdateOrderStatus(id, v);
                                  if (!mounted) return;
                                  if (ok) {
                                    AppSnack.showSuccess(context, 'Status updated');
                                  } else {
                                    setState(() => _orders[i]['status'] = status); // revert
                                    AppSnack.showError(context, 'Failed to update');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Order ${o['id']}'),
                            content: SingleChildScrollView(
                              child: Text(
                                o.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
  }

  Widget _buildUsers() {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!))
            : ListView.builder(
                itemCount: _users.length,
                itemBuilder: (ctx, i) {
                  final u = _users[i];
                  return Card(
                    child: ListTile(
                      title: Text(u['name'] ?? ''),
                      subtitle: Text(u['email'] ?? ''),
                      trailing: DropdownButton<String>(
                        value: (u['role'] ?? 'user').toString(),
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text('User')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          final id = u['_id']?.toString();
                          if (id == null) return;
                          final ok = await UserDataApi.adminUpdateUserRole(id, v);
                          if (!mounted) return;
                          if (ok) {
                            setState(() => _users[i]['role'] = v);
                            AppSnack.showSuccess(context, 'Role updated');
                          } else {
                            AppSnack.showError(context, 'Update failed');
                          }
                        },
                      ),
                      onTap: () async {
                        try {
                          final id = u['_id']?.toString();
                          if (id == null) return;
                          final data = await UserDataApi.adminGetUser(id);
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('User ${u['name']}'),
                              content: SingleChildScrollView(
                                child: Text(
                                  data.toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          AppSnack.showError(context, 'Failed user detail');
                        }
                      },
                    ),
                  );
                },
              );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildProducts(), // 0 Products
      _buildOrders(),   // 1 Orders
      _buildUsers(),    // 2 Users
      const AdminInventoryPage(), // 3 Inventory
      const AdminProfilePage(),   // 4 Profile
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 800;
        final nav = useRail
            ? NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: _switchTab,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.store_outlined),
                    selectedIcon: Icon(Icons.store),
                    label: Text('Products'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: Text('Orders'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: Text('Users'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: Text('Inventory'),
                  ),
                ],
                labelType: NavigationRailLabelType.all,
              )
            : null;

        final appBar = AppBar(
          title: const Text('Admin Dashboard'),
          flexibleSpace: Builder(
            builder: (context) {
              final primary = Theme.of(context).colorScheme.primary;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, Color.lerp(primary, Colors.white, 0.25)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
        );
        return Scaffold(
          appBar: appBar,
          drawer: useRail
              ? null
              : Drawer(
                  child: ListView(
                    children: [
                      const DrawerHeader(child: Text('Admin')),
                      ListTile(
                        leading: const Icon(Icons.store),
                        title: const Text('Products'),
                        selected: _tab == 0,
                        onTap: () { Navigator.pop(context); _switchTab(0); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: const Text('Orders'),
                        selected: _tab == 1,
                        onTap: () { Navigator.pop(context); _switchTab(1); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: const Text('Users'),
                        selected: _tab == 2,
                        onTap: () { Navigator.pop(context); _switchTab(2); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.inventory_2),
                        title: const Text('Inventory'),
                        selected: _tab == 3,
                        onTap: () { Navigator.pop(context); _switchTab(3); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.account_circle),
                        title: const Text('Profile'),
                        selected: _tab == 4,
                        onTap: () { Navigator.pop(context); _switchTab(4); },
                      ),
                    ],
                  ),
                ),
          body: Row(
            children: [
              if (nav != null) SizedBox(width: 72, child: nav),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: pages[_tab],
                ),
              ),
            ],
          ),
          // Bottom nav retained for mobile familiarity
          bottomNavigationBar: useRail
              ? null
              : BottomNavigationBar(
                  currentIndex: _tab.clamp(0, 4),
                  onTap: _switchTab,
                  type: BottomNavigationBarType.fixed,
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Products'),
                    BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
                    BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
                    BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Inventory'),
                    BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Profile'),
                  ],
                ),
        );
      },
    );
  }
}
