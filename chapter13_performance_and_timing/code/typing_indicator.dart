import 'dart:async';

/// Notifies the server that the local user has stopped typing.
/// Each keystroke resets the timer; the callback only fires once
/// after [delay] of inactivity, no matter how fast the user types.
class TypingIndicator {
  final Duration delay;
  final void Function(String conversationId) onStoppedTyping;
  Timer? _timer;

  TypingIndicator({required this.delay, required this.onStoppedTyping});

  void onKeystroke(String conversationId) {
    _timer?.cancel();
    _timer = Timer(delay, () => onStoppedTyping(conversationId));
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
