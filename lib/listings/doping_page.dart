import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DopingPage extends StatefulWidget {
  final String listingId;
  final String title;

  const DopingPage({super.key, required this.listingId, required this.title});

  @override
  State<DopingPage> createState() => _DopingPageState();
}

class _DopingPageState extends State<DopingPage> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final _db = Supabase.instance.client;

  bool _loading = false;

  // =========================
  // APPLY BOOST
  // =========================
  Future<void> _applyBoost({
    required String plan, // featured | urgent | gold
    required int days,
  }) async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final now = DateTime.now().toUtc();
      final end = now.add(Duration(days: days));

      // details alanına yazıyoruz
      final data = {
        'details': {'boost_plan': plan, 'boost_end': end.toIso8601String()},
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _db.from('listings').update(data).eq('id', widget.listingId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İlan öne çıkarıldı 🚀')));

      Navigator.pop(context, true); // MyListingsPage refresh için
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: const Text('İlanı Öne Çıkar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Paket seç. (Ödeme entegrasyonunu sonra bağlayacağız, şimdilik sistemsel aktif ediyoruz.)',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),

          _card(
            title: 'Öne Çıkar · 7 gün',
            desc: '7 gün boyunca üst sıralarda görünür.',
            price: '₺ 350',
            onTap: () => _applyBoost(plan: 'featured', days: 7),
          ),

          _card(
            title: 'Acil · 15 gün',
            desc: '15 gün “ACİL” etiketi ile öne çıkar.',
            price: '₺ 450',
            onTap: () => _applyBoost(plan: 'urgent', days: 15),
          ),

          _card(
            title: 'Altın İlan · 30 gün',
            desc: '30 gün ALTIN rozet + en üst öncelik.',
            price: '₺ 550',
            onTap: () => _applyBoost(plan: 'gold', days: 30),
          ),

          if (_loading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required String desc,
    required String price,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 10),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kTurkuaz,
                foregroundColor: Colors.white,
              ),
              onPressed: _loading ? null : onTap,
              child: const Text('Seç'),
            ),
          ],
        ),
      ),
    );
  }
}
