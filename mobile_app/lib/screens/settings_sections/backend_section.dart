import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../settings_controller.dart';

class BackendSection extends ConsumerWidget {
  final SettingsController controller;

  const BackendSection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = controller.account != null;

    return Column(
      children: [
        TextField(
          controller: controller.urlCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Backend URL',
            hintText: 'https://...',
          ),
          enabled: !controller.busy,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Email',
          ),
          enabled: !controller.busy,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.apiKeyCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Access Key (Optional)',
            hintText: 'Paste access key from email if already registered',
          ),
          enabled: !controller.busy,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (isConnected)
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.busy
                      ? null
                      : () async {
                          await controller.disconnect();
                          await ref.read(authProvider.notifier).notifyChanged();
                        },
                  child: const Text('Disconnect'),
                ),
              )
            else
              Expanded(
                child: ElevatedButton(
                  onPressed: controller.busy
                      ? null
                      : () async {
                          final error = await controller.connect();
                          if (error != null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: Colors.red[900],
                                ),
                              );
                            }
                          } else {
                            await ref.read(authProvider.notifier).notifyChanged();
                          }
                        },
                  child: Text(controller.busy ? 'Connecting...' : 'Connect'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
