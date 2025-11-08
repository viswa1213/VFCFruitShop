import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _picked;
  LatLng _initial = const LatLng(12.9716, 77.5946); // Bengaluru as fallback

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _initial = LatLng(pos.latitude, pos.longitude);
      });
      final ctrl = await _controller.future;
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(_initial, 16));
    } catch (_) {}
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
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _initial, zoom: 14),
            onMapCreated: (c) => _controller.complete(c),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: (latLng) => setState(() => _picked = latLng),
            markers: {
              if (_picked != null)
                Marker(markerId: const MarkerId('picked'), position: _picked!),
            },
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
        ],
      ),
    );
  }
}
