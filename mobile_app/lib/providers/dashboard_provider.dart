import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';
import '../error_utils.dart';
import '../local_store.dart';
import '../models/account_status.dart';
import '../models/job_listing.dart';
import '../models/news_item.dart';
import '../notifications.dart';
import 'auth_provider.dart';

enum FeedFilter { all, jobs, news }

class DashboardState {
  final bool busy;
  final String status;
  final String dateLabel;
  final String lastQuery;
  final List<JobListing> jobs;
  final List<NewsItem> news;
  final List<String> recentSearches;
  final FeedFilter filter;
  final bool seniorityDescending;
  final AccountStatus? account;

  const DashboardState({
    this.busy = false,
    this.status = 'Ready.',
    this.dateLabel = 'No search run yet',
    this.lastQuery = '',
    this.jobs = const [],
    this.news = const [],
    this.recentSearches = const [],
    this.filter = FeedFilter.all,
    this.seniorityDescending = false,
    this.account,
  });

  DashboardState copyWith({
    bool? busy,
    String? status,
    String? dateLabel,
    String? lastQuery,
    List<JobListing>? jobs,
    List<NewsItem>? news,
    List<String>? recentSearches,
    FeedFilter? filter,
    bool? seniorityDescending,
    AccountStatus? account,
    bool clearAccount = false,
  }) {
    return DashboardState(
      busy: busy ?? this.busy,
      status: status ?? this.status,
      dateLabel: dateLabel ?? this.dateLabel,
      lastQuery: lastQuery ?? this.lastQuery,
      jobs: jobs ?? this.jobs,
      news: news ?? this.news,
      recentSearches: recentSearches ?? this.recentSearches,
      filter: filter ?? this.filter,
      seniorityDescending: seniorityDescending ?? this.seniorityDescending,
      account: clearAccount ? null : (account ?? this.account),
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref ref;

  DashboardNotifier(this.ref) : super(const DashboardState()) {
    restore();
    loadAccountStatus();

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isConnected != next.isConnected) {
        onConnectionChanged();
      }
    });
  }

  void onConnectionChanged() {
    loadAccountStatus();
  }

  Future<void> loadAccountStatus() async {
    final auth = ref.read(authProvider);
    if (!auth.isConnected) {
      state = state.copyWith(clearAccount: true);
      return;
    }
    try {
      final account = await ApiClient.instance.me();
      state = state.copyWith(account: account);
    } catch (_) {
      // Leave account state as-is on transient fetch failure
    }
  }

  Future<void> restore() async {
    final recents = await LocalStore.loadRecentSearches();
    final last = await LocalStore.loadLastResults();
    if (last != null && last.query.isNotEmpty) {
      state = state.copyWith(
        recentSearches: recents,
        lastQuery: last.query,
        dateLabel: last.dateLabel,
        jobs: last.jobs,
        news: last.news,
        status: 'Showing your last search: "${last.query}".',
      );
    } else {
      state = state.copyWith(recentSearches: recents);
    }
  }

  void setFilter(FeedFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setSeniorityDescending(bool descending) {
    state = state.copyWith(seniorityDescending: descending);
  }

  Future<void> dismissJob(JobListing job) async {
    final updatedJobs = state.jobs.where((j) => j.url != job.url).toList();
    state = state.copyWith(jobs: updatedJobs);
    try {
      await ApiClient.instance.dismiss(jobs: [job]);
    } catch (e) {
      state = state.copyWith(
        status: "Dismiss didn't save (${friendlyError(e)}) — it may reappear next scan.",
      );
    }
  }

  Future<void> dismissNews(NewsItem item) async {
    final updatedNews = state.news.where((n) => n.url != item.url).toList();
    state = state.copyWith(news: updatedNews);
    try {
      await ApiClient.instance.dismiss(news: [item]);
    } catch (e) {
      state = state.copyWith(
        status: "Dismiss didn't save (${friendlyError(e)}) — it may reappear next scan.",
      );
    }
  }

  Future<void> runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(status: 'Enter something to search for first.');
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isConnected) {
      state = state.copyWith(
        status: 'Not connected — set your backend URL in Settings first.',
      );
      return;
    }

    state = state.copyWith(
      busy: true,
      status: 'Scanning job boards and news feed for "$trimmed"...',
      jobs: [],
      news: [],
    );

    try {
      final res = await ApiClient.instance.scan();
      final date = DateTime.now();
      final dateLabel =
          '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]} ${date.year}';

      final updatedRecents = await LocalStore.addRecentSearch(trimmed);
      await LocalStore.saveLastResults(
        query: trimmed,
        dateLabel: dateLabel,
        jobs: res.jobs,
        news: res.news,
      );

      final notifEnabled = await LocalStore.loadNotificationsEnabled();
      if (notifEnabled && res.jobs.isNotEmpty) {
        await NotificationService.instance.showScanResults(
          jobCount: res.jobs.length,
          newsCount: res.news.length,
        );
      }

      state = state.copyWith(
        busy: false,
        status: res.jobs.isEmpty && res.news.isEmpty
            ? 'Scan finished — no items found.'
            : 'Found ${res.jobs.length} new roles and ${res.news.length} news items.',
        lastQuery: trimmed,
        dateLabel: dateLabel,
        jobs: res.jobs,
        news: res.news,
        recentSearches: updatedRecents,
      );
    } catch (e) {
      state = state.copyWith(
        busy: false,
        status: 'Search failed: ${friendlyError(e)}',
      );
    }
  }

  Future<void> refresh() async {
    if (state.busy) return;
    if (state.lastQuery.isEmpty) {
      state = state.copyWith(
        status: 'Search for something first, then pull to refresh.',
      );
      return;
    }
    await runSearch(state.lastQuery);
  }
}

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'
];

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});
