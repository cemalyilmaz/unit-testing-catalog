# E8: Boundary Conditions

---

## Intent

Verify that the system behaves correctly at the exact edges of its defined limits.

---

## The Problem

`ChatManager` allows 100 messages per minute and files up to 10 MB. The code handles the happy path (50 messages, 5 MB file) and the obviously-over-the-limit path (500 messages, 500 MB file). But what about message number 100 — the last allowed one? What about a file of exactly 10 MB? What about a file of 10 MB + 1 byte?

Bugs at boundary values are disproportionately common. An off-by-one in the condition `>=` vs `>` means message 100 is either accepted or rejected incorrectly. Without a test at the exact boundary, this kind of bug is invisible.

---

## Forces

- Boundary bugs (off-by-one errors) are the most common logical error in range-checking code.
- Three values are worth testing at every boundary: one below the limit, the limit itself, and one above.
- Boundary tests are distinct from validation tests (E7) — the data is valid in type and format; it is only the quantity or size that matters here.

---

## Solution

Test three values around each threshold: at the limit (allowed), at the limit + 1 (rejected), and near the limit - 1 (allowed, for confidence).

Production code:

```dart
// See code/chat_manager.dart
class RateLimitExceededError implements Exception {}

class FileSizeExceededError implements Exception {}

class ChatManager {
  static const int messageRateLimit = 100;
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  int _messageCount = 0;

  void sendMessage(String message) {
    if (_messageCount >= messageRateLimit) {
      throw RateLimitExceededError();
    }
    _messageCount++;
  }

  void uploadFile(List<int> fileData) {
    if (fileData.length > maxFileSizeBytes) {
      throw FileSizeExceededError();
    }
    // upload logic
  }

  void resetRateLimit() {
    _messageCount = 0;
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

void main() {
  group('ChatManager boundary conditions', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    group('message rate limit', () {
      test('allows the 100th message (at the limit)', () {
        for (var i = 0; i < 99; i++) {
          chatManager.sendMessage('Message $i');
        }
        expect(
          () => chatManager.sendMessage('Message 100'),
          returnsNormally,
        );
      });

      test('rejects the 101st message (one over the limit)', () {
        for (var i = 0; i < 100; i++) {
          chatManager.sendMessage('Message $i');
        }
        expect(
          () => chatManager.sendMessage('Message 101'),
          throwsA(isA<RateLimitExceededError>()),
        );
      });
    });

    group('file size limit', () {
      test('accepts a file at exactly the maximum size', () {
        final maxSizeFile = List.filled(ChatManager.maxFileSizeBytes, 0);
        expect(
          () => chatManager.uploadFile(maxSizeFile),
          returnsNormally,
        );
      });

      test('rejects a file one byte over the maximum size', () {
        final overLimitFile =
            List.filled(ChatManager.maxFileSizeBytes + 1, 0);
        expect(
          () => chatManager.uploadFile(overLimitFile),
          throwsA(isA<FileSizeExceededError>()),
        );
      });
    });
  });
}
```

---

## Consequences

**Gains**
- Off-by-one errors in boundary conditions are caught immediately.
- The exact threshold values are documented in tests.
- The three-value pattern (below, at, above) provides systematic coverage of every boundary.

**Trade-offs**
- Boundary tests can be slow when the boundary value requires large setup (filling a list to `maxFileSizeBytes` takes real memory). Use minimum viable payloads where the exact values are not significant.

---

## Implementation Notes

- The standard boundary testing strategy is: one below limit (must succeed), at limit (must succeed), one above limit (must fail). Always test all three.
- When setting up boundary conditions requires many repetitive operations (sending 99 messages before the boundary test), use a helper or a loop — but keep the final boundary assertion clearly visible.
- See [helper_validation_vs_boundary.md](../e07_input_validation/helper_validation_vs_boundary.md) for the distinction between validation and boundary testing.

---

## Related Patterns

- [E7 — Input Validation](../e07_input_validation/README.md): Testing invalid data types and formats.
- [Chapter 6 — Adversarial Inputs](../../chapter06_adversarial_inputs/README.md): Broader strategy for testing inputs that violate happy-path structural assumptions.

---

## Navigation

- Previous: [E7 — Input Validation](../e07_input_validation/README.md)
- Next: [E9 — Resource Cleanup](../e09_resource_cleanup/README.md)
- Back: [Chapter 5 Overview](../README.md)
