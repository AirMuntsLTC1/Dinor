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

      // Safely extract the reply
      if (response.status == 200 && response.data != null) {
        final data = response.data;
        
        // If it's a Map, look for the 'reply' key
        if (data is Map && data['reply'] != null) {
          return data['reply'].toString();
        } 
        // If it's a String, just return it
        else if (data is String) {
          return data;
        }
      }
      
      return "I couldn't generate a response. Please try again. (Status: ${response.status})";
    } catch (e) {
      return "Connection error: ${e.toString()}";
    }
  }
}


============================================================
