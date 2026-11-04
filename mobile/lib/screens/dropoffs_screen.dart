import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import 'map_screen.dart';

class DropOffsScreen extends StatefulWidget {
  const DropOffsScreen({super.key});

  @override
  State<DropOffsScreen> createState() => _DropOffsScreenState();
}

class _DropOffsScreenState extends State<DropOffsScreen> {
  List<DropOffPoint> points = [];
  String error = '';
  String success = '';
  int? busyPointId;
  bool loading = true;
  String town = 'Kansanga';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<Session>().api;
      final user = context.read<Session>().user;
      final requestedTown = user?.isCollector == true ? user!.town : 'Kansanga';
      final data = await api.request(
        '/dropoff-points/?town=${Uri.encodeQueryComponent(requestedTown)}&page_size=100',
      );
      final list = (data['results'] ?? data) as List<dynamic>;
      setState(
        () => points = list
            .map((e) => DropOffPoint.fromJson(e as Map<String, dynamic>))
            .where((p) => p.town.toLowerCase() == requestedTown.toLowerCase())
            .toList(),
      );
      town = requestedTown;
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> notifyRecyclers(DropOffPoint point) async {
    setState(() {
      error = '';
      success = '';
      busyPointId = point.id;
    });
    try {
      final api = context.read<Session>().api;
      final result = await api.request(
        '/dropoff-points/${point.id}/capacity-alert/',
        method: 'POST',
        body: {},
      ) as Map<String, dynamic>;
      if (!mounted) return;
      final count = result['notified'] as int? ?? 0;
      setState(() => success = '$count recycler(s) notified.');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busyPointId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user;
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$town drop-off points',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Certified locations where e-waste can be handed over.',
            style: TextStyle(color: kMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (error.isNotEmpty) ErrorBanner(message: error),
          if (success.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(success, style: const TextStyle(color: kBrandDark)),
            ),
          ...points.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${p.address} · ${p.town}',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                    if (p.openingHours.isNotEmpty)
                      Text(
                        'Hours: ${p.openingHours}',
                        style: const TextStyle(color: kMuted, fontSize: 13),
                      ),
                    if (p.phone.isNotEmpty)
                      Text(
                        'Phone: ${p.phone}',
                        style: const TextStyle(color: kMuted, fontSize: 13),
                      ),
                    if (p.latitude != null && p.longitude != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Open in map'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(p.name)),
                                body: MapScreen(
                                  latitude: p.latitude,
                                  longitude: p.longitude,
                                  name: p.name,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (user?.isCollector == true) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: busyPointId == p.id
                              ? null
                              : () => notifyRecyclers(p),
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: Text(
                            busyPointId == p.id
                                ? 'Sending alert…'
                                : 'Notify recyclers: point is full',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (points.isEmpty && error.isEmpty)
            const EmptyView(message: 'No drop-off points listed yet.'),
        ],
      ),
    );
  }
}
