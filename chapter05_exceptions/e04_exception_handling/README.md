# E4: Exception Handling

---

## Intent

Verify that the catching code responds correctly when an exception is thrown.

---

## The Problem

`ChatManager.sendMessage` catches a `ProhibitedContentError` internally and is supposed to notify the user via a `UserNotifier`. You confirm the exception type and message in E2 and E3. But neither of those tests verifies what `ChatManager` *does* when it catches the error.

A developer refactors the catch block, accidentally removing the `notifier.notify()` call. The exception type test passes. The message test passes. But users never receive a notification when prohibited content is detected. The handling behavior had no test protecting it.

---

## Forces

- The exception catching logic is a separate concern from the throwing logic. Tests for one should not implicitly cover the other.
- The handler often produces a *side effect* (notifying a user, logging, updating state) rather than a return value, so Chapter 3's mock pattern applies here.

---

## Solution

Inject the notifier as a collaborator. In the test, use a mock notifier and assert on what it received after the `sendMessage` call.

Production code:

```dart
// See code/chat_manager.dart
abstract class UserNotifier {
  void notify(String message);
}

class ProhibitedContentError implements Exception {
  final String message;
  ProhibitedContentError(this.message);
}

class ChatManager {
  final UserNotifier _notifier;

  ChatManager({required UserNotifier notifier}) : _notifier = notifier;

  bool sendMessage(String message) {
    if (message.contains('prohibited')) {
      _notifier.notify('Cannot send: message contains prohibited content.');
      return false;
    }
    return true;
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

class MockUserNotifier implements UserNotifier {
  String? lastNotification;

  @override
  void notify(String message) {
    lastNotification = message;
  }
}

void main() {
  group('ChatManager exception handling', () {
    late MockUserNotifier mockNotifier;
    late ChatManager chatManager;

    setUp(() {
      mockNotifier = MockUserNotifier();
      chatManager = ChatManager(notifier: mockNotifier);
    });

    test('notifies the user when a message contains prohibited content', () {
      chatManager.sendMessage('This is prohibited content');

      expect(
        mockNotifier.lastNotification,
        equals('Cannot send: message contains prohibited content.'),
      );
    });

    test('returns false when the message is rejected', () {
      final result = chatManager.sendMessage('prohibited text here');

      expect(result, isFalse);
    });

    test('returns true and does not notify for an acceptable message', () {
      final result = chatManager.sendMessage('Hello, world!');

      expect(result, isTrue);
      expect(mockNotifier.lastNotification, isNull);
    });
  });
}
```

---

## Consequences

**Gains**
- The handling behavior is explicitly verified, independently of the throwing behavior.
- The mock makes it impossible for the handler to silently skip the notification without a test failing.

**Trade-offs**
- Requires the handler to be designed with dependency injection. If the notifier is hard-coded inside the method, the test cannot substitute it.

---

## Implementation Notes

- This pattern is the Chapter 3 "Sending Out More Messages" pattern applied to error paths. The mock records what the handler told its collaborator.
- The three tests above cover three separate concerns: was the notifier called? was the right message passed? was the return value correct? Keep them as separate `test()` blocks.

---

## Related Patterns

- [Chapter 3 — Sending Out More Messages](../../chapter03_sending_out_more_messages/README.md): The general mock pattern.
- [E5 — State After Exception](../e05_state_after_exception/README.md): Checking the object's state after handling.

---

## Navigation

- Previous: [E3 — Error Messages](../e03_error_messages/README.md)
- Next: [E5 — State After Exception](../e05_state_after_exception/README.md)
- Back: [Chapter 5 Overview](../README.md)
