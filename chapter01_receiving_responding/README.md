# Chapter 1: Receiving a Message and Responding

> In the chat app, this is the pure formatting helper that turns a message timestamp into a human-readable label like "5m ago" — no state, no collaborators, just input in and string out.

---

## Intent

Verify that a method returns the correct value when called with given inputs.

---

## The Problem

You write a `MessageFormatter` whose `relativeTime` method renders message timestamps as "just now", "5m ago", "3h ago", or "2d ago". It looks correct when you scroll the conversation list manually. Two weeks later a colleague changes the date arithmetic to use a third-party `Jiffy` package, and suddenly timestamps in the "minutes ago" range jump by one. Nobody notices until a user reports messages appearing to arrive a minute in the future.

The issue is not that the code was wrong when written — it is that there was no automatic check preventing the regression. Manual testing does not scale, and the absence of a test means every change to `relativeTime` requires a human to re-verify every case.

---

## Forces

You want to verify that a method does the right thing — but a unit test can only assert on something observable from outside the object. If a method returns nothing and changes no public state, there is nothing to assert on without reaching inside the class.

A method that returns a value is the one case where the observable output is directly available, requires no design change, and does not couple the test to internal representation. That makes it the natural starting point for testing.

---

## Solution

Write a test that calls the method with a known input and asserts on the return value. The method is treated as a pure message-response pair: send in, expect out.

Production code first:

```dart
// See code/message_formatter.dart
class MessageFormatter {
  String relativeTime(DateTime timestamp, {required DateTime now}) {
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String preview(String body, {int maxLength = 40}) {
    if (body.length <= maxLength) return body;
    return '${body.substring(0, maxLength - 1)}…';
  }
}
```

Note that `now` is injected. A pure function that depends on "the current time" is not actually pure — `DateTime.now()` makes the result time-dependent and the test flaky. Pushing `now` to the parameter list keeps the method a true message-response pair.

Test code:

```dart
// See code/message_formatter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'message_formatter.dart';

void main() {
  group('MessageFormatter', () {
    late MessageFormatter formatter;
    late DateTime now;

    setUp(() {
      formatter = MessageFormatter();
      now = DateTime(2026, 5, 29, 12, 0, 0);
    });

    test('relativeTime returns "just now" for timestamps under a minute old', () {
      final timestamp = now.subtract(const Duration(seconds: 30));
      expect(formatter.relativeTime(timestamp, now: now), equals('just now'));
    });

    test('relativeTime returns minutes ago for timestamps under an hour old', () {
      final timestamp = now.subtract(const Duration(minutes: 5));
      expect(formatter.relativeTime(timestamp, now: now), equals('5m ago'));
    });

    test('relativeTime returns hours ago for timestamps under a day old', () {
      final timestamp = now.subtract(const Duration(hours: 3));
      expect(formatter.relativeTime(timestamp, now: now), equals('3h ago'));
    });

    test('relativeTime returns days ago for older timestamps', () {
      final timestamp = now.subtract(const Duration(days: 2));
      expect(formatter.relativeTime(timestamp, now: now), equals('2d ago'));
    });

    test('preview returns the body unchanged when shorter than the limit', () {
      expect(formatter.preview('hello'), equals('hello'));
    });
  });
}
```

The `expect(actual, equals(expected))` assertion reads like a sentence: "expect that `formatter.relativeTime(timestamp, now: now)` equals `'5m ago'`."

---

## Consequences

**Gains**
- Regressions are caught automatically the moment they are introduced.
- The test documents the contract of the method in a form that is always up to date.
- Tests of pure return values are the fastest and most reliable category of unit test — no setup complexity, no flakiness.

**Trade-offs**
- This pattern only applies to methods that return a value. For methods that change state or call other objects, see Chapters 2 and 3.
- A test that only checks return values cannot detect side effects. If `relativeTime` also wrote to a log, this test would not catch a broken logger.

---

## Implementation Notes

- Prefer `equals(expected)` over `== expected` in matchers — it produces clearer failure messages.
- Test one behavior per `test()` call. Avoid asserting multiple unrelated things in a single test block.
- Name tests as sentences: `'relativeTime returns minutes ago for timestamps under an hour old'` is better than `'testRelativeTime'`.
- Use `group()` to cluster tests for the same class and `setUp()` to share initialization without duplicating it.
- Inject "the current time" rather than calling `DateTime.now()` inside the production code. A function that reads the clock is not pure, and pure-return tests need a pure function to assert against.

---

## Related Patterns

- **Chapter 2 — Changing State**: When the method's observable output is a state change rather than a return value.
- **Chapter 3 — Sending Out More Messages**: When the method's observable output is a call it makes to another object.
- **Chapter 6 — Adversarial Inputs**: Extends this pattern to inputs that violate happy-path assumptions (reversed order, empty collections, boundary values).

---

## Navigation

- Previous: [Introduction](../intro/README.md)
- Next: [Chapter 2 — Changing State](../chapter02_changing_state/README.md)
- Back: [Catalog Index](../README.md)
