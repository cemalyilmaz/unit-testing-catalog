abstract class MessageHistoryLoader {
  Future<List<String>> fetch(String conversationId);
}

class ChatManager {
  List<String> messages = [];
  final MessageHistoryLoader? _loader;

  ChatManager({MessageHistoryLoader? loader}) : _loader = loader;

  Future<void> loadHistory(String conversationId) async {
    if (_loader == null) return;
    messages = await _loader!.fetch(conversationId);
  }
}
