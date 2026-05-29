# Chapter 15: State Transitions

> In the chat app, this is the lifecycle of a single outbound message — from draft to sent, to delivered, to read — with explicit failure and retry paths. Every transition is a named operation, and every disallowed combination throws rather than silently no-opping.

---

## Intent

Verify that every valid state transition produces the correct next state, every invalid transition is explicitly rejected, and the state machine is exhaustively specified by its test suite.

---

## The Problem

`MessageDelivery` tracks the lifecycle of an outbound message: drafting, sending, sent, delivered, read, or failed. A naive implementation represents this as a set of booleans and nullable fields: `bool isDraft`, `bool isSending`, `bool isDelivered`, `String? error`. A `markRead()` method checks `if (!isDelivered) return;` silently.

Six months later, there are eighteen combinations of boolean states, four of which are theoretically impossible but reachable through race conditions in the delivery-receipt pipeline. When `markRead()` is called from `Sending`, nothing happens — which is either correct or a bug, and nobody knows which because the intent was never written down. A developer adds a `retry()` call from `Drafting` and it silently no-ops, hiding a UI bug for months: the retry button appears to do nothing because there is nothing to retry.

Implicit state machines — booleans and nulls scattered across a class — have no exhaustive transition table. Every method must defensively check every other boolean. The test suite cannot be exhaustive because there is no canonical list of what is and is not valid.

---

## Forces

You want to verify that all transitions are valid and all invalid ones are rejected — but when state is represented as scattered booleans and nullable fields, the set of possible states is a combinatorial explosion. Writing a test for each combination is infeasible, and silently ignoring invalid inputs makes the tests misleading — passing tests say nothing about the behavior the code chose not to implement.

A `sealed class` state machine resolves the tension: every state becomes a named type, and the Dart compiler's exhaustiveness checking ensures no state is accidentally omitted in a `switch`. Every invalid transition is an explicit error. The test suite then has a complete, finite specification: one test per valid transition, one test per invalid transition — no gaps, no silent no-ops.

---

## Solution

Represent each state as a subclass of a `sealed class`. Each transition method guards its precondition with an `InvalidTransitionError`. Tests enumerate every valid and invalid transition.

Production code:

```dart
// See code/message_delivery.dart
sealed class MessageDeliveryState {}

class Drafting extends MessageDeliveryState {}

class Sending extends MessageDeliveryState {
  final String clientId;
  Sending(this.clientId);
}

class Sent extends MessageDeliveryState {
  final String clientId;
  Sent(this.clientId);
}

class Delivered extends MessageDeliveryState {
  final String clientId;
  Delivered(this.clientId);
}

class Read extends MessageDeliveryState {
  final String clientId;
  Read(this.clientId);
}

class Failed extends MessageDeliveryState {
  final String clientId;
  final String error;
  Failed(this.clientId, this.error);
}

class InvalidTransitionError extends Error { /* ... */ }

class MessageDelivery {
  MessageDeliveryState _state = Drafting();

  MessageDeliveryState get state => _state;

  void queue(String clientId) {
    if (_state is! Drafting) throw InvalidTransitionError('queue', _state);
    _state = Sending(clientId);
  }

  void acknowledge() {
    if (_state is! Sending) throw InvalidTransitionError('acknowledge', _state);
    _state = Sent((_state as Sending).clientId);
  }

  void markDelivered() {
    if (_state is! Sent) throw InvalidTransitionError('markDelivered', _state);
    _state = Delivered((_state as Sent).clientId);
  }

  void markRead() {
    if (_state is! Delivered) throw InvalidTransitionError('markRead', _state);
    _state = Read((_state as Delivered).clientId);
  }

  void fail(String error) {
    if (_state is Sending) {
      _state = Failed((_state as Sending).clientId, error);
    } else if (_state is Sent) {
      _state = Failed((_state as Sent).clientId, error);
    } else {
      throw InvalidTransitionError('fail', _state);
    }
  }

  void cancel() {
    if (_state is! Sending) throw InvalidTransitionError('cancel', _state);
    _state = Drafting();
  }

  void retry() {
    if (_state is! Failed) throw InvalidTransitionError('retry', _state);
    _state = Sending((_state as Failed).clientId);
  }
}
```

