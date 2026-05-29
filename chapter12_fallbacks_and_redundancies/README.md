# Chapter 12: Fallbacks and Redundancies

> In the chat app, this is the lookup that resolves a single quoted message for the reply preview: try the server first, fall back to the local cache, and as a last resort show a "Message unavailable" placeholder. The UI must always render something — silence is not an option.

---

## Intent

Verify that when a primary strategy fails, the system activates the correct fallback, and that each level in a cascading fallback chain is independently tested.

---

## The Problem

`MessageRepository` loads a quoted message from the chat backend. When the backend is unavailable, it falls back to a local cache. When the cache is empty, it returns a placeholder so the reply preview still renders. This three-level cascade exists in the production code — but only the happy path (remote succeeds) is tested.

A developer refactors the fallback logic and accidentally swaps the cache lookup and the placeholder. The cache is now only checked after the placeholder is returned. In production, users on poor connections see "Message unavailable" instead of their cached preview. No test failed because no test ever exercised the second fallback level.

Fallback paths are the most important paths and the least tested. They are unreachable in development with a healthy network, so developers never see them during manual testing.

---

## Forces

You want resilient behavior across all failure scenarios — but each fallback level is only reachable when the previous level fails. In development, the remote source almost never fails. Without deliberately stubbing failures, the cache and placeholder paths never execute in tests.

The tension is between the apparent stability of a system that always works on a healthy network and the fragility that accumulates in paths that are never exercised. Stubs that can be configured to fail on demand resolve the tension: each test can independently put the system into the exact failure state needed to reach one specific fallback level.

---

## Solution

Define `MessageRemote` and `MessageCache` as abstract interfaces. Inject them into `MessageRepository`. In tests, use a configurable `StubMessageRemote` and a `MockMessageCache` that both records cache writes and serves cache reads.

Production code:

```dart
// See code/message_repository.dart
abstract class MessageRemote {
  Future<Message?> fetchMessage(String id);
}

abstract class MessageCache {
  Message? getCachedMessage(String id);
  void cacheMessage(String id, Message message);
}

class Message {
  final String id;
  final String body;

  const Message({required this.id, required this.body});

  static Message placeholderFor(String id) =>
      Message(id: id, body: 'Message unavailable');
}

class MessageRepository {
  final MessageRemote _remote;
  final MessageCache _cache;

  MessageRepository({required MessageRemote remote, required MessageCache cache})
      : _remote = remote,
        _cache = cache;

  Future<Message> getMessage(String id) async {
    try {
      final message = await _remote.fetchMessage(id);
      if (message != null) {
        _cache.cacheMessage(id, message);
        return message;
      }
    } catch (_) {
      // remote unavailable — fall through to cache
    }

    final cached = _cache.getCachedMessage(id);
    if (cached != null) return cached;

    return Message.placeholderFor(id);
  }
}
```

Test code:

```dart
// See code/message_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'message_repository.dart';

class StubMessageRemote implements MessageRemote {
  Message? _response;
  bool _shouldThrow = false;

  void willReturn(Message? message) => _response = message;
  void willThrow() => _shouldThrow = true;

  @override
  Future<Message?> fetchMessage(String id) async {
    if (_shouldThrow) throw Exception('Network unavailable');
    return _response;
  }
}

class MockMessageCache implements MessageCache {
  final Map<String, Message> _store = {};
  int cacheWriteCount = 0;

  @override
  Message? getCachedMessage(String id) => _store[id];

  @override
  void cacheMessage(String id, Message message) {
    cacheWriteCount++;
    _store[id] = message;
  }
}

void main() {
  group('MessageRepository.getMessage', () {
    late StubMessageRemote stubRemote;
    late MockMessageCache mockCache;
    late MessageRepository repository;

    setUp(() {
      stubRemote = StubMessageRemote();
      mockCache = MockMessageCache();
      repository = MessageRepository(remote: stubRemote, cache: mockCache);
    });

    test('returns remote message when remote succeeds', () async {
      stubRemote.willReturn(const Message(id: 'm1', body: 'hello'));

      final message = await repository.getMessage('m1');

      expect(message.body, equals('hello'));
    });

    test('writes remote message to cache when remote succeeds', () async {
      stubRemote.willReturn(const Message(id: 'm1', body: 'hello'));

      await repository.getMessage('m1');

      expect(mockCache.cacheWriteCount, equals(1));
      expect(mockCache.getCachedMessage('m1')?.body, equals('hello'));
    });

    test('returns cached message when remote throws', () async {
      stubRemote.willThrow();
      mockCache.cacheMessage('m1', const Message(id: 'm1', body: 'cached hello'));

      final message = await repository.getMessage('m1');

      expect(message.body, equals('cached hello'));
    });

    test('does not write to cache when falling back to cached message', () async {
      stubRemote.willThrow();
      mockCache.cacheMessage('m1', const Message(id: 'm1', body: 'cached hello'));
      final writeCountBefore = mockCache.cacheWriteCount;

      await repository.getMessage('m1');

      expect(mockCache.cacheWriteCount, equals(writeCountBefore));
    });

    test('returns placeholder Message when both remote throws and cache is empty', () async {
      stubRemote.willThrow();

      final message = await repository.getMessage('m1');

      expect(message.body, equals('Message unavailable'));
      expect(message.id, equals('m1'));
    });
  });
}
```

Each test puts the system into a specific state: remote succeeds, remote fails with cache populated, remote fails with empty cache. Each fallback level has its own test.

---

## Consequences

**Gains**
- Every fallback path is verified to activate under the exact conditions that trigger it in production.
- The cache write is asserted independently — a refactor that removes the caching step fails immediately.
- The placeholder path is named (`Message.placeholderFor`) rather than being an anonymous literal, making it testable as a value.

**Trade-offs**
- Three levels of fallback require three distinct failure configurations in tests. For deeper cascades, consider a test helper that builds the repository with preset stub behavior.
- Recovery testing (remote comes back online and the system switches back) requires more complex stubs that change behavior across calls. Covered by Chapter 8's `Completer`-based patterns.

---

## Implementation Notes

- The `StubMessageRemote` uses a simple boolean flag for `willThrow`. For more realistic scenarios — a transient failure that succeeds on retry — use a counter-based stub that throws for the first N calls and then succeeds.
- `MockMessageCache` serves a dual role: it is a **mock** for `cacheMessage` assertions (`cacheWriteCount`) and a **stub** for `getCachedMessage` return values. This is acceptable when both concerns are tightly coupled in the same test. See the [Glossary](../glossary/README.md) for the distinction.
- Test the fallback levels in isolation — do not test "all three levels fail together." Isolating each level produces failure messages that tell you which level regressed.

---

## Related Patterns

- [E6 — Fallback Mechanisms](../chapter05_exceptions/e06_fallback_mechanisms/README.md): Single-level fallback on exception.
- [Chapter 11 — Third-Party Integration](../chapter11_third_party_integration/README.md): How to isolate the remote source from the third-party library it wraps.
- [Chapter 4 — Side Effects](../chapter04_side_effects/README.md): The cache write is a side effect — the test for it follows the one-assertion-per-side-effect rule.

---

## Navigation

- Previous: [Chapter 11 — Third-Party Integration](../chapter11_third_party_integration/README.md)
- Next: [Chapter 13 — Performance and Timing](../chapter13_performance_and_timing/README.md)
- Back: [Catalog Index](../README.md)
