import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

class MockAnalyticsApi implements AnalyticsApi {
  String? capturedEventName;
  Map<String, dynamic>? capturedParameters;

  @override
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    capturedEventName = eventName;
    capturedParameters = parameters;
  }
}

void main() {
  group('ChatManager', () {
    late MockAnalyticsApi mockAnalytics;
    late ChatManager chatManager;

    setUp(() {
      mockAnalytics = MockAnalyticsApi();
      chatManager = ChatManager(analyticsApi: mockAnalytics);
    });

    test('sendMessage logs a MessageSent event', () {
      chatManager.sendMessage('Hello, world!');

      expect(mockAnalytics.capturedEventName, equals('MessageSent'));
    });

    test('sendMessage includes the message text in the event parameters', () {
      chatManager.sendMessage('Hello, world!');

      expect(
        mockAnalytics.capturedParameters?['message'],
        equals('Hello, world!'),
      );
    });
  });
}
