import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DinorAI {
  static Future<String> getResponse(String userMessage, {String? imageBase64}) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return "I am currently offline. Please check your internet connection.";
    }

    final supabase = Supabase.instance.client;

    try {
      final response = await supabase.functions.invoke(
        'chat-ai',
        body: {
          'userMessage': userMessage,
          if (imageBase64 != null) 'imageBase64': imageBase64,
        },
      );

      if (response.status == 200 && response.data != null) {
        final reply = response.data['reply'];
        if (reply != null && reply is String && reply.trim().isNotEmpty) {
          return reply;
        }
      }
      return "I couldn't process that image. Please try again.";
    } catch (e) {
      return "Connection error: $e";
    }
  }
}
