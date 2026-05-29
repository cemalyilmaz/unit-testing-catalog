# Glossary

Precise vocabulary matters. This catalog uses the following terms consistently.
When a chapter says "mock," it means specifically what is defined below — not just "any test substitute."

Entries are grouped by concern, then listed alphabetically within each group.

---

## Test Structure

### Arrange / Act / Assert (AAA)

The three-part structure every unit test follows:

- **Arrange** — Put the subject under test in the state required for the scenario.
- **Act** — Send the message (call the method under test).
- **Assert** — Verify the observable outcome: return value, state change, or recorded outgoing calls.

Every test in this catalog is written in this order, even when the comments are not explicit.

---

### Group

A named container for related tests. In `flutter_test`, created with `group('name', () { ... })`. Equivalent to a test class in JUnit or XCTest. Groups do not share setup by default — each `setUp` callback inside a group runs before every test in that group only.

---

### `setUp`

A callback registered with `setUp(() { ... })` that runs before every test in its enclosing `group`. Used to create a fresh instance of the subject under test for each test, so tests do not share state.

```dart
setUp(() {
  subject = MyClass();
});
```

---

### `tearDown`

A callback registered with `tearDown(() { ... })` that runs after every test in its enclosing `group`. Used to release resources that were acquired in `setUp`. Also available as `addTearDown(() { ... })` inside a specific test body — this runs only after that one test.

```dart
tearDown(() {
  controller.dispose();
});
```

---

### Test

A single verifiable claim about the behavior of a unit. In `flutter_test`, created with `test('description', () { ... })`. A test should assert exactly one behavior. If multiple behaviors are asserted in one test, a failure tells you "something broke" but not precisely what.

---

### `testWidgets`

The Flutter-specific equivalent of `test()` for testing widget trees. Provides a `WidgetTester` for pumping widgets, simulating interactions, and asserting on the rendered output. Use `test()` for business logic and `testWidgets()` for anything involving a `Widget`.

```dart
testWidgets('shows a loading spinner while data is loading', (tester) async {
  await tester.pumpWidget(MyWidget());
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

This catalog focuses on `test()`. For `testWidgets`, see the Flutter testing documentation.

---

## Subjects and Collaborators

### Collaborator

Any object that the subject under test interacts with — calls methods on, reads properties from, or sends events to. Collaborators are the objects you replace with test doubles in unit tests.

In this catalog, `AnalyticsApi`, `NetworkService`, `SettingsStorage`, and `FileHandle` are all collaborators of their respective subjects.

---

### Subject Under Test (SUT)

The single class or function whose behavior a test is verifying. Every test has exactly one SUT. All other objects involved are collaborators and are replaced by test doubles.

Naming convention in this catalog: the variable holding the SUT is named after its type (e.g., `chatManager`, `calculator`, `manager`).

---

## Test Doubles

A **test double** is any object that replaces a real collaborator in a test. The term covers stubs, mocks, fakes, and spies. "Mock" is not a synonym for all of these.

---

### Stub

A test double that **returns predefined values** when called. It has no behavior beyond returning those values, and nothing is ever asserted on it after the test.

Use a stub when the SUT needs the collaborator to return something to proceed, but the test does not care how or how often the collaborator was called.

```dart
// Stub: returns a fixed list — nothing is asserted on the stub itself
class StubMessageHistoryLoader implements MessageHistoryLoader {
  @override
  Future<List<String>> fetch(String conversationId) async =>
      ['welcome to the chat', 'how can I help?'];
}

test('loads history from the loader', () async {
  final manager = ChatManager(loader: StubMessageHistoryLoader());
  await manager.loadHistory('conv-1');
  expect(manager.messages, equals(['welcome to the chat', 'how can I help?']));
});
```

---

### Mock

A test double that **records calls made to it**, so those calls can be asserted on after the act. The defining characteristic of a mock is that the test makes assertions *on the mock itself* (not just on the SUT's state).

Use a mock when the test's claim is about an outgoing interaction — "the SUT called this collaborator with these arguments."

```dart
// Mock: capturedEventName is asserted on after the act
class MockAnalyticsApi implements AnalyticsApi {
  String? capturedEventName;

  @override
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    capturedEventName = eventName;
  }
}

test('logs a MessageSent event', () {
  final mock = MockAnalyticsApi();
  ChatManager(analyticsApi: mock).sendMessage('Hello');
  expect(mock.capturedEventName, equals('MessageSent')); // asserted on the mock
});
```

---

### Fake

A test double that has a **working but simplified implementation**. It implements the same interface as the real collaborator and actually does something useful, but in a way that is fast, in-memory, and deterministic.

Use a fake when the SUT needs the collaborator to have real behavior (not just return a value), but the real implementation is too slow or has side effects.

```dart
// Fake: actually stores and retrieves values in memory
class FakeSettingsStorage implements SettingsStorage {
  final Map<String, String> _data = {};

