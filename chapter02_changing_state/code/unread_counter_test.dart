import 'package:flutter_test/flutter_test.dart';

import 'unread_counter.dart';

void main() {
  group('UnreadCounter', () {
    late UnreadCounter unread;

    setUp(() {
      unread = UnreadCounter();
    });

    test('count starts at zero', () {
      expect(unread.count, equals(0));
    });

    test('increment raises count from 0 to 1 when a message arrives', () {
      unread.increment();
      expect(unread.count, equals(1));
    });

    test('multiple increments accumulate as more messages arrive', () {
      unread.increment();
      unread.increment();
      unread.increment();
      expect(unread.count, equals(3));
    });

    test('markAllRead returns count to zero after the user opens the chat', () {
      unread.increment();
      unread.increment();
      unread.markAllRead();
      expect(unread.count, equals(0));
    });
  });
}
