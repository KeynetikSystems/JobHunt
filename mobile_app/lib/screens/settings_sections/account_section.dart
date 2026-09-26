import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../settings_controller.dart';

class AccountSection extends StatelessWidget {
  final SettingsController controller;

  const AccountSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final account = controller.account;
    if (account == null) {
      return const Center(
        child: Text('Connect your backend to view account settings.',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoRow('Status', account.status, account.isPremium ? Colors.green : Colors.orange),
        _infoRow('Email', account.email, null),
        _infoRow('Connected', account.isVerified ? 'Verified' : 'Unverified',
            account.isVerified ? null : Colors.redAccent),
        const Divider(height: 32),
        if (!account.isVerified) ...[
          ElevatedButton(
            onPressed: controller.accountBusy ? null : () async {
              final msg = await controller.resendVerification();
              if (msg != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
            child: const Text('Resend Verification Email'),
          ),
          const SizedBox(height: 12),
        ],
        if (!account.isPremium) ...[
          const Text(
            'Request Premium',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Unlock unlimited searches, unlimited AI drafts, full history, and no ads.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.upgradeNoteCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Tell us why you need an upgrade...',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: controller.accountBusy ? null : () async {
              final msg = await controller.requestUpgrade();
              if (msg != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
            child: const Text('Submit Upgrade Request'),
          ),
          const Divider(height: 32),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined, size: 20),
          title: const Text('Privacy Policy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Read our data protection policies', style: TextStyle(fontSize: 11, color: Colors.grey)),
          trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
          onTap: () async {
            final uri = Uri.parse('https://jobhunt-privacy.keynetiksystems.com');
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open Privacy Policy URL.')),
                );
              }
            }
          },
        ),
        if (account.isVerified) ...[
          OutlinedButton(
            onPressed: controller.accountBusy ? null : () => _addDevice(context),
            child: const Text('Add Another Device'),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: controller.accountBusy ? null : () => _export(context),
                child: const Text('Export Data'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: controller.accountBusy ? null : () => _delete(context),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Delete Account'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _addDevice(BuildContext context) async {
    try {
      final (code, expiresInSeconds) = await controller.requestPairingCode();
      if (!context.mounted) return;
      final minutes = (expiresInSeconds / 60).round();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pairing Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'On your new device, enter this email and code:',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: 12),
              Text(
                'Expires in $minutes minutes, and works only once.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied.')));
              },
              child: const Text('Copy'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate a code: $e')));
    }
  }

  Future<void> _export(BuildContext context) async {
    try {
      final json = await controller.exportAccount();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your Data'),
          content: SingleChildScrollView(
            child: SelectableText(
              json!,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: json));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied.')));
              },
              child: const Text('Copy'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This action is irreversible. All your data will be wiped.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.deleteAccount();
    }
  }
}
