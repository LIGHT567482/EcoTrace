import 'package:geolocator/geolocator.dart';

/// A plain lat/lng pair, kept dependency-free for use across screens.
class SimpleLocation {
  final double latitude;
  final double longitude;

  const SimpleLocation(this.latitude, this.longitude);
}

/// Best-effort current position.
///
/// Returns null when location services are off, permission is denied, or the
/// fix times out — callers fall back to their own default origin/destination.
Future<SimpleLocation?> tryCurrentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    ).timeout(const Duration(seconds: 12));
    return SimpleLocation(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}