  @override
  void save(String key, String value) => _data[key] = value;

  @override
  String? read(String key) => _data[key];
}
```

---

### Spy

A test double that **wraps a real implementation** and records calls made to it, while still forwarding those calls to the real object. Unlike a mock, the real behavior is preserved.

Use a spy when you want to verify that a real object was called in a specific way, without replacing its behavior.

```dart
// Spy: delegates to a real logger but also records the call
class SpyLogger implements Logger {
  final Logger _real;
  final List<String> recorded = [];

  SpyLogger(this._real);

  @override
  void log(String message) {
    recorded.add(message);
    _real.log(message); // real behavior is preserved
  }
}
```

---

### Summary: Choosing the Right Double

| Question | Use |
|---|---|
| Does the test assert on what the collaborator received? | Mock |
| Does the SUT need the collaborator to return something? | Stub |
| Does the collaborator need real (but simplified) behavior? | Fake |
| Do you need real behavior *and* call recording? | Spy |

If in doubt: start with a hand-rolled stub or mock. Only reach for `mockito`-generated doubles when the collaborator interface is large.

---

## Testing Concepts

### Dependency Injection

The practice of passing collaborators into a class through its constructor (or a setter) rather than instantiating them internally. This is the prerequisite for replacing real collaborators with test doubles.

```dart
// Without injection — untestable, AnalyticsApi is hard-coded
class ChatManager {
  final _analytics = FirebaseAnalytics.instance; // cannot be replaced in tests
}

// With injection — testable, any AnalyticsApi implementation can be substituted
class ChatManager {
  final AnalyticsApi _analytics;
  ChatManager({required AnalyticsApi analyticsApi}) : _analytics = analyticsApi;
}
```

Every testable class in this catalog uses constructor injection.

---

### Happy Path

The execution path through code where all inputs are valid, all services are available, and no exceptions are thrown. Testing only the happy path is necessary but not sufficient.

---

### Error Path (Sad Path)

Any execution path that involves invalid inputs, service failures, exceptions, or edge conditions. Testing the error path is what Chapter 4 and its sub-entries are about.

---

### Observable Behavior

The parts of a class's behavior that a test can see from the outside, without reading private fields or implementation details. In this catalog, three things are always observable:

1. The **return value** of a method call.
2. The **state** of the object after a method call (via public getters).
3. The **calls made** to injected collaborators (via mocks).

A test that reads private fields, uses reflection, or depends on the order of internal operations is testing implementation, not behavior. Behavior tests survive refactoring; implementation tests do not.

---

### Test Isolation

The property of a test suite where each test is independent of every other. An isolated test:

- Creates a fresh instance of the SUT in `setUp`.
- Does not read or write shared mutable state.
- Produces the same result regardless of which tests ran before it or what order they ran in.

Tests in this catalog achieve isolation through `setUp` callbacks and stateless test doubles.

---

### Unit Test

A test that verifies the behavior of one class (the SUT) in isolation from all its real collaborators. Collaborators are replaced by test doubles. A unit test is fast (milliseconds), deterministic (same result on every run), and does not touch the network, disk, or device APIs.

Not to be confused with:

- **Integration test** — tests how two or more real classes work together.
- **Widget test** — tests a widget in a simulated Flutter rendering environment (`testWidgets`).
- **End-to-end test** — tests a complete user flow against a real backend.

This catalog is exclusively about unit tests.

---

## Dart-Specific Terms

### `abstract class` (as interface)

In Dart, `abstract class` is used to define interfaces — types that describe a contract without providing an implementation. Collaborator types in this catalog are defined as abstract classes so both the real implementation and test doubles share the same contract.

```dart
abstract class NetworkService {
  Future<void> send(String message);
}
// Real implementation and MockNetworkService both implement this
```

Dart 3 introduced the `interface` keyword for this purpose. Both are valid; `abstract class` is used throughout this catalog for compatibility with Dart 2.12+.

---

### `late`

A Dart keyword indicating that a variable will be assigned before it is first read, even though it is declared without an initial value. Used in test files to declare SUT and mock variables that are initialized in `setUp`.

```dart
late ChatManager chatManager;
late MockAnalyticsApi mockAnalytics;

setUp(() {
  mockAnalytics = MockAnalyticsApi();
  chatManager = ChatManager(analyticsApi: mockAnalytics);
});
```

---

### `implements` vs `extends` (for test doubles)

When writing a test double for an abstract class, always use `implements`, not `extends`:

- `implements` forces the double to implement every method — if the interface grows, the compiler tells you immediately.
- `extends` inherits any default implementations, which can hide missing overrides.

```dart
class MockAnalyticsApi implements AnalyticsApi { ... } // correct
class MockAnalyticsApi extends AnalyticsApi { ... }    // avoid
```

---

## Navigation

- Back: [Introduction](../intro/README.md)
- Back: [Catalog Index](../README.md)
