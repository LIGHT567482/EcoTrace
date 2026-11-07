import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../core/widgets.dart';
import 'admin/redemptions_screen.dart';
import 'admin/reports_screen.dart';
import 'admin/users_screen.dart';
import 'dropoffs_screen.dart';
import 'home_placeholder.dart';
import 'items_screen.dart';
import 'map_screen.dart';
import 'messages_screen.dart';
import 'new_request_screen.dart';
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
  String? utilityPage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Re-pull server state every 45s so web/admin changes appear live.
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      final session = context.read<Session>();
      session.offline; // touch for rebuild via notifyListeners
      // Trigger a light connectivity check + queued flush.
      session.api.ping().then((ok) {
        if (ok && session.offline.pendingCount > 0) {
          session.api.syncNow();
        }
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user!;
    final offline = session.offline;
    final tabs = _tabsFor(user.role);
    final destinations = tabs
        .map((t) => NavigationDestination(icon: t.icon, label: t.label))
        .toList();

    return PopScope(
      canPop: utilityPage == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && utilityPage != null) {
          setState(() => utilityPage = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: utilityPage == null
              ? null
              : IconButton(
                  tooltip: 'Back to home',
                  onPressed: () => setState(() => utilityPage = null),
                  icon: const Icon(Icons.arrow_back),
                ),
          title: utilityPage == null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 36,
                      height: 36,
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
                )
              : Text(utilityPage == 'messages' ? 'Messages' : 'Notifications'),
          actions: [
            if (utilityPage == null) ...[
              if (offline.pendingCount > 0 || !offline.online)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: offline.online
                            ? const Color(0xFFE0F0FF)
                            : const Color(0xFFFFF4E0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        offline.online
                            ? '${offline.pendingCount} pending'
                            : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: offline.online
                              ? const Color(0xFF14497F)
                              : const Color(0xFF7A5600),
                        ),
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Sync now',
                onPressed: () async {
                  final s = context.read<Session>();
                  await s.api.syncNow();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          s.offline.online
                              ? 'Synced with server'
                              : 'Still offline — changes stay queued',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                  if (mounted) setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () => setState(() => utilityPage = 'notifications'),
              ),
              IconButton(
                icon: const Icon(Icons.forum_outlined),
                tooltip: 'Messages',
                onPressed: () => setState(() => utilityPage = 'messages'),
              ),
            ],
            PopupMenuButton<String>(
              tooltip: 'Account options',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'logout') _confirmLogout(context);
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: SizedBox(
                    width: 190,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName.isNotEmpty ? user.fullName : user.phone,
                          style: const TextStyle(
                            color: kInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(user.phone, style: const TextStyle(color: kMuted)),
                        Text(
                          '${user.role} · ${user.town}',
                          style: const TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout),
                    title: Text('Sign out'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            OfflineBanner(
              online: offline.online,
              pending: offline.pendingCount,
              syncing: offline.syncing,
            ),
            Expanded(
              child: switch (utilityPage) {
                'messages' => const MessagesScreen(showAppBar: false),
                'notifications' => const NotificationsScreen(showAppBar: false),
                _ => IndexedStack(
                  index: index,
                  children: tabs.map((t) => t.screen).toList(),
                ),
              },
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() {
            index = i;
            utilityPage = null;
          }),
          destinations: destinations,
        ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await session.logout();
  }

  List<_Tab> _tabsFor(String role) {
    switch (role) {
      case 'COLLECTOR':
        return [
          _Tab(
            'Home',
            const Icon(Icons.home_outlined),
            RequestsListScreen(
              scope: 'mine',
              placeholder: HomePlaceholder(
                title: 'Welcome to EcoTrace',
                subtitle:
                    'Claim nearby pickup jobs, confirm the hand-off with the '
                    'consumer’s one-time code, and deliver them to a '
                    'certified facility.',
                actions: [
                  PlaceholderAction(
                    label: 'Browse available',
                    icon: Icons.search,
                    onTap: () => setState(() => index = 1),
                  ),
                  PlaceholderAction(
                    label: 'Map',
                    icon: Icons.map_outlined,
                    onTap: () => setState(() => index = 4),
                  ),
                ],
              ),
            ),
          ),
          _Tab(
            'Available',
            const Icon(Icons.search),
            const RequestsListScreen(scope: 'available'),
          ),
          _Tab(
            'Activity',
            const Icon(Icons.timeline),
            const RequestsListScreen(scope: 'all'),
          ),
          _Tab(
            'Drop-offs',
            const Icon(Icons.place_outlined),
            const DropOffsScreen(),
          ),
          _Tab('Map', const Icon(Icons.map_outlined), const MapScreen()),
        ];
      case 'RECYCLER':
        return [
          _Tab(
            'Home',
            const Icon(Icons.home_outlined),
            RequestsListScreen(
              scope: 'incoming',
              placeholder: HomePlaceholder(
                title: 'No incoming shipments',
                subtitle:
                    'Consignments on their way to you appear here. Record '
                    'receipt, verify the contents and process them to release '
                    'consumer rewards.',
                actions: [
                  PlaceholderAction(
                    label: 'All tracked',
                    icon: Icons.recycling_outlined,
                    onTap: () => setState(() => index = 1),
                  ),
                  PlaceholderAction(
                    label: 'Map',
                    icon: Icons.map_outlined,
                    onTap: () => setState(() => index = 2),
                  ),
                ],
              ),
            ),
          ),
          _Tab(
            'All tracked',
            const Icon(Icons.recycling_outlined),
            const RequestsListScreen(scope: 'all'),
          ),
          _Tab('Map', const Icon(Icons.map_outlined), const MapScreen()),
        ];
      case 'ADMIN':
        return [
          _Tab('Home', const Icon(Icons.home_outlined), const ReportsScreen()),
          _Tab(
            'Requests',
            const Icon(Icons.list_alt),
            const RequestsListScreen(scope: 'all'),
          ),
          _Tab('Users', const Icon(Icons.people_outline), const UsersScreen()),
          _Tab(
            'Payouts',
            const Icon(Icons.payments_outlined),
            const RedemptionsScreen(),
          ),
          _Tab('Map', const Icon(Icons.map_outlined), const MapScreen()),
        ];
      default:
        return [
          _Tab(
            'Home',
            const Icon(Icons.home_outlined),
            RequestsListScreen(
              scope: 'mine',
              placeholder: HomePlaceholder(
                title: 'Welcome to EcoTrace',
                subtitle:
                    'Your old gadgets aren’t garbage — log what you '
                    'have, request a pickup or drop it off, and earn rewards '
                    'once it’s recycled.',
                actions: [
                  PlaceholderAction(
                    label: 'Log items',
                    icon: Icons.add_box_outlined,
                    onTap: () => setState(() => index = 1),
                  ),
                  PlaceholderAction(
                    label: 'Request pickup',
                    icon: Icons.local_shipping_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NewRequestScreen(),
                      ),
                    ),
                  ),
                  PlaceholderAction(
                    label: 'Map',
                    icon: Icons.map_outlined,
                    onTap: () => setState(() => index = 4),
                  ),
                ],
              ),
            ),
          ),
          _Tab(
            'Log items',
            const Icon(Icons.add_box_outlined),
            const ItemsScreen(),
          ),
          _Tab(
            'Wallet',
            const Icon(Icons.account_balance_wallet_outlined),
            const WalletScreen(),
          ),
          _Tab(
            'Drop-offs',
            const Icon(Icons.place_outlined),
            const DropOffsScreen(),
          ),
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
