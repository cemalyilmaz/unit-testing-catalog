import 'package:flutter_test/flutter_test.dart';

import 'message_sanitizer.dart';

void main() {
  group('MessageSanitizer.sanitize', () {
    late MessageSanitizer sanitizer;

    setUp(() {
      sanitizer = MessageSanitizer();
    });

    const attackVectors = [
      (
        name: 'passes plain text unchanged',
        input: 'Hello, world!',
        expected: 'Hello, world!',
      ),
      (
        name: 'strips script tags and preserves inner content',
        input: '<script>alert(1)</script>',
        expected: 'alert(1)',
      ),
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
        name: 'removes null bytes',
        input: 'null\x00byte',
        expected: 'nullbyte',
      ),
      (
        name: 'handles empty string',
        input: '',
        expected: '',
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
      final taggedInput = '<b>${'a' * 1001}</b>';
      expect(sanitizer.sanitize(taggedInput).length, equals(MessageSanitizer.maxLength));
    });
  });
}
