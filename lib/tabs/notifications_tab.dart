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

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplissez le titre et le message')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      // Récupère les passagers du vol sélectionné (via réservations)
      List<String> userIds = [];
      if (_selectedFlightId != null) {
        final res = await _sb
            .from('reservations')
            .select('passenger_id')
            .eq('flight_id', _selectedFlightId!);
        userIds = (res as List)
            .map((r) => r['passenger_id'].toString())
            .toList();
      }

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

      // Insère une notification par passager
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
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AdminTheme.red),
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: AdminTheme.cardDeco,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Envoyer une notification', style: AdminTheme.h2),
                const SizedBox(height: 6),
                Text('La notification sera envoyée aux passagers du vol choisi.',
                    style: AdminTheme.muted),
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
                      hint: Text('Choisir un vol', style: AdminTheme.muted),
                      items: _flights
                          .map((f) => DropdownMenuItem(
                                value: f['id'].toString(),
                                child: Text(f['flight_number'] ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedFlightId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _label('Type'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _typeChip('info', 'Info'),
                    _typeChip('delay', 'Retard'),
                    _typeChip('cancellation', 'Annulation'),
                    _typeChip('compensation', 'Compensation'),
                  ],
                ),
                const SizedBox(height: 16),

                _label('Titre'),
                const SizedBox(height: 6),
                _input(_title, 'Ex: Changement de porte'),
                const SizedBox(height: 16),

                _label('Message'),
                const SizedBox(height: 6),
                _input(_body, 'Votre message...', lines: 4),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)))
                        : const Icon(Icons.send, size: 18),
                    label: Text(_sending ? 'Envoi...' : 'Envoyer',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AdminTheme.textSecondary));

  Widget _input(TextEditingController c, String hint, {int lines = 1}) {
    return TextField(
      controller: c,
      maxLines: lines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AdminTheme.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminTheme.navy, width: 1.5),
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final active = _type == value;
    return InkWell(
      onTap: () => setState(() => _type = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AdminTheme.navy : AdminTheme.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AdminTheme.navy : AdminTheme.border),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AdminTheme.textSecondary)),
      ),
    );
  }
}
