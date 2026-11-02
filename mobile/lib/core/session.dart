import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

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

  Session(this.api);

  Future<void> init() async {
    await api.init();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw != null && api.hasToken) {
      user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      try {
        final me = await api.request('/auth/me/');
        user = AppUser.fromJson(me as Map<String, dynamic>);
        await prefs.setString('user', jsonEncode(user!.toJson()));
      } catch (_) {
        user = null;
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String phone, String password) async {
    final data = await api.request(
      '/auth/token/',
      method: 'POST',
      body: {'phone': phone, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
    await api.saveTokens(data['access'] as String, data['refresh'] as String);
    user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user!.toJson()));
    notifyListeners();
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
    await api.saveTokens(data['access'] as String, data['refresh'] as String);
    user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    await api.clear();
    user = null;
    notifyListeners();
  }
}
