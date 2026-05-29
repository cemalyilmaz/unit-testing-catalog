import 'dart:math';

class MessageSanitizer {
  static const int maxLength = 1000;

  String sanitize(String input) {
    var result = input
        .replaceAll(RegExp(r'<[^>]*>'), '') // strip all HTML/script tags
        .replaceAll('\x00', ''); // remove null bytes

    return result.substring(0, min(result.length, maxLength));
  }
}
