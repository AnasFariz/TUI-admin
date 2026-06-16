import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'flight_form_dialog.dart';

/// Panneau latéral affichant les détails d'un vol + ses passagers.
class FlightDetailPanel extends StatefulWidget {
  final Map<String, dynamic> flight;
  final VoidCallback onChanged;
  const FlightDetailPanel({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  State<FlightDetailPanel> createState() => _FlightDetailPanelState();
}

class _FlightDetailPanelState extends State<FlightDetailPanel> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _passengers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _sb
          .from('reservations')
          .select('id, seat, class, booking_reference, '
              'passenger:profiles(id, full_name, email, phone)')
          .eq('flight_id', widget.flight['id']);
      _passengers = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      _passengers = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _notifyAll() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Notifier les passagers', style: AdminTheme.h2),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            maxLines: 3,
            style: AdminTheme.body,
            decoration: InputDecoration(
              hintText: 'Message…',
              filled: true,
              fillColor: AdminTheme.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AdminTheme.border),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.navy),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Envoyer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;

    final ids = _passengers
        .map((r) => r['passenger']?['id'])
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return;
    try {
      final rows = ids
          .map((uid) => {
                'user_id': uid,
                'flight_id': widget.flight['id'],
                'type': 'info',
                'title': 'Vol ${widget.flight['flight_number']}',
                'body': ctrl.text.trim(),
              })
          .toList();
      await _sb.from('notifications').insert(rows);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification envoyée à ${ids.length} passager(s)'),
            backgroundColor: AdminTheme.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AdminTheme.red),
        );
      }
    }
  }

  Future<void> _edit() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => FlightFormDialog(flight: widget.flight),
    );
    if (res == true) {
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.card,
        title: Text('Supprimer ce vol ?', style: AdminTheme.h2),
        content: Text(
            'Le vol ${widget.flight['flight_number']} et ses réservations seront supprimés. Cette action est irréversible.',
            style: AdminTheme.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sb.from('flights').delete().eq('id', widget.flight['id']);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AdminTheme.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.flight;
    final status = (f['status'] ?? 'on_time').toString();
    final (color, label) = switch (status) {
      'delayed' => (AdminTheme.orange, 'Retardé'),
      'cancelled' => (AdminTheme.red, 'Annulé'),
      _ => (AdminTheme.green, 'À l\'heure'),
    };

    return Drawer(
      width: 480,
      backgroundColor: AdminTheme.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AdminTheme.navy, Color(0xFF1B2A5A)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.flight_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f['flight_number'] ?? '',
                              style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text(f['flight_date']?.toString() ?? '',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Trajet
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f['departure_code'] ?? '—',
                                style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text(f['departure_city'] ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color:
                                        Colors.white.withValues(alpha: 0.6))),
                            Text(f['scheduled_departure']?.toString() ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Colors.white.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.flight_takeoff_rounded,
                            color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(f['arrival_code'] ?? '—',
                                style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text(f['arrival_city'] ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color:
                                        Colors.white.withValues(alpha: 0.6))),
                            Text(f['scheduled_arrival']?.toString() ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Colors.white.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    if ((f['delay_minutes'] ?? 0) > 0) ...[
                      const SizedBox(width: 8),
                      Text('+${f['delay_minutes']} min',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7))),
                    ],
                    if (f['gate'] != null) ...[
                      const SizedBox(width: 8),
                      Text('Porte ${f['gate']}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7))),
                    ],
                    if (f['distance_km'] != null) ...[
                      const SizedBox(width: 8),
                      Text('· ${f['distance_km']} km',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Actions rapides
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _action(
                      Icons.send_rounded, 'Notifier', AdminTheme.navy, _notifyAll),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _action(
                      Icons.edit_rounded, 'Éditer', AdminTheme.orange, _edit),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _action(Icons.delete_outline_rounded, 'Supprimer',
                      AdminTheme.red, _delete),
                ),
              ],
            ),
          ),
          // Passagers
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 18, color: AdminTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                    _loading
                        ? 'Chargement…'
                        : '${_passengers.length} passager(s) inscrit(s)',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _passengers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined,
                                size: 48, color: AdminTheme.textMuted),
                            const SizedBox(height: 10),
                            Text('Aucun passager inscrit',
                                style: AdminTheme.muted),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _passengers.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _paxTile(_passengers[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _paxTile(Map<String, dynamic> r) {
    final p = r['passenger'] as Map<String, dynamic>?;
    final name = p?['full_name']?.toString().trim().isNotEmpty == true
        ? p!['full_name']
        : (p?['email'] ?? 'Passager');
    final initials = (name as String)
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AdminTheme.cardDeco,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AdminTheme.navy, Color(0xFF1B2A5A)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.textPrimary)),
                Text(p?['email'] ?? '—', style: AdminTheme.muted),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(r['booking_reference'] ?? '—',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.navy)),
              Text('Siège ${r['seat'] ?? '—'} · ${r['class'] ?? 'economy'}',
                  style: AdminTheme.muted),
            ],
          ),
        ],
      ),
    );
  }
}
