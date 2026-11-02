import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';

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
  String error = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final api = context.read<Session>().api;
    try {
      final itemData = await api.request('/items/');
      final dropData = await api.request('/dropoff-points/');
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
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  double get reward => items
      .where((i) => selected.contains(i.id))
      .fold(0, (s, i) => s + (double.tryParse(i.rewardUgx) ?? 0));

  Future<void> submit() async {
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
      await api.request('/requests/', method: 'POST', body: body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted - track it under Requests.')),
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
          const Text('1 · Choose items',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          ...items.map((it) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected.contains(it.id),
                title: Text('${it.typeName} × ${it.quantity}'),
                subtitle: Text(
                    '${it.categoryName} · ${formatUGX(it.rewardUgx)}'),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selected.add(it.id);
                  } else {
                    selected.remove(it.id);
                  }
                }),
              )),
          if (items.isEmpty)
            const EmptyView(message: 'No items logged yet - add some first.'),
          const SizedBox(height: 12),
          const Text('2 · Collection details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
          if (pickupMode)
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Pickup address'),
            )
          else
            DropdownButtonFormField<DropOffPoint>(
              initialValue: dropoff,
              decoration: const InputDecoration(labelText: 'Drop-off point'),
              items: dropoffs
                  .map((d) => DropdownMenuItem(
                      value: d, child: Text('${d.name} - ${d.address}')))
                  .toList(),
              onChanged: (d) => setState(() => dropoff = d),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(
                labelText: 'Note for the collector (optional)'),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selected.length} item row(s) · reward ${formatUGX(reward)} '
                    'after verified disposal',
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
