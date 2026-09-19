import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_listing.dart';
import '../theme.dart';
import 'application_materials_panel.dart';

class JobCard extends StatelessWidget {
  final JobListing job;
  const JobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(job.url), mode: LaunchMode.externalApplication),
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
              Container(width: 3, color: LedgerColors.brass),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          color: LedgerColors.parchment,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${job.firm}  ·  ${job.seniority}',
                        style: const TextStyle(
                          color: LedgerColors.brass,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.note,
                        style: const TextStyle(color: LedgerColors.slate, fontSize: 12),
                      ),
                      ApplicationMaterialsPanel(job: {
                        'title': job.title,
                        'firm': job.firm,
                        'seniority': job.seniority,
                        'note': job.note,
                        'url': job.url,
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
