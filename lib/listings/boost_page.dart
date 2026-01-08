import 'package:flutter/material.dart';

enum BoostPlan { none, bronze, silver, gold }

extension BoostPlanX on BoostPlan {
  String get label {
    switch (this) {
      case BoostPlan.none:
        return 'Yok';
      case BoostPlan.bronze:
        return 'Bronz (7 gün )';
      case BoostPlan.silver:
        return 'Gümüş (15 gün)';
      case BoostPlan.gold:
        return 'Altın (30 gün)';
    }
  }

  String? get dbValue {
    switch (this) {
      case BoostPlan.none:
        return null;
      case BoostPlan.bronze:
        return 'bronze';
      case BoostPlan.silver:
        return 'silver';
      case BoostPlan.gold:
        return 'gold';
    }
  }

  static BoostPlan fromDb(String? v) {
    switch (v) {
      case 'bronze':
        return BoostPlan.bronze;
      case 'silver':
        return BoostPlan.silver;
      case 'gold':
        return BoostPlan.gold;
      default:
        return BoostPlan.none;
    }
  }
}

class BoostPage extends StatefulWidget {
  const BoostPage({super.key, required this.initial});

  final BoostPlan initial;

  @override
  State<BoostPage> createState() => _BoostPageState();
}

class _BoostPageState extends State<BoostPage> {
  BoostPlan _selected = BoostPlan.none;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Doping Seç',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.black12),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _card(
            child: const Text(
              'Doping, ilanını aramalarda daha görünür yapar.\n'
              'Şimdilik seçim kaydı var — ödeme/aktif etme kısmını sonra bağlarız.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),

          _radioTile(BoostPlan.none, subtitle: 'Doping yok'),
          _radioTile(BoostPlan.bronze, subtitle: '24 saat öne çıkar'),
          _radioTile(BoostPlan.silver, subtitle: '3 gün öne çıkar'),
          _radioTile(BoostPlan.gold, subtitle: '7 gün öne çıkar'),

          const SizedBox(height: 14),

          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: const Text('Seçimi Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radioTile(BoostPlan plan, {required String subtitle}) {
    return _card(
      child: RadioListTile<BoostPlan>(
        value: plan,
        groupValue: _selected,
        onChanged: (v) => setState(() => _selected = v ?? _selected),
        title: Text(
          plan.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
      ),
      child: child,
    );
  }
}
