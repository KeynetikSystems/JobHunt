import 'package:flutter/material.dart';
import '../api_client.dart';
import '../error_utils.dart';
import '../models/history_item.dart';
import '../theme.dart';
import '../widgets/history_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final connected = ApiClient.instance.isConnected;
    if (connected && !_loadedOnce && !_busy) {
      // Kick off the first load without blocking the current build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

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
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, i) => HistoryCard(item: _items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
