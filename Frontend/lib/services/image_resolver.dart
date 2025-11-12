import 'package:flutter/material.dart';
import 'package:fruit_shop/services/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

// Internal retrying network image helper: attempts original URL, and on
// failure will try a small set of fallbacks (switch scheme http<->https,
// replace host with configured backend) to improve robustness across
// devices and networks.
class _RetryingCachedImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const _RetryingCachedImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<_RetryingCachedImage> createState() => _RetryingCachedImageState();
}

class _RetryingCachedImageState extends State<_RetryingCachedImage> {
  late String _currentUrl;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    if (kDebugMode) {
      debugPrint('ResolvedImage: initial URL: ${widget.url}');
    }
  }

  List<String> _buildAlternatives(String url) {
    final alt = <String>[];
    try {
      final uri = Uri.parse(url);
      // If scheme is http, try https variant and vice-versa
      if (uri.scheme == 'http') {
        alt.add(uri.replace(scheme: 'https').toString());
      } else if (uri.scheme == 'https') {
        alt.add(uri.replace(scheme: 'http').toString());
      }

      // Also try replacing host with configured backend host (useful if DB
      // contains emulator host or old hostnames)
      final base = Uri.tryParse(AuthService.getBaseUrl());
      if (base != null && base.host.isNotEmpty && base.host != uri.host) {
        alt.add(
          uri
              .replace(
                scheme: base.scheme,
                host: base.host,
                port: base.hasPort ? base.port : null,
              )
              .toString(),
        );
      }
    } catch (_) {}
    return alt;
  }

  void _onError(Object? error, StackTrace? stack) {
    if (!mounted) return;
    final alternatives = _buildAlternatives(widget.url);
    if (_attempt < alternatives.length) {
      // Schedule the state change to run after the current build frame so we
      // don't call setState synchronously during widget building (which
      // causes the "setState() or markNeedsBuild() called during build"
      // exception).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentUrl = alternatives[_attempt];
          _attempt += 1;
        });
        if (kDebugMode) {
          debugPrint('Retrying image with alternative: $_currentUrl');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      key: ValueKey(_currentUrl),
      imageUrl: _currentUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (_, __) =>
          widget.placeholder ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
      errorWidget: (_, __, error) {
        // Log the error and attempt a retry if available; if no more retries,
        // show the configured errorWidget.
        if (kDebugMode) {
          debugPrint('ResolvedImage: failed to load $_currentUrl');
          debugPrint('ResolvedImage: error: $error');
        }
        _onError(error, null);
        // If we've started a retry, return the placeholder while the retry loads.
        final alternatives = _buildAlternatives(widget.url);
        if (_attempt <= alternatives.length) {
          return widget.placeholder ??
              (SizedBox(
                width: widget.width,
                height: widget.height,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ));
        }
        return widget.errorWidget ??
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Center(child: Icon(Icons.broken_image)),
            );
      },
    );
  }
}

/// Unified image resolver for product / order / user images.
/// Rules:
/// * null or empty: show placeholder
/// * absolute http/https: load as network
/// * path starting with `/uploads`: prepend backend base URL
/// * path starting with `assets/`: load as bundled asset
/// * otherwise: treat as relative backend path `baseUrl/<path>`
class ResolvedImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? error;

  const ResolvedImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePath = path?.trim();
    final ph = placeholder ?? _defaultPlaceholder();
    if (effectivePath == null || effectivePath.isEmpty) {
      return _wrap(ph);
    }
    // Absolute network
    if (effectivePath.startsWith('http://') ||
        effectivePath.startsWith('https://')) {
      // Normalize common local-development hosts (emulator loopback / localhost)
      try {
        final uri = Uri.parse(effectivePath);
        final devHosts = {'10.0.2.2', '127.0.0.1', 'localhost'};
        if (devHosts.contains(uri.host)) {
          final base = Uri.parse(AuthService.getBaseUrl());
          // Replace emulator/local host with the configured backend host.
          // IMPORTANT: do NOT preserve the emulator port (e.g. 5001) — use the
          // base URL's port (if any) or none. Preserving the emulator port
          // breaks requests when using a deployed BASE_URL.
          final replaced = uri.replace(
            scheme: base.scheme,
            host: base.host,
            port: base.hasPort ? base.port : null,
          );
          return _wrap(_network(replaced.toString()));
        }
      } catch (_) {
        // fallthrough to normal network loading
      }
      return _wrap(_network(effectivePath));
    }
    // Backend upload path
    if (effectivePath.startsWith('/uploads')) {
      final base = AuthService.getBaseUrl();
      return _wrap(_network('$base$effectivePath'));
    }
    // Asset path
    if (effectivePath.startsWith('assets/')) {
      return _wrap(
        Image.asset(
          effectivePath,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => error ?? _errorPlaceholder(),
        ),
      );
    }
    // Relative server path
    final base = AuthService.getBaseUrl();
    final url = effectivePath.startsWith('/')
        ? '$base$effectivePath'
        : '$base/$effectivePath';
    return _wrap(_network(url));
  }

  Widget _network(String url) {
    // Use a retrying cached image which will try small fallbacks (http<->https
    // and host replacement) when the initial request fails. This helps when
    // devices have different networking policies or DB contains stale URLs.
    return _RetryingCachedImage(
      url: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: SizedBox(
            width: (width ?? 40) * 0.4,
            height: (height ?? 40) * 0.4,
            child: const CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      ),
      errorWidget: error,
    );
  }

  Widget _wrap(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _defaultPlaceholder() => Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: borderRadius,
    ),
    child: const Icon(Icons.image, color: Colors.grey),
  );

  Widget _errorPlaceholder() => Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: borderRadius,
    ),
    child: const Icon(Icons.broken_image, color: Colors.grey),
  );
}
