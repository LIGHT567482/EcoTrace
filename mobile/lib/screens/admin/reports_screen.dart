import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/widgets.dart';
import '../categories_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? summary;
  Map<String, dynamic>? wallet;
  String error = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<Session>().api;
      final s = await api.request('/reports/summary/');
      final w = await api.request('/wallet/stats/');
      setState(() {
        summary = s as Map<String, dynamic>;
        wallet = w as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error.isNotEmpty) return ErrorBanner(message: error);
    final s = summary;
    if (s == null) return const Center(child: CircularProgressIndicator());

    final byStatus = (s['by_status'] as Map<String, dynamic>? ?? {});
    final byRole = (s['users_by_role'] as Map<String, dynamic>? ?? {});
    final categories = (s['categories'] as List<dynamic>? ?? []);
    final carbonSaved =
        (double.tryParse('${s['carbon_saved_kg'] ?? 0}') ?? 0).toStringAsFixed(1);

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Reports & overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.category_outlined),
                tooltip: 'Categories',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _stat('Requests', '${s['total_requests'] ?? 0}'),
              _stat('Items recycled', '${s['recycled_items'] ?? 0}'),
              _stat('Carbon Dioxide avoided', '$carbonSaved kg'),
              _stat('Requests processed', '${s['processed_requests'] ?? 0}'),
              _stat('Reward credits', formatUGX(s['reward_credits_ugx'] ?? 0),
                  amber: true),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Requests by status',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: byStatus.entries
                  .map((e) => ListTile(
                        dense: true,
                        title: StatusChip(status: e.key, label: e.key),
                        trailing: Text('${e.value}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Users by role',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: byRole.entries
                  .map((e) => ListTile(
                        dense: true,
                        title: Text(e.key),
                        trailing: Text('${e.value}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ))
                  .toList(),
            ),
          ),
          if (wallet != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wallet',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                        'Credited: ${formatUGX(wallet!['total_credited'])} · '
                        'Paid out: ${formatUGX(wallet!['total_paid_out'])}',
                        style: const TextStyle(color: kMuted, fontSize: 13)),
                    Text(
                        'Pending redemptions: ${wallet!['pending_redemptions'] ?? 0}',
                        style: const TextStyle(color: kMuted, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Items by category',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: categories
                  .map((c) => ListTile(
                        dense: true,
                        title: Text('${c['name']}'),
                        trailing: Text('${c['qty'] ?? 0} units',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {bool amber = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE7E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(color: kMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: amber ? const Color(0xFFB07800) : kBrandDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
