class ChatError implements Exception {
  final String message;
  ChatError(this.message);

  @override
  String toString() => 'ChatError: $message';
}

class ChatManager {
  String? lastSent;

  void sendMessage(String body) {
    if (body.trim().isEmpty) {
      throw ChatError('Message body cannot be empty.');
    }
    lastSent = body;
  }
}
