import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../error_utils.dart';
import '../local_store.dart';
import '../models/account_status.dart';
import '../models/user_profile.dart';

class SettingsController extends ChangeNotifier {
  final urlCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final apiKeyCtrl = TextEditingController();
  final pairingCodeCtrl = TextEditingController();
  final fullNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final linkedinCtrl = TextEditingController();
  final workHistoryCtrl = TextEditingController();
  final educationCtrl = TextEditingController();
  final skillsCtrl = TextEditingController();
  final upgradeNoteCtrl = TextEditingController();
  final slackCtrl = TextEditingController();
  final telegramCtrl = TextEditingController();

  bool _busy = false;
  bool get busy => _busy;

  bool _profileBusy = false;
  bool get profileBusy => _profileBusy;

  bool _accountBusy = false;
  bool get accountBusy => _accountBusy;

  bool _alertsBusy = false;
  bool get alertsBusy => _alertsBusy;

  AccountStatus? _account;
  AccountStatus? get account => _account;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  final Map<String, bool> sectionExpanded = {
    'Backend': true,
    'Personal Profile': false,
    'Alerts': true,
    'Account': true,
  };

  void init() {
    final auth = AuthService.instance;
    urlCtrl.text = auth.baseUrl ?? '';
    emailCtrl.text = auth.email ?? '';
    apiKeyCtrl.text = auth.apiKey ?? '';
    
    if (auth.isConnected) {
      loadProfile();
      loadAccount();
    }
    
    LocalStore.loadNotificationsEnabled().then((enabled) {
      _notificationsEnabled = enabled;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    urlCtrl.dispose();
    emailCtrl.dispose();
    apiKeyCtrl.dispose();
    pairingCodeCtrl.dispose();
    fullNameCtrl.dispose();
    phoneCtrl.dispose();
    locationCtrl.dispose();
    linkedinCtrl.dispose();
    workHistoryCtrl.dispose();
    educationCtrl.dispose();
    skillsCtrl.dispose();
    upgradeNoteCtrl.dispose();
    slackCtrl.dispose();
    telegramCtrl.dispose();
    super.dispose();
  }

  void toggleSection(String title) {
    sectionExpanded[title] = !(sectionExpanded[title] ?? false);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    await LocalStore.setNotificationsEnabled(enabled);
  }

  Future<void> loadProfile() async {
    _profileBusy = true;
    notifyListeners();
    try {
      final p = await ApiClient.instance.getProfile();
      fullNameCtrl.text = p.fullName;
      phoneCtrl.text = p.phone;
      locationCtrl.text = p.location;
      linkedinCtrl.text = p.linkedinUrl;
      workHistoryCtrl.text = p.workHistory;
      educationCtrl.text = p.education;
      skillsCtrl.text = p.skills;
    } catch (_) {}
    _profileBusy = false;
    notifyListeners();
  }

  Future<void> loadAccount() async {
    try {
      _account = await ApiClient.instance.me();
      if (_account?.isPremium ?? false) {
        final (slack, telegram) = await ApiClient.instance.getAlerts();
        slackCtrl.text = slack;
        telegramCtrl.text = telegram;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<String?> connect() async {
    _busy = true;
    notifyListeners();
    try {
      final key = apiKeyCtrl.text.trim();
      final url = urlCtrl.text.trim();
      final email = emailCtrl.text.trim();

      if (key.isNotEmpty) {
        await ApiClient.instance.connectWithKey(
          baseUrl: url,
          email: email,
          apiKey: key,
        );
      } else {
        await ApiClient.instance.register(url, email);
      }

      await loadProfile();
      await loadAccount();
      _busy = false;
      notifyListeners();
      return null;
    } catch (e) {
      _busy = false;
      notifyListeners();
      return friendlyError(e);
    }
  }

  /// Called on the *new* device with a code shown on an already-connected one —
  /// no prior connection needed, this is itself how the new device authenticates.
  Future<String?> connectWithPairingCode() async {
    _busy = true;
    notifyListeners();
    try {
      await ApiClient.instance.exchangePairingCode(
        baseUrl: urlCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        code: pairingCodeCtrl.text.trim(),
      );
      pairingCodeCtrl.clear();
      await loadProfile();
      await loadAccount();
      _busy = false;
      notifyListeners();
      return null;
    } catch (e) {
      _busy = false;
      notifyListeners();
      return friendlyError(e);
    }
  }

  /// Called on an already-connected device to generate a code for pairing a new one.
  Future<(String, int)> requestPairingCode() async {
    _accountBusy = true;
    notifyListeners();
    try {
      final result = await ApiClient.instance.requestPairingCode();
      _accountBusy = false;
      notifyListeners();
      return result;
    } catch (e) {
      _accountBusy = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await ApiClient.instance.disconnect();
    urlCtrl.text = AuthService.instance.baseUrl ?? '';
    emailCtrl.text = '';
    apiKeyCtrl.clear();
    pairingCodeCtrl.clear();
    _account = null;
    notifyListeners();
  }

  Future<String?> importCv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return 'Could not read selected file.';

      _profileBusy = true;
      notifyListeners();

      final profile = await ApiClient.instance.parseCv(bytes, file.name);
      if (profile.fullName.isNotEmpty) fullNameCtrl.text = profile.fullName;
      if (profile.phone.isNotEmpty) phoneCtrl.text = profile.phone;
      if (profile.location.isNotEmpty) locationCtrl.text = profile.location;
      if (profile.linkedinUrl.isNotEmpty) linkedinCtrl.text = profile.linkedinUrl;
      if (profile.workHistory.isNotEmpty) workHistoryCtrl.text = profile.workHistory;
      if (profile.education.isNotEmpty) educationCtrl.text = profile.education;
      if (profile.skills.isNotEmpty) skillsCtrl.text = profile.skills;

      _profileBusy = false;
      notifyListeners();
      return 'CV imported and profile updated!';
    } catch (e) {
      _profileBusy = false;
      notifyListeners();
      return 'CV import failed: ${friendlyError(e)}';
    }
  }

  Future<String?> saveProfile() async {
    _profileBusy = true;
    notifyListeners();
    try {
      await ApiClient.instance.saveProfile(UserProfile(
        fullName: fullNameCtrl.text,
        phone: phoneCtrl.text,
        location: locationCtrl.text,
        linkedinUrl: linkedinCtrl.text,
        workHistory: workHistoryCtrl.text,
        education: educationCtrl.text,
        skills: skillsCtrl.text,
      ));
      _profileBusy = false;
      notifyListeners();
      return 'Profile saved.';
    } catch (e) {
      _profileBusy = false;
      notifyListeners();
      return 'Save failed: ${friendlyError(e)}';
    }
  }

  Future<String?> saveAlerts() async {
    _alertsBusy = true;
    notifyListeners();
    try {
      await ApiClient.instance.saveAlerts(
        slackWebhookUrl: slackCtrl.text.trim(),
        telegramChatId: telegramCtrl.text.trim(),
      );
      _alertsBusy = false;
      notifyListeners();
      return 'Alerts updated.';
    } catch (e) {
      _alertsBusy = false;
      notifyListeners();
      return 'Failed to save alerts: ${friendlyError(e)}';
    }
  }

  Future<String?> resendVerification() async {
    _accountBusy = true;
    notifyListeners();
    try {
      await ApiClient.instance.resendVerification();
      _accountBusy = false;
      notifyListeners();
      return 'Verification email sent.';
    } catch (e) {
      _accountBusy = false;
      notifyListeners();
      return 'Failed: ${friendlyError(e)}';
    }
  }

  Future<String?> requestUpgrade() async {
    _accountBusy = true;
    notifyListeners();
    try {
      await ApiClient.instance.requestUpgrade(upgradeNoteCtrl.text);
      upgradeNoteCtrl.clear();
      _accountBusy = false;
      notifyListeners();
      return "Upgrade request sent.";
    } catch (e) {
      _accountBusy = false;
      notifyListeners();
      return 'Failed: ${friendlyError(e)}';
    }
  }

  Future<String?> exportAccount() async {
    _accountBusy = true;
    notifyListeners();
    try {
      final json = await ApiClient.instance.exportAccount();
      _accountBusy = false;
      notifyListeners();
      return json;
    } catch (e) {
      _accountBusy = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    await ApiClient.instance.deleteAccount();
    await disconnect();
  }
}
