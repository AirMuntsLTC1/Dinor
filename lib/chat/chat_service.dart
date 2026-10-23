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
        .select()
        .or('and(user1_id.eq.$myId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$myId)')
        .maybeSingle();

    if (existing != null) return existing['id'];

    final newConv = await supabase
        .from('conversations')
        .insert({'user1_id': myId, 'user2_id': otherUserId})
        .select()
        .single();

    return newConv['id'];
  }

  static Future<int> getUnreadCount(String conversationId) async {
    final response = await supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .neq('sender_id', supabase.auth.currentUser!.id)
        .eq('is_read', false);
    return response.length;
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
