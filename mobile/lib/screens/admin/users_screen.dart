import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/widgets.dart';

class _AdminUser {
  final int id;
  final String phone;
  final String fullName;
  final String role;
  final String town;
  final bool isActive;

  const _AdminUser({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
    required this.town,
    required this.isActive,
  });

  factory _AdminUser.fromJson(Map<String, dynamic> json) => _AdminUser(
        id: json['id'] as int? ?? 0,
        phone: json['phone'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        role: json['role'] as String? ?? '',
        town: json['town'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

/// "14:32" for an ISO-8601 timestamp, or "" when it cannot be parsed.
String _clock(dynamic iso) {
  final t = DateTime.tryParse(iso?.toString() ?? '');
  if (t == null) return '';
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}';
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<_AdminUser> users = [];
  List<Map<String, dynamic>> resets = [];
  String error = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final api = context.read<Session>().api;
    try {
      final data = await api.request('/users/?page_size=100');
      final list = (data['results'] ?? data) as List<dynamic>;
      setState(() => users = list
          .map((e) => _AdminUser.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (e) {
      setState(() => error = e.toString());
    }
    try {
      final data =
          await api.request('/auth/password-reset/requests/') as List<dynamic>;
      setState(() => resets = data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList());
    } catch (_) {
      // Codes are a convenience — never break the user list over them.
    }
  }

  Future<void> toggle(int id) async {
    try {
      final api = context.read<Session>().api;
      await api.request('/users/$id/toggle-active/', method: 'POST');
      await load();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> createDialog() async {
    final phone = TextEditingController();
    final name = TextEditingController();
    final password = TextEditingController();
    final town = TextEditingController(text: 'Kansanga');
    String role = 'CONSUMER';
    bool obscurePassword = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create user'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (ctx, setDialog) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'CONSUMER', child: Text('Consumer')),
                    DropdownMenuItem(
                        value: 'COLLECTOR', child: Text('Collector')),
                    DropdownMenuItem(
                        value: 'RECYCLER', child: Text('Recycler')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Administrator')),
                  ],
                  onChanged: (v) => setDialog(() => role = v ?? 'CONSUMER'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: town,
                  decoration: const InputDecoration(labelText: 'Town'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: password,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      tooltip: obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () => setDialog(
                          () => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (created != true) return;
    if (!mounted) return;
    try {
      final api = context.read<Session>().api;
      await api.request('/users/', method: 'POST', body: {
        'phone': phone.text.trim(),
        'password': password.text,
        'full_name': name.text.trim(),
        'role': role,
        'town': town.text.trim(),
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
        Row(
          children: [
            const Expanded(
              child: Text('Users',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Create'),
              onPressed: createDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (error.isNotEmpty) ErrorBanner(message: error),
        if (resets.isNotEmpty) ...[
          const Text('Password reset requests',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Read the code aloud to the account owner — it expires 15 '
            'minutes after it was requested.',
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...resets.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: Text('${r['code']}'),
                  subtitle: Text(
                    '${r['user']} · ${r['phone']}\n'
                    'Expires at ${_clock(r['expires_at'])}',
                  ),
                  isThreeLine: true,
                ),
              )),
          const SizedBox(height: 8),
        ],
        ...users.map((u) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(u.fullName.isNotEmpty ? u.fullName : u.phone),
                subtitle: Text('${u.phone} · ${u.role} · ${u.town}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(
                      status: u.isActive ? 'PROCESSED' : 'CANCELLED',
                      label: u.isActive ? 'Active' : 'Disabled',
                    ),
                    IconButton(
                      icon: Icon(
                        u.isActive ? Icons.block : Icons.check_circle_outline,
                        size: 20,
                      ),
                      tooltip: u.isActive ? 'Disable' : 'Enable',
                      onPressed: () => toggle(u.id),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
