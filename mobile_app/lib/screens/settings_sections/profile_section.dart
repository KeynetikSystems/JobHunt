import 'package:flutter/material.dart';
import '../settings_controller.dart';

class ProfileSection extends StatelessWidget {
  final SettingsController controller;

  const ProfileSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Used to draft application materials (CV highlights, cover letters). "
          "Saved securely on our server, never shared with third parties.",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _field(controller.fullNameCtrl, 'Full Name'),
        _field(controller.phoneCtrl, 'Phone'),
        _field(controller.locationCtrl, 'Location (City, Country)'),
        _field(controller.linkedinCtrl, 'LinkedIn URL'),
        _field(controller.workHistoryCtrl, 'Work History', maxLines: 4),
        _field(controller.educationCtrl, 'Education', maxLines: 3),
        _field(controller.skillsCtrl, 'Skills & Keywords', maxLines: 3),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: controller.profileBusy ? null : () async {
            final msg = await controller.saveProfile();
            if (msg != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            }
          },
          child: Text(controller.profileBusy ? 'Saving...' : 'Save Profile'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}
