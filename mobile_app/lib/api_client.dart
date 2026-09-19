import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/account_status.dart';
import 'models/history_item.dart';
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

  /// Registering an email that already belongs to a *verified* account doesn't return
  /// a key here at all — the server emails a fresh one to that address instead of
  /// handing it back over HTTP to whoever merely typed the email in (that would let
  /// anyone hijack a known email into an account takeover). Throws in that case with a
  /// message telling the caller to check their inbox, rather than connecting.
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
    final key = (jsonDecode(res.body) as Map<String, dynamic>)['api_key'] as String?;
    if (key == null) {
      throw Exception(
        'This email already has a verified account — check your inbox for a new access key.',
      );
    }

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
              seniority: j['seniority'] ?? 'Unspecified',
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

  Future<ScanResult> search(String query) async {
    _requireConnected();
    final res = await http.post(
      Uri.parse('$baseUrl/api/search'),
      headers: _authHeaders,
      body: jsonEncode({'query': query}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final jobs = (data['jobs'] as List)
        .map((j) => JobListing(
              title: j['title'] ?? '',
              firm: j['firm'] ?? '',
              seniority: j['seniority'] ?? 'Unspecified',
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

  Future<void> dismiss({List<JobListing> jobs = const [], List<NewsItem> news = const []}) async {
    _requireConnected();
    if (jobs.isEmpty && news.isEmpty) return;
    final res = await http.post(
      Uri.parse('$baseUrl/api/dismiss'),
      headers: _authHeaders,
      body: jsonEncode({
        'jobs': jobs
            .map((j) => {
                  'title': j.title,
                  'firm': j.firm,
                  'seniority': j.seniority,
                  'note': j.note,
                  'url': j.url,
                })
            .toList(),
        'news': news
            .map((n) => {
                  'headline': n.headline,
                  'source': n.source,
                  'summary': n.summary,
                  'url': n.url,
                })
            .toList(),
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Dismiss failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<List<HistoryItem>> history() async {
    _requireConnected();
    final res = await http.get(Uri.parse('$baseUrl/api/history'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception('History failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['items'] as List)
        .map((i) => HistoryItem.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<String> getCv() async {
    _requireConnected();
    final res = await http.get(Uri.parse('$baseUrl/api/cv'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception('Fetching CV failed (${res.statusCode}): ${res.body}');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['cv_text'] as String? ?? '';
  }

  Future<void> saveCv(String cvText) async {
    _requireConnected();
    final res = await http.put(
      Uri.parse('$baseUrl/api/cv'),
      headers: _authHeaders,
      body: jsonEncode({'cv_text': cvText}),
    );
    if (res.statusCode != 200) {
      throw Exception('Saving CV failed (${res.statusCode}): ${res.body}');
    }
  }

  /// Drafts CV highlights + a cover letter for one job, using the CV saved via
  /// saveCv() and the backend's own Groq key. Returns (cvHighlights, coverLetter).
  /// Takes a plain map (title/firm/seniority/note/url) so both a JobListing and a
  /// job-kind HistoryItem can call this without an extra conversion type.
  Future<(String, String)> draftMaterials(Map<String, String> job) async {
    _requireConnected();
    final res = await http.post(
      Uri.parse('$baseUrl/api/materials'),
      headers: _authHeaders,
      body: jsonEncode({'job': job}),
    );
    if (res.statusCode != 200) {
      final detail = (jsonDecode(res.body) as Map<String, dynamic>)['detail'] ?? res.body;
      throw Exception('$detail');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['cv_highlights'] as String? ?? '', data['cover_letter'] as String? ?? '');
  }

  Future<AccountStatus> me() async {
    _requireConnected();
    final res = await http.get(Uri.parse('$baseUrl/api/me'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
    return AccountStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> resendVerification() async {
    _requireConnected();
    final res = await http.post(Uri.parse('$baseUrl/api/resend-verification'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
  }

  Future<void> requestUpgrade(String note) async {
    _requireConnected();
    final res = await http.post(
      Uri.parse('$baseUrl/api/upgrade-request'),
      headers: _authHeaders,
      body: jsonEncode({'note': note}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
  }

  /// Returns (slackWebhookUrl, telegramChatId).
  Future<(String, String)> getAlerts() async {
    _requireConnected();
    final res = await http.get(Uri.parse('$baseUrl/api/alerts'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['slack_webhook_url'] as String? ?? '', data['telegram_chat_id'] as String? ?? '');
  }

  Future<void> saveAlerts({required String slackWebhookUrl, required String telegramChatId}) async {
    _requireConnected();
    final res = await http.put(
      Uri.parse('$baseUrl/api/alerts'),
      headers: _authHeaders,
      body: jsonEncode({'slack_webhook_url': slackWebhookUrl, 'telegram_chat_id': telegramChatId}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
  }

  String _errorDetail(http.Response res) {
    try {
      final detail = (jsonDecode(res.body) as Map<String, dynamic>)['detail'];
      if (detail != null) return '$detail';
    } catch (_) {
      // Body wasn't JSON — fall through to the raw body below.
    }
    return res.body;
  }

  void _requireConnected() {
    if (!isConnected) {
      throw Exception('Not connected — set your backend URL in Settings first.');
    }
  }
}
