import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import 'directions_screen.dart';

class RequestDetailScreen extends StatefulWidget {
  final int requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  CollectionRequest? request;
  String error = '';
  String note = '';
  String verificationCode = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<Session>().api;
      // Temp (offline-queued) rows live only in the local list cache.
      if (widget.requestId < 0) {
        final cached = await api.offline.getCached('/requests/list/');
        final results = (cached is Map && cached['results'] is List)
            ? cached['results'] as List
            : const [];
        for (final row in results) {
          if (row is Map<String, dynamic> && row['id'] == widget.requestId) {
            setState(() => request = CollectionRequest.fromJson(row));
            return;
          }
        }
        setState(() => error = 'This request is queued offline.');
        return;
      }
      final data = await api.request('/requests/${widget.requestId}/');
      setState(
        () =>
            request = CollectionRequest.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> act(String path, [Map<String, dynamic>? body]) async {
    const confirmations = <String, (String, String, String)>{
      'cancel': (
        'Cancel request?',
        'This cannot be undone.',
        'Cancel request',
      ),
      'reject': (
        'Reject consignment?',
        'Nothing will be credited for it.',
        'Reject',
      ),
      'release': (
        'Release pickup?',
        'The assignment will be removed.',
        'Release',
      ),
    };
    final confirmation = confirmations[path];
    if (confirmation != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(confirmation.$1),
          content: Text(confirmation.$2),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmation.$3),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final api = context.read<Session>().api;
      final res = await api.request(
        '/requests/${widget.requestId}/$path/',
        method: 'POST',
        body: body ?? {},
      );
      if (res is Map && res['_offline'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved offline — will apply when you reconnect.'),
            ),
          );
        }
        // Locally reflect the status change in the cached list row.
        await _patchCachedStatus(path, body);
      }
      await load();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _patchCachedStatus(
    String path,
    Map<String, dynamic>? body,
  ) async {
    final api = context.read<Session>().api;
    final cached = await api.offline.getCached('/requests/list/');
    if (cached is! Map<String, dynamic>) return;
    final results = cached['results'];
    if (results is! List) return;
    for (final row in results) {
      if (row is! Map<String, dynamic>) continue;
      if (row['id'] != widget.requestId) continue;
      if (path == 'cancel') {
        row['status'] = 'CANCELLED';
        row['status_label'] = 'Cancelled';
      } else if (path == 'transition' && body?['status'] is String) {
        row['status'] = body!['status'];
        row['status_label'] = body['status'];
      } else if (path == 'claim') {
        row['status'] = 'ASSIGNED';
        row['status_label'] = 'Assigned';
      } else if (path == 'receive') {
        row['status'] = 'RECEIVED';
        row['status_label'] = 'Received at facility';
      } else if (path == 'process') {
        row['status'] = 'PROCESSED';
        row['status_label'] = 'Processed';
      } else if (path == 'reject') {
        row['status'] = 'REJECTED';
        row['status_label'] = 'Rejected';
      }
      // Optimistic event for the timeline.
      final events = row['events'];
      if (events is List) {
        events.insert(0, {
          'id': -DateTime.now().millisecondsSinceEpoch,
          'status': row['status'],
          'note': body?['note'] ?? body?['reason'] ?? '',
          'created_at': DateTime.now().toIso8601String(),
          '_pending': true,
        });
      }
    }
    await api.offline.cacheGet('/requests/list/', cached);
    // Mirror status onto the in-memory model so the UI refreshes.
    final results2 = cached['results'];
    if (results2 is List) {
      for (final row in results2) {
        if (row is Map<String, dynamic> && row['id'] == widget.requestId) {
          request = CollectionRequest.fromJson(row);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user!;
    final r = request;

    return Scaffold(
      appBar: AppBar(title: Text(r?.reference ?? 'Request')),
      body: r == null
          ? Center(
              child: error.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(error, textAlign: TextAlign.center),
                    )
                  : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (error.isNotEmpty) ErrorBanner(message: error),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              StatusChip(
                                status: r.status,
                                label: r.statusLabel,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                r.requestType,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Consumer: ${r.consumerName}',
                            style: const TextStyle(color: kMuted),
                          ),
                          Text(
                            'Collector: ${r.collectorName ?? 'unassigned'}',
                            style: const TextStyle(color: kMuted),
                          ),
                          if (r.requestType == 'PICKUP')
                            Text(
                              'Pickup proof: ${r.pickupConfirmed ? 'confirmed by consumer' : 'awaiting consumer confirmation'}'
                              '${r.pickupConfirmedAt != null ? ' · ${formatDate(r.pickupConfirmedAt!)}' : ''}',
                              style: const TextStyle(color: kMuted),
                            ),
                          if (user.isConsumer &&
                              user.id == r.consumerId &&
                              r.requestType == 'PICKUP' &&
                              r.status == 'ASSIGNED')
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Your one-time pickup code is in Notifications. Share it with the collector at handoff.',
                                style: TextStyle(color: kMuted, fontSize: 13),
                              ),
                            ),
                          if (r.pickupAddress.isNotEmpty)
                            Text(
                              'Address: ${r.pickupAddress}',
                              style: const TextStyle(color: kMuted),
                            ),
                          if (r.dropoffName != null)
                            Text(
                              'Drop-off: ${r.dropoffName}',
                              style: const TextStyle(color: kMuted),
                            ),
                          Text(
                            'Estimated Carbon Dioxide avoided: ~${r.carbonKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(color: kMuted),
                          ),
                          if (r.hazardousCount > 0)
                            Text(
                              'Hazardous units: ${r.hazardousCount} (specialised handling)',
                              style: const TextStyle(
                                color: Color(0xFF9B2F1C),
                                fontSize: 13,
                              ),
                            ),
                          if (r.rewardCredited)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD8F3E3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${formatPoints(r.pointsEarned)} points credited to the consumer wallet.',
                                style: const TextStyle(color: kBrandDark),
                              ),
                            ),
                          if (r.certificate != null)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD8F3E3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Certificate ${r.certificate!.code} · '
                                '${r.certificate!.summary}'
                                '${r.certificate!.carbonKg > 0 ? ' · ~${r.certificate!.carbonKg.toStringAsFixed(1)} kg Carbon Dioxide equivalent avoided' : ''}',
                                style: const TextStyle(color: kBrandDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Items',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...r.items.map(
                            (it) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${it.typeName} × ${it.quantity}'
                                      '${it.hazardous ? ' · Hazardous' : ''}'
                                      ' · ~${it.carbonKg.toStringAsFixed(1)} kg Carbon Dioxide equivalent',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    formatUGX(it.rewardUgx),
                                    style: const TextStyle(
                                      color: kMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Timeline',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...r.events.map(
                            (e) => Container(
                              margin: const EdgeInsets.only(
                                left: 6,
                                bottom: 10,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: kBrand, width: 3),
                                ),
                              ),
                              padding: const EdgeInsets.only(left: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.status,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (e.note.isNotEmpty)
                                    Text(
                                      e.note,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  Text(
                                    '${formatDate(e.createdAt)}'
                                    '${e.actorName != null ? ' · ${e.actorName}' : ''}',
                                    style: const TextStyle(
                                      color: kMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._actions(user, r),
                ],
              ),
            ),
    );
  }

  List<Widget> _actions(AppUser user, CollectionRequest r) {
    final widgets = <Widget>[];
    // Server actions that submit a note/reason (navigation does not).
    var hasNoteAction = false;
    // The server reports the assigned collector by id, so nameless accounts
    // (phone-only registration) still see their own actions.
    final assignedToMe = r.assignedCollectorId != null
        ? r.assignedCollectorId == user.id
        : r.events.any(
            (e) =>
                e.status == 'ASSIGNED' &&
                (e.actorId == user.id ||
                    e.actorName ==
                        (user.fullName.isNotEmpty
                            ? user.fullName
                            : user.phone)),
          );

    // In-app walking directions: pickup pin for pickups, the certified
    // facility coordinates for drop-offs. Never leaves the app.
    final dest = r.requestType == 'DROPOFF'
        ? (r.dropoffLatitude != null && r.dropoffLongitude != null
            ? (
                r.dropoffLatitude!,
                r.dropoffLongitude!,
                r.dropoffName ?? 'drop-off point',
              )
            : null)
        : (r.latitude != null && r.longitude != null
            ? (r.latitude!, r.longitude!, 'pickup')
            : null);
    if (user.isCollector &&
        dest != null &&
        ['PENDING', 'ASSIGNED', 'COLLECTED', 'IN_TRANSIT'].contains(r.status)) {
      widgets.add(
        _actionButton(
          'Walking directions',
          Icons.directions_walk,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DirectionsScreen(
                destinationLatitude: dest.$1,
                destinationLongitude: dest.$2,
                destinationLabel: dest.$3,
              ),
            ),
          ),
          outlined: true,
        ),
      );
    }

