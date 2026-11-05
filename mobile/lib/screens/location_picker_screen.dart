import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../core/location.dart';
import '../core/widgets.dart';

/// Interactive map used to drop a pin for a pickup location.
///
/// Returns a [SimpleLocation] via `Navigator.pop` when the user confirms.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? selected;
  bool locating = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      selected = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  Future<void> useMyLocation() async {
    setState(() {
      locating = true;
      error = '';
    });
    final loc = await tryCurrentLocation();
    if (!mounted) return;
    if (loc == null) {
      setState(() {
        locating = false;
        error = 'Could not get your location. Check permissions and try '
            'again, or tap the map to drop a pin.';
      });
      return;
    }
    setState(() {
      selected = LatLng(loc.latitude, loc.longitude);
      locating = false;
    });
  }

  void confirm() {
    final pin = selected;
    if (pin == null) return;
    Navigator.pop(context, SimpleLocation(pin.latitude, pin.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final pin = selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick pickup location')),
      body: Column(
        children: [
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ErrorBanner(message: error),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pin == null
                        ? 'Tap the map to drop a pin, or use your live '
                            'location.'
                        : 'Pinned: ${pin.latitude.toStringAsFixed(5)}, '
                            '${pin.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: locating ? null : useMyLocation,
                  icon: locating
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 16),
                  label: const Text('My location'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: pin ??
                    const LatLng(kKansangaCentreLat, kKansangaCentreLng),
                initialZoom: pin == null ? 14 : 16,
                onTap: (_, point) => setState(() => selected = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecotrace.ecotrace',
                ),
                if (pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pin,
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.location_pin,
                          size: 44,
                          color: Color(0xFFD93A2B),
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: pin == null ? null : confirm,
                  child: const Text('Use this location'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
