import 'package:flutter/material.dart';

class ListingPreferencesSection extends StatelessWidget {
  final Map<String, dynamic> preferences;

  const ListingPreferencesSection({super.key, required this.preferences});

  // --- helpers (esnek okumak için) ---
  String _readStr(List<String> keys) {
    for (final k in keys) {
      final v = preferences[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  bool _readBool(List<String> keys) {
    for (final k in keys) {
      final v = preferences[k];
      if (v == null) continue;

      if (v is bool) return v;
      final s = v.toString().toLowerCase().trim();

      // true kabul ettiklerimiz
      if (s == 'true' ||
          s == '1' ||
          s == 'yes' ||
          s == 'var' ||
          s == 'olur' ||
          s == 'preferred' ||
          s == 'tercih' ||
          s == 'tercih_edilir' ||
          s == 'tercih edilir') {
        return true;
      }

      // false kabul ettiklerimiz
      if (s == 'false' || s == '0' || s == 'no' || s == 'yok') {
        return false;
      }
    }
    return false;
  }

  String _genderLabel(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return 'Farketmez';
    if (s == 'any') return 'Farketmez';
    if (s == 'male' || s == 'erkek') return 'Erkek';
    if (s == 'female' || s == 'kadin' || s == 'kadın') return 'Kadın';
    return raw; // ne geldiyse onu göster
  }

  Widget _chip(BuildContext context, String text, {bool selected = false}) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primary.withAlpha(24)
        : theme.colorScheme.surfaceVariant;
    final fg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: selected
            ? Border.all(color: theme.colorScheme.primary.withAlpha(80))
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _row(BuildContext context, String left, Widget right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          right,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cinsiyet (any -> Farketmez)
    final genderRaw = _readStr([
      'preferred_gender',
      'gender',
      'preferredGender',
      'gender_preference',
    ]);
    final genderLabel = _genderLabel(genderRaw);

    // Öğrenci / Çalışan (Tercih edilir yerine chip)
    final preferStudent = _readBool([
      'student',
      'prefer_student',
      'student_preferred',
      'is_student_preferred',
      'studentOk',
    ]);

    final preferWorker = _readBool([
      'worker',
      'prefer_worker',
      'worker_preferred',
      'is_worker_preferred',
      'workerOk',
      'workingOk',
    ]);

    // Açıklama / not (sende “odalar tek kişilik” gibi görünüyor)
    final note = _readStr([
      'note',
      'extra',
      'extra_note',
      'description',
      'preferences_note',
    ]);

    // Eğer map tamamen boşsa hiç göstermeyelim
    final hasAny =
        genderRaw.isNotEmpty ||
        preferStudent ||
        preferWorker ||
        note.isNotEmpty;
    if (!hasAny) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kişi Tercihleri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            _row(
              context,
              'Tercih edilen cinsiyet',
              _chip(context, genderLabel),
            ),

            const SizedBox(height: 2),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(context, 'Öğrenci', selected: preferStudent),
                _chip(context, 'Çalışan', selected: preferWorker),
              ],
            ),

            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  note,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
