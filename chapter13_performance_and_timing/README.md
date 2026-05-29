# Chapter 13: Performance and Timing

> In the chat app, this is the helper that tells the server "the local user has stopped typing" after a short period of inactivity. Each keystroke resets the timer; the network notification only fires once, after the user has actually paused — never on every keystroke.

---

## Intent

Verify that time-sensitive logic behaves correctly at precise intervals, using a controllable clock that makes timing tests fast and deterministic.

---

## The Problem

`TypingIndicator` waits 300 ms after the user stops typing before firing the "stopped typing" callback. It cancels any pending timer when a new keystroke arrives. This prevents a server notification on every keystroke.

You write a test with `Future.delayed(Duration(milliseconds: 350))` to wait for the timer to fire. The test is slow (350 ms per test), non-deterministic (it fails on an overloaded CI machine where 350 ms is not enough), and still incomplete — it never verifies that intermediate keystrokes are suppressed, because doing so would require sub-millisecond timing control.

More fundamentally, removing the `Timer` to make the test faster removes the behavior being tested. The indicator only exists because of the timing — without it, `onKeystroke` is just a callback wrapper.

---

## Forces

You want to verify timing-dependent behavior — fires after N ms, does not fire before, resets on new input — but real `Timer` calls make tests slow and non-deterministic. A test that passes today because the machine was fast enough will fail tomorrow for the opposite reason.

You want deterministic tests that complete in milliseconds — but replacing `Timer` with `Future.value()` removes the temporal behavior you are testing. `fakeAsync` from `flutter_test` resolves the tension: it replaces Dart's clock with a controllable substitute. The production code continues to use real `Timer`; in tests, `fakeAsync` intercepts those timers and only fires them when you explicitly advance the clock.

---

## Solution

Use `dart:async`'s `Timer` in production code. Wrap the entire test body in `fakeAsync(() { ... })` and advance the clock with `fake.elapse(Duration(...))`.

Production code:

```dart
// See code/typing_indicator.dart
import 'dart:async';

class TypingIndicator {
  final Duration delay;
  final void Function(String conversationId) onStoppedTyping;
  Timer? _timer;

  TypingIndicator({required this.delay, required this.onStoppedTyping});

  void onKeystroke(String conversationId) {
    _timer?.cancel();
    _timer = Timer(delay, () => onStoppedTyping(conversationId));
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
```

Test code:

```dart
// See code/typing_indicator_test.dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'typing_indicator.dart';

void main() {
  group('TypingIndicator', () {
    const delay = Duration(milliseconds: 300);

    test('fires only once when the user types many characters in rapid succession', () {
      fakeAsync((fake) {
        final notifications = <String>[];
        final indicator = TypingIndicator(
          delay: delay,
          onStoppedTyping: notifications.add,
        );

        indicator.onKeystroke('conv-1');
        indicator.onKeystroke('conv-1');
        indicator.onKeystroke('conv-1');
        indicator.onKeystroke('conv-1');
        fake.elapse(delay);

        expect(notifications, equals(['conv-1']));
        expect(notifications.length, equals(1));

        indicator.dispose();
      });
    });

    // ... see code/typing_indicator_test.dart for the full suite
  });
}
```

`fakeAsync` intercepts Dart's internal clock. When `fake.elapse(delay)` is called, all timers scheduled within that duration fire synchronously in the test thread. The test completes in microseconds regardless of the configured delay.

---

## Consequences

**Gains**
- Tests complete in microseconds, not milliseconds. A 10-test suite runs faster than a single `await Future.delayed(...)` would.
- Timing is exact — "does not fire at 299 ms" is verifiable. With real timers, testing sub-millisecond boundaries is not possible.
- `fakeAsync` catches a common mistake: a timer that fires immediately (delay of zero) or fires twice (timer not cancelled on new keystroke).

**Trade-offs**
- `fakeAsync` does not cover real elapsed wall-clock time. Integration tests still need real timers to verify end-to-end latency.
- Code that mixes `fakeAsync` with real `Isolate` timers will not work correctly — `fakeAsync` only controls timers on the current isolate.

---

## Implementation Notes

- `fakeAsync` lives in `package:fake_async`. Add `fake_async` to `dev_dependencies` in `pubspec.yaml` and `import 'package:fake_async/fake_async.dart';` in the test file.
- `fake.elapse()` advances the clock by the given duration and fires all timers scheduled within it. Use `fake.flushMicrotasks()` if you need to drain the microtask queue between elapse calls.
- The `TypingIndicator` uses `Timer` from `dart:async`. Do not replace it with a custom clock abstraction just for testability — `fakeAsync` makes that unnecessary.
- For a `RetryPolicy` with exponential backoff (`1s, 2s, 4s, 8s...`), the same pattern applies: call `fake.elapse(Duration(seconds: 1))` to fire the first retry, then `fake.elapse(Duration(seconds: 2))` for the second, and so on.

---

## Related Patterns

- [Chapter 8 — Concurrency and Timing](../chapter08_concurrency_and_timing/README.md): `Completer`-based stubs for async operation control.
- [E8 — Boundary Conditions](../chapter05_exceptions/e08_boundary_conditions/README.md): Testing at timing limits (exactly N ms, exactly N+1 ms).

---

## Navigation

- Previous: [Chapter 12 — Fallbacks and Redundancies](../chapter12_fallbacks_and_redundancies/README.md)
- Next: [Chapter 14 — Security and Input Validation](../chapter14_security_and_input_validation/README.md)
- Back: [Catalog Index](../README.md)
