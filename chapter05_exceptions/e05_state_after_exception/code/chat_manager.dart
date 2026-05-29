class RateLimitExceededError implements Exception {}

class ChatManager {
  final List<String> messageQueue = [];
  bool isSendingEnabled = true;

  void hitRateLimit() {
    isSendingEnabled = false;
  }

  void sendMessage(String message) {
    if (!isSendingEnabled) {
      throw RateLimitExceededError();
    }
    messageQueue.add(message);
  }
}
