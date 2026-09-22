import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'settings_sections/account_section.dart';
import 'settings_sections/alerts_section.dart';
import 'settings_sections/backend_section.dart';
import 'settings_sections/profile_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.watch(settingsControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure your job hunt preferences and backend connection.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _section(
                    context,
                    controller,
                    'Backend',
                    BackendSection(controller: controller),
                  ),
                  _section(
                    context,
                    controller,
                    'Personal Profile',
                    ProfileSection(controller: controller),
                  ),
                  _section(
                    context,
                    controller,
                    'Alerts',
                    AlertsSection(controller: controller),
                  ),
                  _section(
                    context,
                    controller,
                    'Account',
                    AccountSection(controller: controller),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    dynamic controller,
    String title,
    Widget content,
  ) {
    final theme = Theme.of(context);
    final isExpanded = controller.sectionExpanded[title] ?? false;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isExpanded
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (val) => controller.toggleSection(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [content],
      ),
    );
  }
}
