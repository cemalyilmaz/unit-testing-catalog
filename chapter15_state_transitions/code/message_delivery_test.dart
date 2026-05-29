import 'package:flutter_test/flutter_test.dart';

import 'message_delivery.dart';

void main() {
  group('MessageDelivery — valid transitions', () {
    late MessageDelivery delivery;

    setUp(() {
      delivery = MessageDelivery();
    });

    test('Drafting → Sending via queue', () {
      delivery.queue('msg-1');
      expect(delivery.state, isA<Sending>());
    });

    test('Sending → Sent via acknowledge', () {
      delivery.queue('msg-1');
      delivery.acknowledge();
      expect(delivery.state, isA<Sent>());
    });

    test('Sent → Delivered via markDelivered', () {
      delivery.queue('msg-1');
      delivery.acknowledge();
      delivery.markDelivered();
      expect(delivery.state, isA<Delivered>());
    });

    test('Delivered → Read via markRead', () {
      delivery.queue('msg-1');
      delivery.acknowledge();
      delivery.markDelivered();
      delivery.markRead();
      expect(delivery.state, isA<Read>());
    });

    test('Sending → Failed via fail', () {
      delivery.queue('msg-1');
      delivery.fail('timeout');
      expect(delivery.state, isA<Failed>());
    });

    test('Sent → Failed via fail', () {
      delivery.queue('msg-1');
      delivery.acknowledge();
      delivery.fail('recipient blocked');
      expect(delivery.state, isA<Failed>());
    });

    test('Sending → Drafting via cancel', () {
      delivery.queue('msg-1');
      delivery.cancel();
      expect(delivery.state, isA<Drafting>());
    });

    test('Failed → Sending via retry', () {
      delivery.queue('msg-1');
      delivery.fail('timeout');
      delivery.retry();
      expect(delivery.state, isA<Sending>());
    });
  });

  group('MessageDelivery — clientId is preserved through transitions', () {
    test('clientId survives queue and acknowledge', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-abc');
      expect((delivery.state as Sending).clientId, equals('msg-abc'));

      delivery.acknowledge();
      expect((delivery.state as Sent).clientId, equals('msg-abc'));
    });

    test('clientId is present in Delivered state', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-abc');
      delivery.acknowledge();
      delivery.markDelivered();

      expect((delivery.state as Delivered).clientId, equals('msg-abc'));
    });

    test('clientId and error are present in Failed state', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-abc');
      delivery.fail('network error');

      final failed = delivery.state as Failed;
      expect(failed.clientId, equals('msg-abc'));
      expect(failed.error, equals('network error'));
    });

    test('clientId survives a failed retry cycle', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-abc');
      delivery.fail('timeout');
      delivery.retry();
      expect((delivery.state as Sending).clientId, equals('msg-abc'));
    });
  });

  group('MessageDelivery — invalid transitions throw InvalidTransitionError', () {
    test('queue from Sending throws', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-1');
      expect(() => delivery.queue('msg-2'), throwsA(isA<InvalidTransitionError>()));
    });

    test('acknowledge from Drafting throws', () {
      final delivery = MessageDelivery();
      expect(() => delivery.acknowledge(), throwsA(isA<InvalidTransitionError>()));
    });

    test('markDelivered from Drafting throws', () {
      final delivery = MessageDelivery();
      expect(() => delivery.markDelivered(), throwsA(isA<InvalidTransitionError>()));
    });

    test('markRead from Sent throws', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-1');
      delivery.acknowledge();
      expect(() => delivery.markRead(), throwsA(isA<InvalidTransitionError>()));
    });

    test('fail from Drafting throws', () {
      final delivery = MessageDelivery();
      expect(() => delivery.fail('error'), throwsA(isA<InvalidTransitionError>()));
    });

    test('fail from Delivered throws', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-1');
      delivery.acknowledge();
      delivery.markDelivered();
      expect(() => delivery.fail('too late'), throwsA(isA<InvalidTransitionError>()));
    });

    test('cancel from Drafting throws', () {
      final delivery = MessageDelivery();
      expect(() => delivery.cancel(), throwsA(isA<InvalidTransitionError>()));
    });

    test('cancel from Sent throws — sent messages cannot be unsent', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-1');
      delivery.acknowledge();
      expect(() => delivery.cancel(), throwsA(isA<InvalidTransitionError>()));
    });

    test('retry from Drafting throws', () {
      final delivery = MessageDelivery();
      expect(() => delivery.retry(), throwsA(isA<InvalidTransitionError>()));
    });

    test('retry from Read throws', () {
      final delivery = MessageDelivery();
      delivery.queue('msg-1');
      delivery.acknowledge();
      delivery.markDelivered();
      delivery.markRead();
      expect(() => delivery.retry(), throwsA(isA<InvalidTransitionError>()));
    });
  });
}
