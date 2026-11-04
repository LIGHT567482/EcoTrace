import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Wallet? wallet;
  String error = '';
  String success = '';
  final points = TextEditingController();
  final destination = TextEditingController();
  String method = 'MOBILE_MONEY';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<Session>().api;
      final data = await api.request('/wallet/');
      setState(() => wallet = Wallet.fromJson(data as Map<String, dynamic>));
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> redeem() async {
    setState(() {
      error = '';
      success = '';
    });
    final w = wallet;
    if (w == null) return;
    final requested = int.tryParse(points.text.trim()) ?? 0;
    if (requested < w.minRedemptionPoints) {
      setState(
        () =>
            error = 'Enter at least ${w.minRedemptionPoints} points to redeem.',
      );
      return;
    }
    if (requested > w.pointsBalance) {
      setState(
        () => error = 'You only have ${w.pointsBalance} points available.',
      );
      return;
    }
    try {
      final api = context.read<Session>().api;
      await api.request(
        '/wallet/redeem/',
        method: 'POST',
        body: {
          'points': requested,
          'destination': destination.text.trim(),
          'method': method,
        },
      );
      setState(() {
        success = 'Redemption requested. Awaiting admin payout.';
        points.clear();
      });
      await load();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = wallet;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Points balance',
                    style: TextStyle(color: kMuted, fontSize: 13),
                  ),
                  Text(
                    '${formatPoints(w?.pointsBalance ?? 0)} pts',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: kBrandDark,
                    ),
                  ),
                  Text(
                    'Worth ${formatUGX(w?.ugxBalance ?? 0)}'
                    '${w != null && w.balance > 0 ? ' · incl. ${formatUGX(w.balance)} wallet funds' : ''}',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                  if (w != null)
                    Text(
                      'Minimum redemption: ${formatPoints(w.minRedemptionPoints)} pts '
                      '(${formatUGX(w.minRedemptionPoints * w.ugxPerPoint)})',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: points,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Points to redeem',
                      helperText: 'Earned from verified disposals',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: destination,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Payout number',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: const [
                      DropdownMenuItem(
                        value: 'MOBILE_MONEY',
                        child: Text('Mobile money'),
                      ),
                      DropdownMenuItem(
                        value: 'AIRTIME',
                        child: Text('Airtime'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => method = v ?? 'MOBILE_MONEY'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: wallet == null ? null : redeem,
                      child: const Text('Request redemption'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Points history',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...(w?.pointTransactions ?? []).map(
            (t) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Icon(
                  t.kind == 'CREDIT'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: t.kind == 'CREDIT' ? kBrand : const Color(0xFFC8452F),
                  size: 20,
                ),
                title: Text(
                  '${formatPoints(t.points)} pts${t.kind == 'CREDIT' ? '' : ' redeemed'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${t.reason}${t.requestReference.isNotEmpty ? '\n${t.requestReference}' : ''}\n${formatDate(t.createdAt)}',
                ),
                isThreeLine: true,
              ),
            ),
          ),
          if ((w?.pointTransactions ?? []).isEmpty &&
              (w?.transactions ?? []).isEmpty)
            const EmptyView(message: 'No transactions yet.'),
          if ((w?.transactions ?? []).isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Wallet funds',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...(w?.transactions ?? []).map(
              (t) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    t.kind == 'CREDIT'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: t.kind == 'CREDIT'
                        ? kBrand
                        : const Color(0xFFC8452F),
                    size: 20,
                  ),
                  title: Text(
                    formatUGX(t.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${t.reason}\n${formatDate(t.createdAt)}'),
                  isThreeLine: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
