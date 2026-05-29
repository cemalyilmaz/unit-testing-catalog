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
        final overLimitFile = List.filled(ChatManager.maxFileSizeBytes + 1, 0);
        expect(
          () => chatManager.uploadFile(overLimitFile),
          throwsA(isA<FileSizeExceededError>()),
        );
      });
    });
  });
}
