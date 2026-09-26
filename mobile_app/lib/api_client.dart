import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'models/account_status.dart';
import 'models/history_item.dart';
import 'models/job_listing.dart';
import 'models/news_item.dart';
import 'models/user_profile.dart';

class ScanResult {
  final List<JobListing> jobs;
  final List<NewsItem> news;
  ScanResult(this.jobs, this.news);
}

/// Talks to the JobHunt backend (backend/app.py). The app never holds Tavily/Groq/SMTP
/// credentials — only this backend's own API key, obtained via register().
class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  bool get isConnected => AuthService.instance.isConnected;

  String? get baseUrl => AuthService.instance.baseUrl;
  String? get apiKey => AuthService.instance.apiKey;

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

    await AuthService.instance.saveConnection(
      baseUrl: normalizedUrl,
      apiKey: key,
      email: email,
    );
  }

  /// Directly connects using a known Access Key received via email.
  Future<void> connectWithKey({
    required String baseUrl,
    required String email,
    required String apiKey,
  }) async {
    final normalizedUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    await AuthService.instance.saveConnection(
      baseUrl: normalizedUrl,
      apiKey: apiKey,
      email: email,
    );

    try {
      await me();
    } catch (e) {
      await disconnect();
      throw Exception('Invalid Access Key or server connection failed.');
    }
  }

  Future<void> disconnect() async {
    await AuthService.instance.disconnect();
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

  Future<UserProfile> getProfile() async {
    _requireConnected();
    final res = await http.get(Uri.parse('$baseUrl/api/profile'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
    return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> saveProfile(UserProfile profile) async {
    _requireConnected();
    final res = await http.put(
      Uri.parse('$baseUrl/api/profile'),
      headers: _authHeaders,
      body: jsonEncode(profile.toJson()),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
  }

  /// Sends a CV file (PDF or TXT) to the backend to parse and extract structured profile data using AI.
  Future<UserProfile> parseCv(List<int> bytes, String filename) async {
    _requireConnected();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/profile/parse-cv'));
    request.headers.addAll({'X-API-Key': apiKey ?? ''});
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
    return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Drafts CV highlights + a cover letter for one job, using the profile saved via
  /// saveProfile() and the backend's own Groq key. Returns (cvHighlights, coverLetter).
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

  /// Every piece of data this account has stored server-side, as raw JSON — the
  /// caller decides what to do with it (e.g. save to a file).
  Future<String> exportAccount() async {
    _requireConnected();
    final res = await http.get(Uri.parse('$baseUrl/api/export'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(res.body));
  }

  /// Irreversible — deletes the account and everything tied to it server-side, then
  /// clears local connection state exactly like disconnect() (every device's key,
  /// including this one, is invalidated by the deletion itself).
  Future<void> deleteAccount() async {
    _requireConnected();
    final res = await http.delete(Uri.parse('$baseUrl/api/account'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
    await disconnect();
  }

  /// Generated on this (already-connected) device, shown in-app — the whole point is to
  /// skip the email round-trip when adding a second device. Returns (code, expiresInSeconds).
  Future<(String, int)> requestPairingCode() async {
    _requireConnected();
    final res = await http.post(Uri.parse('$baseUrl/api/pairing-code'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['code'] as String, data['expires_in_seconds'] as int);
  }

  /// Run on the *new* device, with a code shown on an already-connected one — no
  /// existing connection required, this is itself how the new device authenticates.
  Future<void> exchangePairingCode({
    required String baseUrl,
    required String email,
    required String code,
  }) async {
    final normalizedUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final res = await http.post(
      Uri.parse('$normalizedUrl/api/pairing-code/exchange'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (res.statusCode != 200) {
      throw Exception(_errorDetail(res));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await AuthService.instance.saveConnection(
      baseUrl: normalizedUrl,
      apiKey: data['api_key'] as String,
      email: email,
    );
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
