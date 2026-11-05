import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/geo.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';

const String kGeneralMapUrl =
    'https://www.google.com/maps?q=Kansanga,+Kampala,+Uganda&z=15&output=embed';

String mapEmbedUrl({double? latitude, double? longitude}) {
  if (latitude == null || longitude == null) return kGeneralMapUrl;
  return 'https://www.google.com/maps?q=$latitude,$longitude&z=16&output=embed';
}

/// Google refuses the embed URL when it is the top-level page, so the
/// WebView loads this shim document which hosts the map in a real iframe.
String mapEmbedHtml(String embedUrl) => '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>html,body{height:100%;width:100%;margin:0;padding:0;background:#fff}iframe{height:100%;width:100%;margin:0;padding:0;border:0;display:block}</style>
</head>
<body><iframe src="$embedUrl" allowfullscreen referrerpolicy="no-referrer-when-downgrade"></iframe></body>
</html>''';

bool mapFrameNavigationAllowed(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  if (uri.scheme == 'about' && uri.host.isEmpty) return true;
  if (uri.scheme != 'https') return false;
  final h = uri.host;
  const suffixes = [
    '.google.com',
    '.google.co.ug',
    '.gstatic.com',
    '.googleapis.com',
    '.googleusercontent.com',
    '.ggpht.com',
  ];
  return h == 'google.com' || suffixes.any((s) => h.endsWith(s));
}

/// Google Maps rendered inside the app. Nothing ever leaves the system.
class MapScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? name;

  const MapScreen({super.key, this.latitude, this.longitude, this.name});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final WebViewController controller;
  List<DropOffPoint> points = [];
  bool pageLoading = true;
  int? selectedIndex;
  String url = kGeneralMapUrl;

  // Directions always start from the Kansanga centre (widget lat/lng is the
  // map's view target, not the user's position).
  double get _originLat => kKansangaCentreLat;
  double get _originLng => kKansangaCentreLng;

  @override
  void initState() {
    super.initState();
    url = kGeneralMapUrl;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => pageLoading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => pageLoading = false);
        },
        onNavigationRequest: (request) {
          return mapFrameNavigationAllowed(request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ))
      ..loadHtmlString(mapEmbedHtml(url),
          baseUrl: 'https://www.google.com');
    loadPoints();
  }

  Future<void> loadPoints() async {
    try {
      final api = context.read<Session>().api;
      final data =
          await api.request('/dropoff-points/?town=Kansanga&page_size=100');
      final list = (data['results'] ?? data) as List<dynamic>;
      final parsed = list
          .map((e) => DropOffPoint.fromJson(e as Map<String, dynamic>))
          .where((p) =>
              p.town.toLowerCase() == 'kansanga' &&
              p.latitude != null &&
              p.longitude != null)
          .toList();
      if (!mounted) return;
      final start = widget.name == null
          ? -1
          : parsed.indexWhere((p) => p.name == widget.name);
      setState(() {
        points = parsed;
        if (start >= 0) selectedIndex = start;
      });
      if (start >= 0) {
        final target = mapEmbedUrl(
            latitude: parsed[start].latitude,
            longitude: parsed[start].longitude);
        if (target != url) {
          controller.loadHtmlString(mapEmbedHtml(target),
              baseUrl: 'https://www.google.com');
        }
      }
    } catch (_) {
      // Map still works without the list.
    }
  }

  void select(int index) {
    final p = points[index];
    final next = mapEmbedUrl(latitude: p.latitude, longitude: p.longitude);
    setState(() {
      selectedIndex = index;
      url = next;
      pageLoading = true;
    });
    controller.loadHtmlString(mapEmbedHtml(next),
        baseUrl: 'https://www.google.com');
  }

  void selectGeneral() {
    setState(() {
      selectedIndex = null;
      url = kGeneralMapUrl;
      pageLoading = true;
    });
    controller.loadHtmlString(mapEmbedHtml(kGeneralMapUrl),
        baseUrl: 'https://www.google.com');
  }

  DropOffPoint? get _selected =>
      selectedIndex == null ? null : points[selectedIndex!];

  Widget _directionsCard() {
    final p = _selected;
    if (p == null) return const SizedBox.shrink();
    final km = haversineKm(
      startLat: _originLat,
      startLng: _originLng,
      endLat: p.latitude!,
      endLng: p.longitude!,
    );
    final deg = bearingDeg(
      startLat: _originLat,
      startLng: _originLng,
      endLat: p.latitude!,
      endLng: p.longitude!,
    );
    final steps = directionsSteps(
      startLat: _originLat,
      startLng: _originLng,
      endLat: p.latitude!,
      endLng: p.longitude!,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Directions to ${p.name}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 4),
              Text(
                '${km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km'}'
                ' · head ${cardinal(deg)} (${deg.round()}°)'
                ' · ${p.address}, ${p.town}',
                style: const TextStyle(color: kMuted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...steps.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('• $s',
                        style: const TextStyle(fontSize: 13.5)),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kansanga map & directions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(
                'Explore Kansanga and its certified drop-off points. The map '
                'is limited to Kansanga.',
                style: TextStyle(color: kMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('General view'),
                  selected: selectedIndex == null,
                  onSelected: (_) => selectGeneral(),
                ),
              ),
              ...points.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value.name),
                      selected: selectedIndex == e.key,
                      onSelected: (_) => select(e.key),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _directionsCard(),
        if (pageLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: WebViewWidget(controller: controller),
        ),
      ],
    );
  }
}
