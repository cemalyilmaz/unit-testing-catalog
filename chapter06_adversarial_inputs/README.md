# Chapter 6: Adversarial Inputs

---

## Intent

Verify that a method's guarantees hold when input structure violates the assumptions built into happy-path tests — reversed order, empty collections, duplicates, and other conditions that real callers will produce.

---

## The Problem

`ChatManager` sorts messages by timestamp so they display in chronological order. The developer writes a test that creates three messages with ascending timestamps and receives them in the same ascending order. The test passes.

Later, network latency causes message 3 to arrive before message 2. The code has a sorting step — but it was never tested with out-of-order input, because the test data was always created in the order the developer found convenient. A refactor of the sorting logic silently breaks the comparison. All tests continue to pass. The defect surfaces in production, where inputs arrive in the order the network decides, not the order the developer imagined.

The mistake was not writing too few tests. It was writing tests where every input was already in the shape the code expected. The test data confirmed the assumption instead of challenging it.

---

## Forces

You want a test suite that gives you confidence the code is correct. But tests written with convenient, developer-authored data only confirm the path you already assumed would work. The implicit assumption of happy-path data — that messages arrive in order, that collections are non-empty, that values are distinct — is exactly what production inputs will violate.

You cannot enumerate every possible input. But you can enumerate the *structural categories* of input your method must handle — ordering, size extremes, duplicates, reversals — and write one test per category. The tension is between the cost of this deliberate effort and the risk of shipping code whose guarantees were never actually tested, only assumed.

---

## Solution

The strategy has three steps:

**Step 1 — Identify the structural assumptions in your happy-path test data.** Ask: does my test data arrive in the most convenient order? Is the collection always non-empty? Are all values distinct? Each "yes" is an assumption that production will violate.

**Step 2 — Enumerate the input categories that break each assumption.** For ordering: reversed, out-of-order, interleaved. For size: empty, single element. For values: duplicates, ties, maximum/minimum.

**Step 3 — Write one test per category that forces the exact condition.** Name the test after the condition being forced, not after the method being called.

Applied to `ChatManager`:

Production code:

```dart
// See code/chat_manager.dart
class Message {
  final String id;
  final String text;
  final double timestamp;

  const Message({
    required this.id,
    required this.text,
    required this.timestamp,
  });
}

class ChatManager {
  final List<Message> messages = [];

  void receiveMessage(Message message) {
    messages.add(message);
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

void main() {
  group('ChatManager adversarial inputs', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    // Category: out-of-order delivery
    test('sorts messages into chronological order when they arrive out of order',
        () {
      // Messages created with timestamps: "Hello"=1.0, "!"=2.0, "World"=3.0
      // But received in the order: "!" (t=2.0), "Hello" (t=1.0), "World" (t=3.0)
      final thirdArrival =
          const Message(id: '2', text: '!', timestamp: 2.0);
      final firstArrival =
          const Message(id: '1', text: 'Hello', timestamp: 1.0);
      final secondArrival =
          const Message(id: '3', text: 'World', timestamp: 3.0);

      chatManager.receiveMessage(thirdArrival);
      chatManager.receiveMessage(firstArrival);
      chatManager.receiveMessage(secondArrival);

      final orderedTexts = chatManager.messages.map((m) => m.text).toList();
      expect(orderedTexts, equals(['Hello', '!', 'World']));
    });

    // Category: size extreme — single element
    test('handles a single message with no sorting needed', () {
      chatManager.receiveMessage(
        const Message(id: '1', text: 'Only message', timestamp: 1.0),
      );

      expect(chatManager.messages.length, equals(1));
      expect(chatManager.messages.first.text, equals('Only message'));
    });

    // Category: complete reversal
    test('handles two messages arriving in reverse order', () {
      chatManager.receiveMessage(
        const Message(id: '2', text: 'Second', timestamp: 2.0),
      );
      chatManager.receiveMessage(
        const Message(id: '1', text: 'First', timestamp: 1.0),
      );

      expect(chatManager.messages.first.text, equals('First'));
      expect(chatManager.messages.last.text, equals('Second'));
    });

    // Category: duplicate values — tie in sort key
    test('handles messages with identical timestamps (stable order)', () {
      chatManager.receiveMessage(
        const Message(id: '1', text: 'A', timestamp: 1.0),
      );
      chatManager.receiveMessage(
        const Message(id: '2', text: 'B', timestamp: 1.0),
      );

      // Both messages are present; neither is lost
      expect(chatManager.messages.length, equals(2));
    });
  });
}
```

Each test is labelled with the structural category it represents. When one of these tests fails, the failure name names the condition precisely — "handles two messages arriving in reverse order" is unambiguous in a CI log.

---

## Consequences

**Gains**
- Structural assumptions that were implicit become explicit, documented tests.
- Each category is independently named and independently protected against regression.
- The process of enumerating categories often reveals design assumptions the production code has never been forced to honour.

**Trade-offs**
- Identifying the relevant input categories requires deliberate thought about the contract each method is meant to fulfil. Start with the standard set: empty collection, single element, reversed order, duplicate values, maximum/minimum values.

---

## Implementation Notes

- Name each test after the structural category, not the method: `'handles two messages arriving in reverse order'` is far more useful in a CI failure log than `'testSort'`.
- In Dart, `List.sort()` is not guaranteed to be stable across all platforms. If ordering among equal-timestamp messages is semantically meaningful, use a stable sort or add a tie-breaker field (e.g., insertion sequence number).
- Boundary values (the numeric edge of a valid range) are a sub-category of adversarial input covered specifically in [E8 — Boundary Conditions](../chapter05_exceptions/e08_boundary_conditions/README.md). Apply this chapter's strategy first; reach for E8 when the adversarial input is specifically a limit value.

---

## Related Patterns

- [E8 — Boundary Conditions](../chapter05_exceptions/e08_boundary_conditions/README.md): Adversarial inputs at numeric limits — the minimum and maximum of a valid range.
- [Chapter 7 — Initial State and Setup](../chapter07_initial_state_and_setup/README.md): The empty collection is itself an adversarial input category; Chapter 7 addresses the setup discipline that makes the starting condition explicit.

---

## Navigation

- Previous: [Chapter 5 — Exceptions & Error Handling](../chapter05_exceptions/README.md)
- Next: [Chapter 7 — Initial State and Setup](../chapter07_initial_state_and_setup/README.md)
- Back: [Catalog Index](../README.md)
