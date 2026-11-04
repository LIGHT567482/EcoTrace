import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache + offline mutation queue.
///
/// GETs are cached on every successful response and served when offline.
/// Mutations that fail due to network are queued and flushed automatically
/// when connectivity returns so actions in the app reflect on the server.
class OfflineStore extends ChangeNotifier {
  static const _cachePrefix = 'cache:';
  static const _queueKey = 'offline_queue';

  SharedPreferences? _prefs;
  bool _online = true;
  bool _syncing = false;
  int _pendingCount = 0;

  bool get online => _online;
  bool get syncing => _syncing;
  int get pendingCount => _pendingCount;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _pendingCount = (_prefs?.getStringList(_queueKey) ?? []).length;
    notifyListeners();
  }

  void setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    notifyListeners();
  }

  // ── GET cache ──────────────────────────────────────────────

  Future<void> cacheGet(String path, dynamic data) async {
    if (_prefs == null || data == null) return;
    await _prefs!.setString(
      '$_cachePrefix$path',
      jsonEncode({'at': DateTime.now().toIso8601String(), 'data': data}),
    );
  }

  Future<dynamic> getCached(String path) async {
    final raw = _prefs?.getString('$_cachePrefix$path');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> invalidatePrefix(String prefix) async {
    final prefs = _prefs;
    if (prefs == null) return;
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('$_cachePrefix$prefix')) {
        await prefs.remove(key);
      }
    }
  }

  // ── Mutation queue ─────────────────────────────────────────

  /// Queue a mutation that could not reach the network.
  /// Returns a temp id (negative) for creates so UI can show the row.
  Future<int> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final prefs = _prefs;
    if (prefs == null) return 0;

    final id = 'm_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}';
    final tempId = -DateTime.now().microsecondsSinceEpoch.remainder(1000000);
    final entry = {
      'id': id,
      'method': method,
      'path': path,
      'body': body,
      'temp_id': tempId,
      'at': DateTime.now().toIso8601String(),
    };

    final list = prefs.getStringList(_queueKey) ?? [];
    list.add(jsonEncode(entry));
    await prefs.setStringList(_queueKey, list);
    _pendingCount = list.length;

    // Optimistic local cache update for creates so lists show the row offline.
    if (method == 'POST') {
      await _optimisticCreate(path, body, tempId);
    } else if (method == 'DELETE') {
      await _optimisticDelete(path);
    }

    notifyListeners();
    return tempId;
  }

  Future<void> _optimisticCreate(
    String path,
    Map<String, dynamic>? body,
    int tempId,
  ) async {
    // Map API list path → cache key used by the screens.
    final listPath = _listPathFor(path);
    if (listPath == null) return;
    final cached = await getCached(listPath);
    if (cached is! Map<String, dynamic>) return;
    final results = cached['results'];
    if (results is! List) return;

    final row = <String, dynamic>{
      ...?body,
      'id': tempId,
      '_pending': true,
      'created_at': DateTime.now().toIso8601String(),
    };
    // Common denormalised fields the UI expects.
    row.putIfAbsent('type_name', () => '');
    row.putIfAbsent('category_name', () => '');
    row.putIfAbsent('reward_ugx', () => 0);
    row.putIfAbsent('condition', () => body?['condition'] ?? 'BROKEN');
    row.putIfAbsent('quantity', () => body?['quantity'] ?? 1);
    row.putIfAbsent('notes', () => body?['notes'] ?? '');
    row.putIfAbsent('reference', () => 'LOCAL-${tempId.abs()}');
    row.putIfAbsent('status', () => 'PENDING');
    row.putIfAbsent('status_label', () => 'Pending (offline)');
    row.putIfAbsent('request_type', () => body?['request_type'] ?? 'PICKUP');
    row.putIfAbsent('item_count', () => (body?['item_ids'] as List?)?.length ?? 0);
    row.putIfAbsent('items', () => <dynamic>[]);
    row.putIfAbsent('events', () => <dynamic>[]);
    row.putIfAbsent('pickup_address', () => body?['pickup_address'] ?? '');
    row.putIfAbsent('consumer_name', () => '');
    row.putIfAbsent('reward_credited', () => false);

    results.insert(0, row);
    await cacheGet(listPath, cached);
  }

  Future<void> _optimisticDelete(String path) async {
    // DELETE /items/123/ → remove from cached /items/
    final m = RegExp(r'^/(\w[\w-]*)/(\d+)/?$').firstMatch(path);
    if (m == null) return;
    final listPath = '/${m.group(1)}/';
    final id = int.tryParse(m.group(2) ?? '');
    if (id == null) return;
    final cached = await getCached(listPath);
    if (cached is! Map<String, dynamic>) return;
    final results = cached['results'];
    if (results is! List) return;
    results.removeWhere((e) => e is Map && e['id'] == id);
    await cacheGet(listPath, cached);
  }

  String? _listPathFor(String path) {
    if (path.startsWith('/items')) return '/items/';
    if (path.startsWith('/requests')) return '/requests/list/';
    if (path.startsWith('/categories')) return '/categories/';
    if (path.startsWith('/dropoff')) return '/dropoff-points/';
    if (path.startsWith('/item-types')) return '/categories/';
    return null;
  }

  Future<List<Map<String, dynamic>>> pendingMutations() async {
    final list = _prefs?.getStringList(_queueKey) ?? [];
    return list
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  Future<void> removeMutation(String id) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final list = prefs.getStringList(_queueKey) ?? [];
    list.removeWhere((raw) {
      try {
        return (jsonDecode(raw) as Map<String, dynamic>)['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_queueKey, list);
    _pendingCount = list.length;
    notifyListeners();
  }

  Future<void> setSyncing(bool value) async {
    _syncing = value;
    notifyListeners();
  }
}

/// Thrown when a read fails offline and no cache exists.
class OfflineException implements Exception {
  final String message;
  OfflineException([this.message = 'You are offline. Showing saved data only.']);
  @override
  String toString() => message;
}
