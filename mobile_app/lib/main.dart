import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';
import 'api_client.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (AdConfig.adsSupported) {
    MobileAds.instance.initialize();
  }
  runApp(const JobHuntApp());
}

class JobHuntApp extends StatelessWidget {
  const JobHuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ledger',
      debugShowCheckedModeBanner: false,
      theme: buildLedgerTheme(),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();
  bool _loadedConnection = false;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.load().then((_) {
      if (mounted) setState(() => _loadedConnection = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedConnection) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(key: _dashboardKey),
          HistoryScreen(key: _historyKey),
          SettingsScreen(
            onConnectionChanged: () {
              _dashboardKey.currentState?.onConnectionChanged();
              _historyKey.currentState?.onConnectionChanged();
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: LedgerColors.inkPanel,
        selectedItemColor: LedgerColors.brass,
        unselectedItemColor: LedgerColors.slate,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
