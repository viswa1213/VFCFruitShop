import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:fruit_shop/services/user_data_api.dart';
import 'package:fruit_shop/pages/home.dart';
import 'package:fruit_shop/pages/login.dart';

/// Simple splash / entrance page shown at app launch.
/// Replace the [FlutterLogo] below with your branded asset when ready,
/// e.g. `Image.asset('assets/images/your_logo.png')`.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  bool? _logoLoaded;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();

    // Start a background check to precache the logo asset so we can report
    // a diagnostic if it fails to load (useful when assets aren't picked up).
    _checkLogoAsset();

    // Show the splash briefly then decide where to go.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Small delay so the logo animation is visible.
      await Future.delayed(const Duration(milliseconds: 900));

      try {
        final token = await AuthService.getToken();
        if (token != null && token.isNotEmpty) {
          // hydrate user in background
          UserDataApi.getMe();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomePage(userData: {})),
          );
          return;
        }
      } catch (_) {
        // ignore and fallthrough to login
      }

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    });
  }

  Future<void> _checkLogoAsset() async {
    try {
      await precacheImage(
        const AssetImage('assets/images/VFC_logo1.png'),
        context,
      );
      if (!mounted) return;
      setState(() => _logoLoaded = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _logoLoaded = false);
      // Keep the error silent in release builds; in debug we print to console.
      if (kDebugMode) debugPrint('Splash: failed to precache vfc_logo.png: $e');
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    // Slightly stronger branding on dark mode so the logo container stands out.
    final containerAlpha = theme.brightness == Brightness.dark ? 0.14 : 0.06;
    final containerColor = primary.withValues(alpha: containerAlpha);

    return Scaffold(
      // Use a green gradient background for the splash screen.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B5E20), // dark green
              Color(0xFF66BB6A), // light green
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 240,
                    height: 240,
                    // Outer ring with a subtle radial gradient to act as a decorative ring.
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.00),
                        ],
                        center: Alignment.center,
                        radius: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: containerColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.28
                                  : 0.10,
                            ),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: ClipOval(
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: Image.asset(
                            'assets/images/VFC_logo1.png',
                            width: 180,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) {
                              // Fallback to FlutterLogo if the asset is missing or fails to load.
                              return FlutterLogo(
                                size: 160,
                                style: FlutterLogoStyle.markOnly,
                                textColor: onPrimary,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Fruizo BY VFC',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                if (kDebugMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _logoLoaded == null
                          ? 'Checking logo...'
                          : (_logoLoaded == true
                                ? 'Logo asset OK'
                                : 'Logo asset missing'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
