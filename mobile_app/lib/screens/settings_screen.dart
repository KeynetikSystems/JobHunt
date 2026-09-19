import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import '../models/account_status.dart';
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
  final _cvCtrl = TextEditingController();
  final _upgradeNoteCtrl = TextEditingController();
  final _slackCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();
  bool _busy = false;
  bool _cvBusy = false;
  bool _accountBusy = false;
  bool _alertsBusy = false;
  String _status = '';
  String _cvStatus = '';
  String _accountStatus = '';
  String _alertsStatus = '';
  AccountStatus? _account;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instance;
    _urlCtrl.text = api.baseUrl ?? '';
    _emailCtrl.text = api.email ?? '';
    if (api.isConnected) {
      _loadCv();
      _loadAccount();
    }
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
      if (mounted) setState(() => _accountStatus = 'Verification email sent — check your inbox.');
    } catch (e) {
      if (mounted) setState(() => _accountStatus = 'Failed: $e');
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
      }
    } catch (e) {
      if (mounted) setState(() => _accountStatus = 'Failed: $e');
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
      if (mounted) setState(() => _alertsStatus = 'Alert settings saved.');
    } catch (e) {
      if (mounted) setState(() => _alertsStatus = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _alertsBusy = false);
    }
  }

  Future<void> _loadCv() async {
    try {
      final cv = await ApiClient.instance.getCv();
      if (mounted) setState(() => _cvCtrl.text = cv);
    } catch (_) {
      // Not fatal — the field just starts empty; saving will still work.
    }
  }

  Future<void> _saveCv() async {
    setState(() {
      _cvBusy = true;
      _cvStatus = 'Saving…';
    });
    try {
      await ApiClient.instance.saveCv(_cvCtrl.text);
      if (mounted) setState(() => _cvStatus = 'CV saved.');
    } catch (e) {
      if (mounted) setState(() => _cvStatus = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _cvBusy = false);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _emailCtrl.dispose();
    _cvCtrl.dispose();
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
      setState(() => _status =
          'Connected as ${_emailCtrl.text.trim()}. Check your email to verify your account.');
      widget.onConnectionChanged();
      await _loadCv();
      await _loadAccount();
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await ApiClient.instance.disconnect();
    setState(() {
      _urlCtrl.clear();
      _emailCtrl.clear();
      _cvCtrl.clear();
      _slackCtrl.clear();
      _telegramCtrl.clear();
      _upgradeNoteCtrl.clear();
      _status = 'Disconnected.';
      _cvStatus = '';
      _accountStatus = '';
      _alertsStatus = '';
      _account = null;
    });
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
                    const Text(
                      'Account',
                      style: TextStyle(color: LedgerColors.parchment, fontFamily: 'Georgia', fontSize: 16),
                    ),
                    const SizedBox(height: 10),
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
                        'Alert channels',
                        style: TextStyle(color: LedgerColors.parchment, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Get new opportunities pushed automatically instead of pulling a scan yourself.",
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
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Backend',
                    style: TextStyle(color: LedgerColors.parchment, fontFamily: 'Georgia', fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  _field('Backend URL', _urlCtrl, hint: 'http://10.0.2.2:8000'),
                  _field('Email', _emailCtrl, hint: 'you@example.com'),
                  const SizedBox(height: 8),
                  const Text(
                    'This app never holds your Tavily/Groq/SMTP keys — those live on the '
                    'backend server. Connecting just registers this email and stores the '
                    'API key it gives back.',
                    style: TextStyle(color: LedgerColors.slate, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                  if (connected) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Your background / CV',
                      style: TextStyle(color: LedgerColors.parchment, fontFamily: 'Georgia', fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Paste your CV or a summary of your experience — used to draft tailored '
                      'CV highlights and cover letters for opportunities you choose to apply to.',
                      style: TextStyle(color: LedgerColors.slate, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cvCtrl,
                      maxLines: 8,
                      style: const TextStyle(color: LedgerColors.parchment, fontSize: 12, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.all(10),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _cvBusy ? null : _saveCv,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LedgerColors.brass,
                            side: const BorderSide(color: LedgerColors.brass),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                          ),
                          child: Text(_cvBusy ? 'Saving…' : 'Save CV'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_cvStatus, style: const TextStyle(color: LedgerColors.brass, fontSize: 12)),
                        ),
                      ],
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

  Widget _field(String label, TextEditingController ctrl, {String? hint}) {
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
        ],
      ),
    );
  }
}
