import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

void main() {
  group('ChatManager.sendMessage', () {
    late ChatManager manager;

    setUp(() {
      manager = ChatManager();
    });

    test('accepts a non-empty message', () {
      manager.sendMessage('hello');
      expect(manager.lastSent, equals('hello'));
    });

    test('throws ChatError when the message body is empty', () {
      expect(
        () => manager.sendMessage(''),
        throwsA(isA<ChatError>()),
      );
    });

    test('throws ChatError when the message body is whitespace only', () {
      expect(
        () => manager.sendMessage('   '),
        throwsA(isA<ChatError>()),
      );
    });

    test('does not record a lastSent message when an exception is thrown', () {
      try {
        manager.sendMessage('');
      } catch (_) {}
      expect(manager.lastSent, isNull);
    });
  });
}
