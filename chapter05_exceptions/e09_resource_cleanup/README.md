# E9: Resource Cleanup

---

## Intent

Verify that resources are properly released even when an exception occurs.

---

## The Problem

`ChatManager` opens a file handle to read an attachment before sending it. If the send fails, the file handle should be closed. The code has a `try-finally` block for this — or it should. Without a test, a developer removes the `finally` block in a refactor, believing the `catch` covers cleanup. On devices with limited file descriptor pools, leaving handles open causes silent performance degradation and eventually crashes.

Resource leaks are among the hardest bugs to reproduce because they accumulate over time. A test that verifies cleanup runs on every commit, before any accumulation occurs.

---

## Forces

- Cleanup must happen regardless of success or failure — the test must exercise the failure path.
- File handles, network sockets, and database connections are not directly mockable without an interface. Design with injection.
- The test verifies a side effect of the error path (the resource was closed), not the error itself.

---

## Solution

Model the resource as an abstract interface so the test can inject a mock resource. Assert on the mock's `isClosed` state after the failure.

Production code:

```dart
// See code/chat_manager.dart
abstract class FileHandle {
  List<int> readData();
  void close();
}

class FileSendFailedError implements Exception {}

class ChatManager {
  Future<void> sendFile(FileHandle fileHandle) async {
    try {
      final data = fileHandle.readData();
      if (data.isEmpty) {
        throw FileSendFailedError();
      }
      // ... send logic
    } finally {
      fileHandle.close();
    }
  }
}
```

Test code:

```dart
// See code/chat_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_manager.dart';

class MockFileHandle implements FileHandle {
  final List<int> _data;
  bool isClosed = false;

  MockFileHandle(this._data);

  @override
  List<int> readData() => _data;

  @override
  void close() {
    isClosed = true;
  }
}

void main() {
  group('ChatManager resource cleanup', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    test('closes the file handle after a successful send', () async {
      final fileHandle = MockFileHandle([1, 2, 3]);

      await chatManager.sendFile(fileHandle);

      expect(fileHandle.isClosed, isTrue);
    });

    test('closes the file handle even when the send fails', () async {
      final emptyFileHandle = MockFileHandle([]);

      try {
        await chatManager.sendFile(emptyFileHandle);
      } on FileSendFailedError {
        // expected
      }

      expect(emptyFileHandle.isClosed, isTrue);
    });
  });
}
```

---

## Consequences

**Gains**
- Resource leaks from error paths are caught immediately in CI.
- The `finally` block (or equivalent cleanup pattern) is protected from accidental removal.
- The test pattern generalizes to any resource: database connections, network sockets, streams.

**Trade-offs**
- Requires the resource to be injected as an interface. Real file system interaction requires a wrapper class around `dart:io` `File`/`RandomAccessFile`.

---

## Implementation Notes

- In Dart, use `try-finally` (not just `try-catch`) to guarantee cleanup runs on both success and failure paths.
- For database connections (e.g., `sqflite`) and streams, wrap the resource in an abstract class and inject it — the same pattern applies.
- The two tests above cover both paths (success and failure) independently. Both are necessary: cleanup after success is easy to forget to test.

---

## Related Patterns

- [Chapter 10 — Memory and Resource Management](../../chapter10_memory_and_resources/README.md): Broader resource management patterns.
- [E5 — State After Exception](../e05_state_after_exception/README.md): Object state after an exception.

---

## Navigation

- Previous: [E8 — Boundary Conditions](../e08_boundary_conditions/README.md)
- Next: [Chapter 6 — Adversarial Inputs](../../chapter06_adversarial_inputs/README.md)
- Back: [Chapter 5 Overview](../README.md)
