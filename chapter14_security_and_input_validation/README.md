# Chapter 14: Security and Input Validation

> In the chat app, this is the last gate before a message body is stored or rendered: HTML and script tags are stripped, null bytes are removed, and the result is capped at a fixed length. Every adversarial input the team has thought of lives in a single table that doubles as the test suite.

---

## Intent

Verify that the application correctly sanitizes, rejects, or constrains inputs that could compromise data integrity, user privacy, or system security.

---

## The Problem

`MessageSanitizer.sanitize()` is supposed to strip HTML tags, remove null bytes, and truncate oversized input before the text is stored or displayed. The unit tests pass a few friendly strings and call it done.

A user submits `<script>alert(document.cookie)</script>`. The sanitizer was never tested against script tags — only against `<b>bold</b>` — and the regex is subtly wrong: it misses self-closing tags. The XSS payload reaches the database and is served to other users.

Security vulnerabilities from untested input handling are among the most common bugs in applications. They are not exotic — they are the result of a developer who tested what the input should look like, not what an adversary would submit.

---

## Forces

You want to prove that security constraints hold for all adversarial inputs — but the attack space is not enumerable, and a test written only for `"hello"` says nothing about what happens with `<script>alert(1)</script>`. A single test per attack type is insufficient when the type has dozens of variants.

The resolution is an explicit **attack-vector table**: a named list of `(input, expected)` pairs that serves as both a test suite and a living specification of what the sanitizer must handle. Adding a new attack pattern to the table is a one-line change. Reviewing the table during a security audit reveals gaps. The cost of enumerating threats is paid upfront, not discovered in production.

---

## Solution

Define a `MessageSanitizer` class with a single `sanitize()` method. Drive tests from a named list of attack vectors, one `test()` per row.

Production code:

```dart
// See code/message_sanitizer.dart
import 'dart:math';

class MessageSanitizer {
  static const int maxLength = 1000;

  String sanitize(String input) {
    var result = input
        .replaceAll(RegExp(r'<[^>]*>'), '')  // strip all HTML/script tags
        .replaceAll('\x00', '');             // remove null bytes

    return result.substring(0, min(result.length, maxLength));
  }
}
```

Test code:

```dart
// See code/message_sanitizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'message_sanitizer.dart';

void main() {
  group('MessageSanitizer.sanitize', () {
    late MessageSanitizer sanitizer;

    setUp(() {
      sanitizer = MessageSanitizer();
    });

    // Attack-vector table: (name, input, expected output)
    const attackVectors = [
      (
        name: 'passes plain text unchanged',
        input: 'Hello, world!',
        expected: 'Hello, world!',
      ),
      (
        name: 'strips script tags and preserves inner content',
        input: '<script>alert(1)</script>',
        expected: 'alert(1)',
      ),
      (
        name: 'strips HTML bold tags',
        input: '<b>bold text</b>',
        expected: 'bold text',
      ),
      (
        name: 'strips nested HTML tags',
        input: '<div><p>content</p></div>',
        expected: 'content',
      ),
      (
        name: 'removes null bytes',
        input: 'null\x00byte',
        expected: 'nullbyte',
      ),
      (
        name: 'handles empty string',
        input: '',
        expected: '',
      ),
    ];

    for (final vector in attackVectors) {
      test(vector.name, () {
        expect(sanitizer.sanitize(vector.input), equals(vector.expected));
      });
    }

    test('truncates input exceeding maxLength', () {
      final longInput = 'a' * (MessageSanitizer.maxLength + 1);
      expect(
        sanitizer.sanitize(longInput).length,
        equals(MessageSanitizer.maxLength),
      );
    });

    test('truncates after stripping tags, not before', () {
      // A 1000-char string wrapped in tags should be truncated AFTER stripping,
      // so the resulting text is up to maxLength, not the tagged input.
      final taggedInput = '<b>${'a' * 1001}</b>';
      expect(sanitizer.sanitize(taggedInput).length, equals(MessageSanitizer.maxLength));
    });
  });
}
```

The attack-vector table is declared as `const` — compile-time data that documents the sanitizer's threat model. New attack types are added as new rows.

---

## Consequences

**Gains**
- The attack-vector table is simultaneously a test suite and a threat-model document. A security review of the table reveals gaps before they reach production.
- Adding a new sanitization rule requires adding one row to the table — the test infrastructure is already in place.
- Truncation-after-stripping is a subtlety that is easy to miss and easy to test — the last test makes it explicit.

**Trade-offs**
- The table-driven approach tests the sanitizer in isolation. Integration tests should verify that sanitized text reaches the database correctly; unit tests only cover the sanitizer's own logic.
- `MessageSanitizer` strips tags but does not encode entities. If the use case requires HTML entity encoding (`<` → `&lt;`), the table would need to be updated and the sanitizer extended.

---

## Implementation Notes

- The Dart 3 record syntax `(name: ..., input: ..., expected: ...)` used in the attack-vector table requires Dart SDK `>=3.0.0`, which this catalog already requires.
- Name each attack vector explicitly (`name:` field). When a test fails, the output reads "passes plain text unchanged — Expected: 'Hello', Got: ''" rather than just a row index.
- `maxLength` is a `static const` so tests can reference it without instantiating the class. Avoid magic numbers in tests.
- For SQL injection patterns (`'; DROP TABLE users; --`), the sanitizer does not need to strip them — SQL injection is prevented by parameterized queries at the database layer, not by input sanitization. Include them in the table to document that the sanitizer passes them through unchanged, not that it strips them.

---

## Related Patterns

- [E7 — Input Validation](../chapter05_exceptions/e07_input_validation/README.md): Rejecting invalid inputs before business logic.
- [E8 — Boundary Conditions](../chapter05_exceptions/e08_boundary_conditions/README.md): Testing at the exact `maxLength` boundary.

---

## Navigation

- Previous: [Chapter 13 — Performance and Timing](../chapter13_performance_and_timing/README.md)
- Next: [Chapter 15 — State Transitions](../chapter15_state_transitions/README.md)
- Back: [Catalog Index](../README.md)
