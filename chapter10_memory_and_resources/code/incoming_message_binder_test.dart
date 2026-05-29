import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'incoming_message_binder.dart';

void main() {
  group('IncomingMessageBinder', () {
    late IncomingMessageBinder binder;

    setUp(() {
      binder = IncomingMessageBinder();
    });

    test('cancels all subscriptions when disposed', () async {
      final incomingMessages = StreamController<String>();
      final typingIndicators = StreamController<bool>();

      binder.bind(incomingMessages.stream.listen((_) {}));
      binder.bind(typingIndicators.stream.listen((_) {}));

      await binder.dispose();

      expect(incomingMessages.hasListener, isFalse);
      expect(typingIndicators.hasListener, isFalse);

      await incomingMessages.close();
      await typingIndicators.close();
    });

    test('subscriptionCount reflects the number of bound subscriptions', () async {
      final incomingMessages = StreamController<String>();
      binder.bind(incomingMessages.stream.listen((_) {}));

      expect(binder.subscriptionCount, equals(1));

      await binder.dispose();
      await incomingMessages.close();
    });

    test('isDisposed is true after dispose', () async {
      await binder.dispose();

      expect(binder.isDisposed, isTrue);
    });

    test('throws StateError when binding a subscription after dispose', () async {
      await binder.dispose();
      final incomingMessages = StreamController<String>();

      expect(
        () => binder.bind(incomingMessages.stream.listen((_) {})),
        throwsA(isA<StateError>()),
      );

      await incomingMessages.close();
    });
  });
}
