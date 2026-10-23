import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../ffi/dinor_bindings.dart';

class DinorAI {
  static Future<String> getResponse(String userMessage) async {
    final msg = userMessage.toLowerCase().trim();

    if (msg == 'hi' || msg == 'hello' || msg == 'hey') {
      return "Hello! I am Dinor AI. My brain runs on C++. What do you want to know?";
    }
    if (msg.contains('your name')) {
      return "I am Dinor AI, powered by a native C++ search engine. No external APIs!";
    }

    // Check internet before trying to search
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return "I am currently offline. Please check your internet connection to search the web!";
    }

    try {
      // 1. Fetch web results
      final query = Uri.encodeComponent(userMessage);
      final url = Uri.parse('https://html.duckduckgo.com/html/?q=$query');
      
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      });

      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        
        // Get all text from the result snippets
        var snippets = document.getElementsByClassName('result__snippet');
        if (snippets.isEmpty) return "I couldn't find any web results for that.";

        // Combine all text into one giant string
        String allText = snippets.map((e) => e.text.trim()).join(' ');

        // 2. Send to C++ Core to extract the best sentence based on keywords
        final core = DinorCore.load();
        final bestAnswer = core.extractAiAnswer(userMessage, allText);

        if (bestAnswer.isNotEmpty) {
          return "Here is what I found:\n\n$bestAnswer";
        } else {
          // Fallback if C++ couldn't find a good match
          final snippet = allText.length > 150 ? allText.substring(0, 150) : allText;
          return "I found some results, but they didn't directly answer your question. Here is the raw context:\n\n$snippet...";
        }
      }
      return "My web search failed (Status: ${response.statusCode}).";
    } catch (e) {
      return "Oops, I lost my internet connection. Error: $e";
    }
  }
}
