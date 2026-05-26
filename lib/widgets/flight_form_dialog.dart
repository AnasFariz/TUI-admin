import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

/// Dialog d'ajout ou d'édition d'un vol.
class FlightFormDialog extends StatefulWidget {
  final Map<String, dynamic>? flight; // null = création
  const FlightFormDialog({super.key, this.flight});

  @override
  State<FlightFormDialog> createState() => _FlightFormDialogState();
}

class _FlightFormDialogState extends State<FlightFormDialog> {
  final _sb = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _number;
  late final TextEditingController _date;
  late final TextEditingController _depCode;
  late final TextEditingController _depCity;
  late final TextEditingController _arrCode;
  late final TextEditingController _arrCity;
  late final TextEditingController _depTime;
  late final TextEditingController _arrTime;
  late final TextEditingController _gate;
  late final TextEditingController _distance;
  String _status = 'on_time';
  bool _saving = false;

  bool get _isEdit => widget.flight != null;

  @override
  void initState() {
    super.initState();
    final f = widget.flight;
    _number = TextEditingController(text: f?['flight_number'] ?? '');
    _date = TextEditingController(text: f?['flight_date']?.toString() ?? '');
    _depCode = TextEditingController(text: f?['departure_code'] ?? '');
    _depCity = TextEditingController(text: f?['departure_city'] ?? '');
    _arrCode = TextEditingController(text: f?['arrival_code'] ?? '');
    _arrCity = TextEditingController(text: f?['arrival_city'] ?? '');
    _depTime = TextEditingController(
        text: f?['scheduled_departure']?.toString() ?? '');
    _arrTime = TextEditingController(
        text: f?['scheduled_arrival']?.toString() ?? '');
    _gate = TextEditingController(text: f?['gate']?.toString() ?? '');
    _distance =
        TextEditingController(text: f?['distance_km']?.toString() ?? '');
    _status = (f?['status'] ?? 'on_time').toString();
  }

  @override
  void dispose() {
    for (final c in [
      _number, _date, _depCode, _depCity, _arrCode, _arrCity,
      _depTime, _arrTime, _gate, _distance,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = {
      'flight_number': _number.text.trim().toUpperCase(),
      'flight_date': _date.text.trim(),
      'departure_code': _depCode.text.trim().toUpperCase(),
      'departure_city': _depCity.text.trim(),
      'arrival_code': _arrCode.text.trim().toUpperCase(),
      'arrival_city': _arrCity.text.trim(),
      'scheduled_departure': _depTime.text.trim(),
      'scheduled_arrival': _arrTime.text.trim(),
      'gate': _gate.text.trim().isEmpty ? null : _gate.text.trim(),
      'distance_km': int.tryParse(_distance.text.trim()),
      'status': _status,
    };
    try {
      if (_isEdit) {
        await _sb.from('flights').update(payload).eq('id', widget.flight!['id']);
      } else {
        await _sb.from('flights').insert(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AdminTheme.red),
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
        constraints: const BoxConstraints(maxWidth: 640),
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
                            _isEdit
                                ? Icons.edit_rounded
                                : Icons.add_rounded,
                            color: Colors.white,
                            size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                            _isEdit ? 'Modifier le vol' : 'Ajouter un vol',
                            style: AdminTheme.h2),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AdminTheme.textMuted),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _field(_number, 'Numéro de vol', 'TB123')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_date, 'Date', '2026-06-15')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(_depCode, 'Code départ', 'BRU')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_depCity, 'Ville départ', 'Bruxelles')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(_arrCode, 'Code arrivée', 'PMI')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_arrCity, 'Ville arrivée', 'Palma')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(_depTime, 'Heure départ', '08:30')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_arrTime, 'Heure arrivée', '10:45')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(_gate, 'Porte (optionnel)', 'B12', required: false)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_distance, 'Distance (km)', '1430', required: false)),
                  ]),
                  const SizedBox(height: 16),
                  Text('Statut',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _statusChip('on_time', 'À l\'heure', AdminTheme.green),
                    _statusChip('delayed', 'Retardé', AdminTheme.orange),
                    _statusChip('cancelled', 'Annulé', AdminTheme.red),
                  ]),
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
                            : Text(_isEdit ? 'Enregistrer' : 'Créer le vol',
                                style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
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

  Widget _field(TextEditingController c, String label, String hint,
      {bool required = true}) {
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
          validator: required
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null
              : null,
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

  Widget _statusChip(String value, String label, Color color) {
    final active = _status == value;
    return InkWell(
      onTap: () => setState(() => _status = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : AdminTheme.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : AdminTheme.border),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? color : AdminTheme.textSecondary)),
      ),
    );
  }
}
