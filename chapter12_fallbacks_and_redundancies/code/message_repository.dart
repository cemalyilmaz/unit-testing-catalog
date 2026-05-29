abstract class MessageRemote {
  Future<Message?> fetchMessage(String id);
}

abstract class MessageCache {
  Message? getCachedMessage(String id);
  void cacheMessage(String id, Message message);
}

class Message {
  final String id;
  final String body;

  const Message({required this.id, required this.body});

  static Message placeholderFor(String id) =>
      Message(id: id, body: 'Message unavailable');
}

class MessageRepository {
  final MessageRemote _remote;
  final MessageCache _cache;

  MessageRepository({required MessageRemote remote, required MessageCache cache})
      : _remote = remote,
        _cache = cache;

  Future<Message> getMessage(String id) async {
    try {
      final message = await _remote.fetchMessage(id);
      if (message != null) {
        _cache.cacheMessage(id, message);
        return message;
      }
    } catch (_) {
      // remote unavailable — fall through to cache
    }

    final cached = _cache.getCachedMessage(id);
    if (cached != null) return cached;

    return Message.placeholderFor(id);
  }
}
