import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'emoji_widget.dart';
import 'dinor_theme.dart';

class CustomEmojiPicker extends StatefulWidget {
  final Function(String) onEmojiSelected;
  final Function(String) onGifSelected;

  const CustomEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onGifSelected,
  });

  @override
  State<CustomEmojiPicker> createState() => _CustomEmojiPickerState();
}

class _CustomEmojiPickerState extends State<CustomEmojiPicker> {
  int _currentTab = 0; // 0 = Emoji, 1 = GIF

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // --- EMOJI DATA ---
  final Map<String, List<String>> _emojiCategories = {
    'Smileys & People': [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
      '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
      '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩'
    ],
    'Animals & Nature': [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐻‍❄️', '🐨',
      '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤'
    ],
    'Food & Drink': [
      '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
      '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑'
    ]
  };

  // --- GIF DATA ---
  final String _apiKey = "RTUwFs8WOiFqRq0K9UBkWS0OlUy3tVza";
  List<dynamic> _gifs = [];
  bool _isGifLoading = false;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _fetchGifs();
  }

  Future<void> _fetchGifs({String? query}) async {
    // Check internet first
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    if (isOffline) {
      setState(() {
        _hasInternet = false;
        _isGifLoading = false;
        _gifs = [];
      });
      return;
    } else {
      setState(() {
        _hasInternet = true;
        _isGifLoading = true;
      });
    }

    final endpoint = query == null || query.isEmpty
        ? 'https://api.giphy.com/v1/gifs/trending?api_key=$_apiKey&limit=20&rating=g'
        : 'https://api.giphy.com/v1/gifs/search?api_key=$_apiKey&q=$query&limit=20&rating=g';

    try {
      // Giphy requires a User-Agent header to prevent bot blocking
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> fetchedGifs = data['data'] ?? [];
        
        setState(() {
          _gifs = fetchedGifs;
          _hasInternet = true;
        });
        
        // If Giphy returns 0 results, it means the API key is invalid or rate-limited
        if (fetchedGifs.isEmpty) {
          debugPrint("Giphy API returned 0 results. Check your API key.");
        }
      } else {
        debugPrint("Giphy API Error: Status ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Giphy network error: $e");
    } finally {
      setState(() => _isGifLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    if (_searchQuery == val) return;
    setState(() => _searchQuery = val);
    if (_currentTab == 1) {
      _fetchGifs(query: _searchQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: DinorTheme.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DinorTheme.textGrey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // TOP TOGGLE BUTTONS (Emoji / GIF)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTabButton('Emoji', 0, Icons.emoji_emotions),
                  const SizedBox(width: 24),
                  _buildTabButton('GIF', 1, Icons.gif_box),
                ],
              ),
              const SizedBox(height: 8),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _currentTab == 0 ? 'Search emojis...' : 'Search GIFs...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: DinorTheme.bgDark,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // BODY (Switches between Emoji and GIF)
              Expanded(
                child: _currentTab == 0
                    ? _buildEmojiGrid(scrollController)
                    : _buildGifGrid(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = index;
          _searchController.clear();
          _searchQuery = '';
          if (index == 1) _fetchGifs();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF229ED9) : DinorTheme.bgDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : DinorTheme.textGrey, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : DinorTheme.textGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiGrid(ScrollController controller) {
    final allEmojis = _emojiCategories.values.expand((i) => i).toList();
    final filtered = allEmojis.where((e) => e.contains(_searchQuery)).toList();

    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return AnimatedEmoji(
          emoji: filtered[index],
          size: 30,
          onTap: () => widget.onEmojiSelected(filtered[index]),
        );
      },
    );
  }

  Widget _buildGifGrid(ScrollController controller) {
    if (!_hasInternet) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text("No Internet Connection", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Please connect to the internet to view GIFs.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }
    if (_isGifLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF229ED9)));
    if (_gifs.isEmpty) return const Center(child: Text("No GIFs found", style: TextStyle(color: Colors.grey)));

    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _gifs.length,
      itemBuilder: (context, index) {
        final gifUrl = _gifs[index]['images']['fixed_height']['url'];
        final originalUrl = _gifs[index]['images']['original']['url'];

        return GestureDetector(
          onTap: () => widget.onGifSelected(originalUrl),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black26,
            ),
            clipBehavior: Clip.hardEdge,
            child: Image.network(
              gifUrl,
              fit: BoxFit.cover,
              cacheWidth: 200, // Force decode at low res for smooth scrolling
              frameBuilder: (context, child, frame, wasSyncLoaded) {
                if (wasSyncLoaded) return child;
                if (frame == null) {
                   return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                }
                return AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 300),
                  child: child,
                );
              },
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}
