# E7: Input Validation

---

## Intent

Verify that invalid inputs are rejected before they reach business logic.

---

## The Problem

`ChatManager` has an `uploadFile` method. It accepts only certain file types and rejects files over 10 MB. The validation logic exists, but only the happy path was tested during development. When a user uploads a `.exe` file or a 500 MB video, the method should reject it immediately — but without tests, a future refactor could remove or weaken the validation silently.

Input validation is the first line of defense. If it is not tested, it cannot be trusted.

---

## Forces

- Validation should fire before any business logic executes. Tests must confirm this ordering.
- There are typically multiple invalid conditions (wrong type, wrong size, null) — each needs its own test.
- The test is not about what happens after rejection; it is about confirming the rejection itself.

---

## Solution

Test each distinct invalid-input condition in isolation, asserting that the appropriate error is thrown.

Production code:

```dart
// See code/chat_manager.dart
class InvalidFileError implements Exception {
  final String message;
  InvalidFileError(this.message);
}

class UnsupportedFileTypeError extends InvalidFileError {
  UnsupportedFileTypeError() : super('Unsupported file type.');
}

class FileTooLargeError extends InvalidFileError {
  FileTooLargeError() : super('File exceeds maximum size of 10 MB.');
}

class ChatManager {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedExtensions = ['jpg', 'png', 'pdf'];

  void uploadFile(String fileName, List<int> fileData) {
    final extension = fileName.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw UnsupportedFileTypeError();
    }
    if (fileData.length > maxFileSizeBytes) {
      throw FileTooLargeError();
    }
    // ... upload logic
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

void main() {
  group('ChatManager.uploadFile input validation', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    test('accepts a valid jpg file within size limit', () {
      final validData = List.filled(1024, 0); // 1 KB
      expect(
        () => chatManager.uploadFile('image.jpg', validData),
        returnsNormally,
      );
    });

    test('throws UnsupportedFileTypeError for a .exe file', () {
      final data = List.filled(1024, 0);
      expect(
        () => chatManager.uploadFile('virus.exe', data),
        throwsA(isA<UnsupportedFileTypeError>()),
      );
    });

    test('throws FileTooLargeError when file exceeds 10 MB', () {
      final oversizedData = List.filled(ChatManager.maxFileSizeBytes + 1, 0);
      expect(
        () => chatManager.uploadFile('large.jpg', oversizedData),
        throwsA(isA<FileTooLargeError>()),
      );
    });

    test('validates file type before file size', () {
      // An oversized unsupported file should fail on type, not size.
      final oversizedUnsupported =
          List.filled(ChatManager.maxFileSizeBytes + 1, 0);
      expect(
        () => chatManager.uploadFile('virus.exe', oversizedUnsupported),
        throwsA(isA<UnsupportedFileTypeError>()),
      );
    });
  });
}
```

---

## Consequences

**Gains**
- Each invalid condition is independently verified.
- Validation ordering is made explicit in tests (type before size, in this example).
- Invalid inputs can never silently succeed after a refactor.

**Trade-offs**
- With many validation rules, the number of tests grows linearly. Use parameterized tests (a loop over a list of invalid inputs) for repetitive cases.

---

## Implementation Notes

- Test invalid inputs in the same order they are validated in the code. This pinpoints which validation check fails when a test breaks.
- See [helper_validation_vs_boundary.md](helper_validation_vs_boundary.md) for a precise distinction between input validation and boundary conditions (E8).
- In Dart, `List.filled(n, 0)` is a convenient way to create test payloads of a specific size without allocating real data.

---

## Related Patterns

- [E8 — Boundary Conditions](../e08_boundary_conditions/README.md): Testing at the exact edges of allowed ranges.
- [E1 — Exception Throwing](../e01_exception_throwing/README.md): The general exception-throwing pattern.

---

## Navigation

- Previous: [E6 — Fallback Mechanisms](../e06_fallback_mechanisms/README.md)
- Next: [E8 — Boundary Conditions](../e08_boundary_conditions/README.md)
- Back: [Chapter 5 Overview](../README.md)
