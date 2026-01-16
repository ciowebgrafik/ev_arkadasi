import 'package:ev_arkadasi/core/widgets/app_ui.dart';
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
  static const Color kTurkuaz = AppUI.kTurkuaz;
  final SupabaseClient _sb = Supabase.instance.client;

  bool _loading = true;
  bool _buying = false;
  String? _error;

  Map<String, dynamic> _listing = {};

  static const int _daysFeatured = 7;
  static const int _daysUrgent = 15;
  static const int _daysGold = 30;

  String _selectedPlan = 'featured';

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  Future<void> _loadListing() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _sb
          .from('listings')
          .select('id,title,status,owner_id,boost_type,boost_until')
          .eq('id', widget.listingId)
          .maybeSingle();

      if (res == null) throw Exception('İlan bulunamadı.');

      _listing = Map<String, dynamic>.from(res as Map);

      final curType = (_listing['boost_type'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (curType == 'gold' || curType == 'featured' || curType == 'urgent') {
        _selectedPlan = curType;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  bool _isBoostActive() {
    final until = _parseDt(_listing['boost_until']);
    if (until == null) return false;
    return until.isAfter(DateTime.now());
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

  Color _planStarColor(String plan) {
    switch (plan) {
      case 'gold':
        return const Color(0xFFFFC107);
      case 'urgent':
        return const Color(0xFF00B8D4);
      case 'featured':
        return const Color(0xFF9E9E9E);
      default:
        return kTurkuaz;
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _applyBoostRpc(String plan) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    final days = _planDays(plan);
    if (days <= 0) throw Exception('Geçersiz paket.');

    final res = await _sb.rpc(
      'apply_listing_boost',
      params: {
        'p_listing_id': widget.listingId, // ✅ artık text
        'p_boost_type': plan,
        'p_days': days,
      },
    );

    if (res is List && res.isNotEmpty) {
      final row = Map<String, dynamic>.from(res.first as Map);
      _listing['boost_type'] = row['boost_type'];
      _listing['boost_until'] = row['boost_until'];
      return;
    }

    if (res is Map) {
      final row = Map<String, dynamic>.from(res);
      _listing['boost_type'] = row['boost_type'];
      _listing['boost_until'] = row['boost_until'];
      return;
    }

    await _loadListing();
  }

  Future<void> _onBuyPressed() async {
    if (_buying) return;

    setState(() => _buying = true);
    try {
      await _applyBoostRpc(_selectedPlan);

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

  Widget _planCard({
    required String plan,
    required String desc,
    required BuildContext context,
  }) {
    final selected = _selectedPlan == plan;

    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.r(context, 16)),
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(AppUI.gap(context, 14)),
        decoration: BoxDecoration(
          color: selected ? kTurkuaz.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(AppUI.r(context, 16)),
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
              size: AppUI.fs(context, 20),
              color: _planStarColor(plan),
            ),
            SizedBox(width: AppUI.gap(context, 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _planTitle(plan),
                    style: TextStyle(
                      fontSize: AppUI.fs(context, 15),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: AppUI.gap(context, 4)),
                  Text(
                    desc,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: AppUI.fs(context, 13),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppUI.gap(context, 10)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppUI.gap(context, 10),
                vertical: AppUI.gap(context, 6),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppUI.r(context, 999)),
              ),
              child: Text(
                '${_planDays(plan)} gün',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: AppUI.fs(context, 12),
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
    final active = _isBoostActive();
    final curPlan = (_listing['boost_type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final until = _parseDt(_listing['boost_until']);

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
              padding: AppUI.pagePadding(context),
              children: [
                Text(
                  widget.title.trim().isEmpty ? 'İlan' : widget.title,
                  style: TextStyle(
                    fontSize: AppUI.fs(context, 18),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: AppUI.gap(context, 10)),
                Container(
                  padding: EdgeInsets.all(AppUI.gap(context, 12)),
                  decoration: BoxDecoration(
                    color: active ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(AppUI.r(context, 16)),
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
                      SizedBox(width: AppUI.gap(context, 10)),
                      Expanded(
                        child: Text(
                          active
                              ? 'Aktif: ${_planTitle(curPlan)} • Bitiş: ${_fmtDate(until)}'
                              : 'Şu an aktif doping yok.',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w800,
                            fontSize: AppUI.fs(context, 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppUI.gap(context, 14)),
                Text(
                  'Paket seç',
                  style: TextStyle(
                    fontSize: AppUI.fs(context, 16),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: AppUI.gap(context, 10)),
                _planCard(
                  plan: 'featured',
                  desc: 'İlanı listede öne taşır (7 gün).',
                  context: context,
                ),
                SizedBox(height: AppUI.gap(context, 10)),
                _planCard(
                  plan: 'urgent',
                  desc: 'Acil rozet / öncelik (15 gün).',
                  context: context,
                ),
                SizedBox(height: AppUI.gap(context, 10)),
                _planCard(
                  plan: 'gold',
                  desc: 'En üst paket (30 gün).',
                  context: context,
                ),
                SizedBox(height: AppUI.gap(context, 18)),
                SizedBox(
                  height: AppUI.gap(context, 50),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTurkuaz,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppUI.r(context, 14),
                        ),
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
                      style: TextStyle(fontSize: AppUI.fs(context, 14)),
                    ),
                  ),
                ),
                SizedBox(height: AppUI.gap(context, 10)),
                Text(
                  'Seçili: ${_planTitle(_selectedPlan)} • Süre: ${_planDays(_selectedPlan)} gün',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: AppUI.fs(context, 13),
                  ),
                ),
              ],
            ),
    );
  }
}
