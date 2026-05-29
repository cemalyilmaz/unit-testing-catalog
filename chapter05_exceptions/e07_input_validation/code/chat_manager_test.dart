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
      final oversizedUnsupported =
          List.filled(ChatManager.maxFileSizeBytes + 1, 0);
      expect(
        () => chatManager.uploadFile('virus.exe', oversizedUnsupported),
        throwsA(isA<UnsupportedFileTypeError>()),
      );
    });
  });
}
