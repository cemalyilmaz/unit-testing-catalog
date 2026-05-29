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
        // expected — this test is about cleanup, not the exception
      }

      expect(emptyFileHandle.isClosed, isTrue);
    });
  });
}
