import 'package:flutter/material.dart';
import '../settings_controller.dart';

class AlertsSection extends StatelessWidget {
  final SettingsController controller;

  const AlertsSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = controller.account?.isPremium ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Local Notifications', style: TextStyle(fontSize: 14)),
          subtitle: const Text('New items from background scans', style: TextStyle(fontSize: 12)),
          value: controller.notificationsEnabled,
          onChanged: controller.setNotificationsEnabled,
          contentPadding: EdgeInsets.zero,
          activeColor: theme.colorScheme.primary,
        ),
        const Divider(height: 32),
        const Text(
          'External Alerts (Premium Only)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          "Get notified via Slack or Telegram as soon as roles matching your "
          "profile are found, even when the app is closed.",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.slackCtrl,
          enabled: isPremium && !controller.alertsBusy,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Slack Webhook URL',
            hintText: 'https://hooks.slack.com/...',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.telegramCtrl,
          enabled: isPremium && !controller.alertsBusy,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Telegram Chat ID',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: isPremium && !controller.alertsBusy ? () async {
            final msg = await controller.saveAlerts();
            if (msg != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            }
          } : null,
          child: Text(controller.alertsBusy ? 'Saving...' : 'Save Alert Settings'),
        ),
        if (!isPremium)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Available for Premium accounts.',
              style: theme.textTheme.labelLarge?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
