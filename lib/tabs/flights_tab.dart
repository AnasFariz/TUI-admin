import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class FlightsTab extends StatefulWidget {
  const FlightsTab({super.key});
  @override
  State<FlightsTab> createState() => _FlightsTabState();
}

class _FlightsTabState extends State<FlightsTab> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _flights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _sb
          .from('flights')
          .select()
          .order('flight_date', ascending: true);
      _flights = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      _flights = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateStatus(
      Map<String, dynamic> flight, String status, int delay) async {
    try {
      await _sb.from('flights').update({
        'status': status,
        'delay_minutes': delay,
        'delay_reason': status == 'delayed'
            ? 'Retard opérationnel'
            : status == 'cancelled'
                ? 'Vol annulé par la compagnie'
                : null,
      }).eq('id', flight['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Vol ${flight['flight_number']} mis à jour → $status. Notifications envoyées aux passagers.'),
            backgroundColor: AdminTheme.green,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'), backgroundColor: AdminTheme.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_flights.length} vols', style: AdminTheme.h2),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualiser'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: AdminTheme.cardDeco,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: AdminTheme.bg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      _hCell('VOL', 2),
                      _hCell('TRAJET', 3),
                      _hCell('DATE', 2),
                      _hCell('STATUT', 2),
                      _hCell('ACTIONS', 3),
                    ],
                  ),
                ),
                ..._flights.map(_row),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hCell(String t, int flex) => Expanded(
        flex: flex,
        child: Text(t,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AdminTheme.textMuted,
                letterSpacing: 0.8)),
      );

  Widget _row(Map<String, dynamic> f) {
    final status = (f['status'] ?? 'on_time').toString();
    final (color, label) = switch (status) {
      'delayed' => (AdminTheme.orange, 'Retardé'),
      'cancelled' => (AdminTheme.red, 'Annulé'),
      _ => (AdminTheme.green, 'À l\'heure'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(f['flight_number'] ?? '',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.textPrimary))),
          Expanded(
              flex: 3,
              child: Text(
                  '${f['departure_code']} → ${f['arrival_code']}',
                  style: AdminTheme.body)),
          Expanded(
              flex: 2,
              child: Text(f['flight_date']?.toString() ?? '',
                  style: AdminTheme.muted)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              children: [
                _actionBtn('À l\'heure', AdminTheme.green,
                    () => _updateStatus(f, 'on_time', 0)),
                _actionBtn('Retard', AdminTheme.orange,
                    () => _updateStatus(f, 'delayed', 120)),
                _actionBtn('Annuler', AdminTheme.red,
                    () => _updateStatus(f, 'cancelled', 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
