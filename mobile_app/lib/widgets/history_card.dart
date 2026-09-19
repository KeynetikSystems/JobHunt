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
          color: LedgerColors.inkPanel,
          border: Border.all(color: LedgerColors.hairline),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: item.isJob ? LedgerColors.brass : LedgerColors.slate,
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
                              style: const TextStyle(
                                color: LedgerColors.parchment,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _formatSeenAt(item.seenAt),
                            style: const TextStyle(color: LedgerColors.slate, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: const TextStyle(
                          color: LedgerColors.brass,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(color: LedgerColors.slate, fontSize: 12),
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
