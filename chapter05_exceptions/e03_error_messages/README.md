# E3: Error Messages

---

## Intent

Verify that exceptions carry accurate, human-readable messages that reflect the specific failure.

---

## The Problem

Your `ChatManager` throws `InvalidMessageError` and `MessageLimitReachedError`. The types are correct. But the messages embedded in those exceptions are what users — or the logging system — actually see. If `InvalidMessageError` says "An error occurred" instead of "Message cannot be empty," a user cannot act on it, and a developer debugging a log has no context.

Tests for exception types (E2) do not verify messages. A test that only checks `isA<InvalidMessageError>()` will pass even if the message is empty, wrong, or hardcoded to the wrong value.

---

## Forces

- Messages change more often than types — localization, UI copy revisions, and logging format updates all touch messages without changing types.
- Separating type tests from message tests means you can update one without breaking the other.
- The message should be verified as a contract, not assumed to be stable.

---

## Solution

Use `throwsA(predicate(...))` or `throwsA(isA<T>().having(..., ..., ...))` to assert both the type and the message in a dedicated test:

Production code:

```dart
// See code/chat_manager.dart
class ChatError implements Exception {
  final String message;
  ChatError(this.message);

  @override
  String toString() => message;
}

class InvalidMessageError extends ChatError {
  InvalidMessageError() : super('Message cannot be empty.');
}

class MessageLimitReachedError extends ChatError {
  MessageLimitReachedError() : super('Message limit reached.');
}

class ChatManager {
  static const int messageLimit = 100;
  final List<String> _messages = [];

  void sendMessage(String message) {
    if (message.isEmpty) {
      throw InvalidMessageError();
    }
    if (_messages.length >= messageLimit) {
      throw MessageLimitReachedError();
    }
    _messages.add(message);
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

void main() {
  group('ChatManager error messages', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    test('InvalidMessageError carries the correct message', () {
      expect(
        () => chatManager.sendMessage(''),
        throwsA(
          isA<InvalidMessageError>().having(
            (e) => e.message,
            'message',
            equals('Message cannot be empty.'),
          ),
        ),
      );
    });

    test('MessageLimitReachedError carries the correct message', () {
      for (var i = 0; i < ChatManager.messageLimit; i++) {
        chatManager.sendMessage('Test $i');
      }

      expect(
        () => chatManager.sendMessage('overflow'),
        throwsA(
          isA<MessageLimitReachedError>().having(
            (e) => e.message,
            'message',
            equals('Message limit reached.'),
          ),
        ),
      );
    });
  });
}
```

The `.having()` matcher extracts a property from the matched object and runs a further assertion on it — here, it extracts `e.message` and checks it against the expected string.

---

## Consequences

**Gains**
- Message copy is pinned by tests — accidental changes to error strings are caught immediately.
- Error message contracts are documented alongside type contracts.

**Trade-offs**
- Message tests are more brittle than type tests under localization: a test asserting the English string will fail when the app is localized. For localized apps, assert on a message key or a stable identifier instead of the string itself.
- The `.having()` API can be verbose. For simpler assertions, a `predicate` matcher is an alternative.

---

## Implementation Notes

- The `.having((e) => e.property, 'description', matcher)` pattern is the idiomatic way to assert on exception properties in `flutter_test`.
- Override `toString()` on your exception class so stack traces and log output print the message rather than a type name.

---

## Related Patterns

- [E2 — Exception Types](../e02_exception_types/README.md): The type-only assertion.
- [E4 — Exception Handling](../e04_exception_handling/README.md): What happens after the exception is caught.

---

## Navigation

- Previous: [E2 — Exception Types](../e02_exception_types/README.md)
- Next: [E4 — Exception Handling](../e04_exception_handling/README.md)
- Back: [Chapter 5 Overview](../README.md)
