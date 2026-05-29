abstract class MessageStorage {
  void persist(String conversationId, String body);
}

abstract class AnalyticsLogger {
  void log(String event, {Map<String, dynamic>? parameters});
}

abstract class ChatObserver {
  void messageDidSend(SentMessage message);
}

class SentMessage {
  final String conversationId;
  final String body;

  const SentMessage({required this.conversationId, required this.body});
}

class ChatManager {
  final MessageStorage _storage;
  final AnalyticsLogger _logger;
  final List<ChatObserver> _observers = [];
  SentMessage? _lastSent;

  ChatManager({required MessageStorage storage, required AnalyticsLogger logger})
      : _storage = storage,
        _logger = logger;

  SentMessage? get lastSent => _lastSent;

  void addObserver(ChatObserver observer) {
    _observers.add(observer);
  }

  void sendMessage(String conversationId, String body, {bool silent = false}) {
    final message = SentMessage(conversationId: conversationId, body: body);
    _storage.persist(conversationId, body);
    _lastSent = message;

    if (silent) return;

    _logger.log('MessageSent', parameters: {'conversationId': conversationId});
    for (final observer in _observers) {
      observer.messageDidSend(message);
    }
  }
}
