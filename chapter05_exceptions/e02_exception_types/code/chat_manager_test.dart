import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

void main() {
  group('ChatManager.sendMessage exception types', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    test('throws InvalidMessageError for an empty message', () {
      expect(
        () => chatManager.sendMessage(''),
        throwsA(isA<InvalidMessageError>()),
      );
    });

    test('throws MessageLimitReachedError when the limit is exceeded', () {
      for (var i = 0; i < ChatManager.messageLimit; i++) {
        chatManager.sendMessage('Test message $i');
      }

      expect(
        () => chatManager.sendMessage('one too many'),
        throwsA(isA<MessageLimitReachedError>()),
      );
    });

    test('does not throw for a valid message within the limit', () {
      expect(
        () => chatManager.sendMessage('Hello'),
        returnsNormally,
      );
    });
  });
}
