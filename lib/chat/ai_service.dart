import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DinorAI {
  static Future<String> getResponse(String userMessage) async {
    final msg = userMessage.toLowerCase().trim();

    if (msg == 'hi' || msg == 'hello' || msg == 'hey') {
      return "Hello! I am Dinor AI. I have live access to the web. What do you want to know?";
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return "I am currently offline. Please check your internet connection.";
    }

    final supabase = Supabase.instance.client;

    // Try up to 2 times to get a valid response
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await supabase.functions.invoke(
          'chat-ai',
          body: {'userMessage': userMessage},
        );

        if (response.status == 200 && response.data != null) {
          final reply = response.data['reply'];
          if (reply != null && reply is String && reply.trim().isNotEmpty) {
            return reply;
          }
        }
        // If we got here, the response was invalid. Try again.
      } catch (e) {
        if (attempt == 2) {
          return "I lost connection while searching the web. Please try again.";
        }
        // Wait 1 second before retrying
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return "I couldn't reach the web right now. Please try again.";
  }
}
