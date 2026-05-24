import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});
  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  final _sb = Supabase.instance.client;
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _type = 'info';
  bool _sending = false;

  List<Map<String, dynamic>> _flights = [];
  String? _selectedFlightId;

  @override
  void initState() {
    super.initState();
    _loadFlights();
    _title.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
  }

  Future<void> _loadFlights() async {
    try {
      final rows = await _sb.from('flights').select('id, flight_number');
      _flights = List<Map<String, dynamic>>.from(rows);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  ({Color color, IconData icon, String label}) get _typeMeta =>
      switch (_type) {
        'delay' => (
            color: AdminTheme.orange,
            icon: Icons.schedule_rounded,
            label: 'Retard'
          ),
        'cancellation' => (
            color: AdminTheme.red,
            icon: Icons.cancel_rounded,
            label: 'Annulation'
          ),
        'compensation' => (
            color: AdminTheme.green,
            icon: Icons.payments_rounded,
            label: 'Compensation'
          ),
        _ => (
            color: AdminTheme.navy,
            icon: Icons.info_rounded,
            label: 'Info'
          ),
      };

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplissez le titre et le message')),
      );
      return;
    }
    if (_selectedFlightId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un vol concerné')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      List<String> userIds = [];
      final res = await _sb
          .from('reservations')
          .select('passenger_id')
          .eq('flight_id', _selectedFlightId!);
      userIds =
          (res as List).map((r) => r['passenger_id'].toString()).toList();

      if (userIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Aucun passager trouvé pour ce vol (aucune réservation).')),
          );
          setState(() => _sending = false);
        }
        return;
      }

      final rows = userIds
          .map((uid) => {
                'user_id': uid,
                'type': _type,
                'title': _title.text.trim(),
                'body': _body.text.trim(),
              })
          .toList();
      await _sb.from('notifications').insert(rows);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
                'Notification envoyée à ${userIds.length} passager(s) !'),
            backgroundColor: AdminTheme.green,
          ),
        );
        _title.clear();
        _body.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'), backgroundColor: AdminTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: AdminTheme.h1),
          const SizedBox(height: 2),
          Text('Diffusez un message instantané aux passagers d\'un vol',
              style: AdminTheme.muted),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Formulaire ──
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: AdminTheme.cardDeco,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Composer le message', style: AdminTheme.h2),
                      const SizedBox(height: 24),

                      _label('Vol concerné'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: AdminTheme.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminTheme.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedFlightId,
                            dropdownColor: AdminTheme.card,
                            icon: Icon(Icons.expand_more_rounded,
                                color: AdminTheme.textMuted),
                            hint: Text('Choisir un vol',
                                style: AdminTheme.muted),
                            style: AdminTheme.body,
                            items: _flights
                                .map((f) => DropdownMenuItem(
                                      value: f['id'].toString(),
                                      child: Text(f['flight_number'] ?? '',
                                          style: AdminTheme.body),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedFlightId = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _label('Type de notification'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _typeChip('info', 'Info', Icons.info_rounded,
                              AdminTheme.navy),
                          _typeChip('delay', 'Retard',
                              Icons.schedule_rounded, AdminTheme.orange),
                          _typeChip('cancellation', 'Annulation',
                              Icons.cancel_rounded, AdminTheme.red),
                          _typeChip('compensation', 'Compensation',
                              Icons.payments_rounded, AdminTheme.green),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _label('Titre'),
                      const SizedBox(height: 6),
                      _input(_title, 'Ex : Changement de porte'),
                      const SizedBox(height: 20),

                      _label('Message'),
                      const SizedBox(height: 6),
                      _input(_body, 'Votre message aux passagers…', lines: 4),
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _sending ? null : _send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white)))
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                              _sending ? 'Envoi…' : 'Envoyer aux passagers',
                              style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // ── Aperçu live (téléphone) ──
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_rounded,
                            size: 16, color: AdminTheme.textMuted),
                        const SizedBox(width: 6),
                        Text('APERÇU EN DIRECT',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: AdminTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _phonePreview(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phonePreview() {
    final meta = _typeMeta;
    final title = _title.text.trim().isEmpty
        ? 'Titre de la notification'
        : _title.text.trim();
    final body = _body.text.trim().isEmpty
        ? 'Le contenu de votre message apparaîtra ici en temps réel pendant que vous tapez.'
        : _body.text.trim();

    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2A5A), AdminTheme.navy, Color(0xFF0A1430)],
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.navy.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E1320),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          children: [
            // Encoche
            const SizedBox(height: 10),
            Container(
              width: 90,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('9:41',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7))),
            ),
            const SizedBox(height: 20),
            // La carte de notification
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: meta.color,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(meta.icon,
                              color: Colors.white, size: 17),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TUI Belgium',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white
                                          .withValues(alpha: 0.6))),
                              Text(meta.label,
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: meta.color)),
                            ],
                          ),
                        ),
                        Text('maintenant',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.4))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 5),
                    Text(body,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.75))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AdminTheme.textSecondary));

  Widget _input(TextEditingController c, String hint, {int lines = 1}) {
    return TextField(
      controller: c,
      maxLines: lines,
      style: AdminTheme.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AdminTheme.muted,
        filled: true,
        fillColor: AdminTheme.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminTheme.navy, width: 1.5),
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label, IconData icon, Color color) {
    final active = _type == value;
    return InkWell(
      onTap: () => setState(() => _type = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : AdminTheme.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : AdminTheme.border,
              width: active ? 1.4 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: active ? color : AdminTheme.textMuted),
            const SizedBox(width: 7),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? color : AdminTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
