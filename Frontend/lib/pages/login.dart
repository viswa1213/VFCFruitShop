import 'package:flutter/material.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/services/favorites_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _rememberMe = true;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _cardOpacity;
  late Animation<Offset> _cardSlide;
  double _buttonScale = 1.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _cardOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return; // Guard before state change
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final baseUrl = AuthService.getBaseUrl();
      // ignore: avoid_print
      print('Auth base URL: $baseUrl');

      final result = await AuthService.login(email: email, password: password);

      if (!mounted) return;
      if (result.containsKey('token')) {
        final user = (result['user'] as Map?) ?? {};
        // One-shot hydration: fetch server state (cart, favorites, etc.)
        try {
          final me = await UserDataApi.getMe();
          if (!mounted) return; // Guard context after async gap
          if (me != null) {
            final favs = (me['favorites'] as List?)?.cast<String>() ?? const [];
            await FavoritesStorage.save(favs);
          }
        } catch (_) {}
        if (!mounted) return;
        AppSnack.showSuccess(
          context,
          'Welcome back, ${user['name']?.toString() ?? 'User'}!',
        );
        // If admin, send to admin dashboard; else go to home
        final role = (user['role'] ?? '').toString();
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          final args = <String, String>{
            'name': (user['name'] ?? 'User').toString(),
            'email': (user['email'] ?? email).toString(),
          };
          Navigator.pushReplacementNamed(context, '/home', arguments: args);
        }
      } else {
        if (!mounted) return;
        final msg = result['message'] ?? 'Invalid credentials';
        final status = result['status'];
        AppSnack.showError(
          context,
          '${status != null ? 'HTTP $status: ' : ''}$msg',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset('assets/images/cherry.avif', fit: BoxFit.cover),
          ),
          // Animated background driven by accent color
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 5),
            builder: (context, t, _) {
              final primary = Theme.of(context).colorScheme.primary;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        primary,
                        Colors.white,
                        0.78,
                      )!.withValues(alpha: 0.25),
                      Color.lerp(
                        primary,
                        Colors.white,
                        0.92,
                      )!.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              );
            },
          ),

          // Centered animated login card
          Center(
            child: SlideTransition(
              position: _cardSlide,
              child: FadeTransition(
                opacity: _cardOpacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(25.0),
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Fruit Shop',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Welcome back! Log in to continue',
                              style: TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Remember me & Forgot password
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (v) => setState(() {
                                    _rememberMe = v ?? true;
                                  }),
                                  activeColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                ),
                                const Text('Remember me'),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    AppSnack.showInfo(
                                      context,
                                      'Reset link sent (demo)',
                                    );
                                  },
                                  child: const Text('Forgot password?'),
                                ),
                              ],
                            ),

                            // Login button with press animation
                            GestureDetector(
                              onTapDown: (_) =>
                                  setState(() => _buttonScale = 0.98),
                              onTapUp: (_) =>
                                  setState(() => _buttonScale = 1.0),
                              onTapCancel: () =>
                                  setState(() => _buttonScale = 1.0),
                              onTap: _login,
                              child: Transform.scale(
                                scale: _buttonScale,
                                child: Container(
                                  width: size.width * 0.6,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: const Text(
                                "Don't have an account? Register",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.12),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
