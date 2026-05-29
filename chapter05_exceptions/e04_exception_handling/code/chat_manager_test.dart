import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

class MockUserNotifier implements UserNotifier {
  String? lastNotification;

  @override
  void notify(String message) {
    lastNotification = message;
  }
}

void main() {
  group('ChatManager exception handling', () {
    late MockUserNotifier mockNotifier;
    late ChatManager chatManager;

    setUp(() {
      mockNotifier = MockUserNotifier();
      chatManager = ChatManager(notifier: mockNotifier);
    });

    test('notifies the user when a message contains prohibited content', () {
      chatManager.sendMessage('This is prohibited content');

      expect(
        mockNotifier.lastNotification,
        equals('Cannot send: message contains prohibited content.'),
      );
    });

    test('returns false when the message is rejected', () {
      final result = chatManager.sendMessage('prohibited text here');

      expect(result, isFalse);
    });

    test('returns true and does not notify for an acceptable message', () {
      final result = chatManager.sendMessage('Hello, world!');

      expect(result, isTrue);
      expect(mockNotifier.lastNotification, isNull);
    });
  });
}
