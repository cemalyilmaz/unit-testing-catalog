import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

void main() {
  group('ChatManager error messages', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    test('InvalidMessageError carries the correct message', () {
      expect(
        () => chatManager.sendMessage(''),
        throwsA(
          isA<InvalidMessageError>().having(
            (e) => e.message,
            'message',
            equals('Message cannot be empty.'),
          ),
        ),
      );
    });

    test('MessageLimitReachedError carries the correct message', () {
      for (var i = 0; i < ChatManager.messageLimit; i++) {
        chatManager.sendMessage('Test $i');
      }

      expect(
        () => chatManager.sendMessage('overflow'),
        throwsA(
          isA<MessageLimitReachedError>().having(
            (e) => e.message,
            'message',
            equals('Message limit reached.'),
          ),
        ),
      );
    });
  });
}
