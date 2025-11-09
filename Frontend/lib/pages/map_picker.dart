import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  LatLng? _picked;
  LatLng _initial = LatLng(12.9716, 77.5946); // Bengaluru fallback
  bool _loading = true;
  String? _error;
  String? _pickedAddress;
  LatLng? _current; // current device location (for circle)
  double? _accuracyMeters;
  double _zoom = 14;
  bool _isRecentering = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
    // If location takes long, hint user to enable location and try the FAB.
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      if (_loading && _error == null) {
        setState(() {
          _error =
              'Fetching your location is taking longer than expected. Ensure location is ON, grant permission, or tap the my-location button.';
        });
      }
    });
  }

  Future<void> _initLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _error =
              'Location services are OFF. Enable GPS to use your current location.';
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied';
          _loading = false;
        });
        return;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (_) {
        try {
          // Try with lower accuracy as a fallback (faster on some devices)
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 12),
          );
        } catch (_) {
          // Try last known as a final fallback
          pos = await Geolocator.getLastKnownPosition();
        }
      }
      if (pos != null) {
        final here = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _initial = here;
          _current = here;
          _picked = here; // preselect current for quick confirm
          _accuracyMeters = pos!.accuracy;
        });
        _mapController.move(here, 16);
        _reverseGeocode(here);
      } else {
        setState(() {
          _error =
              'Could not get your location. You can tap the my-location button or select on the map.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize location: $e';
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _centerOnMyLocation() async {
    try {
      if (_isRecentering) return;
      setState(() => _isRecentering = true);
      final ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) {
        setState(() => _error = 'Enable location services to center map');
        return;
      }
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _picked = here;
        _current = here;
        _accuracyMeters = pos.accuracy;
        _pickedAddress = null;
      });
      _mapController.move(here, 17);
      _reverseGeocode(here);
    } catch (e) {
      setState(() => _error = 'Failed to get location: $e');
    } finally {
      if (mounted) setState(() => _isRecentering = false);
    }
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    try {
      final marks = await geocoding.placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (marks.isNotEmpty) {
        final p = marks.first;
        final line = [
          p.street,
          p.subLocality,
          p.locality,
        ].where((e) => (e ?? '').toString().isNotEmpty).join(', ');
        if (mounted) setState(() => _pickedAddress = line);
      }
    } catch (_) {
      // ignore failures; checkout will also reverse geocode after pop
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick location'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Builder(
          builder: (context) {
            final primary = Theme.of(context).colorScheme.primary;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, Color.lerp(primary, Colors.white, 0.2)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initial,
                initialZoom: 14,
                onMapEvent: (event) {
                  // Track zoom to scale accuracy circle
                  final z = _mapController.camera.zoom;
                  if (z != _zoom && mounted) setState(() => _zoom = z);
                },
                onTap: (tapPos, latLng) {
                  setState(() {
                    _picked = latLng;
                    _pickedAddress = null;
                  });
                  _reverseGeocode(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'fruit_shop',
                ),
                if (_current != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _current!,
                        color: const Color(0x332196F3),
                        borderStrokeWidth: 2,
                        borderColor: const Color(0x552196F3),
                        radius: _accuracyCircleRadiusPx(),
                      ),
                    ],
                  ),
                if (_current != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _current!,
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _picked!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.place,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_pickedAddress != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pickedAddress!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.05),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_error != null && !_loading)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: Colors.red,
                            onPressed: () => setState(() => _error = null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _openLocationSettings,
                            icon: const Icon(Icons.location_on_outlined),
                            label: const Text('Open Location Settings'),
                          ),
                          TextButton.icon(
                            onPressed: _openAppSettings,
                            icon: const Icon(Icons.app_settings_alt_outlined),
                            label: const Text('Open App Settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: ElevatedButton.icon(
              onPressed: _picked == null
                  ? null
                  : () => Navigator.pop(context, {
                      'lat': _picked!.latitude,
                      'lng': _picked!.longitude,
                    }),
              icon: const Icon(Icons.check),
              label: const Text('Use this location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Center on my location button
          Positioned(
            right: 16,
            bottom: 90,
            child: FloatingActionButton(
              mini: true,
              onPressed: _isRecentering ? null : _centerOnMyLocation,
              backgroundColor: Colors.white,
              child: _isRecentering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.my_location,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  double _accuracyCircleRadiusPx() {
    if (_accuracyMeters == null || _current == null) return 20;
    final metersPerPixel =
        156543.03392 *
        math.cos(_current!.latitude * math.pi / 180) /
        math.pow(2, _zoom);
    final px = _accuracyMeters! / metersPerPixel;
    // Clamp to sensible range
    return px.clamp(12, 120).toDouble();
  }
}
