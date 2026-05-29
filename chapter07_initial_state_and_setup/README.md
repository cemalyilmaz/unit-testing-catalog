# Chapter 7: Initial State and Setup

> In the chat app, this is what happens when the user opens a conversation: the `ChatManager` is constructed, and an asynchronous history load brings the recent messages in from disk or the network. The first paint of the conversation depends on getting this initial state right.

---

## Intent

Verify that an object starts in the correct initial state, both before and after asynchronous setup operations.

---

## The Problem

`ChatManager` initializes with an empty `messages` list. Or does it? If a `MessageHistoryLoader` is provided, it pre-populates the list asynchronously when `loadHistory` is awaited. Without tests for both scenarios, you cannot tell whether the empty-list behavior is a deliberate default or a bug in the loader. A developer changes the constructor to eagerly fetch from cache, and now features that relied on an empty initial list — like the "no messages yet" placeholder — break.

Initial state is the foundation every other behavior builds on. If it is wrong, everything else is wrong too. Yet it is the one state that developers rarely test because the object "obviously" starts empty.

---

## Forces

You want to verify that a class starts in a known state — but initial state is the one state developers never test because the object "obviously" starts empty. By the time a bug in initial state is discovered, many other tests have already silently relied on a wrong assumption.

When initialization is asynchronous, there are two distinct starting points: the state immediately after construction, and the state after setup completes. A test that forgets to `await` the setup asserts against the first point while the code under test expects the second. The tension is that the relevant starting state depends on whether setup has run — and the compiler cannot tell you when you have tested the wrong one.

---

## Solution

Write explicit tests for the initial state: one for the synchronous post-construction state, one for the no-loader path, one for the loaded path after async setup completes, and one for the "replace, not append" contract.

Production code:

```dart
// See code/chat_manager.dart
abstract class MessageHistoryLoader {
  Future<List<String>> fetch(String conversationId);
}

class ChatManager {
  List<String> messages = [];
  final MessageHistoryLoader? _loader;

  ChatManager({MessageHistoryLoader? loader}) : _loader = loader;

  Future<void> loadHistory(String conversationId) async {
    if (_loader == null) return;
    messages = await _loader!.fetch(conversationId);
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

class StubMessageHistoryLoader implements MessageHistoryLoader {
  final List<String> _results;
  StubMessageHistoryLoader(this._results);

  @override
  Future<List<String>> fetch(String conversationId) async => _results;
}

void main() {
  group('ChatManager initial state', () {
    test('messages is empty before any setup', () {
      final manager = ChatManager();
      expect(manager.messages, isEmpty);
    });

    test('messages remains empty when no loader is provided', () async {
      final manager = ChatManager();
      await manager.loadHistory('conv-1');
      expect(manager.messages, isEmpty);
    });

    test('messages is populated with loader results after loadHistory', () async {
      final loader = StubMessageHistoryLoader(
        ['welcome to the chat', 'how can I help?'],
      );
      final manager = ChatManager(loader: loader);

      await manager.loadHistory('conv-1');

      expect(manager.messages, isNotEmpty);
      expect(
        manager.messages,
        equals(['welcome to the chat', 'how can I help?']),
      );
    });

    test('loadHistory replaces existing messages, not appends', () async {
      final loader = StubMessageHistoryLoader(['fresh history']);
      final manager = ChatManager(loader: loader);
      manager.messages = ['stale message'];

      await manager.loadHistory('conv-1');

      expect(manager.messages, equals(['fresh history']));
    });
  });
}
```

---

## Consequences

**Gains**
- The initial state is explicitly part of the contract, not an implicit assumption.
- Async setup is verified: the test waits for the loader, then asserts — no race conditions.
- The fourth test (replace, not append) reveals an easily-missed behavioral contract that would otherwise show up as duplicate messages in production.

**Trade-offs**
- Async tests require `async/await` in the test callback. This is idiomatic in Dart but easy to forget — a test that forgets `await` will pass even if the assertion would fail after the future resolves.

---

## Implementation Notes

- Mark async test callbacks with `async` and `await` every `Future` — skipping `await` causes the test to complete before the future resolves, making it pass vacuously.
- The stub loader uses `async => _results` (a synchronous future) so tests are deterministic and do not require timers or delays.
- `setUp()` creates a new instance for each test. Do not use a single manager instance shared across tests — initial state tests are the first to break from shared state.

---

## Related Patterns

- [Chapter 2 — Changing State](../chapter02_changing_state/README.md): Verifying state after method calls.
- [Chapter 6 — Adversarial Inputs](../chapter06_adversarial_inputs/README.md): The empty collection is itself an adversarial input category.
- [Chapter 8 — Concurrency and Timing](../chapter08_concurrency_and_timing/README.md): More complex async testing patterns.

---

## Navigation

- Previous: [Chapter 6 — Adversarial Inputs](../chapter06_adversarial_inputs/README.md)
- Next: [Chapter 8 — Concurrency and Timing](../chapter08_concurrency_and_timing/README.md)
- Back: [Catalog Index](../README.md)
