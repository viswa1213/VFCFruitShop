import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agree = true;
  bool _isLoading = false;

  String _passwordStrength = '';

  late final AnimationController _animController;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardSlide;
  double _buttonScale = 1.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardOpacity = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, .1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      _passwordStrength = '';
    } else if (password.length < 6) {
      _passwordStrength = 'Weak';
    } else if (password.length < 10) {
      _passwordStrength = 'Medium';
    } else {
      _passwordStrength = 'Strong';
    }
    setState(() {});
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      AppSnack.showInfo(context, 'Please agree to the terms to continue');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      if (result.containsKey('token')) {
        if (!mounted) return;
        AppSnack.showInfo(context, 'Registered successfully. Please login.');
        // Navigate to Login as requested flow
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        AppSnack.showError(
          context,
          result['message']?.toString() ?? 'Registration failed',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnack.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primary, Color.lerp(primary, Colors.white, 0.2)!],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset('assets/images/cherry.avif', fit: BoxFit.cover),
          ),
          // Animated background
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 5),
            builder: (context, t, _) => Container(
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
            ),
          ),

          // Card
          Center(
            child: SlideTransition(
              position: _cardSlide,
              child: FadeTransition(
                opacity: _cardOpacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 20,
                            spreadRadius: 1,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Create an Account',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: primary,
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Please enter your name'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                onChanged: _checkPasswordStrength,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (v.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _passwordStrength.isEmpty
                                      ? ''
                                      : 'Password Strength: $_passwordStrength',
                                  style: TextStyle(
                                    color: _passwordStrength == 'Strong'
                                        ? Colors.green
                                        : _passwordStrength == 'Medium'
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    (v != _passwordController.text)
                                    ? 'Passwords do not match'
                                    : null,
                              ),

                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _agree,
                                    onChanged: (v) =>
                                        setState(() => _agree = v ?? true),
                                    activeColor: primary,
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'I agree to the Terms & Privacy',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),
                              GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => _buttonScale = 0.98),
                                onTapUp: (_) =>
                                    setState(() => _buttonScale = 1.0),
                                onTapCancel: () =>
                                    setState(() => _buttonScale = 1.0),
                                onTap: _isLoading ? null : _register,
                                child: Transform.scale(
                                  scale: _buttonScale,
                                  child: Container(
                                    width: size.width * 0.6,
                                    decoration: BoxDecoration(
                                      color: primary,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    alignment: Alignment.center,
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Create account',
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
                                onPressed: () => Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                ),
                                child: const Text(
                                  'Already have an account? Login',
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
