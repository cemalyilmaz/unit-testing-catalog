import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

class StubNetworkService implements NetworkService {
  bool simulateFailure = false;

  @override
  Future<void> send(String message) async {
    if (simulateFailure) {
      throw NetworkUnavailableError();
    }
  }
}

void main() {
  group('ChatManager fallback mechanisms', () {
    late StubNetworkService stubNetwork;
    late ChatManager chatManager;

    setUp(() {
      stubNetwork = StubNetworkService();
      chatManager = ChatManager(networkService: stubNetwork);
    });

    test('queues message when network is unavailable', () async {
      stubNetwork.simulateFailure = true;

      await chatManager.sendMessage('Hello!');

      expect(chatManager.isMessageQueued('Hello!'), isTrue);
    });

    test('does not queue message when network is available', () async {
      await chatManager.sendMessage('Hello!');

      expect(chatManager.isMessageQueued('Hello!'), isFalse);
    });

    test('retries queued messages when network becomes available', () async {
      stubNetwork.simulateFailure = true;
      await chatManager.sendMessage('Hello!');

      stubNetwork.simulateFailure = false;
      await chatManager.retryQueuedMessages();

      expect(chatManager.isMessageQueued('Hello!'), isFalse);
    });
  });
}
