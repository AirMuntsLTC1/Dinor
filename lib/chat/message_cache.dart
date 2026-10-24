import '../ui/chat_screen.dart';

class MessageCache {
  // Stores messages by conversationId
  static final Map<String, List<Message>> _cache = {};

  static List<Message>? getMessages(String conversationId) {
    return _cache[conversationId];
  }

  static void saveMessages(String conversationId, List<Message> messages) {
    _cache[conversationId] = List.from(messages);
  }

  static void clearCache() {
    _cache.clear();
  }
}
