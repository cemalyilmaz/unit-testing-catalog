# Appendix: Designing for Testability

This appendix is for readers whose classes have hard-coded dependencies and who are not sure how to make them testable. If your classes already use constructor injection and abstract interfaces, you can skip this entirely.

---

## The Problem

Here is a class that cannot be unit tested as written:

```dart
class ChatManager {
  final _analytics = FirebaseAnalytics();

  void sendMessage(String message) {
    _analytics.logEvent(
      'MessageSent',
      parameters: {'message': message},
    );
  }
}
```

You want to verify that `sendMessage` logs the correct analytics event. But `_analytics` is created inside the class. There is no way to reach it from a test, no way to replace it with a controllable double, and no way to observe what it was called with — without triggering a real Firebase call.

The class has no *seam*: no place where the test can insert a substitute for the real dependency.

---

## The Four Steps

### Step 1 — Name the dependency as a domain concept

`FirebaseAnalytics` is an implementation. What does `ChatManager` actually need from it? It needs something that can log an event with a name and parameters. Name that concept in your domain:

> An `AnalyticsService`.

This is a naming move, not a code move. But it forces the right question: what is the *contract* this dependency must fulfil, independent of which library implements it?

---

### Step 2 — Extract an abstract class for that contract

Write an abstract class with exactly the methods `ChatManager` calls. Nothing else.

```dart
abstract class AnalyticsService {
  void logEvent(String eventName, {Map<String, dynamic>? parameters});
}
```

This is the contract. `FirebaseAnalytics` is one implementation. Your test double will be another.

---

### Step 3 — Make `ChatManager` depend on the abstract class

Change the field type from `FirebaseAnalytics` to `AnalyticsService`:

```dart
class ChatManager {
  final AnalyticsService _analytics;   // depends on the contract, not the library

  void sendMessage(String message) {
    _analytics.logEvent(
      'MessageSent',
      parameters: {'message': message},
    );
  }
}
```

`ChatManager` no longer knows or cares what `AnalyticsService` is backed by.

---

### Step 4 — Move the creation outside the class

Remove `= FirebaseAnalytics()`. Accept the dependency through the constructor:

```dart
class ChatManager {
  final AnalyticsService _analytics;

  ChatManager({required AnalyticsService analytics})
      : _analytics = analytics;

  void sendMessage(String message) {
    _analytics.logEvent(
      'MessageSent',
      parameters: {'message': message},
    );
  }
}
```

`ChatManager` now receives an `AnalyticsService`. It does not create one. The constructor parameter is the seam — the place where a test can insert a double.

---

## The Before and After

| Before | After |
|---|---|
| `final _analytics = FirebaseAnalytics()` | `final AnalyticsService _analytics` |
| Class creates its own dependency | Class receives its dependency |
| No seam for a test double | Constructor is the seam |
| Untestable | Testable |

---

## What the Production App Does

In production, the real `FirebaseAnalytics` is wrapped in a concrete adapter and passed in at construction time — typically in your dependency injection setup or `main.dart`:

```dart
class FirebaseAnalyticsService implements AnalyticsService {
  final _firebase = FirebaseAnalytics.instance;

  @override
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    _firebase.logEvent(name: eventName, parameters: parameters);
  }
}

// In production setup:
final chatManager = ChatManager(
  analytics: FirebaseAnalyticsService(),
);
```

The adapter is written once. Everything else in the app — including every test — works against the abstract `AnalyticsService` contract.

---

## What the Test Does

With the design above, Chapter 4 applies directly:

```dart
class MockAnalyticsService implements AnalyticsService {
  String? capturedEventName;
  Map<String, dynamic>? capturedParameters;

  @override
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    capturedEventName = eventName;
    capturedParameters = parameters;
  }
}

void main() {
  test('sendMessage logs a MessageSent event', () {
    final mock = MockAnalyticsService();
    final manager = ChatManager(analytics: mock);

    manager.sendMessage('Hello');

    expect(mock.capturedEventName, equals('MessageSent'));
    expect(mock.capturedParameters?['message'], equals('Hello'));
  });
}
```

The four steps are what make this test possible. Without them, the test cannot be written.

---

## The Rule

> A class that creates its own dependencies cannot be unit tested in isolation.
> A class that receives its dependencies can.

Apply these four steps to any class that has a hard-coded collaborator before writing tests for it.

---

## Where to Go Next

- [Chapter 4 — Sending Out More Messages](../chapter04_side_effects/../chapter03_sending_out_more_messages/README.md): The pattern this design enables.
- [Glossary](../glossary/README.md): Definitions for mock, stub, seam, and collaborator.
