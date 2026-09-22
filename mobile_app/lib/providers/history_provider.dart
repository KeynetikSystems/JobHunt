import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';
import '../error_utils.dart';
import '../models/history_item.dart';
import 'auth_provider.dart';

enum HistoryFilter { all, jobs, news }

class HistoryState {
  final bool busy;
  final String status;
  final List<HistoryItem> items;
  final bool loadedOnce;
  final HistoryFilter filter;
  final bool seniorityDescending;

  const HistoryState({
    this.busy = false,
    this.status = '',
    this.items = const [],
    this.loadedOnce = false,
    this.filter = HistoryFilter.all,
    this.seniorityDescending = false,
  });

  HistoryState copyWith({
    bool? busy,
    String? status,
    List<HistoryItem>? items,
    bool? loadedOnce,
    HistoryFilter? filter,
    bool? seniorityDescending,
  }) {
    return HistoryState(
      busy: busy ?? this.busy,
      status: status ?? this.status,
      items: items ?? this.items,
      loadedOnce: loadedOnce ?? this.loadedOnce,
      filter: filter ?? this.filter,
      seniorityDescending: seniorityDescending ?? this.seniorityDescending,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  final Ref ref;

  HistoryNotifier(this.ref) : super(const HistoryState()) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isConnected != next.isConnected) {
        onConnectionChanged();
      }
    });
  }

  void onConnectionChanged() {
    state = state.copyWith(items: [], loadedOnce: false, status: '');
  }

  void setFilter(HistoryFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setSeniorityDescending(bool descending) {
    state = state.copyWith(seniorityDescending: descending);
  }

  Future<void> load() async {
    final auth = ref.read(authProvider);
    if (!auth.isConnected) {
      state = state.copyWith(
        status: 'Not connected — set your backend URL in Settings first.',
      );
      return;
    }

    state = state.copyWith(busy: true, status: '');
    try {
      final items = await ApiClient.instance.history();
      state = state.copyWith(
        busy: false,
        items: items,
        loadedOnce: true,
        status: items.isEmpty ? 'No previously seen items yet.' : '',
      );
    } catch (e) {
      state = state.copyWith(
        busy: false,
        status: 'Could not load history: ${friendlyError(e)}',
      );
    }
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier(ref);
});
