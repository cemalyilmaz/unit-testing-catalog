import 'package:flutter_test/flutter_test.dart';

import 'message_formatter.dart';

void main() {
  group('MessageFormatter', () {
    late MessageFormatter formatter;
    late DateTime now;

    setUp(() {
      formatter = MessageFormatter();
      now = DateTime(2026, 5, 29, 12, 0, 0);
    });

    test('relativeTime returns "just now" for timestamps under a minute old', () {
      final timestamp = now.subtract(const Duration(seconds: 30));
      expect(formatter.relativeTime(timestamp, now: now), equals('just now'));
    });

    test('relativeTime returns minutes ago for timestamps under an hour old', () {
      final timestamp = now.subtract(const Duration(minutes: 5));
      expect(formatter.relativeTime(timestamp, now: now), equals('5m ago'));
    });

    test('relativeTime returns hours ago for timestamps under a day old', () {
      final timestamp = now.subtract(const Duration(hours: 3));
      expect(formatter.relativeTime(timestamp, now: now), equals('3h ago'));
    });

    test('relativeTime returns days ago for older timestamps', () {
      final timestamp = now.subtract(const Duration(days: 2));
      expect(formatter.relativeTime(timestamp, now: now), equals('2d ago'));
    });

    test('preview returns the body unchanged when shorter than the limit', () {
      expect(formatter.preview('hello'), equals('hello'));
    });

    test('preview truncates the body with an ellipsis when longer than the limit', () {
      final long = 'a' * 50;
      final result = formatter.preview(long, maxLength: 10);
      expect(result.length, equals(10));
      expect(result.endsWith('…'), isTrue);
    });
  });
}
