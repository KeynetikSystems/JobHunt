/// A previously seen job or news item, as returned by GET /api/history.
class HistoryItem {
  final String kind; // 'job' or 'news'
  final String url;
  final String title;
  final String firm;
  final String seniority;
  final String note;
  final String headline;
  final String source;
  final String summary;
  final DateTime seenAt;

  const HistoryItem({
    required this.kind,
    required this.url,
    this.title = '',
    this.firm = '',
    this.seniority = '',
    this.note = '',
    this.headline = '',
    this.source = '',
    this.summary = '',
    required this.seenAt,
  });

  bool get isJob => kind == 'job';

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      kind: json['kind'] ?? 'job',
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      firm: json['firm'] ?? '',
      seniority: json['seniority'] ?? '',
      note: json['note'] ?? '',
      headline: json['headline'] ?? '',
      source: json['source'] ?? '',
      summary: json['summary'] ?? '',
      seenAt: DateTime.tryParse('${json['seen_at']}Z') ?? DateTime.now(),
    );
  }
}
