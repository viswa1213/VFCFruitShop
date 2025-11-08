import 'package:flutter/material.dart';

/// Centralized semantic color helpers so we avoid hard-coded black/white
/// values that break in dark mode. Replace direct usages of
/// Colors.black*, Colors.white* (for text) with these helpers.
class UiColors {
  const UiColors._();

  /// Primary readable text color (maps to onSurface).
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// Secondary text with medium emphasis.
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withOpacity(0.70);

  /// Tertiary/disabled style text.
  static Color textTertiary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withOpacity(0.50);

  /// Very subtle caption / divider label text.
  static Color textQuaternary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withOpacity(0.38);
}

// Note: toARGB32 helper not used here; keep conversions local where needed.