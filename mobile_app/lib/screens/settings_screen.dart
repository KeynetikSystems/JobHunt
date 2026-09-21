import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import '../error_utils.dart';
import '../local_store.dart';
import '../models/account_status.dart';
import '../models/user_profile.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onConnectionChanged;
  const SettingsScreen({super.key, required this.onConnectionChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _workHistoryCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _upgradeNoteCtrl = TextEditingController();
  final _slackCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();
  bool _busy = false;
  bool _profileBusy = false;
  bool _accountBusy = false;
  bool _alertsBusy = false;
  String _status = '';
  String _profileStatus = '';
  String _accountStatus = '';
  String _alertsStatus = '';
  AccountStatus? _account;
  bool _notificationsEnabled = true;
  // Personal Profile starts collapsed since it's the biggest section (7 fields,
  // 3 multiline textareas) and adds the most scroll length; the rest default open.
  final Map<String, bool> _sectionExpanded = {'Personal Profile': false};

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instance;
    _urlCtrl.text = api.baseUrl ?? '';
    _emailCtrl.text = api.email ?? '';
    if (api.isConnected) {
      _loadProfile();
      _loadAccount();
    }
    LocalStore.loadNotificationsEnabled().then((enabled) {
      if (mounted) setState(() => _notificationsEnabled = enabled);
    });
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    await LocalStore.setNotificationsEnabled(enabled);
  }

  /// Settings has several independent sections (Account, Alerts, Profile, Backend),
  /// each with its own inline status text for persistent context next to the fields
  /// it's about — but that's easy to miss if you're scrolled somewhere else when an
  /// async result lands. This is the one guaranteed-visible channel, shown regardless
  /// of scroll position, on top of (not instead of) the section-local text.
  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: LedgerColors.parchment, fontSize: 13)),
        backgroundColor: isError ? const Color(0xFF3A1F1F) : LedgerColors.inkPanel,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadAccount() async {
    try {
      final account = await ApiClient.instance.me();
      if (!mounted) return;
      setState(() => _account = account);
      if (account.isPremium) {
        final (slack, telegram) = await ApiClient.instance.getAlerts();
        if (mounted) {
          setState(() {
            _slackCtrl.text = slack;
            _telegramCtrl.text = telegram;
          });
        }
      }
    } catch (_) {
      // Not fatal — the Account section just won't show until this succeeds.
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _accountBusy = true;
      _accountStatus = 'Sending…';
    });
    try {
      await ApiClient.instance.resendVerification();
      if (mounted) {
        setState(() => _accountStatus = 'Verification email sent — check your inbox.');
        _showFeedback('Verification email sent — check your inbox.');
      }
    } catch (e) {
      final message = friendlyError(e);
      if (mounted) {
        setState(() => _accountStatus = 'Failed: $message');
        _showFeedback('Failed: $message', isError: true);
      }
    } finally {
      if (mounted) setState(() => _accountBusy = false);
    }
  }

  Future<void> _requestUpgrade() async {
    setState(() {
      _accountBusy = true;
      _accountStatus = 'Sending…';
    });
    try {
      await ApiClient.instance.requestUpgrade(_upgradeNoteCtrl.text);
      if (mounted) {
        setState(() => _accountStatus = "Request sent — we'll follow up by email.");
        _upgradeNoteCtrl.clear();
        _showFeedback("Request sent — we'll follow up by email.");
      }
    } catch (e) {
      final message = friendlyError(e);
      if (mounted) {
        setState(() => _accountStatus = 'Failed: $message');
        _showFeedback('Failed: $message', isError: true);
      }
    } finally {
      if (mounted) setState(() => _accountBusy = false);
    }
  }

  Future<void> _exportAccount() async {
    setState(() {
      _accountBusy = true;
      _accountStatus = 'Preparing export…';
    });
    try {
      final json = await ApiClient.instance.exportAccount();
      if (mounted) {
        setState(() => _accountStatus = '');
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: LedgerColors.inkPanel,
            title: const Text('Your data', style: TextStyle(color: LedgerColors.parchment)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: const TextStyle(color: LedgerColors.slate, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: json));
                  _showFeedback('Copied to clipboard.');
                },
                child: const Text('Copy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      final message = friendlyError(e);
      if (mounted) {
        setState(() => _accountStatus = 'Export failed: $message');
        _showFeedback('Export failed: $message', isError: true);
      }
    } finally {
      if (mounted) setState(() => _accountBusy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LedgerColors.inkPanel,
        title: const Text('Delete account?', style: TextStyle(color: LedgerColors.parchment)),
        content: const Text(
          "This permanently deletes your account, profile, history, and alert settings from our "
          "servers — including on every other device you've connected. There's no undo.",
          style: TextStyle(color: LedgerColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _accountBusy = true;
      _accountStatus = 'Deleting…';
    });
    try {
      await ApiClient.instance.deleteAccount();
      if (mounted) {
        setState(() {
          _urlCtrl.text = ApiClient.instance.baseUrl ?? '';
          _emailCtrl.clear();
          _fullNameCtrl.clear();
          _phoneCtrl.clear();
          _locationCtrl.clear();
          _linkedinCtrl.clear();
          _workHistoryCtrl.clear();
          _educationCtrl.clear();
          _skillsCtrl.clear();
          _slackCtrl.clear();
          _telegramCtrl.clear();
          _status = 'Account deleted.';
          _profileStatus = '';
          _accountStatus = '';
          _alertsStatus = '';
          _account = null;
        });
        _showFeedback('Account deleted.');
        widget.onConnectionChanged();
      }
    } catch (e) {
      final message = friendlyError(e);
      if (mounted) {
        setState(() => _accountStatus = 'Delete failed: $message');
        _showFeedback('Delete failed: $message', isError: true);
      }
    } finally {
      if (mounted) setState(() => _accountBusy = false);
    }
  }

  Future<void> _saveAlerts() async {
    setState(() {
      _alertsBusy = true;
      _alertsStatus = 'Saving…';
    });
    try {
      await ApiClient.instance.saveAlerts(
        slackWebhookUrl: _slackCtrl.text.trim(),
        telegramChatId: _telegramCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _alertsStatus = 'Alert settings saved.');
        _showFeedback('Alert settings saved.');
      }
    } catch (e) {
      final message = friendlyError(e);
      if (mounted) {
        setState(() => _alertsStatus = 'Save failed: $message');
        _showFeedback('Save failed: $message', isError: true);
      }
    } finally {
      if (mounted) setState(() => _alertsBusy = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ApiClient.instance.getProfile();
      if (!mounted) return;
      setState(() {
        _fullNameCtrl.text = profile.fullName;
        _phoneCtrl.text = profile.phone;
        _locationCtrl.text = profile.location;
        _linkedinCtrl.text = profile.linkedinUrl;
        _workHistoryCtrl.text = profile.workHistory;
        _educationCtrl.text = profile.education;
        _skillsCtrl.text = profile.skills;
      });
    } catch (_) {
      // Not fatal — fields just start empty; saving will still work.
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _profileBusy = true;
      _profileStatus = 'Saving…';
    });
    try {
      await ApiClient.instance.saveProfile(UserProfile(
        fullName: _fullNameCtrl.text,
        phone: _phoneCtrl.text,
        location: _locationCtrl.text,
        linkedinUrl: _linkedinCtrl.text,
        workHistory: _workHistoryCtrl.text,
        education: _educationCtrl.text,
        skills: _skillsCtrl.text,
      ));
      if (mounted) {
        setState(() => _profileStatus = 'Profile saved.');
        _showFeedback('Profile saved.');
      }
    } catch (e) {
      final message = friendlyError(e);
      if (mounted) {
        setState(() => _profileStatus = 'Save failed: $message');
        _showFeedback('Save failed: $message', isError: true);
      }
    } finally {
      if (mounted) setState(() => _profileBusy = false);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _emailCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _linkedinCtrl.dispose();
    _workHistoryCtrl.dispose();
    _educationCtrl.dispose();
    _skillsCtrl.dispose();
    _upgradeNoteCtrl.dispose();
    _slackCtrl.dispose();
    _telegramCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _status = 'Connecting…';
    });
    try {
      await ApiClient.instance.register(_urlCtrl.text.trim(), _emailCtrl.text.trim());
      final message = 'Connected as ${_emailCtrl.text.trim()}. Check your email to verify your account.';
      setState(() => _status = message);
      _showFeedback(message);
      widget.onConnectionChanged();
      await _loadProfile();
      await _loadAccount();
    } catch (e) {
      final message = friendlyError(e);
      setState(() => _status = 'Connection failed: $message');
      _showFeedback('Connection failed: $message', isError: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await ApiClient.instance.disconnect();
    setState(() {
      _urlCtrl.text = ApiClient.instance.baseUrl ?? '';
      _emailCtrl.clear();
      _fullNameCtrl.clear();
      _phoneCtrl.clear();
      _locationCtrl.clear();
      _linkedinCtrl.clear();
      _workHistoryCtrl.clear();
      _educationCtrl.clear();
      _skillsCtrl.clear();
      _slackCtrl.clear();
      _telegramCtrl.clear();
      _upgradeNoteCtrl.clear();
      _status = 'Disconnected.';
      _profileStatus = '';
      _accountStatus = '';
      _alertsStatus = '';
      _account = null;
    });
    _showFeedback('Disconnected.');
    widget.onConnectionChanged();
  }

  Future<void> _openLegalDoc(String path) async {
    final url = Uri.parse('${ApiClient.instance.baseUrl}$path');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final connected = ApiClient.instance.isConnected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: LedgerColors.parchment,
                fontFamily: 'Georgia',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LedgerColors.inkPanel,
                      border: Border.all(color: LedgerColors.hairline),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          connected ? Icons.check_circle : Icons.cloud_off,
                          color: connected ? LedgerColors.brass : LedgerColors.slate,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            connected
                                ? 'Connected as ${ApiClient.instance.email}'
                                : 'Not connected — results are fetched from your own backend, not this device',
                            style: const TextStyle(color: LedgerColors.parchment, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (connected && _account != null) ...[
                    const SizedBox(height: 20),
                    _sectionBox(
                      title: 'Account',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _accountRow('Plan', _account!.isPremium ? 'Premium' : 'Free'),
                          _accountRow('Email verified', _account!.emailVerified ? 'Yes' : 'No'),
                          _accountRow(
                            'AI drafts today',
                            _account!.materialsDailyCap == null
                                ? '${_account!.materialsUsedToday} (unlimited)'
                                : '${_account!.materialsUsedToday} / ${_account!.materialsDailyCap}',
                          ),
                          if (!_account!.emailVerified) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _accountBusy ? null : _resendVerification,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: LedgerColors.brass,
                                side: const BorderSide(color: LedgerColors.brass),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                              ),
                              child: const Text('Resend verification email'),
                            ),
                          ],
                          if (!_account!.isPremium) ...[
                            const SizedBox(height: 12),
                            _field('Request an upgrade (optional note)', _upgradeNoteCtrl,
                                hint: "e.g. I'm hitting the daily draft limit"),
                            OutlinedButton(
                              onPressed: _accountBusy ? null : _requestUpgrade,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: LedgerColors.brass,
                                side: const BorderSide(color: LedgerColors.brass),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                              ),
                              child: const Text('Request upgrade'),
                            ),
                          ],
                          if (_account!.isPremium) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Alert channels (premium — server push)',
                              style: TextStyle(color: LedgerColors.parchment, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Get new opportunities pushed to Slack/Telegram automatically, on top of "
                              "the on-device notifications below.",
                              style: TextStyle(color: LedgerColors.slate, fontSize: 11),
                            ),
                            const SizedBox(height: 8),
                            _field('Slack webhook URL', _slackCtrl, hint: 'https://hooks.slack.com/services/...'),
                            _field('Telegram chat ID', _telegramCtrl, hint: '123456789'),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: _alertsBusy ? null : _saveAlerts,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: LedgerColors.brass,
                                    side: const BorderSide(color: LedgerColors.brass),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                                  ),
                                  child: Text(_alertsBusy ? 'Saving…' : 'Save alert settings'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(_alertsStatus, style: const TextStyle(color: LedgerColors.brass, fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                          if (_accountStatus.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(_accountStatus, style: const TextStyle(color: LedgerColors.brass, fontSize: 12)),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _openLegalDoc('/privacy'),
                                style: TextButton.styleFrom(foregroundColor: LedgerColors.slate, padding: EdgeInsets.zero),
                                child: const Text('Privacy Policy', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 16),
                              TextButton(
                                onPressed: () => _openLegalDoc('/terms'),
                                style: TextButton.styleFrom(foregroundColor: LedgerColors.slate, padding: EdgeInsets.zero),
                                child: const Text('Terms of Service', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _accountBusy ? null : _exportAccount,
                                style: TextButton.styleFrom(foregroundColor: LedgerColors.slate, padding: EdgeInsets.zero),
                                child: const Text('Export my data', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 16),
                              TextButton(
                                onPressed: _accountBusy ? null : _deleteAccount,
                                style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: EdgeInsets.zero),
                                child: const Text('Delete my account', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionBox(
                    title: 'Notifications',
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Notify me on this device when a search finds new results. '
                            'Works on every plan — separate from premium\'s Slack/Telegram push above.',
                            style: TextStyle(color: LedgerColors.slate, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: _notificationsEnabled,
                          activeThumbColor: LedgerColors.brass,
                          onChanged: _setNotificationsEnabled,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionBox(
                    title: 'Backend',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field('Backend URL', _urlCtrl, hint: 'http://10.0.2.2:8000'),
                        _field('Email', _emailCtrl, hint: 'you@example.com'),
                        const SizedBox(height: 4),
                        const Text(
                          'This app never holds your Tavily/Groq/SMTP keys — those live on the '
                          'backend server. Connecting just registers this email and stores the '
                          'API key it gives back.',
                          style: TextStyle(color: LedgerColors.slate, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  if (connected) ...[
                    const SizedBox(height: 20),
                    _sectionBox(
                      title: 'Personal Profile',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Used to draft tailored CV highlights and cover letters, and as a quick '
                            'reference when filling out application forms elsewhere. Never sent '
                            'anywhere except Groq, alongside the specific role you ask to draft for.',
                            style: TextStyle(color: LedgerColors.slate, fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          _field('Full name', _fullNameCtrl),
                          _field('Phone number', _phoneCtrl, warningFor: _phoneWarning),
                          _field('Location / City', _locationCtrl),
                          _field('LinkedIn / portfolio URL', _linkedinCtrl, warningFor: _linkedinWarning),
                          _multilineField('Work history', _workHistoryCtrl, maxLines: 8),
                          _multilineField('Education', _educationCtrl, maxLines: 4),
                          _multilineField('Skills', _skillsCtrl, maxLines: 3),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: _profileBusy ? null : _saveProfile,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: LedgerColors.brass,
                                  side: const BorderSide(color: LedgerColors.brass),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                                ),
                                child: Text(_profileBusy ? 'Saving…' : 'Save profile'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_profileStatus, style: const TextStyle(color: LedgerColors.brass, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _busy ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LedgerColors.brass,
                      foregroundColor: LedgerColors.inkBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    ),
                    child: Text(connected ? 'Reconnect' : 'Connect'),
                  ),
                  if (connected) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : _disconnect,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LedgerColors.parchment,
                        side: const BorderSide(color: LedgerColors.slate),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      ),
                      child: const Text('Disconnect'),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_status, style: const TextStyle(color: LedgerColors.brass, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Visually groups a labeled section into its own bordered card, so the
  /// screen reads as distinct blocks (Account, Notifications, Backend, CV)
  /// instead of one undifferentiated scroll of headers and fields.
  Widget _sectionBox({required String title, required Widget child}) {
    final expanded = _sectionExpanded[title] ?? true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LedgerColors.inkPanel,
        border: Border.all(color: LedgerColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _sectionExpanded[title] = !expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(color: LedgerColors.parchment, fontFamily: 'Georgia', fontSize: 16)),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: LedgerColors.slate,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }

  Widget _accountRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: LedgerColors.slate, fontSize: 12)),
          ),
          Text(value, style: const TextStyle(color: LedgerColors.parchment, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, String? Function(String)? warningFor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: LedgerColors.slate, fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            style: const TextStyle(color: LedgerColors.parchment, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(color: LedgerColors.slate),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              filled: true,
              fillColor: LedgerColors.inkPanel,
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: LedgerColors.hairline),
                borderRadius: BorderRadius.circular(2),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: LedgerColors.hairline),
                borderRadius: BorderRadius.circular(2),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: LedgerColors.brass),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (warningFor != null)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl,
              builder: (context, value, _) {
                final warning = warningFor(value.text);
                if (warning == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(warning, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Non-blocking — a malformed phone number is still saved (it's the user's own
  /// data and only informs application forms filled out elsewhere), this just
  /// surfaces the mismatch before it becomes a rejected form field, per the UX
  /// critique that the old field gave no feedback until a form rejected it later.
  static String? _phoneWarning(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'[\s\-().]'), '');
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(digits)) {
      return "Doesn't look like a valid phone number.";
    }
    return null;
  }

  static String? _linkedinWarning(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    final valid = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    if (!valid) {
      return "Doesn't look like a valid URL — include https://";
    }
    return null;
  }

  Widget _multilineField(String label, TextEditingController ctrl, {required int maxLines}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: LedgerColors.slate, fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(color: LedgerColors.parchment, fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
              filled: true,
              fillColor: LedgerColors.inkBg,
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: LedgerColors.hairline),
                borderRadius: BorderRadius.circular(2),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: LedgerColors.hairline),
                borderRadius: BorderRadius.circular(2),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: LedgerColors.brass),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
