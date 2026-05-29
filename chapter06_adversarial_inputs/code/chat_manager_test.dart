import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

void main() {
  group('ChatManager edge cases', () {
    late ChatManager chatManager;

    setUp(() {
      chatManager = ChatManager();
    });

    test(
        'sorts messages into chronological order when they arrive out of order',
        () {
      // Messages with timestamps: "Hello"=1.0, "!"=2.0, "World"=3.0
      // Received in order: "!" (t=2.0), "Hello" (t=1.0), "World" (t=3.0)
      chatManager.receiveMessage(
          const Message(id: '2', text: '!', timestamp: 2.0));
      chatManager.receiveMessage(
          const Message(id: '1', text: 'Hello', timestamp: 1.0));
      chatManager.receiveMessage(
          const Message(id: '3', text: 'World', timestamp: 3.0));

      final orderedTexts = chatManager.messages.map((m) => m.text).toList();
      expect(orderedTexts, equals(['Hello', '!', 'World']));
    });

    test('handles a single message with no sorting needed', () {
      chatManager.receiveMessage(
        const Message(id: '1', text: 'Only message', timestamp: 1.0),
      );

      expect(chatManager.messages.length, equals(1));
      expect(chatManager.messages.first.text, equals('Only message'));
    });

    test('handles two messages arriving in reverse order', () {
      chatManager.receiveMessage(
          const Message(id: '2', text: 'Second', timestamp: 2.0));
      chatManager.receiveMessage(
          const Message(id: '1', text: 'First', timestamp: 1.0));

      expect(chatManager.messages.first.text, equals('First'));
      expect(chatManager.messages.last.text, equals('Second'));
    });

    test('handles messages with identical timestamps without dropping either',
        () {
      chatManager.receiveMessage(
          const Message(id: '1', text: 'A', timestamp: 1.0));
      chatManager.receiveMessage(
          const Message(id: '2', text: 'B', timestamp: 1.0));

      expect(chatManager.messages.length, equals(2));
    });
  });
}
