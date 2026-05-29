import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

class MockMessageStorage implements MessageStorage {
  String? persistedConversationId;
  String? persistedBody;

  @override
  void persist(String conversationId, String body) {
    persistedConversationId = conversationId;
    persistedBody = body;
  }
}

class MockAnalyticsLogger implements AnalyticsLogger {
  int callCount = 0;
  String? lastEvent;
  Map<String, dynamic>? lastParameters;

  @override
  void log(String event, {Map<String, dynamic>? parameters}) {
    callCount++;
    lastEvent = event;
    lastParameters = parameters;
  }
}

class MockChatObserver implements ChatObserver {
  int callCount = 0;
  SentMessage? lastMessage;

  @override
  void messageDidSend(SentMessage message) {
    callCount++;
    lastMessage = message;
  }
}

void main() {
  group('ChatManager.sendMessage side effects', () {
    late MockMessageStorage storage;
    late MockAnalyticsLogger logger;
    late MockChatObserver observer;
    late ChatManager manager;

    setUp(() {
      storage = MockMessageStorage();
      logger = MockAnalyticsLogger();
      observer = MockChatObserver();
      manager = ChatManager(storage: storage, logger: logger);
      manager.addObserver(observer);
    });

    tearDown(() {
      // Release any resources held by observer here.
      // Use addTearDown() inside a test body for test-specific cleanup.
    });

    test('persists the message to storage', () {
      manager.sendMessage('conv-1', 'hello');

      expect(storage.persistedConversationId, equals('conv-1'));
      expect(storage.persistedBody, equals('hello'));
    });

    test('updates the in-memory lastSent record', () {
      manager.sendMessage('conv-1', 'hello');

      expect(manager.lastSent?.body, equals('hello'));
    });

    test('notifies a registered observer once', () {
      manager.sendMessage('conv-1', 'hello');

      expect(observer.callCount, equals(1));
    });

    test('passes the sent message to the observer', () {
      manager.sendMessage('conv-1', 'hello');

      expect(observer.lastMessage?.body, equals('hello'));
      expect(observer.lastMessage?.conversationId, equals('conv-1'));
    });

    test('logs an analytics event with the conversation id', () {
      manager.sendMessage('conv-1', 'hello');

      expect(logger.callCount, equals(1));
      expect(logger.lastEvent, equals('MessageSent'));
      expect(logger.lastParameters?['conversationId'], equals('conv-1'));
    });

    test('notifies all registered observers', () {
      final secondObserver = MockChatObserver();
      manager.addObserver(secondObserver);

      manager.sendMessage('conv-1', 'hello');

      expect(observer.callCount, equals(1));
      expect(secondObserver.callCount, equals(1));
    });

    test('does not notify observers or log analytics when silent is true', () {
      manager.sendMessage('conv-1', 'hello', silent: true);

      expect(observer.callCount, equals(0));
      expect(logger.callCount, equals(0));
      expect(storage.persistedBody, equals('hello'));
    });
  });
}
