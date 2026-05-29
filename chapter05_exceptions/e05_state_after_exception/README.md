# E5: State After Exception

---

## Intent

Verify that the object is in a consistent, well-defined state after an exception is thrown.

---

## The Problem

`ChatManager` enforces a rate limit. When the limit is hit, it throws `RateLimitExceededError` and is supposed to set `isSendingEnabled` to `false`. You test that the exception is thrown (E1). You test that it is the right type (E2). But you never check the state *after* the throw.

A developer changes the implementation: the rate limit is enforced, but the `isSendingEnabled` flag is not set correctly. The exception still throws. All the previous exception tests still pass. But the application is now in an inconsistent state — users can retry sending even though the rate limit has not reset, because the flag was not updated.

---

## Forces

- Throwing an exception is a state transition. The object should end up in a defined, predictable state.
- State corruption after an exception is among the hardest bugs to diagnose, because the exception itself can mask the root cause.
- The state assertion belongs in a separate test from the type/message assertions — it is a different observable.

---

## Solution

After forcing the exception, check the relevant state properties. Use `setUp` to reset between tests.

Production code:

```dart
// See code/chat_manager.dart
class RateLimitExceededError implements Exception {}

class ChatManager {
  final List<String> messageQueue = [];
  bool isSendingEnabled = true;

  void hitRateLimit() {
    isSendingEnabled = false;
  }

  void sendMessage(String message) {
    if (!isSendingEnabled) {
      throw RateLimitExceededError();
    }
    messageQueue.add(message);
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

void main() {
  group('ChatManager state after exception', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    test('message queue remains empty after rate limit exception', () {
      chatManager.hitRateLimit();

      try {
        chatManager.sendMessage('Hello!');
      } on RateLimitExceededError {
        // expected
      }

      expect(chatManager.messageQueue, isEmpty);
    });

    test('isSendingEnabled is false after rate limit is hit', () {
      chatManager.hitRateLimit();

      expect(chatManager.isSendingEnabled, isFalse);
    });

    test('throws RateLimitExceededError when sending is disabled', () {
      chatManager.hitRateLimit();

      expect(
        () => chatManager.sendMessage('Hello!'),
        throwsA(isA<RateLimitExceededError>()),
      );
    });

    test('successfully adds message to queue when sending is enabled', () {
      chatManager.sendMessage('Hello!');

      expect(chatManager.messageQueue, contains('Hello!'));
    });
  });
}
```

---

## Consequences

**Gains**
- State invariants after error paths are explicitly tested, not assumed.
- The test serves as precise documentation: "after a rate limit exception, the queue is empty and sending is disabled."

**Trade-offs**
- Requires the exception to leave the object in a testable (readable) state. Design classes to expose the state properties that matter to callers.

---

## Implementation Notes

- Catching the exception inside the test with `on RateLimitExceededError` (as shown above) is appropriate here because the *point* of the test is what happens after the catch, not whether the exception was thrown. Keep separate tests for the throwing behavior.
- If multiple state properties must be consistent after an exception, verify each in its own `test()` for the clearest failure messages.

---

## Related Patterns

- [E1 — Exception Throwing](../e01_exception_throwing/README.md): Verifying the exception is thrown at all.
- [Chapter 2 — Changing State](../../chapter02_changing_state/README.md): The general state-assertion pattern.
- [Chapter 9 — Idempotence](../../chapter09_idempotence/README.md): Verifying state consistency when methods are called repeatedly.

---

## Navigation

- Previous: [E4 — Exception Handling](../e04_exception_handling/README.md)
- Next: [E6 — Fallback Mechanisms](../e06_fallback_mechanisms/README.md)
- Back: [Chapter 5 Overview](../README.md)
