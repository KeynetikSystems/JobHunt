import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/job_listing.dart';
import 'models/news_item.dart';

/// On-device-only state: the last search's results (so the Dashboard isn't
/// empty on every app restart), recent search queries (tap to re-run), and
/// the local-notification preference. None of this touches the backend —
/// it's purely a per-device convenience layer.
class LocalStore {
  static const _lastQueryKey = 'last_search_query';
  static const _lastJobsKey = 'last_search_jobs';
  static const _lastNewsKey = 'last_search_news';
  static const _lastDateKey = 'last_search_date';
  static const _recentSearchesKey = 'recent_searches';
  static const _notificationsEnabledKey = 'local_notifications_enabled';
  static const _maxRecentSearches = 8;

  static Future<void> saveLastResults({
    required String query,
    required String dateLabel,
    required List<JobListing> jobs,
    required List<NewsItem> news,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastQueryKey, query);
    await prefs.setString(_lastDateKey, dateLabel);
    await prefs.setString(_lastJobsKey, jsonEncode(jobs.map((j) => j.toJson()).toList()));
    await prefs.setString(_lastNewsKey, jsonEncode(news.map((n) => n.toJson()).toList()));
  }

  /// Returns null if nothing has ever been searched on this device.
  static Future<({String query, String dateLabel, List<JobListing> jobs, List<NewsItem> news})?>
      loadLastResults() async {
    final prefs = await SharedPreferences.getInstance();
    final query = prefs.getString(_lastQueryKey);
    if (query == null) return null;
    final jobsJson = jsonDecode(prefs.getString(_lastJobsKey) ?? '[]') as List;
    final newsJson = jsonDecode(prefs.getString(_lastNewsKey) ?? '[]') as List;
    return (
      query: query,
      dateLabel: prefs.getString(_lastDateKey) ?? '',
      jobs: jobsJson.map((j) => JobListing.fromJson(j as Map<String, dynamic>)).toList(),
      news: newsJson.map((n) => NewsItem.fromJson(n as Map<String, dynamic>)).toList(),
    );
  }

  static Future<List<String>> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? [];
  }

  /// Moves query to the front, dedupes case-insensitively, caps the list length.
  static Future<List<String>> addRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_recentSearchesKey) ?? [];
    final updated = [query, ...existing.where((q) => q.toLowerCase() != query.toLowerCase())]
        .take(_maxRecentSearches)
        .toList();
    await prefs.setStringList(_recentSearchesKey, updated);
    return updated;
  }

  static Future<bool> loadNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }
}
