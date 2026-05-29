# E6: Fallback Mechanisms

---

## Intent

Verify that when the primary path fails, the code activates its fallback path correctly.

---

## The Problem

`ChatManager` tries to send a message over the network. When the network is unavailable, it should queue the message for later delivery. This fallback exists in the code, but nobody has tested it. The network is usually reliable in development and in CI, so the fallback never activates.

A new engineer refactors the `sendMessage` method. The fallback queue logic is accidentally moved into the wrong branch. In production, on poor connections, messages silently disappear rather than being queued. No test caught it because the fallback was never exercised.

---

## Forces

- Fallback paths are not exercised by happy-path tests.
- The network, filesystem, or external service cannot be made to fail reliably in tests — you need a controlled substitute.
- The test must verify two things: that the fallback *activates*, and that the message ends up in the right place.

---

## Solution

Inject the network service as a dependency with an abstract interface. Use a stub that can be configured to simulate failure. Assert that the fallback queue contains the message after the failure.

Production code:

```dart
// See code/chat_manager.dart
abstract class NetworkService {
  Future<void> send(String message);
}

class NetworkUnavailableError implements Exception {}

class ChatManager {
  final NetworkService _networkService;
  final List<String> _pendingQueue = [];

  ChatManager({required NetworkService networkService})
      : _networkService = networkService;

  bool isMessageQueued(String message) => _pendingQueue.contains(message);

  Future<void> sendMessage(String message) async {
    try {
      await _networkService.send(message);
    } on NetworkUnavailableError {
      _pendingQueue.add(message);
    }
  }

  Future<void> retryQueuedMessages() async {
    final toRetry = List<String>.from(_pendingQueue);
    _pendingQueue.clear();
    for (final message in toRetry) {
      await sendMessage(message);
    }
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

class StubNetworkService implements NetworkService {
  bool simulateFailure = false;

  @override
  Future<void> send(String message) async {
    if (simulateFailure) {
      throw NetworkUnavailableError();
    }
  }
}

void main() {
  group('ChatManager fallback mechanisms', () {
    late StubNetworkService stubNetwork;
    late ChatManager chatManager;

    setUp(() {
      stubNetwork = StubNetworkService();
      chatManager = ChatManager(networkService: stubNetwork);
    });

    test('queues message when network is unavailable', () async {
      stubNetwork.simulateFailure = true;

      await chatManager.sendMessage('Hello!');

      expect(chatManager.isMessageQueued('Hello!'), isTrue);
    });

    test('does not queue message when network is available', () async {
      await chatManager.sendMessage('Hello!');

      expect(chatManager.isMessageQueued('Hello!'), isFalse);
    });

    test('retries queued messages when network becomes available', () async {
      stubNetwork.simulateFailure = true;
      await chatManager.sendMessage('Hello!');

      stubNetwork.simulateFailure = false;
      await chatManager.retryQueuedMessages();

      expect(chatManager.isMessageQueued('Hello!'), isFalse);
    });
  });
}
```

---

## Consequences

**Gains**
- The fallback path is verified to activate under failure conditions.
- The stub lets you force failure deterministically — no need to disconnect the network in tests.
- Both the failure path and the recovery path are covered.

**Trade-offs**
- Requires the network service to be injected rather than instantiated internally. Legacy code with hard-coded dependencies needs refactoring before this pattern applies.

---

## Implementation Notes

- Async tests in `flutter_test` use `async/await` naturally — mark the test callback `async` and `await` the method under test.
- The stub's `simulateFailure` flag is the simplest possible control surface. For more complex scenarios, use a queue of responses or a callback.
- This pattern is closely related to E5 (state after exception) — the fallback path also leaves the object in a specific state (the queue is populated), which is what you assert.

---

## Related Patterns

- [E5 — State After Exception](../e05_state_after_exception/README.md): State after the primary path fails.
- [Chapter 12 — Fallbacks and Redundancies](../../chapter12_fallbacks_and_redundancies/README.md): Broader treatment of redundancy patterns.

---

## Navigation

- Previous: [E5 — State After Exception](../e05_state_after_exception/README.md)
- Next: [E7 — Input Validation](../e07_input_validation/README.md)
- Back: [Chapter 5 Overview](../README.md)