The state diagram:

```
Drafting --queue--> Sending --acknowledge--> Sent --markDelivered--> Delivered --markRead--> Read
                       |                       |
                       |  fail                 |  fail
                       v                       v
                     Failed <-----------------+
                       |
                       |  retry
                       v
                     Sending

  Sending --cancel--> Drafting
```

Test code:

```dart
// See code/message_delivery_test.dart
void main() {
  group('MessageDelivery — valid transitions', () {
    test('Drafting → Sending via queue', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-1');
      expect(delivery.state, isA<Sending>());
    });

    test('Sending → Sent via acknowledge', () { ... });
    test('Sent → Delivered via markDelivered', () { ... });
    test('Delivered → Read via markRead', () { ... });
    // ... eight valid transitions in total
  });

  group('MessageDelivery — invalid transitions throw InvalidTransitionError', () {
    test('cancel from Sent throws — sent messages cannot be unsent', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-1');
      delivery.acknowledge();
      expect(() => delivery.cancel(), throwsA(isA<InvalidTransitionError>()));
    });

    // ... ten invalid transitions in total
  });
}
```

The test file is a complete specification of the state machine. Reading it top to bottom reveals every state, every valid transition, and every invalid one — including the deliberate product decisions (you cannot unsend a sent message, you cannot retry a read message).

### A note on the `fail` vs `cancel` asymmetry

`cancel` is only valid from `Sending`, but `fail` is valid from both `Sending` *and* `Sent`. This is deliberate. `cancel` is a *user* action that revokes a message the network has not yet acknowledged; once the server has accepted the message, the user can no longer take it back (hence "sent messages cannot be unsent"). `fail`, by contrast, is a *system* signal: the network reports a problem the local code did not anticipate. A server-side rejection can arrive *after* the initial acknowledgement — a delivery pipeline failure, a moderation reversal, an account suspension mid-flight — and the local state machine must accept that signal or it ends up in a state that does not match reality. The two transitions look symmetric on the diagram and asymmetric in the code because they answer different questions: "can the user retract this?" and "can the server still reject this?"

---

## Consequences

**Gains**
- The `sealed class` makes the compiler an ally. A new state added to the sealed hierarchy without handling it in an exhaustive `switch` produces a compile error — not a runtime bug.
- Invalid transitions throw `InvalidTransitionError` rather than silently no-opping. Every caller knows exactly why an operation failed, and tests can assert on the exact error type.
- The test suite is exhaustive by inspection. Adding a new transition to production code without adding a test for it is visible — the test file's coverage is obvious because it mirrors the machine's structure.

**Trade-offs**
- Terminal states (`Read`) have no exit transition in this design. If editing a read message is a product requirement, an `edit()` transition must be added explicitly — which surfaces the decision in code rather than hiding it in a no-op.
- The `sealed class` approach requires Dart 3 (`>=3.0.0`), which this catalog already requires.

---

## Implementation Notes

- `InvalidTransitionError extends Error` (not `Exception`) because an invalid transition is a programming error — it indicates a caller violated the contract. `Error` is appropriate for bugs; `Exception` is for recoverable conditions.
- The production code uses `(_state as Sending).clientId` casts rather than pattern matching for brevity. In a larger codebase, prefer:

```dart
void acknowledge() {
  switch (_state) {
    case Sending(:final clientId):
      _state = Sent(clientId);
    default:
      throw InvalidTransitionError('acknowledge', _state);
  }
}
```

- The initial state `Drafting()` is constructed in the field initializer (`MessageDeliveryState _state = Drafting()`), so it is always valid before any method is called.

---

## Related Patterns

- [Chapter 2 — Changing State](../chapter02_changing_state/README.md): The foundational pattern for observing state changes via public getters.
- [Chapter 9 — Idempotence](../chapter09_idempotence/README.md): Some transitions (like cancelling an already-cancelled message) could be idempotent. This chapter shows why making them explicit errors is often the safer design.
- [E7 — Input Validation](../chapter05_exceptions/e07_input_validation/README.md): Rejecting invalid inputs at the API boundary.

---

## Navigation

- Previous: [Chapter 14 — Security and Input Validation](../chapter14_security_and_input_validation/README.md)
- Back: [Catalog Index](../README.md)
