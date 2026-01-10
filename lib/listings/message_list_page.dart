import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_page.dart';
import 'chat_service.dart';

class MessageListPage extends StatefulWidget {
  const MessageListPage({super.key});

  @override
  State<MessageListPage> createState() => _MessageListPageState();
}

class _MessageListPageState extends State<MessageListPage> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final _service = ChatService();
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _items = [];

  final Map<String, String> _listingTitleCache = {};
  final Map<String, String> _userNameCache = {};
  final Map<String, Map<String, dynamic>?> _lastMsgCache = {};

  String get _me => Supabase.instance.client.auth.currentUser?.id ?? '';

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtTime(dynamic raw) {
    DateTime? dt;
    if (raw is DateTime) dt = raw;
    dt ??= DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _items = [];
          _loading = false;
          _error = 'Önce giriş yapmalısın.';
        });
        return;
      }

      final list = await _service.fetchMyConversations();
      if (!mounted) return;
      setState(() => _items = list);

      for (final c in list) {
        final convId = _service.convIdFromRow(c);
        final listingId = (c['listing_id'] ?? '').toString();
        final otherId = _service.otherUserIdFromConversationRow(c);

        if (listingId.isNotEmpty &&
            !_listingTitleCache.containsKey(listingId)) {
          _listingTitleCache[listingId] = await _service.fetchListingTitle(
            listingId,
          );
        }

        if (otherId.isNotEmpty && !_userNameCache.containsKey(otherId)) {
          _userNameCache[otherId] = await _service.fetchUserName(otherId);
        }

        if (convId.isNotEmpty && !_lastMsgCache.containsKey(convId)) {
          _lastMsgCache[convId] = await _service.fetchLastMessage(convId);
        }

        if (!mounted) return;
        setState(() {});
      }

      // ✅ son mesaja göre sırala (created_at)
      _items.sort((a, b) {
        final aId = _service.convIdFromRow(a);
        final bId = _service.convIdFromRow(b);

        final aLast = _lastMsgCache[aId]?['created_at'];
        final bLast = _lastMsgCache[bId]?['created_at'];

        DateTime? adt = aLast is DateTime
            ? aLast
            : DateTime.tryParse(aLast?.toString() ?? '');
        DateTime? bdt = bLast is DateTime
            ? bLast
            : DateTime.tryParse(bLast?.toString() ?? '');

        adt ??= DateTime.tryParse((a['created_at'] ?? '').toString());
        bdt ??= DateTime.tryParse((b['created_at'] ?? '').toString());

        if (adt == null && bdt == null) return 0;
        if (adt == null) return 1;
        if (bdt == null) return -1;
        return bdt.compareTo(adt);
      });

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: const Text('Mesajlar'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : (_error != null)
            ? ListView(
                children: [
                  const SizedBox(height: 160),
                  Center(child: Text('Hata: $_error')),
                ],
              )
            : (_items.isEmpty)
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('Henüz sohbet yok.')),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final c = _items[i];

                  final convId = _service.convIdFromRow(c);
                  final listingId = (c['listing_id'] ?? '').toString();
                  final otherId = _service.otherUserIdFromConversationRow(c);

                  final listingTitle = _listingTitleCache[listingId] ?? 'İlan';
                  final otherName = _userNameCache[otherId] ?? 'Kullanıcı';

                  final last = _lastMsgCache[convId];
                  final lastText = (last?['body'] ?? '...').toString();
                  final lastTime = _fmtTime(last?['created_at']);

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade100,
                        child: Icon(Icons.person, color: Colors.grey.shade700),
                      ),
                      title: Text(
                        otherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            listingTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lastText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: Text(
                        lastTime,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () async {
                        if (_me.isEmpty) {
                          _snack('Önce giriş yapmalısın.');
                          return;
                        }
                        if (otherId.isEmpty || otherId == _me) {
                          _snack('Hatalı sohbet: diğer kullanıcı bulunamadı.');
                          return;
                        }
                        if (convId.isEmpty) {
                          _snack('Conversation id bulunamadı.');
                          return;
                        }

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              chatId: convId,
                              otherUserId: otherId,
                              otherUserName: otherName,
                              listingTitle: listingTitle,
                            ),
                          ),
                        );

                        // geri dönünce son mesajı güncelle
                        try {
                          _lastMsgCache[convId] = await _service
                              .fetchLastMessage(convId);
                          if (mounted) setState(() {});
                        } catch (_) {}
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
