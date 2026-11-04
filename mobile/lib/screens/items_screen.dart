import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import 'new_request_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  List<Category> categories = [];
  List<EwasteItem> items = [];
  Category? category;
  ItemType? itemType;
  String condition = 'BROKEN';
  final quantity = TextEditingController(text: '1');
  final notes = TextEditingController();
  String error = '';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final api = context.read<Session>().api;
    try {
      final catData = await api.request('/categories/?page_size=100');
      final cats = ((catData['results'] ?? catData) as List<dynamic>)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .map(
            (c) => Category(
              id: c.id,
              name: c.name,
              types: c.types.where((t) => t.isActive).toList(),
            ),
          )
          .where((c) => c.types.isNotEmpty)
          .toList();
      final itemData = await api.request('/items/?page_size=100');
      final its = (itemData['results'] ?? itemData) as List<dynamic>;
      setState(() {
        categories = cats;
        items = its
            .map((e) => EwasteItem.fromJson(e as Map<String, dynamic>))
            .toList();
        category ??= cats.isNotEmpty ? cats.first : null;
        itemType ??= category?.types.firstOrNull;
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> add() async {
    if (itemType == null) return;
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final api = context.read<Session>().api;
      await api.request(
        '/items/',
        method: 'POST',
        body: {
          'item_type': itemType!.id,
          'quantity': int.tryParse(quantity.text) ?? 1,
          'condition': condition,
          'notes': notes.text,
        },
      );
      notes.clear();
      await load();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove(int id) async {
    try {
      final api = context.read<Session>().api;
      await api.request('/items/$id/', method: 'DELETE');
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
              child: Text(
                'Log your e-waste',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewRequestScreen()),
              ).then((_) => load()),
              child: const Text('Request pickup'),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                        (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (c) => setState(() {
                    category = c;
                    itemType = c?.types.firstOrNull;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ItemType>(
                  initialValue: itemType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: (category?.types ?? [])
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            '${t.name} · ${formatPoints(t.pointsPerItem)} pts/item',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (t) => setState(() => itemType = t),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: condition,
                        decoration: const InputDecoration(
                          labelText: 'Condition',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'WORKING',
                            child: Text('Working'),
                          ),
                          DropdownMenuItem(
                            value: 'BROKEN',
                            child: Text('Broken'),
                          ),
                          DropdownMenuItem(
                            value: 'DAMAGED',
                            child: Text('Damaged'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => condition = v ?? 'BROKEN'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : add,
                    child: Text(saving ? 'Saving…' : 'Add item'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your logged items',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (it) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('${it.typeName} × ${it.quantity}'),
              subtitle: Text('${it.categoryName} · ${it.condition}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${formatPoints(it.points)} pts',
                    style: const TextStyle(fontSize: 12, color: kBrandDark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => remove(it.id),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (items.isEmpty) const EmptyView(message: 'Nothing logged yet.'),
      ],
    );
  }
}
