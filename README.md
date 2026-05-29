# Flutter Unit Testing Catalog

> A catalog of unit testing patterns for Flutter and Dart, structured in the spirit of the Gang of Four Design Patterns.

---

## The Idea Behind This Book

Every method call is a message. An object receives a message, does something with it, and the world changes — or does not. Three things can happen when a method is called: it can **return a value**, it can **change internal state**, or it can **send messages to other objects**. Everything in unit testing flows from these three primitives.

This catalog names each pattern, explains the problem that arises without it, and shows you the solution in Flutter/Dart — production class first, test second. Like the Gang of Four, each entry stands alone. Read them in order or jump to what you need.

---

## How to Read This Catalog

Every chapter follows the same GoF-inspired structure. If you encounter a term you do not recognise, the [Glossary](glossary/README.md) defines every key word used in this catalog.

| Section | Purpose |
|---|---|
| **Intent** | One sentence: what this test pattern verifies |
| **The Problem** | The scenario that hurts without this pattern |
| **Forces** | The tensions you are navigating |
| **Solution** | The pattern in prose, followed by Dart code |
| **Consequences** | What you gain and what you give up |
| **Implementation Notes** | Dart/flutter_test-specific tips |
| **Related Patterns** | Other entries in this catalog |

Code for each chapter lives in its `code/` subfolder — a production `.dart` file and a `_test.dart` file side by side.

---

## Running the Code

This catalog is a Flutter package. The test files live alongside the production code inside each chapter's `code/` folder rather than in a top-level `test/` directory, so `flutter test` needs to be pointed at them explicitly.

To run every test in the catalog:

```bash
cd flutter-unit-testing-catalog
flutter pub get
flutter test $(find . -name "*_test.dart" -not -path "*/build/*")
```

To run a single chapter's tests:

```bash
flutter test chapter01_receiving_responding/code/message_formatter_test.dart
```

Dependencies are declared in `pubspec.yaml`. Run `flutter pub get` once before running tests.

---

## Running Example: A Chat App

Every chapter is anchored to the same domain — a small chat application — so the catalog reads as one continuous story instead of fifteen disconnected examples. Each chapter still has its own self-contained `code/` folder; the spine lives in the names and the prose, not in cross-chapter imports.

The chat-domain subject for each chapter:

| # | Chapter | Subject |
|---|---------|---------|
| 1 | Receiving and Responding | `MessageFormatter` (relative-time labels, message previews) |
| 2 | Changing State | `UnreadCounter` (badge on a conversation row) |
| 3 | Sending Out More Messages | `ChatManager.sendMessage` calling analytics |
| 4 | Side Effects | `ChatManager.sendMessage` (persist + observe + log) |
| 5 | Exceptions & Error Handling | `ChatManager` variants for each E1–E9 entry |
| 6 | Adversarial Inputs | `ChatManager.receiveMessage` with out-of-order timestamps |
| 7 | Initial State and Setup | `ChatManager` loading message history |
| 8 | Concurrency and Timing | `ChatManager` racing concurrent sends + delivery receipts |
| 9 | Idempotence | `ChatManager` dedup by stable `clientMessageId` |
| 10 | Memory and Resource Management | `IncomingMessageBinder` (stream subscriptions for a chat screen) |
| 11 | Third-Party Integration | `ChatService` wrapping a backend HTTP client |
| 12 | Fallbacks and Redundancies | `MessageRepository` (remote + cache + placeholder) |
| 13 | Performance and Timing | `TypingIndicator` (debounced "stopped typing" notification) |
| 14 | Security and Input Validation | `MessageSanitizer` (HTML/null-byte stripping + length cap) |
| 15 | State Transitions | `MessageDelivery` lifecycle (`Drafting → Sending → Sent → Delivered → Read`, with `fail` from `Sending`/`Sent`, `cancel` from `Sending`, and `retry` from `Failed`) |

You can read the chapters in order to see one application's surface area grow, or jump to any chapter for a self-contained pattern.

---

## Catalog Index

### Foundations

| # | Chapter | Status |
|---|---------|--------|
| — | [Introduction: The Message Metaphor](intro/README.md) | Draft |

### Core Message Patterns

| # | Chapter | Status |
|---|---------|--------|
| 1 | [Receiving a Message and Responding](chapter01_receiving_responding/README.md) | Draft |
| 2 | [Changing State](chapter02_changing_state/README.md) | Draft |
| 3 | [Sending Out More Messages](chapter03_sending_out_more_messages/README.md) | Draft |
| 4 | [Side Effects — Completeness of Outgoing Calls](chapter04_side_effects/README.md) | Draft |

### Reliability Patterns

