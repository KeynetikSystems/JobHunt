import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../settings_controller.dart';

class BackendSection extends ConsumerStatefulWidget {
  final SettingsController controller;

  const BackendSection({
    super.key,
    required this.controller,
  });

  @override
  ConsumerState<BackendSection> createState() => _BackendSectionState();
}

class _BackendSectionState extends ConsumerState<BackendSection> {
  bool _showPairing = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
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
        if (!isConnected) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.busy ? null : () => setState(() => _showPairing = !_showPairing),
              child: Text(_showPairing ? 'Hide pairing code' : 'Have a pairing code from another device?'),
            ),
          ),
          if (_showPairing) ...[
            const SizedBox(height: 4),
            TextField(
              controller: controller.pairingCodeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, letterSpacing: 2),
              decoration: const InputDecoration(
                labelText: 'Pairing Code',
                hintText: '6-digit code from your other device',
              ),
              enabled: !controller.busy,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: controller.busy
                    ? null
                    : () async {
                        final error = await controller.connectWithPairingCode();
                        if (error != null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error), backgroundColor: Colors.red[900]),
                            );
                          }
                        } else {
                          await ref.read(authProvider.notifier).notifyChanged();
                        }
                      },
                child: Text(controller.busy ? 'Pairing...' : 'Pair with Code'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
