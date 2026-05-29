import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

void main() {
  group('ChatManager state after exception', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    test('message queue remains empty after rate limit exception', () {
      chatManager.hitRateLimit();

      try {
        chatManager.sendMessage('Hello!');
      } on RateLimitExceededError {
        // expected — this test is about state, not the exception itself
      }

      expect(chatManager.messageQueue, isEmpty);
    });

    test('isSendingEnabled is false after rate limit is hit', () {
      chatManager.hitRateLimit();

      expect(chatManager.isSendingEnabled, isFalse);
    });

    test('throws RateLimitExceededError when sending is disabled', () {
      chatManager.hitRateLimit();

      expect(
        () => chatManager.sendMessage('Hello!'),
        throwsA(isA<RateLimitExceededError>()),
      );
    });

    test('successfully adds message to queue when sending is enabled', () {
      chatManager.sendMessage('Hello!');

      expect(chatManager.messageQueue, contains('Hello!'));
    });
  });
}
