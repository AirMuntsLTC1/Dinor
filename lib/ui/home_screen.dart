import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/chat_service.dart';
import 'chat_screen.dart';
import 'ai_avatar.dart';
import 'bottom_nav.dart';
import 'dinor_theme.dart';
import 'side_drawer.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _drawerPage = 0;
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _listenToConversations();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _listenToConversations() {
    // 1. Fetch initial conversations with profiles
    _fetchConversations();

    // 2. Listen to changes in messages or conversations to trigger a refresh
    supabase.channel('public:messages_refresh')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversations',
        callback: (payload) => _fetchConversations(),
      ).subscribe();
  }

  Future<void> _fetchConversations() async {
    try {
      final data = await ChatService.getMyConversations();
      if (mounted) {
        setState(() => _conversations = data);
      }
    } catch (e) {
      debugPrint("Error fetching conversations: $e");
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() { _isSearching = false; _searchResults = []; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ChatService.searchUsers(query);
      setState(() => _searchResults = results);
    } catch (e) {
      debugPrint("Search error: $e");
      setState(() => _searchResults = []);
    }
  }

  Future<void> _openChat(String otherUserId, String name) async {
    _searchFocus.unfocus(); // Hide keyboard before navigating
    final convId = await ChatService.getOrCreateConversation(otherUserId);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(title: name, conversationId: convId, otherUserId: otherUserId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF229ED9);

    return Scaffold(
      backgroundColor: DinorTheme.bgDark,
      drawer: SideDrawer(
        onHomeTap: () => setState(() => _drawerPage = 1),
        onMessagesTap: () => setState(() => _drawerPage = 0),
      ),
      body: SafeArea(
        child: _drawerPage == 0 
          ? Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: brandBlue.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: brandBlue, width: 1.5)),
                    child: const Icon(Icons.person, color: brandBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Dinor', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: brandBlue)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(color: DinorTheme.surfaceDark, borderRadius: BorderRadius.circular(16), boxShadow: DinorTheme.softShadow),
                child: TextField(
                  focusNode: _searchFocus,
                  autofocus: false, // Prevents the keyboard from popping up automatically
                  onChanged: _searchUsers,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Search users...', hintStyle: TextStyle(color: DinorTheme.textGrey), prefixIcon: Icon(Icons.search, color: DinorTheme.textGrey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen(title: 'Dinor AI', isAi: true))),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(gradient: DinorTheme.primaryGradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: brandBlue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                    child: Row(
                      children: [
                        const AnimatedAIAvatar(size: 48),
                        const SizedBox(width: 16),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dinor AI Assistant', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Ask me anything!', style: TextStyle(color: Colors.white70, fontSize: 13))])),
                        Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.7), size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _isSearching ? _searchResults.length : _conversations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  if (_isSearching) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: brandBlue, child: Text(user['username'][0].toUpperCase())),
                      title: Text(user['username'], style: const TextStyle(color: Colors.white)),
                      onTap: () => _openChat(user['id'], user['username']),
                    );
                  } else {
                    final conv = _conversations[index];
                    final myId = supabase.auth.currentUser!.id;
                    
                    // Safely extract the nested user object
                    final otherUser = conv['user1_id'] == myId ? conv['user2'] : conv['user1'];
                    final otherName = (otherUser != null && otherUser['username'] != null) ? otherUser['username'] : 'Unknown';
                    final otherId = otherUser != null ? otherUser['id'] : '';
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: DinorTheme.surfaceDark, borderRadius: BorderRadius.circular(16), boxShadow: DinorTheme.softShadow),
                      child: ListTile(
                        hoverColor: Colors.transparent, splashColor: Colors.transparent, focusColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: CircleAvatar(backgroundColor: brandBlue.withValues(alpha: 0.15), child: Text(otherName[0].toUpperCase(), style: const TextStyle(color: brandBlue, fontWeight: FontWeight.bold))),
                        title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                        subtitle: Text(conv['last_message'] ?? 'No messages yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DinorTheme.textGrey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Thumbnail for Images / Videos
                            if (conv['latest_message'] != null && 
                                conv['latest_message'].isNotEmpty &&
                                conv['latest_message'][0]['is_image'] == true)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: conv['latest_message'][0]['content'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        placeholder: (c, u) => Container(width: 40, height: 40, color: Colors.grey[800]),
                                        errorWidget: (c, u, e) => Container(width: 40, height: 40, color: Colors.grey[800], child: const Icon(Icons.broken_image, size: 16)),
                                      ),
                                      // If the URL contains "video" or is a known video format, show a pause icon
                                      if (conv['latest_message'][0]['content'].toString().contains('.mp4') || 
                                          conv['latest_message'][0]['content'].toString().contains('video'))
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.pause, color: Colors.white, size: 16),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            
                            // 2. Unread Badge
                            FutureBuilder<int>(
                              future: ChatService.getUnreadCount(conv['id']),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data! > 0) {
                                  return Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text(snapshot.data.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)));
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                        onTap: () => _openChat(otherId, otherName),
                      ),
                    );
                  }
                },
              ),
            ),
            CustomBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) {
                _searchFocus.unfocus(); // Hide keyboard when tapping bottom nav
                if (index == 3) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => setState(() => _currentIndex = 0));
                } else {
                  setState(() => _currentIndex = index);
                }
              },
            ),
          ],
          )
          : const Center(child: Text('Home Feed\nComing Soon!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18))),
      ),
    );
  }
}
