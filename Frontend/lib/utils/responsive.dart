import 'package:flutter/material.dart';

/// Responsive breakpoints for the app
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Responsive utility class
class Responsive {
  final BuildContext context;
  final double width;
  final double height;

  Responsive._(this.context, this.width, this.height);

  factory Responsive.of(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Responsive._(context, mediaQuery.size.width, mediaQuery.size.height);
  }

  /// Check if current screen is mobile
  bool get isMobile => width < Breakpoints.mobile;

  /// Check if current screen is tablet
  bool get isTablet =>
      width >= Breakpoints.mobile && width < Breakpoints.desktop;

  /// Check if current screen is desktop
  bool get isDesktop => width >= Breakpoints.desktop;

  /// Get responsive padding
  EdgeInsets get padding => EdgeInsets.symmetric(
    horizontal: isMobile
        ? 16
        : isTablet
        ? 24
        : 32,
    vertical: isMobile ? 12 : 16,
  );

  /// Get responsive font size
  double fontSize(double mobile, [double? tablet, double? desktop]) {
    if (isMobile) return mobile;
    if (isTablet) return tablet ?? mobile * 1.2;
    return desktop ?? mobile * 1.5;
  }

  /// Get responsive spacing
  double spacing(double mobile, [double? tablet, double? desktop]) {
    if (isMobile) return mobile;
    if (isTablet) return tablet ?? mobile * 1.5;
    return desktop ?? mobile * 2;
  }

  /// Get responsive column count for grids
  int gridColumns(int mobile, [int? tablet, int? desktop]) {
    if (isMobile) return mobile;
    if (isTablet) return tablet ?? mobile + 1;
    return desktop ?? mobile + 2;
  }

  /// Get max width for content
  double get maxContentWidth {
    if (isMobile) return width;
    if (isTablet) return 800;
    return 1200;
  }
}

/// Responsive widget that adapts based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    if (responsive.isDesktop && desktop != null) return desktop!;
    if (responsive.isTablet && tablet != null) return tablet!;
    return mobile;
  }
}
