import 'package:flutter/material.dart';

/// Lightweight placeholder for MapPicker while flutter_map dependency is being
/// stabilized. This prevents build-time errors on devices where flutter_map
/// APIs or versions differ. Replace with the full implementation when ready.
class MapPickerPage extends StatelessWidget {
  const MapPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick location')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 72, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Map picker is temporarily disabled',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'To enable the interactive map, reconcile flutter_map and other map-related dependencies. You can still select locations manually in forms.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
