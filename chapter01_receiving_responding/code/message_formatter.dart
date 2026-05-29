class MessageFormatter {
  String relativeTime(DateTime timestamp, {required DateTime now}) {
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String preview(String body, {int maxLength = 40}) {
    if (body.length <= maxLength) return body;
    return '${body.substring(0, maxLength - 1)}…';
  }
}
