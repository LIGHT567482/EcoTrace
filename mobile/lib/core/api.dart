import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  String? _access;
  String? _refresh;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _access = _prefs?.getString('access');
    _refresh = _prefs?.getString('refresh');
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
    final res = await http.post(
      Uri.parse('$baseUrl/auth/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': _refresh}),
    );
    if (res.statusCode != 200) return false;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await saveTokens(data['access'] as String, data['refresh'] as String);
    return true;
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    Map<String, String> headers = {'Content-Type': 'application/json'};
    if (auth && _access != null) headers['Authorization'] = 'Bearer $_access';

    http.Response res = await _send(uri, method, body, headers);
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
    throw ApiException(res.statusCode, _messageOf(data));
  }

  Future<http.Response> _send(
    Uri uri,
    String method,
    Map<String, dynamic>? body,
    Map<String, String> headers,
  ) {
    final encoded = body == null ? null : jsonEncode(body);
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
