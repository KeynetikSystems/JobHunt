abstract class FeedItem {
  String get url;
  
  /// Converts the item to a JSON map compatible with the backend's /api/dismiss endpoint.
  Map<String, dynamic> toJson();
}
