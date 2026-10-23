import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await supabase
        .from('profiles')
        .select()
        .ilike('username', '%$query%')
        .neq('id', supabase.auth.currentUser!.id)
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

    if (existing != null) return existing['id'];

    final newConv = await supabase
        .from('conversations')
        .insert({'user1_id': myId, 'user2_id': otherUserId})
        .select('id')
        .single();

    return newConv['id'];
  }

  static Future<List<Map<String, dynamic>>> getMyConversations() async {
    final myId = supabase.auth.currentUser!.id;
    
    // 1. Get conversations with joined users
    final response = await supabase
        .from('conversations')
        .select('*, user1:profiles!conversations_user1_id_fkey(*), user2:profiles!conversations_user2_id_fkey(*)')
        .or('user1_id.eq.$myId,user2_id.eq.$myId')
        .order('last_message_time', ascending: false);
        
    final List<Map<String, dynamic>> conversations = List<Map<String, dynamic>>.from(response);

    // 2. For each conversation, fetch the unread count and the latest unread message (if any)
    for (var conv in conversations) {
      final unreadMessages = await supabase
          .from('messages')
          .select('content, is_image')
          .eq('conversation_id', conv['id'])
          .neq('sender_id', myId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      conv['unread_count'] = unreadMessages.length;
      conv['latest_unread'] = unreadMessages.isNotEmpty ? unreadMessages.first : null;
    }

    return conversations;
  }

  static Future<void> markAsRead(String conversationId) async {
    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', supabase.auth.currentUser!.id)
        .eq('is_read', false);
  }
}
