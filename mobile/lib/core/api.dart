import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'offline.dart';

class Api {
  /// Production Render API — falls back to emulator host for local dev.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://ecotrace-api-sr9f.onrender.com/api',
  );

  String? _access;
  String? _refresh;
  SharedPreferences? _prefs;
  final OfflineStore offline = OfflineStore();

  bool _flushing = false;
  Timer? _syncTimer;
  final _syncDone = StreamController<void>.broadcast();

  /// Fires after each successful background sync flush.
  Stream<void> get onSynced => _syncDone.stream;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _access = _prefs?.getString('access');
    _refresh = _prefs?.getString('refresh');
    await offline.init();

    // Kick off an immediate flush of anything queued while last offline.
    unawaited(syncNow());
    // Periodic safety-net flush every 30s while app is alive.
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncDone.close();
  }

  bool get hasToken => _access != null;

  Future<void> saveTokens(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    await _prefs?.setString('access', access);
    await _prefs?.setString('refresh', refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _prefs?.remove('access');
    await _prefs?.remove('refresh');
    await _prefs?.remove('user');
  }

  Future<bool> _tryRefresh() async {
    if (_refresh == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refresh}),
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await saveTokens(data['access'] as String, data['refresh'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True when the device can reach the API right now.
  Future<bool> ping() async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/health/'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      offline.setOnline(ok);
      return ok;
    } catch (_) {
      offline.setOnline(false);
      return false;
    }
  }

  /// Flush queued offline mutations to the server, then refresh caches.
  Future<void> syncNow() async {
    if (_flushing) return;
    final pending = await offline.pendingMutations();
    if (pending.isEmpty) {
      // Still worth checking connectivity for the offline badge.
      await ping();
      return;
    }

    _flushing = true;
    await offline.setSyncing(true);
    try {
      // Connectivity probe first — skip flush if still offline.
      if (!await ping()) return;

      for (final m in List.of(pending)) {
        final id = m['id'] as String;
        final method = m['method'] as String;
        final path = m['path'] as String;
        final body = m['body'] as Map<String, dynamic>?;
        try {
          await _sendRaw(path, method: method, body: body);
          await offline.removeMutation(id);
        } on ApiException catch (e) {
          // Auth failures: retry after refresh once; else drop poison pills
          // that the server permanently rejects (4xx other than 401/408).
          if (e.status == 401) {
            if (await _tryRefresh()) {
              try {
                await _sendRaw(path, method: method, body: body);
                await offline.removeMutation(id);
              } on ApiException catch (e2) {
                if (e2.status >= 400 && e2.status < 500 && e2.status != 401) {
                  await offline.removeMutation(id);
                }
              }
            } else {
              break; // logged out — stop flushing
            }
          } else if (e.status >= 400 && e.status < 500 && e.status != 408) {
            await offline.removeMutation(id); // permanently rejected
          }
        } on SocketException {
          break; // went offline mid-flush
        } on TimeoutException {
          break;
        } catch (_) {
          // leave in queue for next attempt
          break;
        }
      }

      // Pull fresh server state so web dashboard actions appear here too.
      await offline.invalidatePrefix('/');
      _syncDone.add(null);
    } finally {
      _flushing = false;
      await offline.setSyncing(false);
    }
  }

  /// Main request entry used by every screen.
  ///
  /// * GET  → network first (cache on success), cache fallback when offline.
  /// * POST/PUT/PATCH/DELETE → network first; on network failure the call is
  ///   queued and an optimistic success is returned so the UI keeps working.
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final upper = method.toUpperCase();
    if (upper == 'GET') {
      return _get(path, auth: auth);
    }
    return _mutate(path, method: upper, body: body, auth: auth);
  }

  Future<dynamic> _get(String path, {required bool auth}) async {
    try {
      final data = await _sendRaw(path, method: 'GET', auth: auth);
      offline.setOnline(true);
      await offline.cacheGet(path, data);
      // Successful network hit → opportunistic flush of anything queued.
      if (offline.pendingCount > 0) unawaited(syncNow());
      return data;
    } on SocketException {
      offline.setOnline(false);
    } on TimeoutException {
      offline.setOnline(false);
    } on http.ClientException {
      offline.setOnline(false);
    } on ApiException catch (e) {
      if (e.status == 0) {
        offline.setOnline(false);
      } else {
        rethrow; // real HTTP error (403/404/…) — not a connectivity issue
      }
    }

    // Offline path: serve cache.
    final cached = await offline.getCached(path);
    if (cached != null) return cached;
    throw OfflineException();
  }

  Future<dynamic> _mutate(
    String path, {
    required String method,
    Map<String, dynamic>? body,
    required bool auth,
  }) async {
    try {
      final data = await _sendRaw(path, method: method, body: body, auth: auth);
      offline.setOnline(true);
      // Drop stale cache for the affected collection so next GET is fresh.
      await offline.invalidatePrefix(_listPathFor(path));
      if (offline.pendingCount > 0) unawaited(syncNow());
      return data;
    } on SocketException {
      offline.setOnline(false);
    } on TimeoutException {
      offline.setOnline(false);
    } on http.ClientException {
      offline.setOnline(false);
    } on ApiException catch (e) {
      if (e.status != 0) rethrow;
      offline.setOnline(false);
    }

    // Offline → queue for automatic sync when connectivity returns.
    final tempId = await offline.enqueue(
      method: method,
      path: path,
      body: body,
    );
    return {
      '_offline': true,
      '_queued': true,
      'id': tempId,
      'detail': 'Saved offline. Will sync automatically.',
      ...?body,
    };
  }

  String _listPathFor(String path) {
    if (path.startsWith('/items')) return '/items';
    if (path.startsWith('/requests')) return '/requests';
    if (path.startsWith('/categories') || path.startsWith('/item-types')) {
      return '/categories';
    }
    if (path.startsWith('/dropoff')) return '/dropoff';
    if (path.startsWith('/wallet')) return '/wallet';
    if (path.startsWith('/users')) return '/users';
    if (path.startsWith('/redemptions')) return '/redemptions';
    if (path.startsWith('/auth/notifications')) return '/auth/notifications';
    return path;
  }

  Future<dynamic> _sendRaw(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _access != null) headers['Authorization'] = 'Bearer $_access';

    var res = await _send(uri, method, body, headers);
    if (res.statusCode == 401 && auth && _refresh != null) {
      if (await _tryRefresh()) {
        headers['Authorization'] = 'Bearer $_access';
        res = await _send(uri, method, body, headers);
      } else {
        await clear();
      }
    }

    if (res.statusCode == 204) return null;
    final dynamic data = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    // status 0 marker for callers that want to treat as offline
    throw ApiException(res.statusCode, _messageOf(data));
  }

  Future<http.Response> _send(
    Uri uri,
    String method,
    Map<String, dynamic>? body,
    Map<String, String> headers,
  ) {
    final encoded = body == null ? null : jsonEncode(body);
    Future<http.Response> sendReq() {
      switch (method) {
        case 'POST':
          return http.post(uri, headers: headers, body: encoded);
        case 'PUT':
          return http.put(uri, headers: headers, body: encoded);
        case 'PATCH':
          return http.patch(uri, headers: headers, body: encoded);
        case 'DELETE':
          return http.delete(uri, headers: headers, body: encoded);
        default:
          return http.get(uri, headers: headers);
      }
    }

    return sendReq().timeout(const Duration(seconds: 20));
  }

  String _messageOf(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['detail'] != null) return data['detail'].toString();
      final parts = <String>[];
      data.forEach((k, v) {
        parts.add('$k: ${v is List ? v.join(', ') : v}');
      });
      return parts.join(' · ');
    }
    return data?.toString() ?? 'Request failed';
  }
}

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  @override
  String toString() => message;
}
