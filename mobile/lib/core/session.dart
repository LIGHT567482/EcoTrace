import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'offline.dart';

class AppUser {
  final int id;
  final String phone;
  final String fullName;
  final String role;
  final String town;
  final String address;

  const AppUser({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
    required this.town,
    required this.address,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int? ?? 0,
        phone: json['phone'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        role: json['role'] as String? ?? 'CONSUMER',
        town: json['town'] as String? ?? '',
        address: json['address'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'full_name': fullName,
        'role': role,
        'town': town,
        'address': address,
      };

  bool get isConsumer => role == 'CONSUMER';
  bool get isCollector => role == 'COLLECTOR';
  bool get isRecycler => role == 'RECYCLER';
  bool get isAdmin => role == 'ADMIN';
}

class Session extends ChangeNotifier {
  final Api api;
  AppUser? user;
  bool ready = false;
  bool offlineMode = false;

  StreamSubscription<void>? _syncSub;

  Session(this.api);

  OfflineStore get offline => api.offline;

  Future<void> init() async {
    await api.init();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw != null && api.hasToken) {
      // Always restore cached session first so the app works offline.
      user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      try {
        final me = await api.request('/auth/me/');
        user = AppUser.fromJson(me as Map<String, dynamic>);
        await prefs.setString('user', jsonEncode(user!.toJson()));
        offlineMode = false;
      } on OfflineException {
        // Stay signed-in with the cached profile while offline.
        offlineMode = true;
      } on ApiException catch (e) {
        if (e.status == 401 || e.status == 403) {
          user = null; // real auth failure
        } else {
          offlineMode = true;
        }
      } catch (_) {
        offlineMode = true;
      }
    }

    // Re-render UI whenever a background sync flush completes so
    // server-side changes (from web) show up automatically.
    _syncSub ??= api.onSynced.listen((_) {
      offlineMode = !offline.online;
      notifyListeners();
    });
    offline.addListener(_onOfflineChanged);

    ready = true;
    notifyListeners();
  }

  void _onOfflineChanged() {
    final was = offlineMode;
    offlineMode = !offline.online;
    if (was != offlineMode) notifyListeners();
  }

  Future<void> login(String phone, String password) async {
    final data = await api.request(
      '/auth/token/',
      method: 'POST',
      body: {'phone': phone, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
    if (data['_offline'] == true) {
      throw OfflineException('Cannot sign in while offline.');
    }
    await api.saveTokens(data['access'] as String, data['refresh'] as String);
    user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user!.toJson()));
    offlineMode = false;
    notifyListeners();
    unawaited(api.syncNow());
  }

  Future<void> register({
    required String phone,
    required String password,
    String fullName = '',
    String town = 'Kansanga',
    String address = '',
  }) async {
    final data = await api.request(
      '/auth/register/',
      method: 'POST',
      body: {
        'phone': phone,
        'password': password,
        'full_name': fullName,
        'town': town,
        'address': address,
      },
      auth: false,
    ) as Map<String, dynamic>;
    if (data['_offline'] == true) {
      throw OfflineException('Cannot register while offline.');
    }
    await api.saveTokens(data['access'] as String, data['refresh'] as String);
    user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user!.toJson()));
    offlineMode = false;
    notifyListeners();
    unawaited(api.syncNow());
  }

  Future<void> logout() async {
    await api.clear();
    user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    offline.removeListener(_onOfflineChanged);
    api.dispose();
    super.dispose();
  }
}
