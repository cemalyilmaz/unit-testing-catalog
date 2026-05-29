class RateLimitExceededError implements Exception {}

class FileSizeExceededError implements Exception {}

class ChatManager {
  static const int messageRateLimit = 100;
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  int _messageCount = 0;

  void sendMessage(String message) {
    if (_messageCount >= messageRateLimit) {
      throw RateLimitExceededError();
    }
    _messageCount++;
  }

  void uploadFile(List<int> fileData) {
    if (fileData.length > maxFileSizeBytes) {
      throw FileSizeExceededError();
    }
    // upload logic
  }

  void resetRateLimit() {
    _messageCount = 0;
  }
}
