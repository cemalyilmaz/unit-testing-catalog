import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

class StubChatSendingService implements ChatSendingService {
  Exception? errorToThrow;
  final Map<String, Completer<void>> _completers = {};

  Completer<void> completerFor(String clientId) {
    _completers[clientId] ??= Completer<void>();
    return _completers[clientId]!;
  }

  @override
  Future<void> send(String clientId, String body) {
    return completerFor(clientId).future.then((_) {
      if (errorToThrow != null) throw errorToThrow!;
    });
  }

  void completeSend(String clientId) {
    completerFor(clientId).complete();
  }
}

class MockChatDelegate implements ChatDelegate {
  final List<String> acknowledged = [];
  final List<(String, Exception)> failed = [];
  final List<(String, DeliveryStatus)> receipts = [];

  @override
  void onAcknowledged(String clientId) => acknowledged.add(clientId);

  @override
  void onFailed(String clientId, Exception error) =>
      failed.add((clientId, error));

  @override
  void onDeliveryReceipt(String clientId, DeliveryStatus status) =>
      receipts.add((clientId, status));
}

void main() {
  group('ChatManager', () {
    late StubChatSendingService stubService;
    late MockChatDelegate mockDelegate;
    late ChatManager manager;

    setUp(() {
      stubService = StubChatSendingService();
      mockDelegate = MockChatDelegate();
      manager = ChatManager(service: stubService)..delegate = mockDelegate;
    });

    test('reports active send while in progress', () {
      manager.sendMessage('msg-1', 'hello');

      expect(manager.isSending('msg-1'), isTrue);
    });

    test('notifies delegate when the server acknowledges the send', () async {
      final send = manager.sendMessage('msg-1', 'hello');
      stubService.completeSend('msg-1');
      await send;

      expect(mockDelegate.acknowledged, contains('msg-1'));
      expect(manager.deliveryStatusFor('msg-1'), equals(DeliveryStatus.sent));
    });

    test('notifies delegate on send failure', () async {
      stubService.errorToThrow = Exception('network down');

      final send = manager.sendMessage('msg-1', 'hello');
      stubService.completeSend('msg-1');
      await send;

      expect(mockDelegate.failed.map((r) => r.$1), contains('msg-1'));
    });

    test('does not start a duplicate send for the same clientId', () {
      manager.sendMessage('msg-1', 'hello');
      manager.sendMessage('msg-1', 'hello');

      expect(manager.isSending('msg-1'), isTrue);
    });

    test('handles concurrent sends independently', () async {
      final s1 = manager.sendMessage('msg-1', 'hello');
      final s2 = manager.sendMessage('msg-2', 'world');

      stubService.completeSend('msg-1');
      stubService.completeSend('msg-2');
      await Future.wait([s1, s2]);

      expect(mockDelegate.acknowledged, containsAll(['msg-1', 'msg-2']));
    });

    test('tracks delivery receipts after the message is sent', () async {
      final send = manager.sendMessage('msg-1', 'hello');
      stubService.completeSend('msg-1');
      await send;

      manager.markDelivered('msg-1', DeliveryStatus.delivered);

      expect(manager.deliveryStatusFor('msg-1'), equals(DeliveryStatus.delivered));
      expect(mockDelegate.receipts, contains(('msg-1', DeliveryStatus.delivered)));
    });

    test('clears active status and delivery state after cancellation', () {
      manager.sendMessage('msg-1', 'hello');
      manager.cancel('msg-1');

      expect(manager.isSending('msg-1'), isFalse);
      expect(manager.deliveryStatusFor('msg-1'), isNull);
    });
  });
}
