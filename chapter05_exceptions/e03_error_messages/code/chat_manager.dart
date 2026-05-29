class ChatError implements Exception {
  final String message;
  ChatError(this.message);

  @override
  String toString() => message;
}

class InvalidMessageError extends ChatError {
  InvalidMessageError() : super('Message cannot be empty.');
}

class MessageLimitReachedError extends ChatError {
  MessageLimitReachedError() : super('Message limit reached.');
}

class ChatManager {
  static const int messageLimit = 100;
  final List<String> _messages = [];

  void sendMessage(String message) {
    if (message.isEmpty) {
      throw InvalidMessageError();
    }
    if (_messages.length >= messageLimit) {
      throw MessageLimitReachedError();
    }
    _messages.add(message);
  }
}
