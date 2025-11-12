import 'package:flutter/material.dart';
import 'package:fruit_shop/utils/responsive.dart';

/// A container that adapts its width based on screen size
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? responsive.maxContentWidth,
      ),
      padding: padding ?? responsive.padding,
      child: child,
    );
  }
}
