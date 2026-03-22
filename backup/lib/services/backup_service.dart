import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  static String? _cachedUrl;
  static const String _fallbackUrl = 'http://localhost:8000';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedUrl = prefs.getString('backend_url');
    if (_cachedUrl == null) {
      await _autoDetectServer();
    }
  }

  static Future<void> _autoDetectServer() async {
    final subnets = ['192.168.101', '192.168.1', '192.168.0', '10.0.0'];
    final blocked = ['192.168.211', '192.168.137', '192.168.56'];

    for (final subnet in subnets) {
      if (blocked.any((p) => subnet.startsWith(p))) continue;
      for (int i = 2; i < 20; i++) {
        final url = 'http://$subnet.$i:8000';
        try {
          final response = await http
              .get(Uri.parse('$url/'))
              .timeout(const Duration(milliseconds: 400));
          if (response.statusCode == 200 &&
              response.body.contains('Database Backup API')) {
            _cachedUrl = url;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('backend_url', url);
            print('Found backend: $url');
            return;
          }
        } catch (_) {}
      }
    }
  }

  static String get baseUrl => _cachedUrl ?? _fallbackUrl;

  static Future<void> setManualUrl(String url) async {
    _cachedUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', _cachedUrl!);
  }

  static Future<void> clearUrl() async {
    _cachedUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('backend_url');
    await _autoDetectServer();
  }

  static String? get savedUrl => _cachedUrl;

  static Future<Map<String, dynamic>> backupDatabase() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/backup'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Server error', 'filename': null};
    } catch (e) {
      return {'success': false, 'message': 'Connection failed: $e', 'filename': null};
    }
  }

  static Future<List<String>> listBackups() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/backups'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['backups'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
