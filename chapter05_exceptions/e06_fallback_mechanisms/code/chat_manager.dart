abstract class NetworkService {
  Future<void> send(String message);
}

class NetworkUnavailableError implements Exception {}

class ChatManager {
  final NetworkService _networkService;
  final List<String> _pendingQueue = [];

  ChatManager({required NetworkService networkService})
      : _networkService = networkService;

  bool isMessageQueued(String message) => _pendingQueue.contains(message);

  Future<void> sendMessage(String message) async {
    try {
      await _networkService.send(message);
    } on NetworkUnavailableError {
      _pendingQueue.add(message);
    }
  }

  Future<void> retryQueuedMessages() async {
    final toRetry = List<String>.from(_pendingQueue);
    _pendingQueue.clear();
    for (final message in toRetry) {
      await sendMessage(message);
    }
  }
}
