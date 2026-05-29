# Chapter 2: Changing State

> In the chat app, this is the unread-message badge on each conversation row. Every incoming message bumps the count; opening the chat clears it. The class returns nothing — its whole job is to mutate state.

---

## Intent

Verify that a method correctly modifies the internal state of its object.

---

## The Problem

You have an `UnreadCounter` attached to each conversation. The `increment()` method bumps the badge when a new message arrives. Six months later another developer adds a "mark all read" feature and accidentally introduces an off-by-one error in `increment` — the count starts at 1 instead of 0 after `markAllRead`. The app ships with phantom unread badges that never go away.

The bug is not caught because no test verifies the value of `count` after calling `increment`. The method has no return value — its entire purpose is to change internal state — and without a test that reads that state, the change is invisible to automation.

---

## Forces

You want to verify the effect of a method that returns nothing — but a unit test can only assert on values it can read. A void method leaves nothing to evaluate directly; after calling it, the test is standing in front of a black box with no way out.

The first instinct is to read the internal field. Dart's library-private convention (`_count`) does not prevent a test in the same package from accessing it — technically, you could assert `unread._count == 1`. But this reaches past the object's contract into its storage. If the implementation changes — the counter switches from a single `int` to a list of unread message IDs whose length determines the count — the test breaks without any behavioral change. That is testing the filing cabinet, not what was filed.

The resolution is to recognise that a public getter is not an internal leak — it is the contract. When `UnreadCounter` exposes `int get count`, it is declaring: "reading this value is a supported operation." Asserting on `count` in a test is asserting on observable behavior, not implementation detail. The tension between "I need to see inside" and "I should not depend on internals" resolves the moment you treat the getter as a first-class output — because it is.

---

## Solution

Call the method, then read the object's state and assert the expected value. Use `setUp()` to create a fresh instance for every test so tests do not interfere with each other.

Production code:

```dart
// See code/unread_counter.dart
class UnreadCounter {
  int _count = 0;

  int get count => _count;

  void increment() {
    _count++;
  }

  void markAllRead() {
    _count = 0;
  }
}
```

Test code:

```dart
// See code/unread_counter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'unread_counter.dart';

void main() {
  group('UnreadCounter', () {
    late UnreadCounter unread;

    setUp(() {
      unread = UnreadCounter();
    });

    test('count starts at zero', () {
      expect(unread.count, equals(0));
    });

    test('increment raises count from 0 to 1 when a message arrives', () {
      unread.increment();
      expect(unread.count, equals(1));
    });

    test('multiple increments accumulate as more messages arrive', () {
      unread.increment();
      unread.increment();
      expect(unread.count, equals(2));
    });

    test('markAllRead returns count to zero after the user opens the chat', () {
      unread.increment();
      unread.increment();
      unread.markAllRead();
      expect(unread.count, equals(0));
    });
  });
}
```

The `setUp()` callback runs before every `test()`, so each test starts with a fresh `UnreadCounter` at zero. A failure in one test does not corrupt the state for the next.

---

## Consequences

**Gains**
- State-changing methods are explicitly covered — they cannot silently regress.
- Tests read like a specification: "after calling `increment`, `count` equals 1."
- `setUp` / `tearDown` isolate tests from each other, eliminating order-dependent failures.

**Trade-offs**
- The class must expose state for the test to read it. If you prefer to keep all fields private, you may need to add getters or rethink the interface.
- Testing every possible state sequence can be combinatorially expensive. Focus on the transitions that matter: from initial state, after the primary operation, after error paths.

---

## Implementation Notes

- Dart does not have access modifiers as strict as Swift's `private`. The `_count` naming convention (leading underscore) makes a field library-private, which is sufficient for encapsulation in production code while still being readable in tests within the same package.
- Prefer `late` for test subjects initialized in `setUp` — it communicates that the variable will always be set before use.
- Test the initial state explicitly (the "count starts at zero" test). Initial state bugs are common and easy to miss.

---

## Related Patterns

- **Chapter 1 — Receiving a Message and Responding**: When the observable output is a return value rather than a state change.
- **Chapter 7 — Initial State and Setup**: Deeper treatment of how to set up and verify initial state.
- **Chapter 9 — Idempotence**: Verifying that calling a state-changing method multiple times produces the same final state as calling it once.

---

## Navigation

- Previous: [Chapter 1 — Receiving a Message and Responding](../chapter01_receiving_responding/README.md)
- Next: [Chapter 3 — Sending Out More Messages](../chapter03_sending_out_more_messages/README.md)
- Back: [Catalog Index](../README.md)
