import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ffi/dinor_bindings.dart';

/// Local cache for conversations and chat messages.
///
/// Strategy ("show first, refresh after"):
///  * Startup paints the cached conversation list immediately (no spinner).
///  * Opening a chat paints its cached messages immediately.
///  * Every entry carries `savedAt`; stale entries still paint, then the
///    screen refreshes from the network in the background.
///  * Data is mirrored in memory (instant) and in SharedPreferences (survives restarts).
///  * Message lists are capped so the cache never grows without bound.
class LocalCache {
  LocalCache._();

  static const String _conversationsKey = 'cache.v2.conversations';
  static const String _messagesPrefix = 'cache.v2.messages.';
  static const String _indexKey = 'cache.v2.message_index';

  /// Entries older than this are refreshed in the background.
  static const Duration ttl = Duration(minutes: 5);

  /// Max messages kept per conversation on disk and in memory.
  static const int maxMessagesPerConversation = 100;

  /// Max conversations whose messages we keep (least recently used are dropped).
  static const int maxCachedConversations = 30;

  static SharedPreferences? _prefs;
  static bool _loaded = false;

  static final Map<String, _Entry> _memory = {};

  static Future<SharedPreferences> _p() async => _prefs ??= await SharedPreferences.getInstance();

  /// Loads the conversation list into memory. Call once at startup, before runApp
  /// finishes its first frame where possible.
  static Future<void> preload() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await _p();
    final raw = prefs.getString(_conversationsKey);
    if (raw != null) {
      final entry = _Entry.decode(raw);
      if (entry != null) _memory[_conversationsKey] = entry;
    }
    // Load recent chats into memory now, so opening one paints on the first frame.
    for (final id in prefs.getStringList(_indexKey) ?? const <String>[]) {
      final rawMessages = prefs.getString(_messagesPrefix + id);
      if (rawMessages == null) continue;
      final entry = _Entry.decode(rawMessages);
      if (entry != null) _memory[_messagesPrefix + id] = entry;
    }
  }

  /// Synchronous: cached messages for a chat, or null. Call after [preload].
  static List<Map<String, dynamic>>? peekMessages(String conversationId) {
    final e = _memory[_messagesPrefix + conversationId];
    if (e == null) return null;
    return (e.data as List).map((x) => Map<String, dynamic>.from(x as Map)).toList();
  }

  // ---- conversations -------------------------------------------------------
  /// Synchronous: returns the last saved conversation list, or null.
  static List<Map<String, dynamic>>? peekConversations() {
    final e = _memory[_conversationsKey];
    if (e == null) return null;
    return (e.data as List).map((x) => Map<String, dynamic>.from(x as Map)).toList();
  }

  static bool conversationsAreFresh() => _isFresh(_memory[_conversationsKey]);

  static Future<void> saveConversations(List<Map<String, dynamic>> conversations) async {
    // Only keep the lightweight fields the list actually renders.
    final light = conversations.map((c) => _lightConversation(c)).toList();
    _memory[_conversationsKey] = _Entry(DateTime.now().millisecondsSinceEpoch, light);
    final prefs = await _p();
    await prefs.setString(_conversationsKey, _memory[_conversationsKey]!.encode());
  }

  // ---- messages ------------------------------------------------------------
  /// Loads cached rows for a conversation (memory first, then disk).
  static Future<List<Map<String, dynamic>>?> loadMessages(String conversationId) async {
    final key = _messagesPrefix + conversationId;
    var entry = _memory[key];
    if (entry == null) {
      final prefs = await _p();
      final raw = prefs.getString(key);
      if (raw != null) {
        entry = _Entry.decode(raw);
        if (entry != null) _memory[key] = entry;
      }
    }
    if (entry == null) return null;
    return (entry.data as List).map((x) => Map<String, dynamic>.from(x as Map)).toList();
  }

  static bool messagesAreFresh(String conversationId) =>
      _isFresh(_memory[_messagesPrefix + conversationId]);

  static Future<void> saveMessages(String conversationId, List<Map<String, dynamic>> rows) async {
    final key = _messagesPrefix + conversationId;
    final trimmed = rows.length > maxMessagesPerConversation
        ? rows.sublist(rows.length - maxMessagesPerConversation)
        : rows;
    final entry = _Entry(DateTime.now().millisecondsSinceEpoch, trimmed);
    _memory[key] = entry;

    final prefs = await _p();
    await prefs.setString(key, entry.encode());

    // Track recency so we can evict old conversations.
    final index = List<String>.from(prefs.getStringList(_indexKey) ?? const []);
    index.remove(conversationId);
    index.add(conversationId);
    while (index.length > maxCachedConversations) {
      final evicted = index.removeAt(0);
      _memory.remove(_messagesPrefix + evicted);
      await prefs.remove(_messagesPrefix + evicted);
    }
    await prefs.setStringList(_indexKey, index);
  }

  /// Removes one message from the cached list (keeps cache in sync after a delete).
  static Future<void> removeMessage(String conversationId, String messageId) async {
    final rows = await loadMessages(conversationId);
    if (rows == null) return;
    rows.removeWhere((r) => r['id']?.toString() == messageId);
    await saveMessages(conversationId, rows);
  }

  /// Clears everything (call on sign-out so the next user never sees old data).
  static Future<void> clearAll() async {
    _memory.clear();
    final prefs = await _p();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache.v2.')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  // ---- helpers -------------------------------------------------------------
  static bool _isFresh(_Entry? e) {
    if (e == null) return false;
    return !DinorCore.load().isStale(savedAtMs: e.savedAt, ttlMs: ttl.inMilliseconds);
  }

  static Map<String, dynamic> _lightConversation(Map<String, dynamic> c) {
    Map<String, dynamic>? slim(dynamic p) => p == null
        ? null
        : {'id': (p as Map)['id'], 'username': p['username'], 'avatar_url': p['avatar_url']};
    return {
      'id': c['id'],
      'user1_id': c['user1_id'],
      'user2_id': c['user2_id'],
      'last_message': c['last_message'],
      'last_message_time': c['last_message_time'],
      'unread_count': c['unread_count'] ?? 0,
      'latest_unread': c['latest_unread'],
      'user1': slim(c['user1']),
      'user2': slim(c['user2']),
    };
  }
}

class _Entry {
  final int savedAt;
  final dynamic data;
  _Entry(this.savedAt, this.data);

  String encode() => jsonEncode({'savedAt': savedAt, 'data': data});

  static _Entry? decode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return _Entry(m['savedAt'] as int, m['data']);
    } catch (_) {
      return null; // corrupt cache: ignore it
    }
  }
}
