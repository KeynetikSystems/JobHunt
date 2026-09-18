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
}
