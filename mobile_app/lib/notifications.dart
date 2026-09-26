import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local (in-app) notifications only — shown when the app is open and a scan
/// finds new items. Doesn't need Firebase/a push service, but also can't fire
/// while the app is closed; that's the tradeoff for zero external setup. See
/// the roadmap doc for the real push-notification path (FCM) if this isn't
/// enough someday.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> showScanResults({required int jobCount, required int newsCount}) async {
    if (jobCount == 0 && newsCount == 0) return;
    await init();
    final parts = <String>[];
    if (jobCount > 0) parts.add('$jobCount new opportunit${jobCount == 1 ? 'y' : 'ies'}');
    if (newsCount > 0) parts.add('$newsCount news item${newsCount == 1 ? '' : 's'}');
    const androidDetails = AndroidNotificationDetails(
      'scan_results',
      'Scan results',
      channelDescription: 'New opportunities and news found by a scan',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    await _plugin.show(id: 0, title: 'Ledger', body: parts.join(' · '), notificationDetails: details);
  }
}
