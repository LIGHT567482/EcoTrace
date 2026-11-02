import 'dart:math' as math;

/// Approximate centre of Kansanga, used when no explicit origin is given.
const double kKansangaCentreLat = 0.3236;
const double kKansangaCentreLng = 32.5866;

const double _earthKm = 6371;

double haversineKm({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
}) {
  double toRad(double d) => d * math.pi / 180;
  final dLat = toRad(endLat - startLat);
  final dLng = toRad(endLng - startLng);
  final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(startLat)) *
          math.cos(toRad(endLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _earthKm * math.asin(math.sqrt(s));
}

double bearingDeg({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
}) {
  double toRad(double d) => d * math.pi / 180;
  final dLng = toRad(endLng - startLng);
  final y = math.sin(dLng) * math.cos(toRad(endLat));
  final x = math.cos(toRad(startLat)) * math.sin(toRad(endLat)) -
      math.sin(toRad(startLat)) * math.cos(toRad(endLat)) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

const List<String> kCardinals = [
  'north', 'north-east', 'east', 'south-east',
  'south', 'south-west', 'west', 'north-west',
];

String cardinal(double deg) => kCardinals[(deg / 45).round() % 8];

/// Turn-by-turn guidance computed inside the app (no external routing calls).
List<String> directionsSteps({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
}) {
  final km = haversineKm(
    startLat: startLat, startLng: startLng, endLat: endLat, endLng: endLng,
  );
  final deg = bearingDeg(
    startLat: startLat, startLng: startLng, endLat: endLat, endLng: endLng,
  );
  final dir = cardinal(deg);
  return [
    'Head $dir from your position (bearing ${deg.round()}°).',
    if (km < 0.1)
      'The drop-off point is essentially here - look for the collection bay.'
    else if (km < 1)
      'Continue for about ${(km * 1000).round()} m; roughly '
          '${math.max(1, (km * 12).round())} min on foot.'
    else
      'Follow the road $dir for about ${km.toStringAsFixed(1)} km '
          '(${(km * 12).round()} min on foot or a short boda ride).',
    'Hand your e-waste to the certified attendant and record the drop-off in EcoTrace.',
  ];
}
