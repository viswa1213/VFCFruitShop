import 'package:flutter/material.dart';
import 'package:fruit_shop/pages/home.dart';
import 'package:fruit_shop/pages/login.dart';
import 'package:fruit_shop/pages/register.dart';
import 'package:fruit_shop/services/app_theme.dart';
import 'package:fruit_shop/pages/settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _lightTheme(Color accent) {
    final base = ThemeData.light();
    // Derive a subtle card color from the drawer's gradient (primary -> white)
    final card = Color.lerp(Colors.white, accent, 0.06)!;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent.withValues(alpha: 0.8),
      ),
      scaffoldBackgroundColor: Colors.grey.shade50,
      cardColor: card,
      cardTheme: base.cardTheme.copyWith(color: card),
      appBarTheme: AppBarTheme(
        backgroundColor: accent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  ThemeData _darkTheme(Color accent) {
    final base = ThemeData.dark();
    // Blend accent into a dark base to echo the drawer background subtly
    final darkBase = const Color(0xFF121212);
    final card = Color.alphaBlend(accent.withValues(alpha: 0.08), darkBase);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent.withValues(alpha: 0.8),
      ),
      scaffoldBackgroundColor: Colors.black,
      cardColor: card,
      cardTheme: base.cardTheme.copyWith(color: card),
      appBarTheme: AppBarTheme(
        backgroundColor: accent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: AppTheme.accent,
          builder: (context, accent, __) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Fruit Shop',
              theme: _lightTheme(accent),
              darkTheme: _darkTheme(accent),
              themeMode: mode,
              themeAnimationDuration: const Duration(milliseconds: 380),
              themeAnimationCurve: Curves.easeInOut,
              home: const LoginPage(),
              routes: {
                '/login': (context) => const LoginPage(),
                '/register': (context) => const RegisterPage(),
                '/home': (context) {
                  final userData =
                      ModalRoute.of(context)!.settings.arguments
                          as Map<String, String>? ??
                      {};
                  return HomePage(userData: userData);
                },
                '/settings': (context) => const SettingsPage(),
              },
            );
          },
        );
      },
    );
  }
}
