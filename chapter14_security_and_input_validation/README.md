# Chapter 14: Security and Input Validation

> In the chat app, this is the last gate before a message body is rendered in an HTML context: markup is stripped, null bytes are removed, the result is capped at a fixed length — and then, as the step that actually makes it safe, every character HTML could interpret is entity-encoded. Every adversarial input the team has thought of lives in a single table that doubles as the test suite.

---

## Intent

Verify that the application correctly sanitizes, rejects, or constrains inputs that could compromise data integrity, user privacy, or system security — and that the tests distinguish the steps that *tidy* input from the one step that *secures* it.

---

## The Problem

`MessageSanitizer.sanitize()` strips HTML tags, removes null bytes, and truncates oversized input before a message body is stored or displayed. The unit tests pass `<b>bold</b>` and a few friendly strings, see clean output, and call it done. The team believes the sanitizer is an XSS defense.

It is not. A single-pass strip is trivially bypassed. Submit

```
<scr<script>ipt>alert(1)</scr</script>ipt>
```

and the regex removes the *inner* `<script>` and `</script>`, leaving `ipt>alert(1)ipt>` — the outer fragments reassemble around the hole. Attribute-based vectors, malformed tags, and encoded variants all have the same shape: the stripper handles the case the developer imagined and passes through the one the attacker constructed. Because the tests only ever asked "is the tag gone?", nothing ever asked "can this output still be interpreted as markup?" — and that is the only question that matters.

Security vulnerabilities from untested input handling are not exotic. They come from testing what input *should* look like instead of what an adversary *will* submit, and from mistaking a normalisation step for a security boundary.

---

## Forces

You want to prove that security constraints hold for all adversarial inputs — but the attack space is not enumerable, and a test written only for `"hello"` says nothing about `<script>alert(1)</script>`, let alone its hundred variants. A single test per attack type is insufficient when the type has dozens of shapes.

You also want the sanitizer to *do* several things — strip markup so a chat message reads cleanly, drop control characters, enforce a length — but not every one of those steps is a security control, and treating them as if they were is how the bypass ships. Stripping is best-effort normalisation. Encoding is a guarantee: after `<` becomes `&lt;`, nothing downstream can interpret the text as a tag, regardless of what earlier steps missed.

Two things resolve the tension. First, an explicit **attack-vector table**: a named list of `(input, expected)` pairs that serves as both a test suite and a living specification of what the sanitizer must handle. Adding a new attack pattern is a one-line change; reviewing the table during a security audit reveals gaps. Second, a **property test** alongside the table: whatever the input, the output contains no raw `<` or `>`. The table documents the threats you have thought of; the property covers the ones you have not.

---

## Solution

Order the pipeline so that normalisation runs first and encoding runs last. Drive the tests from a named attack-vector table, one `test()` per row, and add one property test for the invariant the whole pipeline exists to guarantee.

Production code:

```dart
// See code/message_sanitizer.dart
import 'dart:math';

class MessageSanitizer {
  static const int maxLength = 1000;

  String sanitize(String input) {
    final stripped = input
        .replaceAll(RegExp(r'<[^>]*>'), '') // normalise: drop markup
        .replaceAll('\x00', '');            // normalise: drop null bytes

    final truncated =
        stripped.substring(0, min(stripped.length, maxLength));

    return _encodeHtml(truncated); // security boundary: always last
  }

  static String _encodeHtml(String text) => text
      .replaceAll('&', '&amp;') // must run first so later entities survive
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
```

