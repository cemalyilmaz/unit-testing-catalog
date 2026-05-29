import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'typing_indicator.dart';

void main() {
  group('TypingIndicator', () {
    const delay = Duration(milliseconds: 300);

    test('does not fire onStoppedTyping immediately on a keystroke', () {
      fakeAsync((fake) {
        final notifications = <String>[];
        final indicator = TypingIndicator(
          delay: delay,
          onStoppedTyping: notifications.add,
        );

        indicator.onKeystroke('conv-1');

        expect(notifications, isEmpty);

        indicator.dispose();
      });
    });

    test('fires onStoppedTyping after the delay elapses', () {
      fakeAsync((fake) {
        final notifications = <String>[];
        final indicator = TypingIndicator(
          delay: delay,
          onStoppedTyping: notifications.add,
        );

        indicator.onKeystroke('conv-1');
        fake.elapse(delay);

        expect(notifications, equals(['conv-1']));

        indicator.dispose();
      });
    });

    test('does not fire before the delay has fully elapsed', () {
      fakeAsync((fake) {
        final notifications = <String>[];
        final indicator = TypingIndicator(
          delay: delay,
          onStoppedTyping: notifications.add,
        );

        indicator.onKeystroke('conv-1');
        fake.elapse(const Duration(milliseconds: 299));

        expect(notifications, isEmpty);

        indicator.dispose();
      });
    });

    test('fires only once when the user types many characters in rapid succession', () {
      fakeAsync((fake) {
        final notifications = <String>[];
        final indicator = TypingIndicator(
          delay: delay,
          onStoppedTyping: notifications.add,
        );

        indicator.onKeystroke('conv-1');
        indicator.onKeystroke('conv-1');
        indicator.onKeystroke('conv-1');
        indicator.onKeystroke('conv-1');
        fake.elapse(delay);

        expect(notifications, equals(['conv-1']));
        expect(notifications.length, equals(1));

        indicator.dispose();
      });
    });

    test('does not fire after dispose is called', () {
      fakeAsync((fake) {
        final notifications = <String>[];
        final indicator = TypingIndicator(
          delay: delay,
          onStoppedTyping: notifications.add,
        );

        indicator.onKeystroke('conv-1');
        indicator.dispose();
        fake.elapse(delay);

        expect(notifications, isEmpty);
      });
    });
  });
}
