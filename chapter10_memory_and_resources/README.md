# Chapter 10: Memory and Resource Management

> In the chat app, this is the helper that lives behind a conversation screen and holds every stream subscription the screen has opened — incoming messages, typing indicators, presence updates. When the user backs out of the chat, every one of those subscriptions must be cancelled or the next screen leaks them.

---

## Intent

Verify that an object cancels all held resources when it is disposed, and that it rejects new work after disposal.

---

## The Problem

`IncomingMessageBinder` is used by a chat screen to listen to an incoming-messages stream, a typing-indicator stream, and a presence stream — one `StreamSubscription` per channel. When the user navigates away, `dispose()` is called. Six months later, a developer adds a fourth subscription but forgets to bind it through the binder. That subscription is never cancelled. Over time, the screen is opened and closed dozens of times, each time leaking another copy of the same subscription. Memory climbs. Stale events arrive on screens that no longer exist.

The bug is invisible in development and catastrophic in production. And it is never caught because no test verifies that `dispose()` actually cancels each subscription.

---

## Forces

You want to verify that `dispose()` cancels every subscription — but calling `dispose()` on the real object with real streams leaves no directly observable trace from the outside. The subscription objects are held internally; there is nothing to assert on after the fact without looking inside.

The resolution is to use the stream's own observable state. When a `StreamSubscription` is cancelled, the `StreamController` that produced it reports `hasListener == false`. The test creates real `StreamController` objects, binds their subscriptions through the binder, calls `dispose()`, and asserts on `controller.hasListener`. No mock is needed — the stream infrastructure itself becomes the oracle.

---

## Solution

Model the binder as a list of `StreamSubscription<dynamic>` objects with a `bind()` method and an async `dispose()`. Tests use `StreamController` instances to produce subscriptions and observe their cancellation.

Production code:

```dart
// See code/incoming_message_binder.dart
import 'dart:async';

class IncomingMessageBinder {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;
  int get subscriptionCount => _subscriptions.length;

  void bind(StreamSubscription<dynamic> subscription) {
    if (_isDisposed) {
      throw StateError('Cannot bind subscriptions to a disposed binder');
    }
    _subscriptions.add(subscription);
  }

  Future<void> dispose() async {
    _isDisposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
```

Test code:

```dart
// See code/incoming_message_binder_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'incoming_message_binder.dart';

void main() {
  group('IncomingMessageBinder', () {
    late IncomingMessageBinder binder;

    setUp(() {
      binder = IncomingMessageBinder();
    });

    test('cancels all subscriptions when disposed', () async {
      final incomingMessages = StreamController<String>();
      final typingIndicators = StreamController<bool>();

      binder.bind(incomingMessages.stream.listen((_) {}));
      binder.bind(typingIndicators.stream.listen((_) {}));

      await binder.dispose();

      expect(incomingMessages.hasListener, isFalse);
      expect(typingIndicators.hasListener, isFalse);

      await incomingMessages.close();
      await typingIndicators.close();
    });

    test('throws StateError when binding a subscription after dispose', () async {
      await binder.dispose();
      final incomingMessages = StreamController<String>();

      expect(
        () => binder.bind(incomingMessages.stream.listen((_) {})),
        throwsA(isA<StateError>()),
      );

      await incomingMessages.close();
    });
  });
}
```

`StreamController.hasListener` reports whether any active subscriber is attached. After `subscription.cancel()` is called, it becomes `false`. The test does not need a mock — the stream's own API serves as the oracle.

---

## Consequences

**Gains**
- Every bound subscription has a verified cancellation test. Adding a new subscription to production code without binding it through the binder causes a test failure only if a test covers that subscription — which is a prompt to add one.
- `StateError` on post-dispose `bind()` catches a common mistake: a race condition where a callback fires after disposal and tries to bind a new subscription.

**Trade-offs**
- Requires `StreamController` in tests, which means the test creates the stream infrastructure rather than using a real source. This is appropriate for unit tests; integration tests should use real streams.
- `dispose()` is `async` because `StreamSubscription.cancel()` returns `Future<void>`. Tests must `await` it.

---

## Implementation Notes

- `StreamSubscription<dynamic>` accepts subscriptions from any stream type (`Stream<String>`, `Stream<int>`, etc.), making the binder reusable across every chat screen.
- In Flutter widgets, call `binder.dispose()` inside `State.dispose()`. In services, call it when the service is deregistered from a service locator.
- `StreamController.close()` should be called in tests after the controller is no longer needed to avoid the test runner warning about unclosed controllers. The `addTearDown` pattern keeps this tidy:

```dart
test('cancels subscription', () async {
  final controller = StreamController<String>();
  addTearDown(() async {
    if (!controller.isClosed) await controller.close();
  });
  // ... rest of test
});
```

---

## Related Patterns

- [E9 — Resource Cleanup](../chapter05_exceptions/e09_resource_cleanup/README.md): Releasing resources in error paths.
- [Chapter 4 — Side Effects](../chapter04_side_effects/README.md): Each subscription binding and cancellation is a side effect — test them independently.
- [Chapter 7 — Initial State and Setup](../chapter07_initial_state_and_setup/README.md): A binder before `dispose()` is called has a different valid state than one after.

---

## Navigation

- Previous: [Chapter 9 — Idempotence](../chapter09_idempotence/README.md)
- Next: [Chapter 11 — Third-Party Integration](../chapter11_third_party_integration/README.md)
- Back: [Catalog Index](../README.md)
