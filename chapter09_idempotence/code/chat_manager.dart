abstract class ChatDelegate {
  void didSendMessage(String clientMessageId, String body);
}

class ChatManager {
  final Map<String, String> _sentBodies = {};
  ChatDelegate? delegate;

  /// Sends a message identified by a stable client-generated id.
  /// Calling send for an id that has already been sent does not change
  /// the recorded body and does not re-notify the delegate.
  void send(String clientMessageId, String body) {
    if (_sentBodies.containsKey(clientMessageId)) return;
    _sentBodies[clientMessageId] = body;
    delegate?.didSendMessage(clientMessageId, body);
  }

  String? bodyFor(String clientMessageId) => _sentBodies[clientMessageId];

  int get sentCount => _sentBodies.length;
}
