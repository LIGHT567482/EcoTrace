import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import 'admin/redemptions_screen.dart';
import 'admin/reports_screen.dart';
import 'admin/users_screen.dart';
import 'dropoffs_screen.dart';
import 'items_screen.dart';
import 'map_screen.dart';
import 'notifications_screen.dart';
import 'requests_list_screen.dart';
import 'wallet_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user!;
    final tabs = _tabsFor(user.role);
    final destinations = tabs
        .map((t) => NavigationDestination(icon: t.icon, label: t.label))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/bg.png',
              width: 64,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'EcoTrace · ${user.role[0]}${user.role.substring(1).toLowerCase()}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () => setState(() => index = 0),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: IndexedStack(index: index, children: tabs.map((t) => t.screen).toList()),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: destinations,
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final session = context.read<Session>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await session.logout();
  }

  List<_Tab> _tabsFor(String role) {
    switch (role) {
      case 'COLLECTOR':
        return [
          _Tab('Home', const Icon(Icons.home_outlined),
              const RequestsListScreen(scope: 'mine')),
          _Tab('Available', const Icon(Icons.search),
              const RequestsListScreen(scope: 'available')),
          _Tab('Activity', const Icon(Icons.timeline),
              const RequestsListScreen(scope: 'all')),
          _Tab('Map', const Icon(Icons.map_outlined), const MapScreen()),
        ];
      case 'RECYCLER':
        return [
          _Tab('Home', const Icon(Icons.home_outlined),
              const RequestsListScreen(scope: 'incoming')),
          _Tab('All tracked', const Icon(Icons.recycling_outlined),
              const RequestsListScreen(scope: 'all')),
          _Tab('Map', const Icon(Icons.map_outlined), const MapScreen()),
        ];
      case 'ADMIN':
        return [
          _Tab('Home', const Icon(Icons.home_outlined), const ReportsScreen()),
          _Tab('Requests', const Icon(Icons.list_alt), const RequestsListScreen(scope: 'all')),
          _Tab('Users', const Icon(Icons.people_outline), const UsersScreen()),
          _Tab('Payouts', const Icon(Icons.payments_outlined), const RedemptionsScreen()),
          _Tab('Map', const Icon(Icons.map_outlined), const MapScreen()),
        ];
      default:
        return [
          _Tab('Home', const Icon(Icons.home_outlined), const RequestsListScreen(scope: 'mine')),
          _Tab('Log items', const Icon(Icons.add_box_outlined), const ItemsScreen()),
          _Tab('Wallet', const Icon(Icons.account_balance_wallet_outlined), const WalletScreen()),
          _Tab('Drop-offs', const Icon(Icons.place_outlined), const DropOffsScreen()),
          _Tab('Map', const Icon(Icons.map_outlined), const MapScreen()),
        ];
    }
  }
}

class _Tab {
  final String label;
  final Icon icon;
  final Widget screen;
  const _Tab(this.label, this.icon, this.screen);
}
