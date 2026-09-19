class NewsItem {
  final String headline;
  final String source;
  final String summary;
  final String url;

  const NewsItem({
    required this.headline,
    required this.source,
    required this.summary,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'source': source,
        'summary': summary,
        'url': url,
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        headline: json['headline'] as String? ?? '',
        source: json['source'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}
