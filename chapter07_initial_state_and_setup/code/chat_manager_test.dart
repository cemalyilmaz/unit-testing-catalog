import 'package:flutter_test/flutter_test.dart';

import 'chat_manager.dart';

class StubMessageHistoryLoader implements MessageHistoryLoader {
  final List<String> _results;
  StubMessageHistoryLoader(this._results);

  @override
  Future<List<String>> fetch(String conversationId) async => _results;
}

void main() {
  group('ChatManager initial state', () {
    test('messages is empty before any setup', () {
      final manager = ChatManager();
      expect(manager.messages, isEmpty);
    });

    test('messages remains empty when no loader is provided', () async {
      final manager = ChatManager();
      await manager.loadHistory('conv-1');
      expect(manager.messages, isEmpty);
    });

    test('messages is populated with loader results after loadHistory', () async {
      final loader = StubMessageHistoryLoader(
        ['welcome to the chat', 'how can I help?'],
      );
      final manager = ChatManager(loader: loader);

      await manager.loadHistory('conv-1');

      expect(manager.messages, isNotEmpty);
      expect(
        manager.messages,
        equals(['welcome to the chat', 'how can I help?']),
      );
    });

    test('loadHistory replaces existing messages, not appends', () async {
      final loader = StubMessageHistoryLoader(['fresh history']);
      final manager = ChatManager(loader: loader);
      manager.messages = ['stale message'];

      await manager.loadHistory('conv-1');

      expect(manager.messages, equals(['fresh history']));
    });
  });
}
