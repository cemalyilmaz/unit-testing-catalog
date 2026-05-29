# Chapter 4: Side Effects — Completeness of Outgoing Calls

> In the chat app, this is the full send-pipeline: when the user taps send, the message must be persisted to local storage, recorded in memory, broadcast to UI observers, *and* logged for analytics. Four side effects, one method call.

---

## Intent

Enumerate every outgoing call a method produces, verify each one independently, and confirm that unintended calls do not occur.

---

## The Problem

`ChatManager.sendMessage` does four things: persists the message to local storage, updates the in-memory `lastSent` record, broadcasts to all registered UI observers, and logs an analytics event. You write one test — the storage persist. The other three go unchecked.

Six months of feature work later, a developer removes the observer notification while fixing an unrelated bug. Conversation rows stop refreshing when the user sends a message — they only update after a manual pull-to-refresh. No test fails. The regression ships.

A combined test that asserts storage *and* observer in one block would have read:

```
expect(storage.persistedBody, equals('hello'));
expect(observer.callCount, equals(1));
```

When both break at once, the output tells you "something is wrong" but not *which* side effect regressed. That ambiguity costs investigation time. It also means you have been testing a policy ("these two things happen together") rather than a contract ("this specific thing happens at all").

---

## Forces

You want complete coverage of all outgoing calls — but a method with four side effects has four independently-owned contracts. Combining them into one test produces ambiguous failures. Testing them in four separate tests lets each one fail independently and precisely. The discipline of counting side effects before you write a single assertion forces you to look at the whole surface of the method, not just the one path you thought of first.

---

## Solution

### Step 1 — Enumerate before you write

Before writing any test, ask four questions about the method under test:

1. Does it write to storage or a database?
2. Does it notify observers or event listeners?
3. Does it change any field on `this`?
4. Does it call any other object's methods?

Each "yes" is one test case. For `sendMessage` the answers are yes (storage), yes (observers), yes (`_lastSent`), yes (analytics) — at minimum four tests, plus one for the "all observers receive the message" count and one negative assertion for the silent-mode guard.

### Step 2 — Inject and mock every collaborator

```dart
// See code/chat_manager.dart
abstract class MessageStorage {
  void persist(String conversationId, String body);
}

abstract class AnalyticsLogger {
  void log(String event, {Map<String, dynamic>? parameters});
}

abstract class ChatObserver {
  void messageDidSend(SentMessage message);
}

class SentMessage {
  final String conversationId;
  final String body;
  const SentMessage({required this.conversationId, required this.body});
}

class ChatManager {
  final MessageStorage _storage;
  final AnalyticsLogger _logger;
  final List<ChatObserver> _observers = [];
  SentMessage? _lastSent;

  ChatManager({required MessageStorage storage, required AnalyticsLogger logger})
      : _storage = storage,
        _logger = logger;

  SentMessage? get lastSent => _lastSent;

  void addObserver(ChatObserver observer) {
    _observers.add(observer);
  }

  void sendMessage(String conversationId, String body, {bool silent = false}) {
    final message = SentMessage(conversationId: conversationId, body: body);
    _storage.persist(conversationId, body);
    _lastSent = message;

    if (silent) return;

    _logger.log('MessageSent', parameters: {'conversationId': conversationId});
    for (final observer in _observers) {
      observer.messageDidSend(message);
    }
  }
}
```

The `silent` parameter is a real chat-app affordance — system messages and migrated history get persisted without spamming the UI or analytics. It also gives us the guard condition we need for the negative assertion in Step 3.

### Step 3 — One test per side effect, including negative assertions

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

class MockMessageStorage implements MessageStorage {
  String? persistedConversationId;
  String? persistedBody;

  @override
  void persist(String conversationId, String body) {
    persistedConversationId = conversationId;
    persistedBody = body;
  }
}

class MockAnalyticsLogger implements AnalyticsLogger {
  int callCount = 0;
  String? lastEvent;
  Map<String, dynamic>? lastParameters;

  @override
  void log(String event, {Map<String, dynamic>? parameters}) {
    callCount++;
    lastEvent = event;
    lastParameters = parameters;
  }
}

class MockChatObserver implements ChatObserver {
  int callCount = 0;
  SentMessage? lastMessage;

  @override
  void messageDidSend(SentMessage message) {
    callCount++;
    lastMessage = message;
  }
}

