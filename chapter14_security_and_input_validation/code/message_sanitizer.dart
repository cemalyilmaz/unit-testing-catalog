import 'dart:math';

/// Produces the display-safe form of a message body for an HTML context.
///
/// Tag stripping and null-byte removal are *normalisation* — they tidy
/// the text a chat client shows. They are not a security boundary: a
/// single-pass strip can be bypassed (`<scr<script>ipt>` survives it as
/// `ipt>`). The security boundary is the final step, HTML entity
/// encoding, which guarantees nothing in the output is interpreted as
/// markup no matter what the earlier steps missed.
class MessageSanitizer {
  static const int maxLength = 1000;

  String sanitize(String input) {
    final stripped = input
        .replaceAll(RegExp(r'<[^>]*>'), '') // normalise: drop markup
        .replaceAll('\x00', ''); // normalise: drop null bytes

    final truncated =
        stripped.substring(0, min(stripped.length, maxLength));

    return _encodeHtml(truncated); // security boundary: always last
  }

  static String _encodeHtml(String text) => text
      .replaceAll('&', '&amp;') // must run first so later entities survive
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