| # | Chapter | Status |
|---|---------|--------|
| 5 | [Exceptions & Error Handling](chapter05_exceptions/README.md) | Draft |
| — | ↳ [E1: Exception Throwing](chapter05_exceptions/e01_exception_throwing/README.md) | Draft |
| — | ↳ [E2: Exception Types](chapter05_exceptions/e02_exception_types/README.md) | Draft |
| — | ↳ [E3: Error Messages](chapter05_exceptions/e03_error_messages/README.md) | Draft |
| — | ↳ [E4: Exception Handling](chapter05_exceptions/e04_exception_handling/README.md) | Draft |
| — | ↳ [E5: State After Exception](chapter05_exceptions/e05_state_after_exception/README.md) | Draft |
| — | ↳ [E6: Fallback Mechanisms](chapter05_exceptions/e06_fallback_mechanisms/README.md) | Draft |
| — | ↳ [E7: Input Validation](chapter05_exceptions/e07_input_validation/README.md) | Draft |
| — | ↳ [E8: Boundary Conditions](chapter05_exceptions/e08_boundary_conditions/README.md) | Draft |
| — | ↳ [E9: Resource Cleanup](chapter05_exceptions/e09_resource_cleanup/README.md) | Draft |
| 6 | [Adversarial Inputs](chapter06_adversarial_inputs/README.md) | Draft |
| 7 | [Initial State and Setup](chapter07_initial_state_and_setup/README.md) | Draft |
| 8 | [Concurrency and Timing](chapter08_concurrency_and_timing/README.md) | Draft |
| 9 | [Idempotence](chapter09_idempotence/README.md) | Draft |

### Specialized Patterns

| # | Chapter | Status |
|---|---------|--------|
| 10 | [Memory and Resource Management](chapter10_memory_and_resources/README.md) | Draft |
| 11 | [Third-Party Integration](chapter11_third_party_integration/README.md) | Draft |
| 12 | [Fallbacks and Redundancies](chapter12_fallbacks_and_redundancies/README.md) | Draft |
| 13 | [Performance and Timing](chapter13_performance_and_timing/README.md) | Draft |
| 14 | [Security and Input Validation](chapter14_security_and_input_validation/README.md) | Draft |
| 15 | [State Transitions](chapter15_state_transitions/README.md) | Draft |

---

## What This Catalog Deliberately Does Not Cover

The patterns in this book are scoped to **unit tests for plain Dart classes** — the layer where business logic lives. Several adjacent categories of testing are intentionally outside that scope. They are not less important; they answer different questions and use different oracles. Naming them here is meant to set expectations, not to dismiss them.

- **Widget tests (`testWidgets`)** — Tests that mount a widget tree in a simulated rendering environment and verify layout, tap behavior, or accessibility. Every `test()` call in this catalog operates on a plain class; nothing renders on screen. For the widget layer, see the [Flutter widget testing documentation](https://docs.flutter.dev/testing/overview#widget-tests).

- **Golden / snapshot tests** — Pixel-level regression tests for rendered widgets. The oracle is an image comparison, not an `expect()` matcher. These belong in the same suite as widget tests and require the same rendering pipeline.

- **Integration tests (`integration_test` package)** — End-to-end tests that drive a real app on a device or emulator. They verify that the assembled application behaves correctly, not that any individual class fulfills its contract. The patterns in this catalog are about the second question; integration tests answer the first.

- **Property-based testing (e.g. `glados`)** — Generative testing where the framework fabricates inputs to find counterexamples. Complementary rather than excluded: every pattern here could be reinforced with a property-based test. The catalog uses example-based assertions throughout because they are the form most teams write first and most reliably.

- **Test-first vs test-last workflow** — Whether tests are written before, after, or alongside production code is a workflow choice. The patterns work regardless. The [Introduction](intro/README.md) discusses this briefly; this catalog takes no position.

- **State-management framework testing (bloc / riverpod / provider / GetX)** — Testing notifiers, blocs, and providers requires conventions specific to each framework (e.g. `bloc_test`'s `blocTest()` helper, `ProviderContainer` for Riverpod). The general patterns here apply to the classes those frameworks wrap, but framework-specific helpers are not covered.

- **Mocking libraries (`mocktail`, `mockito`)** — Every test in this catalog hand-writes its stubs and mocks to keep the seam visible. In a real codebase, `mocktail` removes most of the boilerplate. The patterns translate directly; the syntax changes.

---

## Exception Sub-Catalog Quick Reference

Chapter 5 is itself a mini-catalog. The nine entries cover every aspect of testing error handling:

| Entry | What It Tests |
|---|---|
| E1 | That an exception is thrown at all |
| E2 | That the correct exception *type* is thrown |
| E3 | That the exception carries the correct *message* |
| E4 | That the calling code *handles* the exception correctly |
| E5 | That the object is in a consistent *state* after an exception |
| E6 | That a *fallback* path is taken when the primary path fails |
| E7 | That *invalid inputs* are rejected before reaching business logic |
| E8 | That the system behaves correctly at *boundary values* |
| E9 | That *resources* are released even when an exception occurs |

See [helper: validation vs boundaries](chapter05_exceptions/e07_input_validation/helper_validation_vs_boundary.md).

---

## Reference

- [Glossary](glossary/README.md) — Definitions for every key term: stub, mock, fake, spy, SUT, observable behavior, and more.
- [License](LICENSE) — All rights reserved. Reading and local learning use of the example code is permitted; copying or redistribution is not.

If your classes have hard-coded dependencies and you are not sure how to make them testable before applying the patterns, see [Designing for Testability](appendix/designing-for-testability.md).
