import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> categories = [];
  String error = '';
  Category? category;
  final name = TextEditingController();
  final pointsPerItem = TextEditingController(text: '1000');

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<Session>().api;
      final data = await api.request('/categories/?page_size=100');
      final list = ((data['results'] ?? data) as List<dynamic>)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        categories = list;
        category ??= list.isNotEmpty ? list.first : null;
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> add() async {
    if (category == null || name.text.trim().isEmpty) return;
    try {
      final api = context.read<Session>().api;
      await api.request(
        '/item-types/',
        method: 'POST',
        body: {
          'category': category!.id,
          'name': name.text.trim(),
          'points_per_item': int.tryParse(pointsPerItem.text) ?? 0,
        },
      );
      name.clear();
      await load();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> toggle(ItemType t) async {
    if (t.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Disable item type?'),
          content: Text(
            '${t.name} will stop earning rewards until re-enabled.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    try {
      final api = context.read<Session>().api;
      await api.request(
        '/item-types/${t.id}/',
        method: 'PATCH',
        body: {'is_active': !t.isActive},
      );
      await load();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories & item types')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error.isNotEmpty) ErrorBanner(message: error),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<Category>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)),
                        )
                        .toList(),
                    onChanged: (c) => setState(() => category = c),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Type name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pointsPerItem,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Points per item',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: add,
                      child: const Text('Add item type'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...categories.map(
            (c) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...c.types.map(
                      (t) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.name),
                        subtitle: Text(
                          '${formatPoints(t.pointsPerItem)} pts / item',
                        ),
                        trailing: TextButton(
                          onPressed: () => toggle(t),
                          child: Text(t.isActive ? 'Disable' : 'Enable'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
