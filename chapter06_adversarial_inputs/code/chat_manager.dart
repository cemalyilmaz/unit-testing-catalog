class Message {
  final String id;
  final String text;
  final double timestamp;

  const Message({
    required this.id,
    required this.text,
    required this.timestamp,
  });
}

class ChatManager {
  final List<Message> messages = [];

  void receiveMessage(Message message) {
    messages.add(message);
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}