Three steps, in a deliberate order. Stripping and null-byte removal are cosmetic — a chat client does not want `<b>` in a message, but nothing breaks if one slips through. Truncation runs on the stripped text so the limit counts characters the user typed, not markup they wrapped around them. Encoding runs last so that nothing after it can reintroduce an interpretable character. `&` is encoded before the others because otherwise `&lt;` produced by the `<` rule would itself be re-encoded.

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
      // --- benign input
      (
        name: 'passes plain text unchanged',
        input: 'Hello, world!',
        expected: 'Hello, world!',
      ),
      // --- markup normalisation
      (
        name: 'strips script tags and neutralises inner content',
        input: '<script>alert(1)</script>',
        expected: 'alert(1)',
      ),
      (
        name: 'strips attribute-based vectors entirely',
        input: '<img src=x onerror=alert(1)>',
        expected: '',
      ),
      // --- strip bypasses: encoding is what makes these safe
      (
        name: 'encodes what a nested-tag bypass leaves behind',
        input: '<scr<script>ipt>alert(1)</scr</script>ipt>',
        expected: 'ipt&gt;alert(1)ipt&gt;',
      ),
      (
        name: 'encodes an ampersand so it cannot start an entity',
        input: 'Tom & Jerry',
        expected: 'Tom &amp; Jerry',
      ),
      // --- out of scope, documented as such
      (
        name: 'passes SQL injection text through (parameterised queries handle it)',
        input: "'; DROP TABLE users; --",
        expected: '&#39;; DROP TABLE users; --',
      ),
      // ... see code/message_sanitizer_test.dart for the full table
    ];

    for (final vector in attackVectors) {
      test(vector.name, () {
        expect(sanitizer.sanitize(vector.input), equals(vector.expected));
      });
    }

    test('never lets a raw angle bracket reach the output', () {
      const payloads = [
        '<script>alert(1)</script>',
        '<scr<script>ipt>alert(1)</scr</script>ipt>',
        '<img src=x onerror=alert(1)>',
        '<a href="javascript:alert(1)">click</a>',
        '<<b>b>',
      ];
      for (final payload in payloads) {
        final out = sanitizer.sanitize(payload);
        expect(out, isNot(contains('<')), reason: payload);
        expect(out, isNot(contains('>')), reason: payload);
      }
    });

    test('truncates after stripping tags, not before', () {
      final taggedInput = '<b>${'a' * 1001}</b>';
      expect(sanitizer.sanitize(taggedInput).length, equals(MessageSanitizer.maxLength));
    });
  });
}
```

The table is declared `const` — compile-time data that documents the threat model. The nested-tag row is the most important one in it: its expected value, `ipt&gt;alert(1)ipt&gt;`, shows the stripper *failing* and the encoder making that failure harmless. A reader who sees only the table understands why the pipeline has two kinds of step.

The property test asks a different question from every row above it. The rows say "this specific input produces this specific output." The property says "no input produces output containing `<` or `>`." When a new bypass is discovered, it goes in the table as a row *and* it should already have been caught by the property — if it was not, the property was too weak, and that is the finding.

---

## Consequences

**Gains**
- The attack-vector table is simultaneously a test suite and a threat-model document. A security review of the table reveals gaps before they reach production.
- The pipeline order is pinned by tests: truncation-after-stripping, encoding-after-everything. A refactor that reorders the steps fails a named test that says which invariant it broke.
- The nested-tag row makes the limits of stripping visible in the test file itself, so the next developer does not inherit the belief that the regex is the defense.
- The property test protects against vectors that are not yet in the table.

**Trade-offs**
- Encoding at sanitize time bakes an HTML assumption into stored text. The safer general architecture is to store raw (normalised) text and encode at each *render* boundary, because a message shown in an HTML web view, a push notification, and a plain-text export need different encodings. This chapter encodes inside the sanitizer to keep the pipeline in one testable unit; in a real app, the encoding step belongs to the renderer and the same table tests it there.
- A hand-rolled encoder covers the five characters HTML cares about. For contexts beyond text nodes and quoted attributes — URLs, inline JavaScript, CSS — encoding rules differ, and a vetted library should replace `_encodeHtml`.
- The table-driven approach tests the sanitizer in isolation. Integration tests should verify that sanitized text survives the round trip through storage and rendering; unit tests only cover the sanitizer's own logic.

---

## Implementation Notes

- Flutter's `Text` widget does not interpret HTML — a `<script>` tag rendered in a `Text` is inert. Encoding matters when message bodies reach an HTML renderer: a `WebView`, an `Html` widget, an HTML email digest, or a web build of the chat. Know which of those your app has before deciding where encoding lives.
- The Dart 3 record syntax `(name: ..., input: ..., expected: ...)` used in the attack-vector table requires Dart SDK `>=3.0.0`, which this catalog already requires.
- Name each attack vector explicitly (`name:` field). When a test fails, the output reads "encodes what a nested-tag bypass leaves behind — Expected: 'ipt&gt;…', Got: 'ipt>…'" rather than a row index.
- `maxLength` counts characters of *content*, so the encoded output can be longer than `maxLength`. A test pins this: `maxLength` ampersands become `maxLength` copies of `&amp;`. If the storage layer has a byte limit, enforce it there, on the encoded form.
- SQL injection strings (`'; DROP TABLE users; --`) are not the sanitizer's job — parameterized queries at the database layer prevent them. Keep such a row in the table anyway, to document that the sanitizer only encodes the quote and otherwise passes the text through; a future developer who "helpfully" adds SQL escaping here will see a named test fail.

---

## Related Patterns

- [E7 — Input Validation](../chapter05_exceptions/e07_input_validation/README.md): Rejecting invalid inputs before business logic — the sanitizer normalises instead of rejecting, but the two are neighbours.
- [E8 — Boundary Conditions](../chapter05_exceptions/e08_boundary_conditions/README.md): Testing at the exact `maxLength` boundary.
- [Chapter 6 — Adversarial Inputs](../chapter06_adversarial_inputs/README.md): The general discipline of enumerating input categories a happy-path test never exercises. This chapter is that discipline pointed at an attacker.

---

## Navigation

- Previous: [Chapter 13 — Performance and Timing](../chapter13_performance_and_timing/README.md)
- Next: [Chapter 15 — State Transitions](../chapter15_state_transitions/README.md)
- Back: [Catalog Index](../README.md)
