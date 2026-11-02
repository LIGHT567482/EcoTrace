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
  final amount = TextEditingController();
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
    try {
      final api = context.read<Session>().api;
      await api.request('/wallet/redeem/', method: 'POST', body: {
        'amount': double.tryParse(amount.text) ?? 0,
        'destination': destination.text.trim(),
        'method': method,
      });
      setState(() {
        success = 'Redemption requested. Awaiting admin payout.';
        amount.clear();
      });
      await load();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
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
                const Text('Balance',
                    style: TextStyle(color: kMuted, fontSize: 13)),
                Text(
                  formatUGX(wallet?.balance ?? 0),
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: kBrandDark),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (UGX)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: destination,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Payout number'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: const [
                    DropdownMenuItem(
                        value: 'MOBILE_MONEY', child: Text('Mobile money')),
                    DropdownMenuItem(value: 'AIRTIME', child: Text('Airtime')),
                  ],
                  onChanged: (v) => setState(() => method = v ?? 'MOBILE_MONEY'),
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
        const Text('Transactions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...(wallet?.transactions ?? []).map((t) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Icon(
                  t.kind == 'CREDIT' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: t.kind == 'CREDIT' ? kBrand : const Color(0xFFC8452F),
                  size: 20,
                ),
                title: Text(formatUGX(t.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${t.reason}\n${formatDate(t.createdAt)}'),
                isThreeLine: true,
              ),
            )),
        if ((wallet?.transactions ?? []).isEmpty)
          const EmptyView(message: 'No transactions yet.'),
      ],
    );
  }
}
