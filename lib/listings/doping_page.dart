import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DopingPage extends StatefulWidget {
  const DopingPage({super.key, required this.listingId, required this.title});

  final String listingId;
  final String title;

  @override
  State<DopingPage> createState() => _DopingPageState();
}

class _DopingPageState extends State<DopingPage> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final SupabaseClient _sb = Supabase.instance.client;

  bool _loading = true;
  bool _buying = false;
  String? _error;

  Map<String, dynamic> _listing = {};
  Map<String, dynamic> _details = {};

  // ✅ Paket süreleri (konuştuğumuz gibi)
  static const int _daysFeatured = 7; // Öne çıkar
  static const int _daysUrgent = 15; // Acil
  static const int _daysGold = 30; // Altın ilan

  // Seçili plan
  String _selectedPlan = 'featured'; // default

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  // ------------------ LOAD LISTING ------------------
  Future<void> _loadListing() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _sb
          .from('listings')
          .select('id,title,details,status,owner_id')
          .eq('id', widget.listingId)
          .maybeSingle();

      if (res == null) throw Exception('İlan bulunamadı.');

      _listing = Map<String, dynamic>.from(res as Map);

      final d = _listing['details'];
      if (d is Map<String, dynamic>) {
        _details = d;
      } else if (d is Map) {
        _details = d.map((k, v) => MapEntry('$k', v));
      } else {
        _details = {};
      }

      // mevcut plan varsa seçiliye çek
      final cur = (_details['boost_plan'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (cur == 'gold' || cur == 'featured' || cur == 'urgent') {
        _selectedPlan = cur;
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------ HELPERS ------------------
  DateTime? _parseDt(String? s) {
    if (s == null) return null;
    final x = s.trim();
    if (x.isEmpty) return null;
    try {
      return DateTime.parse(x);
    } catch (_) {
      return null;
    }
  }

  bool _isBoostActive() {
    final end = _parseDt((_details['boost_end'] ?? '').toString());
    if (end == null) return false;
    return end.isAfter(DateTime.now());
  }

  String _planTitle(String plan) {
    switch (plan) {
      case 'gold':
        return 'ALTIN İLAN';
      case 'featured':
        return 'ÖNE ÇIKAR';
      case 'urgent':
        return 'ACİL';
      default:
        return plan;
    }
  }

  int _planDays(String plan) {
    switch (plan) {
      case 'gold':
        return _daysGold;
      case 'featured':
        return _daysFeatured;
      case 'urgent':
        return _daysUrgent;
      default:
        return 0;
    }
  }

  // ✅ DÜZELTİLDİ: Renkler
  // ALTIN = sarı, ACİL = mavi, ÖNE ÇIKAR = gri
  Color _planStarColor(String plan) {
    switch (plan) {
      case 'gold':
        return const Color(0xFFFFC107); // sarı
      case 'urgent':
        return const Color(0xFF00B8D4); // mavi (ACİL)
      case 'featured':
        return const Color(0xFF9E9E9E); // gri (ÖNE ÇIKAR)
      default:
        return kTurkuaz;
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  // ✅ Asıl iş: satın alma başarılı olunca bunu çağıracağız
  Future<void> _applyBoostToDb(String plan) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    final now = DateTime.now();

    final currentEnd = _parseDt((_details['boost_end'] ?? '').toString());
    final base = (currentEnd != null && currentEnd.isAfter(now))
        ? currentEnd
        : now;

    final end = base.add(Duration(days: _planDays(plan)));

    final newDetails = Map<String, dynamic>.from(_details);

    // ✅ yeni sistem alanları
    newDetails['boost_plan'] = plan; // gold/featured/urgent
    newDetails['boost_start'] = now.toIso8601String();
    newDetails['boost_end'] = end.toIso8601String();
    newDetails['boost_platform'] = Theme.of(context).platform.name; // optional

    // ❌ Eski sistem kalıntılarını temizle
    newDetails.remove('boosted');
    newDetails.remove('boost_type');
    newDetails.remove('boost_level');
    newDetails.remove('boost_until');
    newDetails.remove('is_featured');
    newDetails.remove('is_premium');

    await _sb
        .from('listings')
        .update({'details': newDetails})
        .eq('id', widget.listingId);

    _details = newDetails;
  }

  // ------------------ UI ACTION ------------------
  Future<void> _onBuyPressed() async {
    if (_buying) return;

    setState(() => _buying = true);
    try {
      await _applyBoostToDb(_selectedPlan);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_planTitle(_selectedPlan)} aktif edildi ✅')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  // ------------------ WIDGETS ------------------
  Widget _planCard({required String plan, required String desc}) {
    final selected = _selectedPlan == plan;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kTurkuaz.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? kTurkuaz : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.04),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.star_rounded,
              size: 20, // ✅ küçük yıldız
              color: _planStarColor(plan),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _planTitle(plan),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_planDays(plan)} gün',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final end = _parseDt((_details['boost_end'] ?? '').toString());
    final active = _isBoostActive();
    final curPlan = (_details['boost_plan'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: const Text('Doping'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loadListing,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Hata: $_error'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.title.trim().isEmpty ? 'İlan' : widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),

                // ✅ Aktif info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: active ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active
                          ? Colors.green.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        active ? Icons.verified_rounded : Icons.info_outline,
                        color: active
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          active
                              ? 'Aktif: ${_planTitle(curPlan)} • Bitiş: ${_fmtDate(end)}'
                              : 'Şu an aktif doping yok.',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Text(
                  'Paket seç',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),

                _planCard(
                  plan: 'featured',
                  desc: 'İlanı listede öne taşır (7 gün).',
                ),
                const SizedBox(height: 10),
                _planCard(
                  plan: 'urgent',
                  desc: 'Acil rozet / öncelik (15 gün).',
                ),
                const SizedBox(height: 10),
                _planCard(plan: 'gold', desc: 'En üst paket (30 gün).'),

                const SizedBox(height: 18),

                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTurkuaz,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _buying ? null : _onBuyPressed,
                    icon: _buying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.shopping_bag_outlined),
                    label: Text(
                      _buying ? 'İşleniyor...' : 'Satın Al / Aktif Et',
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Seçili: ${_planTitle(_selectedPlan)} • Süre: ${_planDays(_selectedPlan)} gün',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}
