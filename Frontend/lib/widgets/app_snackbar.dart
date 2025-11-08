import 'package:flutter/material.dart';

class AppSnack {
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      duration: duration,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: _card(
        context,
        message,
        leading: const Icon(Icons.check_circle_rounded, color: Colors.white),
        tint: Theme.of(context).colorScheme.primary,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      duration: duration,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: _card(
        context,
        message,
        leading: const Icon(Icons.info_rounded, color: Colors.white),
        tint: Color.lerp(primary, Colors.blueAccent, 0.3) ?? primary,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      duration: duration,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: _card(
        context,
        message,
        leading: const Icon(Icons.error_outline_rounded, color: Colors.white),
        tint: Colors.redAccent,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  static Widget _card(
    BuildContext context,
    String message, {
    required Widget leading,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, Color.lerp(tint, Colors.white, 0.22)!],
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
