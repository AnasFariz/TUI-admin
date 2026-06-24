import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

/// Dialog d'ajout ou d'édition d'un hôtel (CRUD).
class HotelFormDialog extends StatefulWidget {
  final Map<String, dynamic>? hotel; // null = création
  const HotelFormDialog({super.key, this.hotel});

  @override
  State<HotelFormDialog> createState() => _HotelFormDialogState();
}

class _HotelFormDialogState extends State<HotelFormDialog> {
  final _sb = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _countryCode;
  late final TextEditingController _rating;
  String _brand = 'TUI BLUE';
  bool _saving = false;

  static const _brands = [
    'TUI BLUE',
    'RIU',
    'TUI MAGIC LIFE',
    'ROBINSON',
    'TUI SUNEO',
  ];

  bool get _isEdit => widget.hotel != null;

  @override
  void initState() {
    super.initState();
    final h = widget.hotel;
    _name = TextEditingController(text: h?['name'] ?? '');
    _city = TextEditingController(text: h?['city'] ?? '');
    _country = TextEditingController(text: h?['country'] ?? '');
    _countryCode = TextEditingController(text: h?['country_code'] ?? '');
    _rating = TextEditingController(text: (h?['rating'] ?? '4.5').toString());
    final b = (h?['brand'] ?? 'TUI BLUE').toString();
    _brand = _brands.contains(b) ? b : 'TUI BLUE';
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _country, _countryCode, _rating]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = {
      'name': _name.text.trim(),
      'city': _city.text.trim(),
      'country': _country.text.trim(),
      'country_code': _countryCode.text.trim().toUpperCase(),
      'rating': double.tryParse(_rating.text.trim().replaceAll(',', '.')) ?? 4.5,
      'brand': _brand,
    };
    try {
      if (_isEdit) {
        await _sb.from('hotels').update(payload).eq('id', widget.hotel!['id']);
      } else {
        await _sb.from('hotels').insert(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'), backgroundColor: AdminTheme.red),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AdminTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AdminTheme.navy, Color(0xFF1B2A5A)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                            _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                            color: Colors.white,
                            size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                            _isEdit
                                ? 'Modifier l\'hôtel'
                                : 'Ajouter un hôtel',
                            style: AdminTheme.h2),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AdminTheme.textMuted),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _field(_name, 'Nom de l\'hôtel', 'RIU Palace Tenerife'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(_city, 'Ville', 'Tenerife')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_country, 'Pays', 'Espagne')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _field(_countryCode, 'Code pays (ISO-2)', 'ES')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_rating, 'Note /5', '4.6')),
                  ]),
                  const SizedBox(height: 16),
                  Text('Marque',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _brands.map(_brandChip).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: AdminTheme.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Annuler',
                            style: GoogleFonts.inter(
                                color: AdminTheme.textSecondary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AdminTheme.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white)))
                            : Text(
                                _isEdit ? 'Enregistrer' : 'Créer l\'hôtel',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminTheme.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          style: AdminTheme.body,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Requis' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AdminTheme.muted,
            isDense: true,
            filled: true,
            fillColor: AdminTheme.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AdminTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AdminTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminTheme.navy, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandChip(String value) {
    final active = _brand == value;
    return InkWell(
      onTap: () => setState(() => _brand = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AdminTheme.navy.withValues(alpha: 0.15)
              : AdminTheme.bg,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? AdminTheme.navy : AdminTheme.border),
        ),
        child: Text(value,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? AdminTheme.navy : AdminTheme.textSecondary)),
      ),
    );
  }
}
