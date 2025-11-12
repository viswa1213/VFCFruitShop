import 'package:flutter/material.dart';

/// Staggered animation widget for list items
class StaggeredAnimation extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  const StaggeredAnimation({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 100),
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration + (delay * index),
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Transform.scale(scale: 0.8 + (0.2 * value), child: child),
          ),
        );
      },
      child: child,
    );
  }
}

/// Parallax scroll effect widget
class ParallaxWidget extends StatelessWidget {
  final Widget child;
  final ScrollController scrollController;
  final double parallaxOffset;

  const ParallaxWidget({
    super.key,
    required this.child,
    required this.scrollController,
    this.parallaxOffset = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        final offset = scrollController.hasClients
            ? scrollController.offset * parallaxOffset
            : 0.0;
        return Transform.translate(
          offset: Offset(0, offset),
          child: this.child,
        );
      },
      child: child,
    );
  }
}

/// Pulse animation widget for attention-grabbing elements
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 2),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(scale: _animation.value, child: widget.child);
      },
    );
  }
}

/// Shimmer loading effect
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0.0),
              end: Alignment(1.0 - _controller.value * 2, 0.0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Fade in slide animation
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;

  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 30),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _started = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _started = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return Opacity(opacity: 0, child: widget.child);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              widget.offset.dx * (1 - value),
              widget.offset.dy * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
