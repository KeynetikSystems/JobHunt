import 'package:flutter/material.dart';
import '../api_client.dart';
import '../error_utils.dart';
import '../local_store.dart';
import '../models/job_listing.dart';
import '../models/news_item.dart';
import '../notifications.dart';
import '../theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/inline_ad_card.dart';
import '../widgets/job_card.dart';
import '../widgets/news_card.dart';

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'
];

/// Shown as tap-to-run suggestions when the user has never searched before
/// (and so has no recent-searches history yet) — lowers the "what do I even
/// type" barrier for a first-time visitor to an empty Dashboard.
const _suggestedQueries = [
  'graduate strategy consulting London',
  'private equity analyst London',
  'remote software engineer',
  'venture capital associate Europe',
];

enum _FeedFilter { all, jobs, news }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  bool _busy = false;
  String _status = 'Ready.';
  String _dateLabel = 'No search run yet';
  String _lastQuery = '';
  List<JobListing> _jobs = [];
  List<NewsItem> _news = [];
  List<String> _recentSearches = [];
  _FeedFilter _filter = _FeedFilter.all;
  bool _seniorityDescending = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Public so Settings can nudge the Dashboard to reflect a fresh connection.
  void onConnectionChanged() => setState(() {});

  /// Restores the last search's results and recent-search history from disk,
  /// so the Dashboard isn't a blank slate on every app restart.
  Future<void> _restore() async {
    final recents = await LocalStore.loadRecentSearches();
    final last = await LocalStore.loadLastResults();
    if (!mounted) return;
    setState(() {
      _recentSearches = recents;
      if (last != null && last.query.isNotEmpty) {
        _jobs = last.jobs;
        _news = last.news;
        _dateLabel = last.dateLabel;
        _lastQuery = last.query;
        _searchController.text = last.query;
        _status = 'Showing your last search: "${last.query}".';
      }
    });
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _status = 'Enter something to search for first.');
      return;
    }
    if (!ApiClient.instance.isConnected) {
      setState(() => _status = 'Not connected — set your backend URL in Settings first.');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Searching for "$query"…';
    });
    try {
      final result = await ApiClient.instance.search(query);
      if (!mounted) return;
      final dateLabel = _formatToday();
      setState(() {
        _jobs = result.jobs;
        _news = result.news;
        _dateLabel = dateLabel;
        _lastQuery = query;
        _status = 'Found ${_jobs.length} new roles and ${_news.length} news items.';
      });
      await LocalStore.saveLastResults(query: query, dateLabel: dateLabel, jobs: _jobs, news: _news);
      final recents = await LocalStore.addRecentSearch(query);
      if (mounted) setState(() => _recentSearches = recents);
      if (await LocalStore.loadNotificationsEnabled()) {
        NotificationService.instance.showScanResults(jobCount: result.jobs.length, newsCount: result.news.length);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Search failed: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    if (_lastQuery.isEmpty) {
      setState(() => _status = 'Search for something first, then pull to refresh.');
      return;
    }
    _searchController.text = _lastQuery;
    await _runSearch();
  }

  Future<void> _dismissJob(JobListing job) async {
    setState(() => _jobs.remove(job));
    try {
      await ApiClient.instance.dismiss(jobs: [job]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = "Dismiss didn't save (${friendlyError(e)}) — it may reappear next scan.");
    }
  }

  Future<void> _dismissNews(NewsItem item) async {
    setState(() => _news.remove(item));
    try {
      await ApiClient.instance.dismiss(news: [item]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = "Dismiss didn't save (${friendlyError(e)}) — it may reappear next scan.");
    }
  }

  String _formatToday() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LEDGER',
                    style: TextStyle(
                      color: LedgerColors.parchment,
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Today's entries",
                    style: TextStyle(
                      color: LedgerColors.parchment,
                      fontFamily: 'Georgia',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(_dateLabel, style: const TextStyle(color: LedgerColors.slate, fontSize: 12)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (_busy) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: LedgerColors.brass),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(_status, style: const TextStyle(color: LedgerColors.brass, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Swipe a card left to dismiss it — it won\'t show up again.',
                    style: TextStyle(color: LedgerColors.slate, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  _buildFilterBar(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      color: LedgerColors.brass,
                      backgroundColor: LedgerColors.inkPanel,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: _buildFeedItems(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildSearchBar(),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    if (_jobs.isEmpty && _news.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                _filterChip('All', _FeedFilter.all),
                _filterChip('Jobs (${_jobs.length})', _FeedFilter.jobs),
                _filterChip('News (${_news.length})', _FeedFilter.news),
              ],
            ),
          ),
          if (_filter != _FeedFilter.news && _jobs.isNotEmpty)
            Tooltip(
              message: _seniorityDescending ? 'Seniority: senior first — tap to reverse' : 'Seniority: junior first — tap to reverse',
              child: IconButton(
                onPressed: () => setState(() => _seniorityDescending = !_seniorityDescending),
                icon: Icon(
                  _seniorityDescending ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 18,
                  color: LedgerColors.brass,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _FeedFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, color: selected ? LedgerColors.inkBg : LedgerColors.parchment),
      ),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: LedgerColors.brass,
      backgroundColor: LedgerColors.inkPanel,
      side: const BorderSide(color: LedgerColors.hairline),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<Widget> _buildFeedItems() {
    final items = <Widget>[];
    final sortedJobs = [..._jobs]..sort((a, b) => _seniorityDescending
        ? seniorityRankOf(b.seniority).compareTo(seniorityRankOf(a.seniority))
        : seniorityRankOf(a.seniority).compareTo(seniorityRankOf(b.seniority)));

    void addJobs() {
      for (var i = 0; i < sortedJobs.length; i++) {
        final job = sortedJobs[i];
        items.add(
          Dismissible(
            key: ValueKey(job.url),
            direction: DismissDirection.endToStart,
            background: _dismissBackground(),
            onDismissed: (_) => _dismissJob(job),
            child: JobCard(job: job),
          ),
        );
        if ((i + 1) % 4 == 0) items.add(const InlineAdCard());
      }
    }

    void addNews() {
      for (var i = 0; i < _news.length; i++) {
        final item = _news[i];
        items.add(
          Dismissible(
            key: ValueKey(item.url),
            direction: DismissDirection.endToStart,
            background: _dismissBackground(),
            onDismissed: (_) => _dismissNews(item),
            child: NewsCard(news: item),
          ),
        );
        if ((i + 1) % 4 == 0) items.add(const InlineAdCard());
      }
    }

    switch (_filter) {
      case _FeedFilter.all:
        if (sortedJobs.isNotEmpty) {
          items.add(_sectionHeader('JOBS'));
          addJobs();
        }
        if (_news.isNotEmpty) {
          items.add(_sectionHeader('NEWS'));
          addNews();
        }
      case _FeedFilter.jobs:
        addJobs();
      case _FeedFilter.news:
        addNews();
    }

    if (items.isEmpty) {
      items.add(_emptyState());
    }
    return items;
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: const TextStyle(color: LedgerColors.brass, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _emptyState() {
    final connected = ApiClient.instance.isConnected;
    final neverSearched = _jobs.isEmpty && _news.isEmpty;
    final String message;
    if (!connected) {
      message = 'Connect to your backend in Settings, then search.';
    } else if (neverSearched) {
      message = 'Nothing yet. Search below to check for fresh listings.';
    } else {
      message = 'No ${_filter == _FeedFilter.jobs ? 'job' : 'news'} results in this search — try a different filter.';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(
        message,
        style: const TextStyle(color: LedgerColors.slate, fontStyle: FontStyle.italic, fontSize: 12),
      ),
    );
  }

  Widget _buildSearchBar() {
    final suggestions = _recentSearches.isNotEmpty
        ? _recentSearches
        : (_jobs.isEmpty && _news.isEmpty ? _suggestedQueries : const <String>[]);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LedgerColors.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (suggestions.isNotEmpty) ...[
            Text(
              _recentSearches.isNotEmpty ? 'Recent searches' : 'Try searching for',
              style: const TextStyle(color: LedgerColors.slate, fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(suggestions[i], style: const TextStyle(fontSize: 11, color: LedgerColors.parchment)),
                  backgroundColor: LedgerColors.inkPanel,
                  side: const BorderSide(color: LedgerColors.hairline),
                  visualDensity: VisualDensity.compact,
                  onPressed: _busy
                      ? null
                      : () {
                          _searchController.text = suggestions[i];
                          _runSearch();
                        },
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Tooltip(
                message: 'Run search',
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _runSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LedgerColors.brass,
                      foregroundColor: LedgerColors.inkBg,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    ),
                    child: const Icon(Icons.search, size: 20, semanticLabel: 'Search'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  enabled: !_busy,
                  onSubmitted: (_) => _runSearch(),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: LedgerColors.parchment, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search for roles, firms, news…',
                    hintStyle: const TextStyle(color: LedgerColors.slate, fontSize: 13),
                    filled: true,
                    fillColor: LedgerColors.inkPanel,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: LedgerColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: LedgerColors.hairline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: LedgerColors.brass),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LedgerColors.inkPanel,
        border: Border.all(color: LedgerColors.slate),
      ),
      child: const Icon(Icons.close, color: LedgerColors.parchment),
    );
  }
}
