import 'package:flutter/material.dart';
import '../api_client.dart';
import '../error_utils.dart';
import '../models/history_item.dart';
import '../models/job_listing.dart';
import '../theme.dart';
import '../widgets/feed_filter_chip.dart';
import '../widgets/history_card.dart';

enum _HistoryFilter { all, jobs, news }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  bool _busy = false;
  String _status = '';
  List<HistoryItem> _items = [];
  bool _loadedOnce = false;
  _HistoryFilter _filter = _HistoryFilter.all;
  bool _seniorityDescending = false;

  /// Public so the shell can refresh history right after Settings connects/disconnects.
  void onConnectionChanged() {
    _items = [];
    _loadedOnce = false;
    setState(() {});
  }

  Future<void> _load() async {
    if (!ApiClient.instance.isConnected) {
      setState(() => _status = 'Not connected — set your backend URL in Settings first.');
      return;
    }
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      final items = await ApiClient.instance.history();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loadedOnce = true;
        _status = items.isEmpty ? 'No previously seen items yet.' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Could not load history: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<HistoryItem> get _filteredSortedItems {
    final jobs = _items.where((i) => i.isJob).toList()
      ..sort((a, b) => _seniorityDescending
          ? seniorityRankOf(b.seniority).compareTo(seniorityRankOf(a.seniority))
          : seniorityRankOf(a.seniority).compareTo(seniorityRankOf(b.seniority)));
    final news = _items.where((i) => !i.isJob).toList();
    switch (_filter) {
      case _HistoryFilter.jobs:
        return jobs;
      case _HistoryFilter.news:
        return news;
      case _HistoryFilter.all:
        // Keep original newest-first order for "All" rather than grouping by kind —
        // History (unlike Dashboard) is one continuous timeline, so interleaving by
        // recency is more useful than section-grouping it.
        return _items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ApiClient.instance.isConnected;
    if (connected && !_loadedOnce && !_busy) {
      // Kick off the first load without blocking the current build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final jobCount = _items.where((i) => i.isJob).length;
    final newsCount = _items.length - jobCount;
    final visibleItems = _filteredSortedItems;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'History',
                    style: TextStyle(
                      color: LedgerColors.parchment,
                      fontFamily: 'Georgia',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: connected && !_busy ? _load : null,
                  tooltip: 'Refresh history',
                  icon: const Icon(Icons.refresh, color: LedgerColors.brass),
                ),
              ],
            ),
            const Text(
              'Everything previously sent or dismissed, newest first.',
              style: TextStyle(color: LedgerColors.slate, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (_items.isNotEmpty)
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
                            selected: _filter == _HistoryFilter.all,
                            onSelected: () => setState(() => _filter = _HistoryFilter.all),
                          ),
                          FeedFilterChip(
                            label: 'Jobs ($jobCount)',
                            selected: _filter == _HistoryFilter.jobs,
                            onSelected: () => setState(() => _filter = _HistoryFilter.jobs),
                          ),
                          FeedFilterChip(
                            label: 'News ($newsCount)',
                            selected: _filter == _HistoryFilter.news,
                            onSelected: () => setState(() => _filter = _HistoryFilter.news),
                          ),
                        ],
                      ),
                    ),
                    if (_filter == _HistoryFilter.jobs && jobCount > 0)
                      TextButton.icon(
                        onPressed: () => setState(() => _seniorityDescending = !_seniorityDescending),
                        icon: Icon(
                          _seniorityDescending ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 16,
                          color: LedgerColors.brass,
                        ),
                        label: const Text('Seniority', style: TextStyle(fontSize: 12, color: LedgerColors.brass)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(44, 44),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: LedgerColors.brass),
                ),
              ),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_status, style: const TextStyle(color: LedgerColors.brass, fontSize: 12)),
              ),
            if (_items.isNotEmpty && visibleItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No ${_filter == _HistoryFilter.jobs ? 'job' : 'news'} items in your history.',
                  style: const TextStyle(color: LedgerColors.slate, fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: visibleItems.length,
                itemBuilder: (context, i) => HistoryCard(item: visibleItems[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
