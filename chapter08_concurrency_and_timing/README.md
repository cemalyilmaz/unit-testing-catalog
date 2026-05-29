# Chapter 8: Concurrency and Timing

> In the chat app, this is the outbound send queue: the user can fire several `sendMessage` calls in rapid succession before any of them complete. Each must succeed or fail on its own merits, without corrupting the others, and delivery receipts can land in any order after the fact.

---

## Intent

Verify that concurrent operations complete correctly, in the right order, and without corrupting shared state.

---

## The Problem

`ChatManager.sendMessage` issues a request to the server, awaits acknowledgement, and records the message's delivery status. You test a single send in isolation and it works. But in production, tapping send twice in 200ms causes one message's `DeliveryStatus` entry to overwrite the other's, because `_deliveryStatus` is a `Map` being written from multiple async contexts without synchronization.

Concurrency bugs are the hardest category of bug to reproduce because they depend on timing that varies between machines, builds, and runs. Without tests that deliberately exercise concurrent paths, these bugs survive code review and land in production.

---

## Forces

You want to test timing-dependent behavior — acknowledgement ordering, delivery receipts, cancellation — but real async operations complete at times the test cannot control. A test that passes today because a fast network happened to complete first will fail tomorrow for the opposite reason.

You want deterministic tests that run in milliseconds — but replacing every async operation with `Future.value()` removes the temporal behavior you are trying to test. A `Completer`-based stub resolves the tension: the test controls exactly when each future completes, making the timing deterministic without removing it.

---

## Solution

Model the sending service as an injectable interface. Use a stub that returns controlled `Future` results. Test concurrent sends, cancellation, delivery receipts, and error handling.

Production code:

```dart
// See code/chat_manager.dart
abstract class ChatDelegate {
  void onAcknowledged(String clientId);
  void onFailed(String clientId, Exception error);
  void onDeliveryReceipt(String clientId, DeliveryStatus status);
}

enum DeliveryStatus { sending, sent, delivered, read }

abstract class ChatSendingService {
  Future<void> send(String clientId, String body);
}

class ChatManager {
  final ChatSendingService _service;
  final Map<String, DeliveryStatus> _deliveryStatus = {};
  final Set<String> _activeSends = {};
  ChatDelegate? delegate;

  ChatManager({required ChatSendingService service}) : _service = service;

  bool isSending(String clientId) => _activeSends.contains(clientId);

  DeliveryStatus? deliveryStatusFor(String clientId) => _deliveryStatus[clientId];

  Future<void> sendMessage(String clientId, String body) async {
    if (_activeSends.contains(clientId)) return;
    _activeSends.add(clientId);
    _deliveryStatus[clientId] = DeliveryStatus.sending;
    try {
      await _service.send(clientId, body);
      _activeSends.remove(clientId);
      _deliveryStatus[clientId] = DeliveryStatus.sent;
      delegate?.onAcknowledged(clientId);
    } on Exception catch (e) {
      _activeSends.remove(clientId);
      _deliveryStatus.remove(clientId);
      delegate?.onFailed(clientId, e);
    }
  }

  void markDelivered(String clientId, DeliveryStatus status) {
    if (!_deliveryStatus.containsKey(clientId)) return;
    _deliveryStatus[clientId] = status;
    delegate?.onDeliveryReceipt(clientId, status);
  }

  void cancel(String clientId) {
    _activeSends.remove(clientId);
    _deliveryStatus.remove(clientId);
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

class StubChatSendingService implements ChatSendingService {
  Exception? errorToThrow;
  final Map<String, Completer<void>> _completers = {};

  Completer<void> completerFor(String clientId) {
    _completers[clientId] ??= Completer<void>();
    return _completers[clientId]!;
  }

  @override
  Future<void> send(String clientId, String body) {
    return completerFor(clientId).future.then((_) {
      if (errorToThrow != null) throw errorToThrow!;
    });
  }

  void completeSend(String clientId) {
    completerFor(clientId).complete();
  }
}

class MockChatDelegate implements ChatDelegate {
  final List<String> acknowledged = [];
  final List<(String, Exception)> failed = [];
  final List<(String, DeliveryStatus)> receipts = [];

  @override
  void onAcknowledged(String clientId) => acknowledged.add(clientId);

  @override
  void onFailed(String clientId, Exception error) =>
      failed.add((clientId, error));

  @override
  void onDeliveryReceipt(String clientId, DeliveryStatus status) =>
      receipts.add((clientId, status));
}

void main() {
  group('ChatManager', () {
    late StubChatSendingService stubService;
    late MockChatDelegate mockDelegate;
    late ChatManager manager;

    setUp(() {
      stubService = StubChatSendingService();
      mockDelegate = MockChatDelegate();
      manager = ChatManager(service: stubService)..delegate = mockDelegate;
    });

    test('handles concurrent sends independently', () async {
      final s1 = manager.sendMessage('msg-1', 'hello');
      final s2 = manager.sendMessage('msg-2', 'world');

      stubService.completeSend('msg-1');
      stubService.completeSend('msg-2');
      await Future.wait([s1, s2]);

      expect(mockDelegate.acknowledged, containsAll(['msg-1', 'msg-2']));
    });

    // ... see code/chat_manager_test.dart for the full suite
  });
}
```

