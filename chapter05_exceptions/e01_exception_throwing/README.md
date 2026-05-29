# E1: Exception Throwing

> In the chat app, this is the first line of defense in the send pipeline: empty or whitespace-only messages must be rejected before they reach storage, the network, or the UI.

---

## Intent

Verify that a method throws an exception when it encounters a condition it cannot handle.

---

## The Problem

You write a `ChatManager` with a `sendMessage` method. You add a guard clause: if the body is empty (or whitespace only), the method should reject it. You test the happy path — sending "hello" works. But you never test the empty-body path, because it "obviously" throws.

Three months later, a refactor removes the guard clause by accident. Every test still passes. A user accidentally taps send on an empty input field, an empty message appears in their friend's conversation, and the empty bubble breaks layout in the message list. The method silently accepted invalid data because the test for the error path was never written.

---

## Forces

- You cannot observe that a method "correctly did nothing" — you can only assert that it threw, and what it threw.
- The happy path and the error path are equally part of the contract. Testing only one half leaves the contract half-verified.
- Dart exceptions are not declared in method signatures (unlike Java's checked exceptions or Swift's `throws`). Only a test makes the throwing behavior part of the public contract.

---

## Solution

Use `expect(() => method(), throwsA(isA<ErrorType>()))` to assert that calling the method throws the expected exception type.

Production code:

```dart
// See code/chat_manager.dart
class ChatError implements Exception {
  final String message;
  ChatError(this.message);

  @override
  String toString() => 'ChatError: $message';
}

class ChatManager {
  String? lastSent;

  void sendMessage(String body) {
    if (body.trim().isEmpty) {
      throw ChatError('Message body cannot be empty.');
    }
    lastSent = body;
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

void main() {
  group('ChatManager.sendMessage', () {
    late ChatManager manager;

    setUp(() {
      manager = ChatManager();
    });

    test('accepts a non-empty message', () {
      manager.sendMessage('hello');
      expect(manager.lastSent, equals('hello'));
    });

    test('throws ChatError when the message body is empty', () {
      expect(
        () => manager.sendMessage(''),
        throwsA(isA<ChatError>()),
      );
    });

    test('throws ChatError when the message body is whitespace only', () {
      expect(
        () => manager.sendMessage('   '),
        throwsA(isA<ChatError>()),
      );
    });

    test('does not record a lastSent message when an exception is thrown', () {
      try {
        manager.sendMessage('');
      } catch (_) {}
      expect(manager.lastSent, isNull);
    });
  });
}
```

---

## Consequences

**Gains**
- The throwing behavior becomes part of the automated contract — it cannot be silently removed.
- The test doubles as documentation: readers can see exactly which conditions cause exceptions.

**Trade-offs**
- The test only asserts that *something* is thrown. For the type and message, see E2 and E3.
- Writing a test for every possible invalid input can be verbose. Group related invalid inputs and name tests clearly.

---

## Implementation Notes

- `throwsA(isA<ChatError>())` is the standard pattern. For convenience matchers, `throwsException` asserts that any `Exception` is thrown; `throwsArgumentError` matches `ArgumentError` specifically.
- Do not use `try-catch` in your test to verify throwing — this hides failures. Use `expect(..., throwsA(...))` so failures surface as test failures, not silent passes. (The last test above uses `try-catch` only to *swallow* the exception so it can then assert on post-throw state — that is a different use, covered in detail in E5.)
- In Dart, `throw` can throw any object, not just `Exception` subclasses. Prefer extending `Exception` for domain errors to keep the type hierarchy meaningful.

---

## Related Patterns

- [E2 — Exception Types](../e02_exception_types/README.md): Asserting the specific type thrown.
- [E3 — Error Messages](../e03_error_messages/README.md): Asserting the message carried by the exception.
- [E5 — State After Exception](../e05_state_after_exception/README.md): Asserting object state after throwing.

---

## Navigation

- Previous: [Chapter 5 Overview](../README.md)
- Next: [E2 — Exception Types](../e02_exception_types/README.md)
- Back: [Catalog Index](../../README.md)
