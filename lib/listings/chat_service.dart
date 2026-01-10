import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _sb = Supabase.instance.client;

  String? get myUserId => _sb.auth.currentUser?.id;

  // ---------------------------------------------
  // ✅ İlan + iki kullanıcı için conversation bul/yoksa oluştur
  // (A-B / B-A fark etmez)
  // ---------------------------------------------
  Future<String> getOrCreateConversation({
    required String listingId,
    required String otherUserId,
  }) async {
    final me = myUserId;
    if (me == null) throw Exception('Giriş yapılmamış.');
    if (listingId.trim().isEmpty) throw Exception('listingId boş.');
    if (otherUserId.trim().isEmpty) throw Exception('otherUserId boş.');
    if (otherUserId == me) throw Exception('Kendine mesaj atamazsın.');

    // ✅ Aynı ilan + aynı 2 kişi için var mı?
    final existing = await _sb
        .from('conversations')
        .select('id')
        .eq('listing_id', listingId)
        .or(
          'and(user_a.eq.$me,user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.$me)',
        )
        .maybeSingle();

    if (existing != null) {
      return existing['id'].toString();
    }

    final inserted = await _sb
        .from('conversations')
        .insert({'listing_id': listingId, 'user_a': me, 'user_b': otherUserId})
        .select('id')
        .single();

    return inserted['id'].toString();
  }

  // ---------------------------------------------
  // ✅ Benim tüm konuşmalarım
  // ---------------------------------------------
  Future<List<Map<String, dynamic>>> fetchMyConversations() async {
    final me = myUserId;
    if (me == null) throw Exception('Giriş yapılmamış.');

    final res = await _sb
        .from('conversations')
        .select('*')
        .or('user_a.eq.$me,user_b.eq.$me')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  // id okuma helper (bazı yerlerde string ister)
  String convIdFromRow(Map<String, dynamic> c) => (c['id'] ?? '').toString();

  // ---------------------------------------------
  // ✅ Konuşmadaki diğer kullanıcı id
  // ---------------------------------------------
  String otherUserIdFromConversationRow(Map<String, dynamic> c) {
    final me = myUserId;
    if (me == null) return '';
    final a = (c['user_a'] ?? '').toString();
    final b = (c['user_b'] ?? '').toString();
    return a == me ? b : a;
  }

  // ---------------------------------------------
  // ✅ Son mesajı çek (messages tablosundan)
  // ---------------------------------------------
  Future<Map<String, dynamic>?> fetchLastMessage(String conversationId) async {
    final res = await _sb
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res;
  }

  // ---------------------------------------------
  // ✅ Mesaj gönder
  // ---------------------------------------------
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final me = myUserId;
    if (me == null) throw Exception('Giriş yapılmamış.');
    final body = text.trim();
    if (body.isEmpty) return;

    await _sb.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': me,
      'body': body,
    });
  }

  // ---------------------------------------------
  // ✅ İlan başlığı
  // ---------------------------------------------
  Future<String> fetchListingTitle(String listingId) async {
    final res = await _sb
        .from('listings')
        .select('title')
        .eq('id', listingId)
        .maybeSingle();
    return (res?['title'] ?? '').toString();
  }

  // ---------------------------------------------
  // ✅ Kullanıcı adı
  // ---------------------------------------------
  Future<String> fetchUserName(String userId) async {
    final res = await _sb
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();
    return (res?['full_name'] ?? '').toString();
  }
}
