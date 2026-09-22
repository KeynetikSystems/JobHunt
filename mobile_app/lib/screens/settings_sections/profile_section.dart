import 'package:flutter/material.dart';
import '../settings_controller.dart';

class ProfileSection extends StatelessWidget {
  final SettingsController controller;

  const ProfileSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Guidance Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Detailed profile info powers tailored AI cover letters & CV highlights for each job you select.",
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick Import Button
        OutlinedButton.icon(
          onPressed: controller.profileBusy ? null : () async {
            final msg = await controller.importCv();
            if (msg != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          icon: const Icon(Icons.upload_file, size: 20),
          label: Text(
            controller.profileBusy ? 'Parsing CV with AI...' : 'Auto-Fill from CV File (PDF / TXT)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),

        const SizedBox(height: 20),
        _sectionHeader(theme, 'CONTACT INFORMATION', Icons.person_outline),
        const SizedBox(height: 8),
        _field(
          controller.fullNameCtrl,
          'Full Name',
          hint: 'e.g., Jane Doe',
          helper: 'Your name as it should appear on cover letters',
        ),
        _field(
          controller.phoneCtrl,
          'Phone',
          hint: 'e.g., +44 7123 456789',
        ),
        _field(
          controller.locationCtrl,
          'Location',
          hint: 'e.g., London, UK (or Remote)',
          helper: 'Preferred working city or region',
        ),
        _field(
          controller.linkedinCtrl,
          'LinkedIn / Portfolio URL',
          hint: 'e.g., https://linkedin.com/in/janedoe',
        ),

        const SizedBox(height: 16),
        _sectionHeader(theme, 'EDUCATION & ACADEMICS', Icons.school_outlined),
        const SizedBox(height: 8),
        _field(
          controller.educationCtrl,
          'Education',
          hint: 'e.g., BSc Computer Science, University of Oxford (2018-2021)',
          helper: 'Degrees, institutions, honors, or relevant certifications',
          maxLines: 3,
        ),

        const SizedBox(height: 16),
        _sectionHeader(theme, 'BACKGROUND & EXPERIENCE', Icons.work_outline),
        const SizedBox(height: 8),
        _field(
          controller.workHistoryCtrl,
          'Work History',
          hint: 'e.g., Senior Consultant at Deloitte (2021-2024): led digital transformation projects...',
          helper: 'Include major roles, companies, dates, and key achievements',
          maxLines: 4,
        ),

        const SizedBox(height: 16),
        _sectionHeader(theme, 'SKILLS & COMPETENCIES', Icons.psychology_outlined),
        const SizedBox(height: 8),
        _field(
          controller.skillsCtrl,
          'Skills & Keywords',
          hint: 'e.g., Python, Financial Modeling, Strategy, Agile, React, SQL',
          helper: 'Comma-separated core skills, tools, and domain keywords',
          maxLines: 3,
        ),

        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: controller.profileBusy ? null : () async {
            final msg = await controller.saveProfile();
            if (msg != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            }
          },
          child: Text(controller.profileBusy ? 'Saving Profile...' : 'Save Profile'),
        ),
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    String? helper,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}
