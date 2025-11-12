import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:fruit_shop/widgets/app_snackbar.dart';
import 'package:fruit_shop/utils/responsive.dart';
import 'package:fruit_shop/widgets/responsive_container.dart';
import 'package:fruit_shop/widgets/animated_sections.dart';

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
  final double _buttonScale = 1.0;

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
    final responsive = Responsive.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          // Enhanced background with parallax effect
          Positioned.fill(
            child: Stack(
              children: [
                Image.asset(
                  'assets/images/bg.jpg',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                // Animated gradient overlay
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, t, _) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primary.withValues(alpha: 0.4 * t),
                            primary.withValues(alpha: 0.2 * t),
                            Colors.white.withValues(alpha: 0.1 * t),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Responsive centered register card
          Center(
            child: SingleChildScrollView(
              child: ResponsiveContainer(
                maxWidth: responsive.isMobile ? double.infinity : 500,
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
                                          Icons.person_add_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Create Account',
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
                                        'Join us for fresh fruits!',
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

                                // Name field
                                FadeInSlide(
                                  offset: const Offset(-30, 0),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 100),
                                  child: TextFormField(
                                    controller: _nameController,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: InputDecoration(
                                      labelText: 'Full Name',
                                      prefixIcon: Icon(
                                        Icons.person_outlined,
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
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Please enter your name'
                                        : null,
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(16, 20)),

                                // Email field
                                FadeInSlide(
                                  offset: const Offset(-30, 0),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 200),
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
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                      ).hasMatch(v)) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(16, 20)),

                                // Password field with strength indicator
                                FadeInSlide(
                                  offset: const Offset(-30, 0),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 300),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        onChanged: _checkPasswordStrength,
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
                                              onTap: () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                          .visibility_off_outlined,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: primary,
                                              width: 2,
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
                                      if (_passwordStrength.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color:
                                                    _passwordStrength ==
                                                        'Strong'
                                                    ? Colors.green
                                                    : _passwordStrength ==
                                                          'Medium'
                                                    ? Colors.orange
                                                    : Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _passwordStrength,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    _passwordStrength ==
                                                        'Strong'
                                                    ? Colors.green
                                                    : _passwordStrength ==
                                                          'Medium'
                                                    ? Colors.orange
                                                    : Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(16, 20)),

                                // Confirm Password field
                                FadeInSlide(
                                  offset: const Offset(-30, 0),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 400),
                                  child: TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      prefixIcon: Icon(
                                        Icons.lock_outlined,
                                        color: primary,
                                      ),
                                      suffixIcon: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => setState(
                                            () => _obscureConfirmPassword =
                                                !_obscureConfirmPassword,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Icon(
                                            _obscureConfirmPassword
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
                                    validator: (v) =>
                                        (v != _passwordController.text)
                                        ? 'Passwords do not match'
                                        : null,
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(16, 20)),

                                // Terms agreement
                                FadeInSlide(
                                  offset: const Offset(0, 20),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 500),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _agree = !_agree),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: _agree
                                                    ? primary
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: _agree
                                                      ? primary
                                                      : Colors.grey.shade400,
                                                  width: 2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: _agree
                                                  ? const Icon(
                                                      Icons.check,
                                                      color: Colors.white,
                                                      size: 16,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'I agree to the Terms & Privacy Policy',
                                                style: TextStyle(
                                                  fontSize: responsive.fontSize(
                                                    14,
                                                  ),
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(24, 32)),

                                // Enhanced register button
                                FadeInSlide(
                                  offset: const Offset(0, 30),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 600),
                                  child: Material(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      onTap: _isLoading ? null : _register,
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
                                                    'Create Account',
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

                                // Login link
                                FadeInSlide(
                                  offset: const Offset(0, 20),
                                  duration: const Duration(milliseconds: 700),
                                  delay: const Duration(milliseconds: 700),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: responsive.fontSize(14),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pushReplacementNamed(
                                              context,
                                              '/login',
                                            ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: primary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Login',
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
                        'Creating account...',
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
