import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/geo.dart';
import '../core/location.dart';
import '../core/widgets.dart';
import 'map_screen.dart';

/// In-app walking directions to a pickup or drop-off point.
///
/// Steps are computed locally from geo.dart and the map is rendered in an
/// embedded WebView — nothing is handed off to an external navigation app.
class DirectionsScreen extends StatefulWidget {
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationLabel;

  const DirectionsScreen({
    super.key,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationLabel,
  });

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  late final WebViewController controller;
  SimpleLocation? origin;
  bool locating = true;
  bool pageLoading = true;

  @override
  void initState() {
    super.initState();
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
        onNavigationRequest: (request) =>
            mapFrameNavigationAllowed(request.url)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
      ))
      ..loadHtmlString(
        mapEmbedHtml(mapEmbedUrl(
          latitude: widget.destinationLatitude,
          longitude: widget.destinationLongitude,
        )),
        baseUrl: 'https://www.google.com',
      );
    _locate();
  }

  Future<void> _locate() async {
    final loc = await tryCurrentLocation();
    if (!mounted) return;
    setState(() {
      origin = loc;
      locating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = origin;
    final km = haversineKm(
      startLat: start?.latitude ?? kKansangaCentreLat,
      startLng: start?.longitude ?? kKansangaCentreLng,
      endLat: widget.destinationLatitude,
      endLng: widget.destinationLongitude,
    );
    final deg = bearingDeg(
      startLat: start?.latitude ?? kKansangaCentreLat,
      startLng: start?.longitude ?? kKansangaCentreLng,
      endLat: widget.destinationLatitude,
      endLng: widget.destinationLongitude,
    );
    final steps = directionsSteps(
      startLat: start?.latitude ?? kKansangaCentreLat,
      startLng: start?.longitude ?? kKansangaCentreLng,
      endLat: widget.destinationLatitude,
      endLng: widget.destinationLongitude,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Directions to ${widget.destinationLabel}')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (locating) const LinearProgressIndicator(minHeight: 2),
          if (start == null && !locating)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'Location unavailable - directions start from the Kansanga '
                'centre. Enable location for exact steps.',
                style: TextStyle(color: kMuted, fontSize: 12.5),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Walking directions',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km'}'
                      ' · head ${cardinal(deg)} (${deg.round()}°)'
                      '${start == null ? ' · from Kansanga centre' : ' · from your location'}',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    ...steps.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('• $s', style: const TextStyle(fontSize: 13.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (pageLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: WebViewWidget(controller: controller),
          ),
        ],
      ),
    );
  }
}
