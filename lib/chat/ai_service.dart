import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class DinorAI {
  static Future<String> getResponse(String userMessage) async {
    final msg = userMessage.toLowerCase().trim();

    if (msg == 'hi' || msg == 'hello' || msg == 'hey') {
      return "Hello! I am Dinor AI. I am powered by Llama 3. What do you want to know?";
    }
    if (msg.contains('your name')) {
      return "I am Dinor AI, running on a completely free AI engine. How can I help you today?";
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return "I am currently offline. Please check your internet connection.";
    }

    try {
      // 1. Fetch web results for context
      String context = "";
      try {
        final query = Uri.encodeComponent(userMessage);
        final url = Uri.parse('https://html.duckduckgo.com/html/?q=$query');
        final searchRes = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
        
        if (searchRes.statusCode == 200) {
          var document = parser.parse(searchRes.body);
          var snippets = document.getElementsByClassName('result__snippet');
          if (snippets.isNotEmpty) {
            context = snippets.take(3).map((e) => e.text.trim()).join('\n');
          }
        }
      } catch (e) {
        debugPrint("Search failed, continuing with AI only: $e");
      }

      // 2. Call the secure Supabase Edge Function
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'chat-ai',
        body: {
          'userMessage': userMessage,
          'context': context,
        },
      );

      if (response.status == 200 && response.data['reply'] != null) {
        return response.data['reply'];
      } else {
        return "I'm having trouble thinking right now. (Error ${response.status})";
      }
    } catch (e) {
      return "Oops, I lost my connection. Error: $e";
    }
  }
}
