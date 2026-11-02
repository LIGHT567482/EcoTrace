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
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<Session>().api;
      final data = await api.request('/dropoff-points/?town=Kansanga');
      final list = (data['results'] ?? data) as List<dynamic>;
      setState(() => points = list
          .map((e) => DropOffPoint.fromJson(e as Map<String, dynamic>))
          .where((p) => p.town.toLowerCase() == 'kansanga')
          .toList());
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Kansanga drop-off points',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
              'Certified locations in Kansanga where you can hand over e-waste.',
              style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 12),
          if (error.isNotEmpty) ErrorBanner(message: error),
          ...points.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${p.address} · ${p.town}',
                          style: const TextStyle(
                              color: kMuted, fontSize: 13)),
                      if (p.openingHours.isNotEmpty)
                        Text('Hours: ${p.openingHours}',
                            style: const TextStyle(
                                color: kMuted, fontSize: 13)),
                      if (p.phone.isNotEmpty)
                        Text('Phone: ${p.phone}',
                            style: const TextStyle(
                                color: kMuted, fontSize: 13)),
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
                    ],
                  ),
                ),
              )),
          if (points.isEmpty && error.isEmpty)
            const EmptyView(message: 'No drop-off points listed yet.'),
        ],
      ),
    );
  }
}
