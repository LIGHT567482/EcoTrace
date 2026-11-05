import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/location.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import 'location_picker_screen.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  List<EwasteItem> items = [];
  List<DropOffPoint> dropoffs = [];
  final Set<int> selected = {};
  bool pickupMode = true;
  final address = TextEditingController();
  final note = TextEditingController();
  DropOffPoint? dropoff;
  double? latitude;
  double? longitude;
  String error = '';
  bool busy = false;
  int pickupPointsPercent = 50;
  int dropoffPointsPercent = 100;

  @override
  void initState() {
    super.initState();
    // Prefill from the profile so the pickup address is never blank.
    final saved = context.read<Session>().user?.address ?? '';
    if (saved.isNotEmpty) address.text = saved;
    load();
  }

  Future<void> load() async {
    final api = context.read<Session>().api;
    try {
      final itemData = await api.request('/items/?page_size=100');
      final dropData = await api.request('/dropoff-points/?page_size=100');
      final policy = await api.request('/wallet/policy/');
      final its = (itemData['results'] ?? itemData) as List<dynamic>;
      final dps = (dropData['results'] ?? dropData) as List<dynamic>;
      setState(() {
        items = its
            .map((e) => EwasteItem.fromJson(e as Map<String, dynamic>))
            .toList();
        dropoffs = dps
            .map((e) => DropOffPoint.fromJson(e as Map<String, dynamic>))
            .toList();
        dropoff ??= dropoffs.isNotEmpty ? dropoffs.first : null;
        pickupPointsPercent = policy['pickup_points_percent'] as int? ?? 50;
        dropoffPointsPercent = policy['dropoff_points_percent'] as int? ?? 100;
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  int get reward => items
      .where((i) => selected.contains(i.id))
      .fold(0, (s, i) => s + i.points);

  int get pointsEstimate =>
      (reward * (pickupMode ? pickupPointsPercent : dropoffPointsPercent) / 100)
          .round();

  Future<void> useMyLocation() async {
    setState(() => error = '');
    final loc = await tryCurrentLocation();
    if (!mounted) return;
    if (loc == null) {
      setState(
        () => error =
            'Could not get your location. Check permissions, or pick the '
            'spot on the map instead.',
      );
      return;
    }
    setState(() {
      latitude = loc.latitude;
      longitude = loc.longitude;
    });
  }

  Future<void> pickOnMap() async {
    final result = await Navigator.push<SimpleLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: latitude,
          initialLongitude: longitude,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      latitude = result.latitude;
      longitude = result.longitude;
    });
  }

  void clearPin() => setState(() {
        latitude = null;
        longitude = null;
      });

  Future<void> submit() async {
    final hasPin = latitude != null && longitude != null;
    if (pickupMode && address.text.trim().isEmpty && !hasPin) {
      setState(
        () => error =
            'Enter the pickup address or drop a map pin so the collector '
            'can find you.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final api = context.read<Session>().api;
      final body = <String, dynamic>{
        'request_type': pickupMode ? 'PICKUP' : 'DROPOFF',
        'item_ids': selected.toList(),
        'pickup_address': address.text,
        'consumer_note': note.text,
      };
      if (!pickupMode && dropoff != null) body['dropoff_point'] = dropoff!.id;
      if (hasPin) {
        body['latitude'] = latitude;
        body['longitude'] = longitude;
      }
      await api.request('/requests/', method: 'POST', body: body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted - track it under Requests.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New collection request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error.isNotEmpty) ErrorBanner(message: error),
          const Text(
            '1 · Choose items',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (it) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: selected.contains(it.id),
              title: Text('${it.typeName} × ${it.quantity}'),
              subtitle: Text(
                '${it.categoryName} · ${formatPoints(it.points)} base pts',
              ),
              onChanged: (v) => setState(() {
                if (v == true) {
                  selected.add(it.id);
                } else {
                  selected.remove(it.id);
                }
              }),
            ),
          ),
          if (items.isEmpty)
            const EmptyView(message: 'No items logged yet - add some first.'),
          const SizedBox(height: 12),
          const Text(
            '2 · Collection details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Pickup')),
              ButtonSegment(value: false, label: Text('Drop-off')),
            ],
            selected: {pickupMode},
            onSelectionChanged: (s) => setState(() => pickupMode = s.first),
          ),
          const SizedBox(height: 12),
          if (pickupMode) ...[
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Pickup address'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: useMyLocation,
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text('My location'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pickOnMap,
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Pick on map'),
                  ),
                ),
              ],
            ),
            if (latitude != null && longitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InputChip(
                  avatar: const Icon(Icons.location_pin, size: 16),
                  label: Text(
                    'Pinned ${latitude!.toStringAsFixed(5)}, '
                    '${longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: clearPin,
                ),
              ),
          ] else
            DropdownButtonFormField<DropOffPoint>(
              initialValue: dropoff,
              decoration: const InputDecoration(labelText: 'Drop-off point'),
              items: dropoffs
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text('${d.name} - ${d.address}'),
                    ),
                  )
                  .toList(),
              onChanged: (d) => setState(() => dropoff = d),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(
              labelText: 'Note for the collector (optional)',
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selected.length} item row(s) · about ${formatPoints(pointsEstimate)} points '
                    'after verified processing',
                    style: const TextStyle(fontSize: 13, color: kMuted),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: busy || selected.isEmpty ? null : submit,
                      child: Text(busy ? 'Submitting…' : 'Submit request'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
