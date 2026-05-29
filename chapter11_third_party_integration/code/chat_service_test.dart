import 'package:flutter_test/flutter_test.dart';

import 'chat_service.dart';

class StubNetworkService implements NetworkService {
  Map<String, dynamic>? _response;
  Exception? _error;

  void willReturn(Map<String, dynamic> response) => _response = response;
  void willThrow(Exception error) => _error = error;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (_error != null) throw _error!;
    return _response ?? {};
  }

  @override
  Future<void> post(String path, Map<String, dynamic> body) async {}
}

class MockNetworkService implements NetworkService {
  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Map<String, dynamic>> get(String path) async => {};

  @override
  Future<void> post(String path, Map<String, dynamic> body) async {
    lastPostPath = path;
    lastPostBody = body;
  }
}

void main() {
  group('ChatService.fetchMessages', () {
    late StubNetworkService stubNetwork;
    late ChatService service;

    setUp(() {
      stubNetwork = StubNetworkService();
      service = ChatService(network: stubNetwork);
    });

    test('returns a parsed list of messages when network succeeds', () async {
      stubNetwork.willReturn({
        'messages': [
          {'id': '1', 'text': 'Hello', 'senderId': 'user1'},
          {'id': '2', 'text': 'World', 'senderId': 'user2'},
        ]
      });

      final messages = await service.fetchMessages();

      expect(messages.length, equals(2));
      expect(messages.first.text, equals('Hello'));
      expect(messages.last.senderId, equals('user2'));
    });

    test('returns an empty list when the network returns no messages', () async {
      stubNetwork.willReturn({'messages': []});

      final messages = await service.fetchMessages();

      expect(messages, isEmpty);
    });

    test('propagates NetworkException when network fails', () async {
      stubNetwork.willThrow(NetworkException('503 Service Unavailable'));

      expect(
        () => service.fetchMessages(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('ChatService.sendMessage', () {
    late MockNetworkService mockNetwork;
    late ChatService service;

    setUp(() {
      mockNetwork = MockNetworkService();
      service = ChatService(network: mockNetwork);
    });

    test('posts to the correct path', () async {
      await service.sendMessage('Hello');

      expect(mockNetwork.lastPostPath, equals('/messages'));
    });

    test('includes the message text in the request body', () async {
      await service.sendMessage('Hello');

      expect(mockNetwork.lastPostBody?['text'], equals('Hello'));
    });
  });
}