void main() {
  group('ChatManager.sendMessage side effects', () {
    late MockMessageStorage storage;
    late MockAnalyticsLogger logger;
    late MockChatObserver observer;
    late ChatManager manager;

    setUp(() {
      storage = MockMessageStorage();
      logger = MockAnalyticsLogger();
      observer = MockChatObserver();
      manager = ChatManager(storage: storage, logger: logger);
      manager.addObserver(observer);
    });

    test('persists the message to storage', () {
      manager.sendMessage('conv-1', 'hello');
      expect(storage.persistedConversationId, equals('conv-1'));
      expect(storage.persistedBody, equals('hello'));
    });

    test('updates the in-memory lastSent record', () {
      manager.sendMessage('conv-1', 'hello');
      expect(manager.lastSent?.body, equals('hello'));
    });

    test('notifies a registered observer once', () {
      manager.sendMessage('conv-1', 'hello');
      expect(observer.callCount, equals(1));
    });

    test('passes the sent message to the observer', () {
      manager.sendMessage('conv-1', 'hello');
      expect(observer.lastMessage?.body, equals('hello'));
    });

    test('logs an analytics event with the conversation id', () {
      manager.sendMessage('conv-1', 'hello');
      expect(logger.lastEvent, equals('MessageSent'));
      expect(logger.lastParameters?['conversationId'], equals('conv-1'));
    });

    test('notifies all registered observers', () {
      final secondObserver = MockChatObserver();
      manager.addObserver(secondObserver);

      manager.sendMessage('conv-1', 'hello');

      expect(observer.callCount, equals(1));
      expect(secondObserver.callCount, equals(1));
    });

    test('does not notify observers or log analytics when silent is true', () {
      manager.sendMessage('conv-1', 'hello', silent: true);

      expect(observer.callCount, equals(0));
      expect(logger.callCount, equals(0));
      expect(storage.persistedBody, equals('hello'));
    });
  });
}
```

The final test is the negative assertion. Absence of a call is as testable as presence. Without it, the guard `if (silent) return;` in production code is completely invisible to the test suite — and the next refactor that removes the silent-mode branch will pass every other test cleanly.

---

## Consequences

**Gains**
- Every side effect has an independently-failing test. When one breaks, the test output tells you exactly which side effect regressed, not just that something is wrong.
- Counting side effects before writing tests makes the method's full behavioral contract explicit. Gaps become obvious.
- Negative assertions give the guard conditions in production code their own safety net.

**Trade-offs**
- A method with many side effects requires many tests. This is a design signal: a method with five or more side effects may be doing too much and should be refactored.
- Observer patterns can cause memory leaks if observers are not removed. Use `tearDown` to release them; see Chapter 10 for resource management testing.

---

## Implementation Notes

- One test per side effect is a firm rule. Combined assertions produce ambiguous failures.
- `tearDown` runs after every test in the group. Use it to clean up shared state — removing observers, closing streams, releasing controllers. For cleanup that is specific to a single test, prefer `addTearDown(() { ... })` inside the test body.

```dart
setUp(() {
  observer = MockChatObserver();
  manager.addObserver(observer);
});

tearDown(() {
  // If observers held resources, release them here.
  // addTearDown() inside a test body for test-specific cleanup.
});
```

- Dart does not have `WeakReference`-based observer patterns built in. If your observers hold strong references, test that removing an observer stops notifications.
- `SentMessage` is an immutable value object — observers receive a snapshot, not a mutable reference to the manager's internal state. This pattern matters for observer-heavy code: see Chapter 10 for the resource-management side of the same coin.

---

## Related Patterns

- [Chapter 3 — Sending Out More Messages](../chapter03_sending_out_more_messages/README.md): The mechanics of testing a single outgoing call. Read Chapter 3 before this one.
- [Chapter 8 — Concurrency and Timing](../chapter08_concurrency_and_timing/README.md): Side effects in async contexts.
- [Chapter 9 — Idempotence](../chapter09_idempotence/README.md): Preventing duplicate side effects on repeated calls.

---

## Navigation

- Previous: [Chapter 3 — Sending Out More Messages](../chapter03_sending_out_more_messages/README.md)
- Next: [Chapter 5 — Exceptions & Error Handling](../chapter05_exceptions/README.md)
- Back: [Catalog Index](../README.md)
