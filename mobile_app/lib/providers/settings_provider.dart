import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/settings_controller.dart';

final settingsControllerProvider = ChangeNotifierProvider.autoDispose((ref) {
  final controller = SettingsController();
  controller.init();
  return controller;
});
