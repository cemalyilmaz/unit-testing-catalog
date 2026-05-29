# Chapter 3: Sending Out More Messages

---

## Intent

Verify that a method calls the correct methods on its collaborators, with the correct arguments.

---

## The Problem

`ChatManager.sendMessage` logs an analytics event. The method has no return value and changes no local state. From the outside, calling it appears to do nothing observable. How do you know the analytics event was actually logged? How do you verify the right event name and payload were used?

Without a test that specifically checks the outgoing call, a developer can rename the event key from `"MessageSent"` to `"message_sent"` in the production code and break the analytics dashboard without any test failing. The problem is invisible until a data analyst notices the gap days later in a report.

---

## Forces

You want to verify that the right outgoing call was made with the right arguments — but the real collaborator has side effects (network, billing, data) that make it unsuitable in tests. Calling the real service would make the test slow, flaky, and expensive.

You want to isolate the test to the subject's logic alone — but if the collaborator is never called, there is nothing to observe. The tension is that the interaction itself is what must be verified, yet the real participant in that interaction cannot be present.

---

## Solution

Introduce a hand-rolled mock that implements the same abstract interface as the real collaborator. Inject the double into the subject under test. After the method call, assert on what the double recorded.

In Dart, define the collaborator as an abstract class so the real implementation and the mock share the same contract:

```dart
// See code/chat_manager.dart
abstract class AnalyticsApi {
  void logEvent(String eventName, {Map<String, dynamic>? parameters});
}

class ChatManager {
  final AnalyticsApi _analyticsApi;

  ChatManager({required AnalyticsApi analyticsApi})
      : _analyticsApi = analyticsApi;

  void sendMessage(String message) {
    _analyticsApi.logEvent(
      'MessageSent',
      parameters: {'message': message},
    );
  }
}
```

Test code with a hand-rolled mock:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

class MockAnalyticsApi implements AnalyticsApi {
  String? capturedEventName;
  Map<String, dynamic>? capturedParameters;

  @override
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    capturedEventName = eventName;
    capturedParameters = parameters;
  }
}

void main() {
  group('ChatManager', () {
    late MockAnalyticsApi mockAnalytics;
    late ChatManager chatManager;

    setUp(() {
      mockAnalytics = MockAnalyticsApi();
      chatManager = ChatManager(analyticsApi: mockAnalytics);
    });

    test('sendMessage logs a MessageSent event', () {
      chatManager.sendMessage('Hello, world!');

      expect(mockAnalytics.capturedEventName, equals('MessageSent'));
    });

    test('sendMessage includes the message text in the event parameters', () {
      chatManager.sendMessage('Hello, world!');

      expect(
        mockAnalytics.capturedParameters?['message'],
        equals('Hello, world!'),
      );
    });
  });
}
```

The mock implements `AnalyticsApi` and records whatever it is called with. The test then reads those recordings via assertions.

---

## Consequences

**Gains**
- Outgoing calls are verified as part of the test suite, so interface breakage is caught immediately.
- The subject under test is fully isolated from real dependencies — no network, no database, no billing.
- The mock makes the dependency explicit: `ChatManager` cannot be constructed without an `AnalyticsApi`, which communicates its design intent.

**Trade-offs**
- Every collaborator interface needs an abstract class (or an interface) to be mockable. Retrofitting this on existing code can require refactoring.
- Testing the interface of an interaction is not the same as testing that the integration works end-to-end. This test confirms `ChatManager` *calls* the analytics API correctly — it does not confirm the API processes the call correctly. That is an integration test concern.
- Hand-rolled mocks become verbose as the number of collaborators grows. The `mockito` package (included in `pubspec.yaml`) provides code-generation-based mocks for complex cases.

---

## Implementation Notes

- In Dart, implement the abstract class with `implements`, not `extends` — this forces the mock to implement every method and is more explicit about intent.
- Separate assertions: one `test()` for the event name, one for the parameters. If both fail together, the single-assertion approach pinpoints which part broke.
- For heavier mocking needs, see the `mockito` package documentation and run `flutter pub run build_runner build` to generate mock classes.

---

## Related Patterns

- **Chapter 1 — Receiving a Message and Responding**: When the observable output is a return value.
- **Chapter 2 — Changing State**: When the observable output is internal state.
- **Chapter 5 — Exceptions & Error Handling**: Using mocks to verify that error paths trigger the right notifications.
- **Chapter 4 — Side Effects**: When a method produces multiple outgoing calls — how to enumerate all of them and verify each one independently.

---

## Navigation

- Previous: [Chapter 2 — Changing State](../chapter02_changing_state/README.md)
- Next: [Chapter 4 — Side Effects](../chapter04_side_effects/README.md)
- Back: [Catalog Index](../README.md)
