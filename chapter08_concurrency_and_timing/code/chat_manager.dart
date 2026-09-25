import 'dart:async';

abstract class ChatDelegate {
  void onAcknowledged(String clientId);
  void onFailed(String clientId, Exception error);
  void onDeliveryReceipt(String clientId, DeliveryStatus status);
}

enum DeliveryStatus { sending, sent, delivered, read }

abstract class ChatSendingService {
  Future<void> send(String clientId, String body);
}

class ChatManager {
  final ChatSendingService _service;
  final Map<String, DeliveryStatus> _deliveryStatus = {};
  final Set<String> _activeSends = {};
  final Map<String, StreamController<DeliveryStatus>> _deliveryControllers = {};
  ChatDelegate? delegate;

  ChatManager({required ChatSendingService service}) : _service = service;

  bool isSending(String clientId) => _activeSends.contains(clientId);

  DeliveryStatus? deliveryStatusFor(String clientId) => _deliveryStatus[clientId];

  /// Delivery receipts for [clientId], in the order they arrive.
  Stream<DeliveryStatus> deliveryStream(String clientId) =>
      _controllerFor(clientId).stream;

  Future<void> sendMessage(String clientId, String body) async {
    if (_activeSends.contains(clientId)) return;
    _activeSends.add(clientId);
    _deliveryStatus[clientId] = DeliveryStatus.sending;
    try {
      await _service.send(clientId, body);
      _activeSends.remove(clientId);
      _deliveryStatus[clientId] = DeliveryStatus.sent;
      delegate?.onAcknowledged(clientId);
    } on Exception catch (e) {
      _activeSends.remove(clientId);
      _deliveryStatus.remove(clientId);
      delegate?.onFailed(clientId, e);
    }
  }

  void markDelivered(String clientId, DeliveryStatus status) {
    if (!_deliveryStatus.containsKey(clientId)) return;
    _deliveryStatus[clientId] = status;
    _deliveryControllers[clientId]?.add(status);
    delegate?.onDeliveryReceipt(clientId, status);
  }

  void cancel(String clientId) {
    _activeSends.remove(clientId);
    _deliveryStatus.remove(clientId);
  }

  Future<void> dispose() async {
    for (final controller in _deliveryControllers.values) {
      await controller.close();
    }
    _deliveryControllers.clear();
  }

  StreamController<DeliveryStatus> _controllerFor(String clientId) =>
      _deliveryControllers[clientId] ??=
          StreamController<DeliveryStatus>.broadcast();
}
