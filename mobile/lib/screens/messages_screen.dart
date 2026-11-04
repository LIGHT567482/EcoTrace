import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../core/widgets.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final message = TextEditingController();
  List<Map<String, dynamic>> contacts = [];
  List<Map<String, dynamic>> messages = [];
  int? contactId;
  String error = '';
  bool loading = true;
  bool sending = false;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    loadContacts();
    refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final id = contactId;
      if (id != null) loadMessages(id);
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    message.dispose();
    super.dispose();
  }

  Future<void> loadContacts() async {
    try {
      final api = context.read<Session>().api;
      final response =
          await api.request('/messages/contacts/') as List<dynamic>;
      if (!mounted) return;
      final nextContacts = response.cast<Map<String, dynamic>>();
      final nextId = nextContacts.any((contact) => contact['id'] == contactId)
          ? contactId
          : (nextContacts.isEmpty ? null : nextContacts.first['id'] as int);
      setState(() {
        contacts = nextContacts;
        contactId = nextId;
        error = '';
      });
      if (nextId != null) await loadMessages(nextId);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadMessages(int id) async {
    try {
      final api = context.read<Session>().api;
      final response =
          await api.request('/messages/?with=$id') as Map<String, dynamic>;
      if (!mounted || contactId != id) return;
      setState(() {
        messages = (response['results'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        error = '';
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> send() async {
    final id = contactId;
    final text = message.text.trim();
    if (id == null || text.isEmpty || sending) return;
    setState(() {
      sending = true;
      error = '';
    });
    try {
      final api = context.read<Session>().api;
      await api.request(
        '/messages/',
        method: 'POST',
        body: {'recipient_id': id, 'body': text},
      );
      message.clear();
      await loadMessages(id);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<Session>().user?.id;
    final selected = contacts.where((contact) => contact['id'] == contactId);
    final selectedName = selected.isEmpty
        ? 'No eligible stakeholder'
        : '${selected.first['full_name'] ?? selected.first['phone']} · ${selected.first['role']}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stakeholder messages'),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: loadContacts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ErrorBanner(message: error),
                  ),
                if (contacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: DropdownButtonFormField<int>(
                      initialValue: contactId,
                      decoration: const InputDecoration(labelText: 'Recipient'),
                      items: contacts
                          .map(
                            (contact) => DropdownMenuItem(
                              value: contact['id'] as int,
                              child: Text(
                                '${contact['full_name'] ?? contact['phone']} · ${contact['role']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        setState(() {
                          contactId = id;
                          messages = [];
                        });
                        loadMessages(id);
                      },
                    ),
                  ),
                if (contacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        selectedName,
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                    ),
                  ),
                Expanded(
                  child: contacts.isEmpty
                      ? const EmptyView(
                          message:
                              'No eligible stakeholders in your message chain.',
                        )
                      : RefreshIndicator(
                          onRefresh: () => loadMessages(contactId!),
                          child: messages.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    EmptyView(
                                      message: 'No messages with this stakeholder yet.',
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final item = messages[index];
                                    final outgoing = item['sender'] == userId;
                                    return Align(
                                      alignment: outgoing
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.sizeOf(context).width *
                                              .82,
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: outgoing
                                              ? const Color(0xFFE4F5EC)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(color: kLine),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('${item['body'] ?? ''}'),
                                            const SizedBox(height: 4),
                                            Text(
                                              formatDate(
                                                '${item['created_at'] ?? ''}',
                                              ),
                                              style: const TextStyle(
                                                color: kMuted,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: message,
                            maxLength: 2000,
                            minLines: 1,
                            maxLines: 4,
                            enabled: contacts.isNotEmpty && !sending,
                            decoration: const InputDecoration(
                              labelText: 'Message',
                              counterText: '',
                            ),
                            onSubmitted: (_) => send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send message',
                          onPressed: contacts.isNotEmpty && !sending
                              ? send
                              : null,
                          icon: sending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
