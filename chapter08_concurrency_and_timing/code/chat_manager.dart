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
  ChatDelegate? delegate;

  ChatManager({required ChatSendingService service}) : _service = service;

  bool isSending(String clientId) => _activeSends.contains(clientId);

  DeliveryStatus? deliveryStatusFor(String clientId) => _deliveryStatus[clientId];

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
    delegate?.onDeliveryReceipt(clientId, status);
  }

  void cancel(String clientId) {
    _activeSends.remove(clientId);
    _deliveryStatus.remove(clientId);
  }
}
