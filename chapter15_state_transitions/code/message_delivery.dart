sealed class MessageDeliveryState {}

class Drafting extends MessageDeliveryState {}

class Sending extends MessageDeliveryState {
  final String clientId;
  Sending(this.clientId);
}

class Sent extends MessageDeliveryState {
  final String clientId;
  Sent(this.clientId);
}

class Delivered extends MessageDeliveryState {
  final String clientId;
  Delivered(this.clientId);
}

class Read extends MessageDeliveryState {
  final String clientId;
  Read(this.clientId);
}

class Failed extends MessageDeliveryState {
  final String clientId;
  final String error;
  Failed(this.clientId, this.error);
}

class InvalidTransitionError extends Error {
  final String operation;
  final MessageDeliveryState fromState;

  InvalidTransitionError(this.operation, this.fromState);

  @override
  String toString() =>
      'InvalidTransitionError: Cannot call "$operation" from state '
      '${fromState.runtimeType}';
}

class MessageDelivery {
  MessageDeliveryState _state = Drafting();

  MessageDeliveryState get state => _state;

  void queue(String clientId) {
    if (_state is! Drafting) throw InvalidTransitionError('queue', _state);
    _state = Sending(clientId);
  }

  void acknowledge() {
    if (_state is! Sending) throw InvalidTransitionError('acknowledge', _state);
    _state = Sent((_state as Sending).clientId);
  }

  void markDelivered() {
    if (_state is! Sent) throw InvalidTransitionError('markDelivered', _state);
    _state = Delivered((_state as Sent).clientId);
  }

  void markRead() {
    if (_state is! Delivered) throw InvalidTransitionError('markRead', _state);
    _state = Read((_state as Delivered).clientId);
  }

  void fail(String error) {
    if (_state is Sending) {
      _state = Failed((_state as Sending).clientId, error);
    } else if (_state is Sent) {
      _state = Failed((_state as Sent).clientId, error);
    } else {
      throw InvalidTransitionError('fail', _state);
    }
  }

  void cancel() {
    if (_state is! Sending) throw InvalidTransitionError('cancel', _state);
    _state = Drafting();
  }

  void retry() {
    if (_state is! Failed) throw InvalidTransitionError('retry', _state);
    _state = Sending((_state as Failed).clientId);
  }
}
