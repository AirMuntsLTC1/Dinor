import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/chat_service.dart';
import '../chat/call_service.dart';
import '../chat/message_cache.dart';
import 'call_screen.dart';
import 'skeleton_loader.dart';
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
  bool _isLoading = true; // true only when there is no cached list to show
  final FocusNode _searchFocus = FocusNode();

  RealtimeChannel? _convChannel;
  Timer? _refreshDebounce;
  Timer? _searchDebounce;
  int _fetchSeq = 0;   // drops out-of-order conversation responses
  int _searchSeq = 0;  // drops out-of-order search responses
  bool _incomingDialogOpen = false;

  @override
  void initState() {
    super.initState();

    // 1. Paint instantly from the local cache (no spinner on startup).
    final cached = LocalCache.peekConversations();
    if (cached != null) {
      _conversations = cached;
      _isLoading = false;
    }

    // 2. Refresh from the network in the background.
    _fetchConversations();

    // 3. Realtime updates, debounced so bursts trigger one refresh.
    _subscribeRealtime();

    // 4. Calls addressed to this user.
    CallService.startIncomingListener();
    CallService.incoming.addListener(_onIncomingCall);
  }

  void _subscribeRealtime() {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return;
    _convChannel?.unsubscribe();
    _convChannel = supabase.channel('conversations:$me').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversations',
      callback: (_) => _scheduleRefresh(),
    ).subscribe();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), _fetchConversations);
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _searchDebounce?.cancel();
    _convChannel?.unsubscribe();
    CallService.incoming.removeListener(_onIncomingCall);
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    final seq = ++_fetchSeq;
    try {
      final data = await ChatService.getMyConversations();
      if (seq != _fetchSeq) return; // a newer fetch is already in flight
      LocalCache.saveConversations(data); // fire-and-forget persistence
      if (mounted) {
        setState(() {
          _conversations = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      // Keep showing cached data on failure; only stop the skeleton.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () => _searchUsers(query));
  }

  Future<void> _searchUsers(String query) async {
    final seq = ++_searchSeq;
    if (query.trim().isEmpty) {
      if (mounted) setState(() { _isSearching = false; _searchResults = []; });
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    try {
      final results = await ChatService.searchUsers(query);
      if (seq == _searchSeq && mounted) setState(() => _searchResults = results);
    } catch (e) {
      debugPrint('Search error: $e');
      if (seq == _searchSeq && mounted) setState(() => _searchResults = []);
    }
  }

  String _initial(String? name) =>
      (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';

  Future<void> _openChat(String otherUserId, String name) async {
    _searchFocus.unfocus();

    String convId;
    try {
      convId = await ChatService.getOrCreateConversation(otherUserId);
    } catch (e) {
      debugPrint('Could not open chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open chat. Try again.")));
      }
      return;
    }

    if (!mounted) return;
    // Clear the unread badge instantly; the list refreshes when the chat closes.
    setState(() {
      for (var conv in _conversations) {
        if (conv['id'] == convId) {
          conv['unread_count'] = 0;
          conv['latest_unread'] = null;
        }
      }
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(title: name, conversationId: convId, otherUserId: otherUserId),
      ),
    ).then((_) => _scheduleRefresh());
  }

  void _onIncomingCall() {
    final call = CallService.incoming.value;
    if (call == null || _incomingDialogOpen || !mounted) return;
    _incomingDialogOpen = true;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: DinorTheme.surfaceDark,
        title: const Text('Incoming call', style: TextStyle(color: Colors.white)),
        content: Text('${call.callerName} is calling you', style: const TextStyle(color: DinorTheme.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Decline', style: TextStyle(color: Colors.redAccent))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Answer', style: TextStyle(color: DinorTheme.brandBlue))),
        ],
      ),
    ).then((accepted) {
      _incomingDialogOpen = false;
      if (accepted == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              receiverName: call.callerName,
              receiverId: call.callerId,
              conversationId: call.conversationId,
              incomingCallId: call.callId,
            ),
          ),
        );
      } else {
        CallService.declineCall(call.callId);
      }
    });
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
            // Header
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
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(color: DinorTheme.surfaceDark, borderRadius: BorderRadius.circular(16), boxShadow: DinorTheme.softShadow),
                child: TextField(
                  focusNode: _searchFocus,
                  autofocus: false,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Search users...', hintStyle: TextStyle(color: DinorTheme.textGrey), prefixIcon: Icon(Icons.search, color: DinorTheme.textGrey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // AI Card
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

            // Loading / Chat List
            Expanded(
              child: _isLoading 
                ? const ConversationListSkeleton()
                : ListView.separated(
                itemCount: _isSearching ? _searchResults.length : _conversations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  if (_isSearching) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: brandBlue, child: Text(_initial(user['username'] as String?))),
                      title: Text((user['username'] ?? '') as String, style: const TextStyle(color: Colors.white)),
                      onTap: () => _openChat(user['id'], user['username']),
                    );
                  } else {
                    final conv = _conversations[index];
                    final myId = supabase.auth.currentUser!.id;
                    
                    final otherUser = conv['user1_id'] == myId ? conv['user2'] : conv['user1'];
                    final otherName = (otherUser != null && otherUser['username'] != null) ? otherUser['username'] : 'Unknown';
                    final otherId = otherUser != null ? otherUser['id'] : '';
                    
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: DinorTheme.surfaceDark, borderRadius: BorderRadius.circular(16), boxShadow: DinorTheme.softShadow),
                      child: ListTile(
                        hoverColor: Colors.transparent, splashColor: Colors.transparent, focusColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: CircleAvatar(backgroundColor: brandBlue.withValues(alpha: 0.15), child: Text(_initial(otherName), style: const TextStyle(color: brandBlue, fontWeight: FontWeight.bold))),
                        title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                        subtitle: Text(
                          conv['last_message'] ?? 'No messages yet', 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis, 
                          style: const TextStyle(color: DinorTheme.textGrey)
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Thumbnail (ONLY show if there is an unread image/video)
                            if (conv['latest_unread'] != null && conv['latest_unread']['is_image'] == true)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: conv['latest_unread']['content'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        placeholder: (c, u) => Container(width: 40, height: 40, color: Colors.grey[800]),
                                        errorWidget: (c, u, e) => Container(width: 40, height: 40, color: Colors.grey[800], child: const Icon(Icons.broken_image, size: 16)),
                                      ),
                                      if (conv['latest_unread']['content'].toString().contains('.mp4') || conv['latest_unread']['content'].toString().contains('video'))
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                                          child: const Icon(Icons.pause, color: Colors.white, size: 16),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            
                            // 2. Unread Badge (Using pre-fetched count)
                            if ((conv['unread_count'] ?? 0) > 0)
                              Container(
                                padding: const EdgeInsets.all(6), 
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), 
                                child: Text(conv['unread_count'].toString(), style: const TextStyle(color: Colors.white, fontSize: 12))
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
            
            // Bottom Nav
            CustomBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) {
                _searchFocus.unfocus();
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


============================================================
