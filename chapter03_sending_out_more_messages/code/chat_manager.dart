abstract class AnalyticsApi {
  void logEvent(String eventName, {Map<String, dynamic>? parameters});
}

class ChatManager {
  final AnalyticsApi _analyticsApi;

  ChatManager({required AnalyticsApi analyticsApi})
      : _analyticsApi = analyticsApi;

  void sendMessage(String message) {
    _analyticsApi.logEvent(
      'MessageSent',
      parameters: {'message': message},
    );
  }
}
