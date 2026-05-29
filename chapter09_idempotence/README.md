# Chapter 9: Idempotence

> In the chat app, this is the retry-safe send: when the network drops mid-request, the client retries the same message — identified by a stable client-generated id — and neither the local state nor the UI should treat the retry as a new message.

---

## Intent

Verify that calling a state-changing operation multiple times produces the same final state as calling it once.

---

## The Problem

`ChatManager.send(clientMessageId, body)` is called when the user taps send. It should be safe to call multiple times with the same `clientMessageId` — if the network drops and the retry layer fires again, or if the lifecycle replays the call on a screen transition, the result should be the same as a single send: one entry in the local history, one notification to the UI.

Without a test, a developer adds a counter to track send attempts, and now calling `send('msg-1', 'hello')` three times produces three entries in the conversation. The operation is no longer idempotent. Tests that only call `send()` once will never catch this.

---

## Forces

You want to verify two distinct guarantees — that calling `send()` N times with the same `clientMessageId` leaves the message store in the same state as calling it once (idempotence of state), and that the delegate is not called N times for what is really the same logical send (deduplication of side effects). These are not the same guarantee and are not tested the same way. Treating them as one produces a test that conflates state with messaging, making it possible to pass the wrong implementation. Separating them requires naming each guarantee before writing a single assertion.

---

## Solution

### Step 1 — Name the guarantees before writing tests

Before writing any test, ask two questions about the method under test:

1. Must the object's visible state be the same after N calls as after 1 call?
2. Must side effects (delegate calls, network requests, notifications) be suppressed when the operation is logically the same?

Each "yes" is a separate test group. For `send()` both answers are yes — so there are two groups, each with independent tests.

### Step 2 — Production class

```dart
// See code/chat_manager.dart
abstract class ChatDelegate {
  void didSendMessage(String clientMessageId, String body);
}

class ChatManager {
  final Map<String, String> _sentBodies = {};
  ChatDelegate? delegate;

  /// Sends a message identified by a stable client-generated id.
  /// Calling send for an id that has already been sent does not change
  /// the recorded body and does not re-notify the delegate.
  void send(String clientMessageId, String body) {
    if (_sentBodies.containsKey(clientMessageId)) return;
    _sentBodies[clientMessageId] = body;
    delegate?.didSendMessage(clientMessageId, body);
  }

  String? bodyFor(String clientMessageId) => _sentBodies[clientMessageId];

  int get sentCount => _sentBodies.length;
}
```

The `_sentBodies` map keyed by `clientMessageId` is the dirty-state tracker that makes deduplication possible. The state idempotence guarantee falls out of the same mechanism: the map only gains an entry the first time a given `clientMessageId` is seen, so the visible state cannot diverge across retries.

### Step 3 — Test suite

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

class MockChatDelegate implements ChatDelegate {
  int callCount = 0;

  @override
  void didSendMessage(String clientMessageId, String body) {
    callCount++;
  }
}

void main() {
  group('ChatManager idempotence', () {
    test('state is unchanged after calling send multiple times with the same clientMessageId', () {
      final manager = ChatManager();

      manager.send('msg-1', 'hello');
      manager.send('msg-1', 'hello');
      manager.send('msg-1', 'hello');

      expect(manager.sentCount, equals(1));
      expect(manager.bodyFor('msg-1'), equals('hello'));
    });

    test('delegate is called once when send is called multiple times with the same clientMessageId', () {
      final mockDelegate = MockChatDelegate();
      final manager = ChatManager()..delegate = mockDelegate;

      manager.send('msg-1', 'hello');
      manager.send('msg-1', 'hello');
      manager.send('msg-1', 'hello');

      expect(mockDelegate.callCount, equals(1));
    });

    test('delegate is called again for a different clientMessageId', () {
      final mockDelegate = MockChatDelegate();
      final manager = ChatManager()..delegate = mockDelegate;

      manager.send('msg-1', 'hello');
      manager.send('msg-2', 'world');

      expect(mockDelegate.callCount, equals(2));
    });

    test('delegate is not called before any send', () {
      final mockDelegate = MockChatDelegate();
      ChatManager()..delegate = mockDelegate;

      expect(mockDelegate.callCount, equals(0));
    });
  });
}
```

The first test verifies state idempotence. The remaining three verify deduplication from three angles: repeated identical calls collapse to one notification, a different `clientMessageId` triggers a new notification, and the baseline that construction alone produces no notification.

---

## Consequences

**Gains**
- The idempotence guarantee is explicitly tested — retry layers cannot silently break it.
- The two patterns (state idempotence and side-effect deduplication) are clearly separated, making each independently verifiable.

**Trade-offs**
- Implementing deduplication requires the class to track which `clientMessageId`s have already been seen, adding memory cost proportional to the number of sent messages. In production, this is typically bounded by a TTL or LRU cache.

---

## Implementation Notes

- Idempotence of state is almost always free — if `send()` short-circuits on a duplicate `clientMessageId`, the state cannot diverge no matter how many times it is called. The test value is in protection against future regressions.
- Deduplication requires explicit tracking. In this example the `_sentBodies` map serves double duty as both storage and deduplication index. For larger systems, a separate `_seenClientIds` set is often clearer.
- A related concept is *atomicity*: the operation should either succeed fully or not at all. Idempotence tests do not verify atomicity — see Chapter 15 for state transition testing.

---

## Related Patterns

- [Chapter 2 — Changing State](../chapter02_changing_state/README.md): The basic state verification pattern.
- [Chapter 4 — Side Effects](../chapter04_side_effects/README.md): Testing that side effects occur.
- [Chapter 15 — State Transitions](../chapter15_state_transitions/README.md): Testing state machine transitions, including atomicity.

---

## Navigation

- Previous: [Chapter 8 — Concurrency and Timing](../chapter08_concurrency_and_timing/README.md)
- Next: [Chapter 10 — Memory and Resource Management](../chapter10_memory_and_resources/README.md)
- Back: [Catalog Index](../README.md)
