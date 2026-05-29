# E2: Exception Types

---

## Intent

Verify that a method throws the *correct type* of exception for each distinct failure condition.

---

## The Problem

Your `ChatManager` throws when a message is invalid *and* when the message limit is reached. Both failures trigger a `throw`. Your E1 test confirms that *something* is thrown. But the callers of `sendMessage` need to distinguish between the two cases — one should show "invalid message" in the UI, the other should disable the send button until the limit resets.

If both conditions throw the same generic `Exception`, callers cannot tell them apart. If the test only confirms that *an* exception is thrown, it cannot prevent a future refactor from collapsing both cases into one type.

---

## Forces

- A single method can have multiple, distinct failure modes that require different handling upstream.
- The exception *type* is the machine-readable signal; the message is for humans. Catching logic switches on type.
- Separate tests per failure mode make each failure mode's contract independently verifiable.

---

## Solution

Define a typed exception enum or hierarchy. Write one test per exception type, each exercising the specific condition that should trigger it.

Production code:

```dart
// See code/chat_manager.dart
class ChatError implements Exception {
  final String message;
  ChatError(this.message);
}

class InvalidMessageError extends ChatError {
  InvalidMessageError() : super('Message cannot be empty.');
}

class MessageLimitReachedError extends ChatError {
  MessageLimitReachedError() : super('Message limit reached.');
}

class ChatManager {
  static const int messageLimit = 100;
  final List<String> messages = [];

  void sendMessage(String message) {
    if (message.isEmpty) {
      throw InvalidMessageError();
    }
    if (messages.length >= messageLimit) {
      throw MessageLimitReachedError();
    }
    messages.add(message);
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

void main() {
  group('ChatManager.sendMessage exception types', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    test('throws InvalidMessageError for an empty message', () {
      expect(
        () => chatManager.sendMessage(''),
        throwsA(isA<InvalidMessageError>()),
      );
    });

    test('throws MessageLimitReachedError when the limit is exceeded', () {
      for (var i = 0; i < ChatManager.messageLimit; i++) {
        chatManager.sendMessage('Test message $i');
      }

      expect(
        () => chatManager.sendMessage('one too many'),
        throwsA(isA<MessageLimitReachedError>()),
      );
    });

    test('does not throw for a valid message within the limit', () {
      expect(
        () => chatManager.sendMessage('Hello'),
        returnsNormally,
      );
    });
  });
}
```

---

## Consequences

**Gains**
- Each error case has a concrete type that both callers and tests can reference.
- Refactoring one error type cannot accidentally collapse it into another without tests failing.
- The error type hierarchy is documented via tests.

**Trade-offs**
- A proliferation of exception classes can be hard to maintain. Use a class hierarchy (`ChatError` base with subclasses) to group related errors.
- In Dart, unlike Java, exception types are not part of a method's signature. The tests are the only enforceable specification of which types are thrown.

---

## Implementation Notes

- Dart does not have checked exceptions. All exception type contracts live in documentation and tests.
- Prefer a sealed class hierarchy (Dart 3+) for exhaustive error modeling: `sealed class ChatError {}` with subclasses ensures `switch` statements handle every case.
- `returnsNormally` is the matcher for "this should not throw" — it makes the intent explicit rather than relying on a test passing by not crashing.

---

## Related Patterns

- [E1 — Exception Throwing](../e01_exception_throwing/README.md): Confirming that *something* is thrown.
- [E3 — Error Messages](../e03_error_messages/README.md): Asserting the human-readable message on the exception.
- [helper: Why E2 and E3 are separate tests](helper_is_in_e03.md)

---

## Navigation

- Previous: [E1 — Exception Throwing](../e01_exception_throwing/README.md)
- Next: [E3 — Error Messages](../e03_error_messages/README.md)
- Back: [Chapter 5 Overview](../README.md)
