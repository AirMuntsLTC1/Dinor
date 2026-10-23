import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DinorAI {
  static Future<String> getResponse(String userMessage) async {
    final msg = userMessage.toLowerCase().trim();

    if (msg == 'hi' || msg == 'hello' || msg == 'hey') {
      return "Hello! I am Dinor AI. I am connected to the live web. What do you want to search?";
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return "I am currently offline. Please check your internet connection.";
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'chat-ai',
        body: {'userMessage': userMessage},
      );

      if (response.status == 200 && response.data['reply'] != null) {
        return response.data['reply'];
      } else {
        final errorMsg = response.data != null ? response.data.toString() : "Unknown error";
        return "Error: $errorMsg (Status ${response.status})";
      }
    } catch (e) {
      return "Oops, I lost my connection. Error: $e";
    }
  }
}
