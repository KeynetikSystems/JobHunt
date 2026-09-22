import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/history_item.dart';
import '../models/job_listing.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/feed_filter_chip.dart';
import '../widgets/history_card.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  List<HistoryItem> _filteredSortedItems(HistoryState state) {
    final jobs = state.items.where((i) => i.isJob).toList()
      ..sort((a, b) => state.seniorityDescending
          ? seniorityRankOf(b.seniority).compareTo(seniorityRankOf(a.seniority))
          : seniorityRankOf(a.seniority).compareTo(seniorityRankOf(b.seniority)));
    final news = state.items.where((i) => !i.isJob).toList();
    switch (state.filter) {
      case HistoryFilter.jobs:
        return jobs;
      case HistoryFilter.news:
        return news;
      case HistoryFilter.all:
        return state.items;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyProvider);
    final connected = ref.watch(authProvider).isConnected;
    final notifier = ref.read(historyProvider.notifier);

    if (connected && !state.loadedOnce && !state.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.load();
      });
    }

    final jobCount = state.items.where((i) => i.isJob).length;
    final newsCount = state.items.length - jobCount;
    final visibleItems = _filteredSortedItems(state);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'History',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                IconButton(
                  onPressed: connected && !state.busy ? notifier.load : null,
                  tooltip: 'Refresh history',
                  icon: Icon(
                    Icons.refresh,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            Text(
              'Everything previously sent or dismissed, newest first.',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (state.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          FeedFilterChip(
                            label: 'All',
                            selected: state.filter == HistoryFilter.all,
                            onSelected: () =>
                                notifier.setFilter(HistoryFilter.all),
                          ),
                          FeedFilterChip(
                            label: 'Jobs ($jobCount)',
                            selected: state.filter == HistoryFilter.jobs,
                            onSelected: () =>
                                notifier.setFilter(HistoryFilter.jobs),
                          ),
                          FeedFilterChip(
                            label: 'News ($newsCount)',
                            selected: state.filter == HistoryFilter.news,
                            onSelected: () =>
                                notifier.setFilter(HistoryFilter.news),
                          ),
                        ],
                      ),
                    ),
                    if (state.filter == HistoryFilter.jobs && jobCount > 0)
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
              ),
            if (state.busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            if (state.status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  state.status,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            if (state.items.isNotEmpty && visibleItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No ${state.filter == HistoryFilter.jobs ? 'job' : 'news'} items in your history.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: visibleItems.length,
                itemBuilder: (context, i) =>
                    HistoryCard(item: visibleItems[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