    if (user.isConsumer && ['PENDING', 'ASSIGNED'].contains(r.status)) {
      hasNoteAction = true;
      widgets.add(
        _actionButton(
          'Cancel request',
          Icons.cancel_outlined,
          () => act('cancel'),
          danger: true,
        ),
      );
    }
    if (user.isCollector && r.status == 'PENDING') {
      hasNoteAction = true;
      widgets.add(
        _actionButton('Claim pickup', Icons.add_task, () => act('claim')),
      );
    }
    if (user.isCollector && r.status == 'ASSIGNED' && assignedToMe) {
      hasNoteAction = true;
      final needsCode = r.requestType == 'PICKUP' && user.isCollector;
      if (needsCode) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pickup verification code',
                helperText: 'The code the consumer shares at hand-over',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              maxLength: 8,
              onChanged: (v) => verificationCode = v.trim(),
            ),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ElevatedButton(
            onPressed: busy || (needsCode && verificationCode.length != 8)
                ? null
                : () => act('transition', {
                    'status': 'COLLECTED',
                    'note': note,
                    if (needsCode) 'verification_code': verificationCode,
                  }),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 18),
                SizedBox(width: 8),
                Flexible(child: Text('Mark collected')),
              ],
            ),
          ),
        ),
      );
      widgets.add(
        _actionButton(
          'Release',
          Icons.undo,
          () => act('release'),
          outlined: true,
        ),
      );
    }
    if (user.isCollector && r.status == 'COLLECTED' && assignedToMe) {
      hasNoteAction = true;
      widgets.add(
        _actionButton(
          'Send to facility',
          Icons.local_shipping_outlined,
          () => act('transition', {'status': 'IN_TRANSIT', 'note': note}),
        ),
      );
    }
    if ((user.isRecycler || user.isAdmin) && r.status == 'IN_TRANSIT') {
      hasNoteAction = true;
      widgets.add(
        _actionButton(
          'Record receipt',
          Icons.assignment_turned_in,
          () => act('receive', {
            'items_received': r.itemCount,
            'method': 'RECYCLING',
            'notes': note,
          }),
        ),
      );
    }
    if ((user.isRecycler || user.isAdmin) && r.status == 'RECEIVED') {
      hasNoteAction = true;
      widgets.add(
        _actionButton(
          'Verify disposal & credit reward',
          Icons.verified_outlined,
          () => act('process', {'method': 'RECYCLING', 'notes': note}),
        ),
      );
      widgets.add(
        _actionButton(
          'Reject consignment',
          Icons.block,
          () => act('reject', {'reason': note}),
          danger: true,
        ),
      );
    }

    if (hasNoteAction && (user.isCollector || user.isRecycler)) {
      widgets.insert(
        0,
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Note / reason (optional)',
            ),
            onChanged: (v) => note = v,
          ),
        ),
      );
    }
    if (widgets.isEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'No actions available for your role.',
            style: TextStyle(color: kMuted),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool danger = false,
    bool outlined = false,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(label)),
      ],
    );
    final onPressedSafe = busy ? null : onPressed;
    if (danger) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC8452F),
          ),
          onPressed: onPressedSafe,
          child: child,
        ),
      );
    }
    if (outlined) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton(onPressed: onPressedSafe, child: child),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(onPressed: onPressedSafe, child: child),
    );
  }
}
