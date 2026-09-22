/// Strips Dart's default "Exception: " noise and translates the handful of
/// low-level network exceptions users actually hit into plain language.
/// Shared across every screen/widget that surfaces an ApiClient failure to
/// the user, so error text reads the same everywhere instead of dumping a
/// raw stringified exception in some places and not others.
String friendlyError(Object e) {
  var msg = e.toString();
  if (msg.startsWith('Exception: ')) msg = msg.substring('Exception: '.length);
  final lower = msg.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('failed host lookup') ||
      lower.contains('clientexception')) {
    return "Couldn't reach the server — check your connection and backend URL in Settings.";
  }
  if (lower.contains('not found')) {
    return "Resource not found (404) — the backend may have changed or the session expired.";
  }
  return msg;
}
