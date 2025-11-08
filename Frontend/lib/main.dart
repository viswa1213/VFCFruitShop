import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fruit_shop/pages/home.dart';
import 'package:fruit_shop/pages/login.dart';
import 'package:fruit_shop/pages/register.dart';
import 'package:fruit_shop/services/app_theme.dart';
import 'package:fruit_shop/pages/settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv load failed: $e');
  }
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
                  final args = ModalRoute.of(context)!.settings.arguments;
                  Map<String, String> userData = {};
                  // initialTab handled by HomePage via route arguments; no local use needed here.
                  if (args is Map<String, String>) {
                    userData = args;
                  } else if (args is Map) {
                    final ud = args['userData'];
                    if (ud is Map) {
                      // Try to coerce keys/values to String
                      userData = ud.map<String, String>(
                        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
                      );
                    }
                    // HomePage will read args['initialTab'] itself; nothing to do here.
                  }
                  // If no explicit initialTab, default remains Home (0); HomePage reads it via route args too
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
