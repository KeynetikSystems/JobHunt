import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models/job_listing.dart';
import '../models/news_item.dart';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool _busy = false;
  String _status = 'Ready.';
  String _dateLabel = 'No scan run yet';
  List<JobListing> _jobs = [];
  List<NewsItem> _news = [];

  /// Public so Settings can nudge the Dashboard to reflect a fresh connection.
  void onConnectionChanged() => setState(() {});

  Future<void> _runScan() async {
    if (!ApiClient.instance.isConnected) {
      setState(() => _status = 'Not connected — set your backend URL in Settings first.');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Scanning for new listings and news…';
    });
    try {
      final result = await ApiClient.instance.scan();
      if (!mounted) return;
      setState(() {
        _jobs = result.jobs;
        _news = result.news;
        _dateLabel = _formatToday();
        _status = 'Found ${_jobs.length} new roles and ${_news.length} news items.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Scan failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismissJob(JobListing job) async {
    setState(() => _jobs.remove(job));
    try {
      await ApiClient.instance.dismiss(jobs: [job]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = "Dismiss didn't save ($e) — it may reappear next scan.");
    }
  }

  Future<void> _dismissNews(NewsItem item) async {
    setState(() => _news.remove(item));
    try {
      await ApiClient.instance.dismiss(news: [item]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = "Dismiss didn't save ($e) — it may reappear next scan.");
    }
  }

  String _formatToday() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final connected = ApiClient.instance.isConnected;

    final feedItems = <Widget>[];
    for (var i = 0; i < _jobs.length; i++) {
      final job = _jobs[i];
      feedItems.add(
        Dismissible(
          key: ValueKey(job.url),
          direction: DismissDirection.endToStart,
          background: _dismissBackground(),
          onDismissed: (_) => _dismissJob(job),
          child: JobCard(job: job),
        ),
      );
      if ((i + 1) % 4 == 0) feedItems.add(const InlineAdCard());
    }
    for (var i = 0; i < _news.length; i++) {
      final item = _news[i];
      feedItems.add(
        Dismissible(
          key: ValueKey(item.url),
          direction: DismissDirection.endToStart,
          background: _dismissBackground(),
          onDismissed: (_) => _dismissNews(item),
          child: NewsCard(news: item),
        ),
      );
      if ((i + 1) % 4 == 0) feedItems.add(const InlineAdCard());
    }
    if (feedItems.isEmpty) {
      feedItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text(
            connected
                ? 'Nothing new yet. Run a scan to check for fresh listings.'
                : 'Connect to your backend in Settings, then run a scan.',
            style: const TextStyle(color: LedgerColors.slate, fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ),
      );
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
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _busy ? null : _runScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LedgerColors.brass,
                      foregroundColor: LedgerColors.inkBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    ),
                    child: Text(_busy ? 'Working…' : 'Run scan now'),
                  ),
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
                    style: TextStyle(color: LedgerColors.slate, fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: ListView(children: feedItems)),
                ],
              ),
            ),
          ),
          const BannerAdWidget(),
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
