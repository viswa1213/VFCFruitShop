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
  late final List<String> _attemptUrls;
  int _attemptIndex = 0;
  bool _retryScheduled = false;
  // Maximum number of fallback attempts (not counting the initial try).
  static const int _maxFallbacks = 2; // try original + up to 2 alternates

  @override
  void initState() {
    super.initState();
    // Build the list of candidate URLs once to keep retry behavior stable.
    final alternatives = _buildAlternatives(widget.url);
    _attemptUrls = [widget.url, ...alternatives];
    if (_attemptUrls.length > _maxFallbacks + 1) {
      _attemptUrls = _attemptUrls.sublist(0, _maxFallbacks + 1);
    }
    _currentUrl = _attemptUrls[_attemptIndex];
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
    // If there are more candidate URLs, schedule a retry with exponential
    // backoff. Prevent duplicate scheduling while a retry is pending.
    if (_attemptIndex < _attemptUrls.length - 1 && !_retryScheduled) {
      _retryScheduled = true;
      final nextIndex = _attemptIndex + 1;
      // exponential backoff base (ms)
      final baseDelay = 200;
      final backoff = baseDelay * (1 << _attemptIndex);
      final delay = Duration(milliseconds: backoff.clamp(200, 1600));

      if (kDebugMode) {
        debugPrint(
        'ResolvedImage: scheduling retry #$nextIndex in ${delay.inMilliseconds}ms -> ${_attemptUrls[nextIndex]}');
      }

      Future.delayed(delay, () {
        if (!mounted) return;
        // Use addPostFrameCallback to avoid setState during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _attemptIndex = nextIndex;
            _currentUrl = _attemptUrls[_attemptIndex];
            _retryScheduled = false;
          });
        });
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
        // Only log the error in debug; schedule a retry if candidates remain.
        if (kDebugMode) {
          debugPrint('ResolvedImage: failed to load $_currentUrl');
          debugPrint('ResolvedImage: error: $error');
        }
        _onError(error, null);

        // If a retry is scheduled or remaining attempts exist, show placeholder
        // while waiting. When final attempt fails, show the configured error
        // widget (or a default broken-image icon).
        if (_attemptIndex < _attemptUrls.length - 1 || _retryScheduled) {
          return widget.placeholder ??
              (SizedBox(
                width: widget.width,
                height: widget.height,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ));
        }

        // Final failure: reduce log noise by only emitting a single message.
        if (kDebugMode) {
          debugPrint('ResolvedImage: all retries exhausted for ${widget.url}');
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
