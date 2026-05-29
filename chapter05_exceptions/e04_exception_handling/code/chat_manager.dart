abstract class UserNotifier {
  void notify(String message);
}

class ProhibitedContentError implements Exception {
  final String message;
  ProhibitedContentError(this.message);
}

class ChatManager {
  final UserNotifier _notifier;

  ChatManager({required UserNotifier notifier}) : _notifier = notifier;

  bool sendMessage(String message) {
    if (message.contains('prohibited')) {
      _notifier.notify('Cannot send: message contains prohibited content.');
      return false;
    }
    return true;
  }
}
