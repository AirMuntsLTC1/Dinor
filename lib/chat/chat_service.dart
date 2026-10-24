import 'package:supabase_flutter/supabase_flutter.dart';

import '../ffi/dinor_bindings.dart';

class ChatService {
  static SupabaseClient get supabase => Supabase.instance.client;

  static String? get myId => supabase.auth.currentUser?.id;

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final me = myId;
    if (me == null) return [];
    // Escape % and _ so user input cannot act as wildcards.
    final safe = DinorCore.load().escapeLike(query.trim());
    if (safe.isEmpty) return [];
    final response = await supabase
        .from('profiles')
        .select()
        .ilike('username', '%$safe%')
        .neq('id', me)
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<String> getOrCreateConversation(String otherUserId) async {
    final myId = supabase.auth.currentUser!.id;

    final existing = await supabase
        .from('conversations')
        .select('id')
        .or('and(user1_id.eq.$myId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$myId)')
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final newConv = await supabase
        .from('conversations')
        .insert({'user1_id': myId, 'user2_id': otherUserId})
        .select('id')
        .single();

    return newConv['id'] as String;
  }

  /// Conversations with the other user's profile and unread info.
  /// Unread lookups run in parallel (one round trip of latency, not N).
  static Future<List<Map<String, dynamic>>> getMyConversations() async {
    final myId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from('conversations')
        .select('*, user1:profiles!conversations_user1_id_fkey(*), user2:profiles!conversations_user2_id_fkey(*)')
        .or('user1_id.eq.$myId,user2_id.eq.$myId')
        .order('last_message_time', ascending: false);

    final conversations = List<Map<String, dynamic>>.from(response);

    final unreadLists = await Future.wait(conversations.map((conv) {
      return supabase
          .from('messages')
          .select('content, is_image')
          .eq('conversation_id', conv['id'])
          .neq('sender_id', myId)
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .then((rows) => List<Map<String, dynamic>>.from(rows))
          .catchError((_) => <Map<String, dynamic>>[]);
    }));

    for (var i = 0; i < conversations.length; i++) {
      final unread = unreadLists[i];
      conversations[i]['unread_count'] = unread.length;
      conversations[i]['latest_unread'] = unread.isNotEmpty ? unread.first : null;
    }

    return conversations;
  }

  static Future<void> markAsRead(String conversationId) async {
    final me = myId;
    if (me == null) return;
    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', me)
        .eq('is_read', false);
  }
}
