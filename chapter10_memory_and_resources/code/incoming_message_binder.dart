import 'dart:async';

/// Holds the stream subscriptions used by a chat screen — incoming messages,
/// typing indicators, presence updates — and cancels all of them in one shot
/// when the screen is disposed.
class IncomingMessageBinder {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;
  int get subscriptionCount => _subscriptions.length;

  void bind(StreamSubscription<dynamic> subscription) {
    if (_isDisposed) {
      throw StateError('Cannot bind subscriptions to a disposed binder');
    }
    _subscriptions.add(subscription);
  }

  Future<void> dispose() async {
    _isDisposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
