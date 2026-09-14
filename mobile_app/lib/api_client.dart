import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/job_listing.dart';
import 'models/news_item.dart';

class ScanResult {
  final List<JobListing> jobs;
  final List<NewsItem> news;
  ScanResult(this.jobs, this.news);
}

/// Talks to the JobHunt backend (backend/app.py). The app never holds Tavily/Groq/SMTP
/// credentials — only this backend's own API key, obtained via register().
class ApiClient {
  static const _baseUrlKey = 'backend_base_url';
  static const _apiKeyKey = 'backend_api_key';
  static const _emailKey = 'backend_email';

  static final ApiClient instance = ApiClient._();
  ApiClient._();

  String? baseUrl;
  String? apiKey;
  String? email;

  bool get isConnected =>
      (baseUrl?.isNotEmpty ?? false) && (apiKey?.isNotEmpty ?? false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_baseUrlKey);
    apiKey = prefs.getString(_apiKeyKey);
    email = prefs.getString(_emailKey);
  }

  Future<void> register(String baseUrl, String email) async {
    final normalizedUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final res = await http.post(
      Uri.parse('$normalizedUrl/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 200) {
      throw Exception('Registration failed (${res.statusCode}): ${res.body}');
    }
    final key = (jsonDecode(res.body) as Map<String, dynamic>)['api_key'] as String;

    this.baseUrl = normalizedUrl;
    apiKey = key;
    this.email = email;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalizedUrl);
    await prefs.setString(_apiKeyKey, key);
    await prefs.setString(_emailKey, email);
  }

  Future<void> disconnect() async {
    baseUrl = null;
    apiKey = null;
    email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_apiKeyKey);
    await prefs.remove(_emailKey);
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey ?? '',
      };

  Future<ScanResult> scan() async {
    _requireConnected();
    final res = await http.post(Uri.parse('$baseUrl/api/scan'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception('Scan failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final jobs = (data['jobs'] as List)
        .map((j) => JobListing(
              title: j['title'] ?? '',
              firm: j['firm'] ?? '',
              note: j['note'] ?? '',
              url: j['url'] ?? '',
            ))
        .toList();
    final news = (data['news'] as List)
        .map((n) => NewsItem(
              headline: n['headline'] ?? '',
              source: n['source'] ?? '',
              summary: n['summary'] ?? '',
              url: n['url'] ?? '',
            ))
        .toList();
    return ScanResult(jobs, news);
  }

  Future<void> dismiss(List<String> urls) async {
    _requireConnected();
    if (urls.isEmpty) return;
    final res = await http.post(
      Uri.parse('$baseUrl/api/dismiss'),
      headers: _authHeaders,
      body: jsonEncode({'urls': urls}),
    );
    if (res.statusCode != 200) {
      throw Exception('Dismiss failed (${res.statusCode}): ${res.body}');
    }
  }

  void _requireConnected() {
    if (!isConnected) {
      throw Exception('Not connected — set your backend URL in Settings first.');
    }
  }
}
