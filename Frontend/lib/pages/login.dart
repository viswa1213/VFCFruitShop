import 'package:flutter/material.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/services/favorites_storage.dart';
import 'package:fruit_shop/utils/responsive.dart';
import 'package:fruit_shop/widgets/responsive_container.dart';
import 'package:fruit_shop/widgets/animated_sections.dart';

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
  final double _buttonScale = 1.0;

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
    final responsive = Responsive.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen background image (normal, no overlay)
          Positioned.fill(
            child: Image.asset('assets/images/bg.jpg', alignment: Alignment.center, fit: BoxFit.cover),
          ),

          // Responsive centered login card
          Center(
            child: SingleChildScrollView(
              child: ResponsiveContainer(
                maxWidth: responsive.isMobile ? double.infinity : 450,
                padding: responsive.padding,
                child: SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: primary.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          padding: EdgeInsets.all(
                            responsive.isMobile ? 24.0 : 32.0,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Logo and title with animation
                                FadeInSlide(
                                  offset: const Offset(0, -20),
                                  duration: const Duration(milliseconds: 600),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              primary,
                                              primary.withValues(alpha: 0.7),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: primary.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.shopping_bag_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Fruit Shop',
                                        style: TextStyle(
                                          fontSize: responsive.fontSize(
                                            28,
                                            32,
                                            36,
                                          ),
                                          fontWeight: FontWeight.w900,
                                          color: primary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Welcome back!',
                                        style: TextStyle(
                                          fontSize: responsive.fontSize(14, 16),
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(24, 32)),

                                // Email field with enhanced design
                                FadeInSlide(
                                  offset: const Offset(-30, 0),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 100),
                                  child: TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        color: primary,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: primary,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Enter your email';
                                      }
                                      if (!RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                      ).hasMatch(value)) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(16, 20)),

                                // Password field with enhanced design
                                FadeInSlide(
                                  offset: const Offset(-30, 0),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 200),
                                  child: TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(
                                        Icons.lock_outlined,
                                        color: primary,
                                      ),
                                      suffixIcon: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _isPasswordVisible =
                                                  !_isPasswordVisible;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: primary,
                                          width: 2,
                                        ),
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
                                ),
                                SizedBox(height: responsive.spacing(16, 20)),

                                // Remember me & Forgot password
                                FadeInSlide(
                                  offset: const Offset(0, 20),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 300),
                                  child: Row(
                                    children: [
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => setState(() {
                                            _rememberMe = !_rememberMe;
                                          }),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value: _rememberMe,
                                                onChanged: (v) => setState(() {
                                                  _rememberMe = v ?? true;
                                                }),
                                                activeColor: primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                              const Text(
                                                'Remember me',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {
                                          AppSnack.showInfo(
                                            context,
                                            'Password reset feature coming soon!',
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: primary,
                                        ),
                                        child: const Text(
                                          'Forgot password?',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(24, 32)),

                                // Enhanced login button
                                FadeInSlide(
                                  offset: const Offset(0, 30),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 400),
                                  child: Material(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      onTap: _isLoading ? null : _login,
                                      borderRadius: BorderRadius.circular(14),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        transform: Matrix4.diagonal3Values(
                                          _buttonScale,
                                          _buttonScale,
                                          _buttonScale,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: responsive.isMobile
                                              ? 16
                                              : 18,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              primary,
                                              primary.withValues(alpha: 0.8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primary.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 15,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Login',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: responsive
                                                          .fontSize(16, 18),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(20, 24)),

                                // Register link
                                FadeInSlide(
                                  offset: const Offset(0, 20),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 500),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: responsive.fontSize(14),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/register',
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: primary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Register',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
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
                  ),
                ),
              ),
            ),
          ),

          // Enhanced loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Signing in...',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
