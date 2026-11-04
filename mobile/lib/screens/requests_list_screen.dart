import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import 'request_detail_screen.dart';

class RequestsListScreen extends StatefulWidget {
  final String scope;
  const RequestsListScreen({super.key, this.scope = 'mine'});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  List<CollectionRequest> requests = [];
  bool loading = true;
  String error = '';
  String status = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final api = context.read<Session>().api;
      final params = <String, String>{'page_size': '100'};
      if (status.isNotEmpty) params['status'] = status;
      if (widget.scope == 'available') params['scope'] = 'available';
      if (widget.scope == 'incoming') params['status'] = 'IN_TRANSIT';
      if (widget.scope == 'all') params['status'] = '';
      final query = params.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      final data = await api.request('/requests/list/${query.isEmpty ? '' : '?$query'}');
      final results = (data['results'] as List<dynamic>? ?? [])
          .map((e) => CollectionRequest.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => requests = results);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error.isNotEmpty) ErrorBanner(message: error),
          if (loading && requests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!loading && requests.isEmpty && error.isEmpty)
            const EmptyView(message: 'No requests to show.'),
          ...requests.map((r) => _RequestCard(
                request: r,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(requestId: r.id),
                    ),
                  );
                  load();
                },
              )),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final CollectionRequest request;
  final VoidCallback onTap;

  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.reference,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusChip(status: request.status, label: request.statusLabel),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${request.requestType} · ${request.itemCount} items',
                style: const TextStyle(color: kMuted, fontSize: 13),
              ),
              Text(
                request.pickupAddress.isNotEmpty
                    ? request.pickupAddress
                    : (request.dropoffName ?? ''),
                style: const TextStyle(color: kMuted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                formatDate(request.createdAt),
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
