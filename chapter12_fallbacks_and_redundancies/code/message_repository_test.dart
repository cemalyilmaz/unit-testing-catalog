import 'package:flutter_test/flutter_test.dart';

import 'message_repository.dart';

class StubMessageRemote implements MessageRemote {
  Message? _response;
  bool _shouldThrow = false;

  void willReturn(Message? message) => _response = message;
  void willThrow() => _shouldThrow = true;

  @override
  Future<Message?> fetchMessage(String id) async {
    if (_shouldThrow) throw Exception('Network unavailable');
    return _response;
  }
}

class MockMessageCache implements MessageCache {
  final Map<String, Message> _store = {};
  int cacheWriteCount = 0;

  @override
  Message? getCachedMessage(String id) => _store[id];

  @override
  void cacheMessage(String id, Message message) {
    cacheWriteCount++;
    _store[id] = message;
  }
}

void main() {
  group('MessageRepository.getMessage', () {
    late StubMessageRemote stubRemote;
    late MockMessageCache mockCache;
    late MessageRepository repository;

    setUp(() {
      stubRemote = StubMessageRemote();
      mockCache = MockMessageCache();
      repository = MessageRepository(remote: stubRemote, cache: mockCache);
    });

    test('returns remote message when remote succeeds', () async {
      stubRemote.willReturn(const Message(id: 'm1', body: 'hello'));

      final message = await repository.getMessage('m1');

      expect(message.body, equals('hello'));
    });

    test('writes remote message to cache when remote succeeds', () async {
      stubRemote.willReturn(const Message(id: 'm1', body: 'hello'));

      await repository.getMessage('m1');

      expect(mockCache.cacheWriteCount, equals(1));
      expect(mockCache.getCachedMessage('m1')?.body, equals('hello'));
    });

    test('returns cached message when remote throws', () async {
      stubRemote.willThrow();
      mockCache.cacheMessage('m1', const Message(id: 'm1', body: 'cached hello'));

      final message = await repository.getMessage('m1');

      expect(message.body, equals('cached hello'));
    });

    test('does not write to cache when falling back to cached message', () async {
      stubRemote.willThrow();
      mockCache.cacheMessage('m1', const Message(id: 'm1', body: 'cached hello'));
      final writeCountBefore = mockCache.cacheWriteCount;

      await repository.getMessage('m1');

      expect(mockCache.cacheWriteCount, equals(writeCountBefore));
    });

    test('returns placeholder Message when both remote throws and cache is empty', () async {
      stubRemote.willThrow();

      final message = await repository.getMessage('m1');

      expect(message.body, equals('Message unavailable'));
      expect(message.id, equals('m1'));
    });
  });
}
