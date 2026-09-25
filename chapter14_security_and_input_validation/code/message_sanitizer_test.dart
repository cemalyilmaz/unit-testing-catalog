import 'package:flutter_test/flutter_test.dart';

import 'message_sanitizer.dart';

void main() {
  group('MessageSanitizer.sanitize', () {
    late MessageSanitizer sanitizer;

    setUp(() {
      sanitizer = MessageSanitizer();
    });

    // Attack-vector table: (name, input, expected output).
    // The table is the threat model. Every row is one claim the sanitizer
    // makes about one category of adversarial input.
    const attackVectors = [
      // --- benign input -----------------------------------------------
      (
        name: 'passes plain text unchanged',
        input: 'Hello, world!',
        expected: 'Hello, world!',
      ),
      (
        name: 'handles empty string',
        input: '',
        expected: '',
      ),
      // --- markup normalisation ---------------------------------------
      (
        name: 'strips HTML bold tags',
        input: '<b>bold text</b>',
        expected: 'bold text',
      ),
      (
        name: 'strips nested HTML tags',
        input: '<div><p>content</p></div>',
        expected: 'content',
      ),
      (
        name: 'strips script tags and neutralises inner content',
        input: '<script>alert(1)</script>',
        expected: 'alert(1)',
      ),
      (
        name: 'strips attribute-based vectors entirely',
        input: '<img src=x onerror=alert(1)>',
        expected: '',
      ),
      (
        name: 'removes null bytes',
        input: 'null\x00byte',
        expected: 'nullbyte',
      ),
      // --- strip bypasses: encoding is what makes these safe ----------
      (
        name: 'encodes what a nested-tag bypass leaves behind',
        // A single strip pass turns this into `ipt>alert(1)ipt>` — still
        // containing `>`. Encoding is why that residue is inert.
        input: '<scr<script>ipt>alert(1)</scr</script>ipt>',
        expected: 'ipt&gt;alert(1)ipt&gt;',
      ),
      (
        name: 'encodes an unclosed angle bracket',
        input: '1 < 2',
        expected: '1 &lt; 2',
      ),
      (
        name: 'encodes an ampersand so it cannot start an entity',
        input: 'Tom & Jerry',
        expected: 'Tom &amp; Jerry',
      ),
      (
        name: 'does not double-encode an existing entity by accident',
        // `&lt;` is plain text to the sanitizer: the user typed it.
        input: '&lt;',
        expected: '&amp;lt;',
      ),
      (
        name: 'encodes quotes so text is safe inside an attribute',
        input: '"quoted" and \'single\'',
        expected: '&quot;quoted&quot; and &#39;single&#39;',
      ),
      // --- out of scope, documented as such ---------------------------
      (
        name: 'passes SQL injection text through (parameterised queries handle it)',
        input: "'; DROP TABLE users; --",
        expected: '&#39;; DROP TABLE users; --',
      ),
    ];

    for (final vector in attackVectors) {
      test(vector.name, () {
        expect(sanitizer.sanitize(vector.input), equals(vector.expected));
      });
    }

    test('truncates input exceeding maxLength', () {
      final longInput = 'a' * (MessageSanitizer.maxLength + 1);
      expect(
        sanitizer.sanitize(longInput).length,
        equals(MessageSanitizer.maxLength),
      );
    });

    test('truncates after stripping tags, not before', () {
      // A 1001-char string wrapped in tags is truncated AFTER stripping,
      // so the result is maxLength characters of content, not of markup.
      final taggedInput = '<b>${'a' * 1001}</b>';
      expect(
        sanitizer.sanitize(taggedInput).length,
        equals(MessageSanitizer.maxLength),
      );
    });

    test('truncates before encoding so the limit counts characters, not entities',
        () {
      // maxLength ampersands: none are cut, and each becomes `&amp;`.
      final ampersands = '&' * MessageSanitizer.maxLength;
      expect(
        sanitizer.sanitize(ampersands),
        equals('&amp;' * MessageSanitizer.maxLength),
      );
    });

    test('never lets a raw angle bracket reach the output', () {
      // The property the whole pipeline exists to guarantee.
      const payloads = [
        '<script>alert(1)</script>',
        '<scr<script>ipt>alert(1)</scr</script>ipt>',
        '<img src=x onerror=alert(1)>',
        '<a href="javascript:alert(1)">click</a>',
        '<<b>b>',
        '>>>',
      ];
      for (final payload in payloads) {
        final out = sanitizer.sanitize(payload);
        expect(out, isNot(contains('<')), reason: payload);
        expect(out, isNot(contains('>')), reason: payload);
      }
    });
  });
}
