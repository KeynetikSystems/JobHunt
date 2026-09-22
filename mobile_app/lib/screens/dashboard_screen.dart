import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_listing.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/feed_filter_chip.dart';
import '../widgets/inline_ad_card.dart';
import '../widgets/job_card.dart';
import '../widgets/news_card.dart';
import '../widgets/skeleton_card.dart';

const _suggestedQueries = [
  'graduate strategy consulting London',
  'private equity analyst London',
  'remote software engineer',
  'venture capital associate Europe',
];

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch([String? query]) {
    final search = query ?? _searchController.text;
    ref.read(dashboardProvider.notifier).runSearch(search);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final isConnected = ref.watch(authProvider).isConnected;

    if (_searchController.text.isEmpty && state.lastQuery.isNotEmpty) {
      _searchController.text = state.lastQuery;
    }

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
                      fontSize: 14,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.lastQuery.isEmpty ? 'Your entries' : 'Results',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  if (state.lastQuery.isNotEmpty)
                    Text(
                      'for "${state.lastQuery}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  Text(
                    state.dateLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (state.busy) ...[
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          state.status,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Swipe a card left (or tap ✕) to dismiss it — it won\'t show up again.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildFilterBar(state),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          ref.read(dashboardProvider.notifier).refresh(),
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: _buildFeedItems(state, isConnected),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildSearchBar(state),
          if (state.account?.isPremium != true) const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildFilterBar(DashboardState state) {
    if (state.jobs.isEmpty && state.news.isEmpty) {
      return const SizedBox.shrink();
    }
    final notifier = ref.read(dashboardProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                FeedFilterChip(
                  label: 'All',
                  selected: state.filter == FeedFilter.all,
                  onSelected: () => notifier.setFilter(FeedFilter.all),
                ),
                FeedFilterChip(
                  label: 'Jobs (${state.jobs.length})',
                  selected: state.filter == FeedFilter.jobs,
                  onSelected: () => notifier.setFilter(FeedFilter.jobs),
                ),
                FeedFilterChip(
                  label: 'News (${state.news.length})',
                  selected: state.filter == FeedFilter.news,
                  onSelected: () => notifier.setFilter(FeedFilter.news),
                ),
              ],
            ),
          ),
          if (state.filter != FeedFilter.news && state.jobs.isNotEmpty)
            TextButton.icon(
              onPressed: () => notifier
                  .setSeniorityDescending(!state.seniorityDescending),
              icon: Icon(
                state.seniorityDescending
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                'Seniority',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 44),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFeedItems(DashboardState state, bool isConnected) {
    final items = <Widget>[];
    final showAds = state.account?.isPremium != true;
    final notifier = ref.read(dashboardProvider.notifier);

    final sortedJobs = [...state.jobs]..sort((a, b) => state.seniorityDescending
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
            onDismissed: (_) => notifier.dismissJob(job),
            child: _withDismissButton(
                JobCard(job: job), () => notifier.dismissJob(job)),
          ),
        );
        if (showAds && (i + 1) % 4 == 0) items.add(const InlineAdCard());
      }
    }

    void addNews() {
      for (var i = 0; i < state.news.length; i++) {
        final item = state.news[i];
        items.add(
          Dismissible(
            key: ValueKey(item.url),
            direction: DismissDirection.endToStart,
            background: _dismissBackground(),
            onDismissed: (_) => notifier.dismissNews(item),
            child: _withDismissButton(
                NewsCard(news: item), () => notifier.dismissNews(item)),
          ),
        );
        if (showAds && (i + 1) % 4 == 0) items.add(const InlineAdCard());
      }
    }

    switch (state.filter) {
      case FeedFilter.all:
        if (sortedJobs.isNotEmpty) {
          items.add(_sectionHeader('JOBS'));
          addJobs();
        }
        if (state.news.isNotEmpty) {
          items.add(_sectionHeader('NEWS'));
          addNews();
        }
      case FeedFilter.jobs:
        addJobs();
      case FeedFilter.news:
        addNews();
    }

    if (items.isEmpty) {
      if (state.busy) {
        items.addAll(const [SkeletonCard(), SkeletonCard(), SkeletonCard()]);
      } else {
        items.add(_emptyState(state, isConnected));
      }
    }
    return items;
  }

  Widget _sectionHeader(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyState(DashboardState state, bool isConnected) {
    final theme = Theme.of(context);
    final neverSearched = state.jobs.isEmpty && state.news.isEmpty;
    final String message;
    if (!isConnected) {
      message = 'Connect to your backend in Settings, then search.';
    } else if (neverSearched) {
      message = 'Nothing yet. Search below to check for fresh listings.';
    } else {
      message =
          'No ${state.filter == FeedFilter.jobs ? 'job' : 'news'} results in this search — try a different filter.';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(
        message,
        style: theme.textTheme.bodySmall
            ?.copyWith(fontSize: 12, fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildSearchBar(DashboardState state) {
    final theme = Theme.of(context);
    final suggestions = state.recentSearches.isNotEmpty
        ? state.recentSearches
        : (state.jobs.isEmpty && state.news.isEmpty
            ? _suggestedQueries
            : const <String>[]);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (suggestions.isNotEmpty) ...[
            Text(
              state.recentSearches.isNotEmpty
                  ? 'Recent searches'
                  : 'Try searching for',
              style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(
                    suggestions[i],
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: theme.colorScheme.surface,
                  side: BorderSide(color: theme.colorScheme.outline),
                  visualDensity: VisualDensity.compact,
                  onPressed: state.busy
                      ? null
                      : () {
                          _searchController.text = suggestions[i];
                          _runSearch(suggestions[i]);
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
                    onPressed: state.busy ? null : () => _runSearch(),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    child:
                        const Icon(Icons.search, size: 20, semanticLabel: 'Search'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  enabled: !state.busy,
                  onSubmitted: (_) => _runSearch(),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search for roles, firms, news…',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border.all(color: theme.textTheme.bodySmall?.color ?? Colors.grey),
      ),
      child: Icon(Icons.close, color: theme.colorScheme.onSurface),
    );
  }

  Widget _withDismissButton(Widget card, VoidCallback onDismiss) {
    return Stack(
      children: [
        card,
        Positioned(
          top: 0,
          right: 0,
          child: Tooltip(
            message: 'Dismiss',
            child: SizedBox(
              width: 44,
              height: 44,
              child: InkWell(
                onTap: onDismiss,
                customBorder: const CircleBorder(),
                child: Center(
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
