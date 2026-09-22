import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/history_item.dart';
import '../theme.dart';
import 'application_materials_panel.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

class HistoryCard extends StatelessWidget {
  final HistoryItem item;
  const HistoryCard({super.key, required this.item});

  String _formatSeenAt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = item.isJob ? item.title : item.headline;
    final meta = item.isJob
        ? '${item.firm}  ·  ${item.seniority}'
        : item.source;
    final body = item.isJob ? item.note : item.summary;

    return InkWell(
      onTap: () => launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: item.isJob ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _formatSeenAt(item.seenAt),
                            style: theme.textTheme.labelLarge?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                      if (item.isJob)
                        ApplicationMaterialsPanel(job: {
                          'title': item.title,
                          'firm': item.firm,
                          'seniority': item.seniority,
                          'note': item.note,
                          'url': item.url,
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
