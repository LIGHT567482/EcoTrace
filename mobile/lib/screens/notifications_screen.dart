import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import 'request_detail_screen.dart';
import 'requests_list_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final bool showAppBar;
  const NotificationsScreen({super.key, this.showAppBar = true});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> items = [];
  int unread = 0;
  String error = '';
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<Session>().api;
      final data = await api.request('/auth/notifications/');
      if (!mounted) return;
      setState(() {
        unread = data['count'] as int? ?? 0;
        items = (data['results'] as List<dynamic>? ?? [])
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      final api = context.read<Session>().api;
      await api.request(
        '/auth/notifications/${notification.id}/read/',
        method: 'POST',
      );
      if (!mounted) return;
      setState(() {
        unread = unread > 0 ? unread - 1 : 0;
        items = items
            .map(
              (item) => item.id == notification.id
                  ? AppNotification(
                      id: item.id,
                      requestId: item.requestId,
                      title: item.title,
                      body: item.body,
                      isRead: true,
                      createdAt: item.createdAt,
                    )
                  : item,
            )
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> readAll() async {
    setState(() {
      error = '';
      busy = true;
    });
    try {
      final api = context.read<Session>().api;
      await api.request('/auth/notifications/read-all/', method: 'POST');
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteOne(AppNotification notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete notification?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final api = context.read<Session>().api;
      await api.request(
        '/auth/notifications/${notification.id}/',
        method: 'DELETE',
      );
      if (!mounted) return;
      setState(() {
        items = items.where((item) => item.id != notification.id).toList();
        if (!notification.isRead && unread > 0) unread--;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> clearAll() async {
    final api = context.read<Session>().api;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This permanently deletes all your notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      error = '';
      busy = true;
    });
    try {
      await api.request('/auth/notifications/clear/', method: 'DELETE');
      if (!mounted) return;
      setState(() {
        items = [];
        unread = 0;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openRequest(int requestId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(requestId: requestId),
      ),
    );
    if (mounted) load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text('Notifications${unread > 0 ? ' ($unread)' : ''}'),
              actions: [
                TextButton(
                  onPressed: unread > 0 && !busy ? readAll : null,
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear all notifications',
                  onPressed: items.isNotEmpty && !busy ? clearAll : null,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!widget.showAppBar)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: unread > 0 && !busy ? readAll : null,
                            child: const Text('Mark all read'),
                          ),
                          IconButton(
                            tooltip: 'Clear all notifications',
                            onPressed: items.isNotEmpty && !busy
                                ? clearAll
                                : null,
                            icon: const Icon(Icons.delete_sweep_outlined),
                          ),
                        ],
                      ),
                    ),
                  if (error.isNotEmpty) ErrorBanner(message: error),
                  ...items.map(
                    (notification) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        key: PageStorageKey(notification.id),
                        onExpansionChanged: (expanded) {
                          if (expanded) markRead(notification);
                        },
                        leading: Icon(
                          notification.isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active_outlined,
                          color: notification.isRead ? kMuted : kBrand,
                        ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: notification.isRead ? kMuted : kInk,
                          ),
                        ),
                        subtitle: Text(
                          formatDate(notification.createdAt),
                          style: const TextStyle(color: kMuted, fontSize: 11),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              notification.body.isEmpty
                                  ? 'There are no additional details.'
                                  : notification.body,
                              style: const TextStyle(color: kMuted),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (notification.requestId != null)
                                TextButton.icon(
                                  onPressed: () =>
                                      openRequest(notification.requestId!),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('View request details'),
                                ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const RequestsListScreen(scope: 'all'),
                                  ),
                                ),
                                icon: const Icon(Icons.list_alt),
                                label: const Text('View requests'),
                              ),
                              TextButton.icon(
                                onPressed: () => deleteOne(notification),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (items.isEmpty && error.isEmpty)
                    const EmptyView(message: 'No notifications yet.'),
                ],
              ),
            ),
    );
  }
}
