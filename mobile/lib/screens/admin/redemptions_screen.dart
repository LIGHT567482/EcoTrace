import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

class RedemptionsScreen extends StatefulWidget {
  const RedemptionsScreen({super.key});

  @override
  State<RedemptionsScreen> createState() => _RedemptionsScreenState();
}

class _RedemptionsScreenState extends State<RedemptionsScreen> {
  List<Redemption> items = [];
  String error = '';
  String success = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<Session>().api;
      final data = await api.request('/redemptions/');
      final list = (data['results'] ?? data) as List<dynamic>;
      setState(() => items = list
          .map((e) => Redemption.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> decide(int id, String action) async {
    setState(() {
      error = '';
      success = '';
    });
    try {
      final api = context.read<Session>().api;
      await api.request('/redemptions/$id/$action/', method: 'POST', body: {
        if (action == 'reject') 'reason': 'Payout could not be made',
      });
      setState(() => success = 'Redemption $action done.');
      await load();
    } catch (e) {
      setState(() => error = e.toString());
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
          const Text('Redemptions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Approve payouts or reject and refund them.',
              style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 12),
          if (error.isNotEmpty) ErrorBanner(message: error),
          if (success.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD8F3E3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(success, style: const TextStyle(color: kBrandDark)),
            ),
          ...items.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatUGX(r.amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                          StatusChip(
                            status: r.status == 'PAID'
                                ? 'PROCESSED'
                                : r.status == 'REJECTED'
                                    ? 'CANCELLED'
                                    : 'PENDING',
                            label: r.status,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.userName} · ${r.method} → ${r.destination}',
                        style: const TextStyle(color: kMuted, fontSize: 13),
                      ),
                      Text(formatDate(r.createdAt),
                          style: const TextStyle(color: kMuted, fontSize: 12)),
                      if (r.status == 'PENDING')
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () => decide(r.id, 'approve'),
                              child: const Text('Mark paid'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => decide(r.id, 'reject'),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              )),
          if (items.isEmpty && error.isEmpty)
            const EmptyView(message: 'No redemption requests.'),
        ],
      ),
    );
  }
}