The `Completer`-based stub is the key idea. `completerFor(clientId)` lets the *test* decide exactly when each individual send resolves. That is what makes ordering deterministic — the test can complete `msg-2` before `msg-1` and assert that delivery state is still correct.

---

## Consequences

**Gains**
- Concurrent paths are exercised with deterministic, controller-driven stubs — no flakiness from timing.
- Each concurrency concern (acknowledgement, failure, duplication, delivery receipts, cancellation) is a separate test.

**Trade-offs**
- The `Completer`-based stub requires understanding Dart's `Future` mechanics. Simpler scenarios can use `Future.value()` directly.
- True multi-isolate race conditions require `Isolate` tests and are beyond the scope of standard `flutter_test`.

---

## Testing Strategy for Concurrency

1. **Identify all async operations** — every `Future`, `Stream`, and callback.
2. **Identify shared state** — any field written from more than one async context (here, `_deliveryStatus`).
3. **Test completion paths** — acknowledgement, failure, delivery receipt, cancellation.
4. **Test concurrent execution** — starting N operations simultaneously, verifying each completes independently.
5. **Test ordering assumptions** — if operation A must complete before B, test that explicitly.

---

## Advanced Patterns

### Testing Timeouts

```dart
test('times out if the server never acknowledges a send', () async {
  // Do not complete the stub — simulate a hanging send
  final send = manager.sendMessage('msg-1', 'hello');

  await expectLater(
    send.timeout(const Duration(milliseconds: 100)),
    throwsA(isA<TimeoutException>()),
  );
});
```

### Testing Streams

```dart
test('emits delivery receipts as a stream', () async {
  final events = <DeliveryStatus>[];
  manager.deliveryStream('msg-1').listen(events.add);

  await manager.sendMessage('msg-1', 'hello');
  manager.markDelivered('msg-1', DeliveryStatus.delivered);
  manager.markDelivered('msg-1', DeliveryStatus.read);

  await Future.delayed(Duration.zero); // flush microtasks
  expect(events, equals([DeliveryStatus.delivered, DeliveryStatus.read]));
});
```

---

## Common Pitfalls

- **Forgetting `await`**: An async test that forgets to `await` the operation under test passes vacuously. Always `await` every `Future` in an async test.
- **Using real timers**: Tests with `Future.delayed(Duration(seconds: 1))` are slow and flaky. Use `FakeAsync` from `package:fake_async` for timer-dependent tests.
- **Shared test state**: Concurrent tests sharing a single manager instance can interfere. Use `setUp` to create fresh instances.

---

## Related Patterns

- [Chapter 7 — Initial State and Setup](../chapter07_initial_state_and_setup/README.md): Async initialization.
- [Chapter 4 — Side Effects](../chapter04_side_effects/README.md): Side effects in completion callbacks.
- [Chapter 13 — Performance and Timing](../chapter13_performance_and_timing/README.md): Testing timing constraints.

---

## Navigation

- Previous: [Chapter 7 — Initial State and Setup](../chapter07_initial_state_and_setup/README.md)
- Next: [Chapter 9 — Idempotence](../chapter09_idempotence/README.md)
- Back: [Catalog Index](../README.md)
