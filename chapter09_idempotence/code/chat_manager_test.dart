import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

class MockChatDelegate implements ChatDelegate {
  int callCount = 0;
  final List<(String, String)> sent = [];

  @override
  void didSendMessage(String clientMessageId, String body) {
    callCount++;
    sent.add((clientMessageId, body));
  }
}

void main() {
  group('ChatManager idempotence', () {
    test('state is unchanged after calling send multiple times with the same clientMessageId', () {
      final manager = ChatManager();

      manager.send('msg-1', 'hello');
      manager.send('msg-1', 'hello');
      manager.send('msg-1', 'hello');

      expect(manager.sentCount, equals(1));
      expect(manager.bodyFor('msg-1'), equals('hello'));
    });

    test('delegate is called once when send is called multiple times with the same clientMessageId', () {
      final mockDelegate = MockChatDelegate();
      final manager = ChatManager()..delegate = mockDelegate;

      manager.send('msg-1', 'hello');
      manager.send('msg-1', 'hello');
      manager.send('msg-1', 'hello');

      expect(mockDelegate.callCount, equals(1));
    });

    test('delegate is called again for a different clientMessageId', () {
      final mockDelegate = MockChatDelegate();
      final manager = ChatManager()..delegate = mockDelegate;

      manager.send('msg-1', 'hello');
      manager.send('msg-2', 'world');

      expect(mockDelegate.callCount, equals(2));
    });

    test('delegate is not called before any send', () {
      final mockDelegate = MockChatDelegate();
      ChatManager()..delegate = mockDelegate;

      expect(mockDelegate.callCount, equals(0));
    });
  });
}
