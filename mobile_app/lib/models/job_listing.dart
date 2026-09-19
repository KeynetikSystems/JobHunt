class JobListing {
  final String title;
  final String firm;
  final String seniority;
  final String note;
  final String url;

  const JobListing({
    required this.title,
    required this.firm,
    this.seniority = 'Unspecified',
    required this.note,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'firm': firm,
        'seniority': seniority,
        'note': note,
        'url': url,
      };

  factory JobListing.fromJson(Map<String, dynamic> json) => JobListing(
        title: json['title'] as String? ?? '',
        firm: json['firm'] as String? ?? '',
        seniority: json['seniority'] as String? ?? 'Unspecified',
        note: json['note'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}

/// Rank used to sort jobs by seniority — lower is more junior. Anything
/// unrecognized (including "Unspecified") sorts last.
const seniorityRank = {
  'Graduate/Intern': 0,
  'Analyst/Junior': 1,
  'Associate/Mid': 2,
  'Manager/Senior': 3,
  'Director/Partner+': 4,
};

int seniorityRankOf(String seniority) => seniorityRank[seniority] ?? 99;
