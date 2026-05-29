abstract class NetworkService {
  Future<Map<String, dynamic>> get(String path);
  Future<void> post(String path, Map<String, dynamic> body);
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class Message {
  final String id;
  final String text;
  final String senderId;

  const Message({required this.id, required this.text, required this.senderId});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      text: json['text'] as String,
      senderId: json['senderId'] as String,
    );
  }
}

class ChatService {
  final NetworkService _network;

  ChatService({required NetworkService network}) : _network = network;

  Future<List<Message>> fetchMessages() async {
    final response = await _network.get('/messages');
    final items = response['messages'] as List<dynamic>;
    return items
        .map((item) => Message.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendMessage(String text) async {
    await _network.post('/messages', {'text': text});
  }
}
