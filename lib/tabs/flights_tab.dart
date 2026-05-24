import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../export_service.dart';
import '../widgets/export_button.dart';

class FlightsTab extends StatefulWidget {
  const FlightsTab({super.key});
  @override
  State<FlightsTab> createState() => _FlightsTabState();
}

class _FlightsTabState extends State<FlightsTab> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _flights = [];
  bool _loading = true;
  String _filter = 'all'; // all | on_time | delayed | cancelled
  String _query = '';

  // Filtre par passager (email)
  final _passengerCtrl = TextEditingController();
  Set<String>? _passengerFlightIds; // null = filtre inactif
  String? _passengerLabel;
  bool _passengerLoading = false;

  @override
  void dispose() {
    _passengerCtrl.dispose();
    super.dispose();
  }

  Future<void> _filterByPassenger() async {
    final email = _passengerCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() {
        _passengerFlightIds = null;
        _passengerLabel = null;
      });
      return;
    }
    setState(() => _passengerLoading = true);
    try {
      // email → user_id (profiles)
      final prof = await _sb
          .from('profiles')
          .select('id, email, full_name')
          .ilike('email', email)
          .maybeSingle();
      if (prof == null) {
        setState(() {
          _passengerFlightIds = <String>{};
          _passengerLabel = '$email (introuvable)';
        });
        return;
      }
      // user_id → flight_ids (reservations)
      final res = await _sb
          .from('reservations')
          .select('flight_id')
          .eq('passenger_id', prof['id']);
      final ids = (res as List)
          .map((r) => r['flight_id'].toString())
          .toSet();
      setState(() {
        _passengerFlightIds = ids;
        _passengerLabel = prof['full_name']?.toString().isNotEmpty == true
            ? '${prof['full_name']} · ${ids.length} vol(s)'
            : '$email · ${ids.length} vol(s)';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AdminTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _passengerLoading = false);
    }
  }

  void _clearPassenger() {
    _passengerCtrl.clear();
    setState(() {
      _passengerFlightIds = null;
      _passengerLabel = null;
    });
  }

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
            behavior: SnackBarBehavior.floating,
            content: Text(
                'Vol ${flight['flight_number']} mis à jour. Notifications envoyées aux passagers.'),
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

  List<Map<String, dynamic>> get _filtered {
    return _flights.where((f) {
      // Filtre passager (réservations)
      if (_passengerFlightIds != null &&
          !_passengerFlightIds!.contains(f['id'].toString())) {
        return false;
      }
      final st = (f['status'] ?? 'on_time').toString();
      final matchFilter = _filter == 'all' ||
          (_filter == 'on_time' && st != 'delayed' && st != 'cancelled') ||
          st == _filter;
      final q = _query.toLowerCase();
      final matchQuery = q.isEmpty ||
          (f['flight_number'] ?? '').toString().toLowerCase().contains(q) ||
          (f['departure_code'] ?? '').toString().toLowerCase().contains(q) ||
          (f['arrival_code'] ?? '').toString().toLowerCase().contains(q);
      return matchFilter && matchQuery;
    }).toList();
  }

  String _statusLabel(String st) => switch (st) {
        'delayed' => 'Retardé',
        'cancelled' => 'Annulé',
        _ => 'À l\'heure',
      };

  List<List<String>> _exportRows() {
    return _filtered
        .map((f) => [
              (f['flight_number'] ?? '').toString(),
              '${f['departure_code'] ?? ''} → ${f['arrival_code'] ?? ''}',
              '${f['departure_city'] ?? ''} → ${f['arrival_city'] ?? ''}',
              (f['flight_date'] ?? '').toString(),
              _statusLabel((f['status'] ?? 'on_time').toString()),
              '${f['delay_minutes'] ?? 0} min',
            ])
        .toList();
  }

  static const _exportHeaders = [
    'Vol',
    'Trajet',
    'Villes',
    'Date',
    'Statut',
    'Retard'
  ];

  void _exportCsv() {
    ExportService.downloadCsv('vols_tui.csv', _exportHeaders, _exportRows());
  }

  Future<void> _exportPdf() async {
    await ExportService.downloadPdf(
      title: 'Liste des vols',
      subtitle: '${_filtered.length} vol(s) — TUI Belgium',
      headers: _exportHeaders,
      rows: _exportRows(),
      filename: 'vols_tui.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final onTime = _flights
        .where((f) => f['status'] != 'delayed' && f['status'] != 'cancelled')
        .length;
    final delayed = _flights.where((f) => f['status'] == 'delayed').length;
    final cancelled = _flights.where((f) => f['status'] == 'cancelled').length;
    final list = _filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestion des vols', style: AdminTheme.h1),
                  const SizedBox(height: 2),
                  Text('Pilotez le statut des vols en temps réel',
                      style: AdminTheme.muted),
                ],
              ),
              const Spacer(),
              ExportButton(onCsv: _exportCsv, onPdf: _exportPdf),
              const SizedBox(width: 10),
              _refreshBtn(),
            ],
          ),
          const SizedBox(height: 24),

          // ── Mini stats ──
          Row(
            children: [
              _miniStat('Total', _flights.length, Icons.flight_rounded,
                  AdminTheme.navy),
              const SizedBox(width: 16),
              _miniStat('À l\'heure', onTime, Icons.check_circle_rounded,
                  AdminTheme.green),
              const SizedBox(width: 16),
              _miniStat('Retardés', delayed, Icons.schedule_rounded,
                  AdminTheme.orange),
              const SizedBox(width: 16),
              _miniStat('Annulés', cancelled, Icons.cancel_rounded,
                  AdminTheme.red),
            ],
          ),
          const SizedBox(height: 24),

          // ── Barre filtres + recherche ──
          Row(
            children: [
              _filterChip('all', 'Tous', _flights.length),
              const SizedBox(width: 8),
              _filterChip('on_time', 'À l\'heure', onTime),
              const SizedBox(width: 8),
              _filterChip('delayed', 'Retardés', delayed),
              const SizedBox(width: 8),
              _filterChip('cancelled', 'Annulés', cancelled),
              const Spacer(),
              SizedBox(
                width: 240,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: AdminTheme.body,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un vol…',
                    hintStyle: AdminTheme.muted,
                    prefixIcon: Icon(Icons.search,
                        size: 20, color: AdminTheme.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: AdminTheme.card,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                      borderSide:
                          const BorderSide(color: AdminTheme.navy, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Filtre par passager (email) ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AdminTheme.cardDeco,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AdminTheme.navy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.person_search_rounded,
                      color: AdminTheme.navy, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filtrer par passager',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AdminTheme.textPrimary)),
                    Text('Affiche uniquement ses vols réservés',
                        style: AdminTheme.muted),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TextField(
                    controller: _passengerCtrl,
                    style: AdminTheme.body,
                    onSubmitted: (_) => _filterByPassenger(),
                    decoration: InputDecoration(
                      hintText: 'email du passager (ex: anasfariz15@gmail.com)',
                      hintStyle: AdminTheme.muted,
                      prefixIcon: Icon(Icons.alternate_email_rounded,
                          size: 18, color: AdminTheme.textMuted),
                      isDense: true,
                      filled: true,
                      fillColor: AdminTheme.bg,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
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
                        borderSide: const BorderSide(
                            color: AdminTheme.navy, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _passengerLoading ? null : _filterByPassenger,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: AdminTheme.navy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _passengerLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)))
                        : Text('Filtrer',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
                if (_passengerFlightIds != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _clearPassenger,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminTheme.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminTheme.border),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 18, color: AdminTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_passengerLabel != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.filter_alt_rounded,
                    size: 16, color: AdminTheme.navy),
                const SizedBox(width: 6),
                Text('Passager : $_passengerLabel',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.navy)),
              ],
            ),
          ],
          const SizedBox(height: 18),

          // ── Liste de cartes de vol ──
          if (list.isEmpty)
            _empty()
          else
            ...list.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _FlightCard(
                    flight: f,
                    onStatus: _updateStatus,
                  ),
                )),
        ],
      ),
    );
  }

  Widget _refreshBtn() => InkWell(
        onTap: _load,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: AdminTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminTheme.border),
          ),
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18, color: AdminTheme.textSecondary),
              const SizedBox(width: 8),
              Text('Actualiser',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.textSecondary)),
            ],
          ),
        ),
      );

  Widget _miniStat(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AdminTheme.cardDeco,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AdminTheme.textPrimary,
                        height: 1)),
                const SizedBox(height: 2),
                Text(label, style: AdminTheme.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label, int count) {
    final active = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AdminTheme.navy : AdminTheme.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: active ? AdminTheme.navy : AdminTheme.border),
        ),
        child: Row(
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AdminTheme.textSecondary)),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.2)
                    : AdminTheme.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : AdminTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(60),
        decoration: AdminTheme.cardDeco,
        child: Column(
          children: [
            Icon(Icons.flight_takeoff_rounded,
                size: 48, color: AdminTheme.textMuted),
            const SizedBox(height: 12),
            Text('Aucun vol ne correspond', style: AdminTheme.muted),
          ],
        ),
      );
}

// ──────────────────────────────────────────
// CARTE DE VOL (hover + design billet)
// ──────────────────────────────────────────
class _FlightCard extends StatefulWidget {
  final Map<String, dynamic> flight;
  final Future<void> Function(Map<String, dynamic>, String, int) onStatus;
  const _FlightCard({required this.flight, required this.onStatus});

  @override
  State<_FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends State<_FlightCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.flight;
    final status = (f['status'] ?? 'on_time').toString();
    final (color, label, icon) = switch (status) {
      'delayed' => (AdminTheme.orange, 'Retardé', Icons.schedule_rounded),
      'cancelled' => (AdminTheme.red, 'Annulé', Icons.cancel_rounded),
      _ => (AdminTheme.green, 'À l\'heure', Icons.check_circle_rounded),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: AdminTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _hover ? color.withValues(alpha: 0.4) : AdminTheme.border),
          boxShadow: [
            BoxShadow(
              color: _hover
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: isDarkMode.value ? 0.2 : 0.04),
              blurRadius: _hover ? 22 : 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Bande couleur de statut à gauche
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(18)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      // Numéro de vol + avatar
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AdminTheme.navy, Color(0xFF1B2A5A)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.flight_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      // Trajet
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f['flight_number'] ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AdminTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(f['departure_code'] ?? '—',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AdminTheme.textSecondary)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Icon(Icons.arrow_forward_rounded,
                                      size: 14, color: AdminTheme.textMuted),
                                ),
                                Text(f['arrival_code'] ?? '—',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AdminTheme.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Date
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 14, color: AdminTheme.textMuted),
                            const SizedBox(width: 6),
                            Text(f['flight_date']?.toString() ?? '',
                                style: AdminTheme.muted),
                          ],
                        ),
                      ),
                      // Badge statut
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 14, color: color),
                                const SizedBox(width: 6),
                                Text(label,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: color)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Actions
                      _actionBtn('À l\'heure', AdminTheme.green,
                          () => widget.onStatus(f, 'on_time', 0)),
                      const SizedBox(width: 6),
                      _actionBtn('Retard', AdminTheme.orange,
                          () => widget.onStatus(f, 'delayed', 120)),
                      const SizedBox(width: 6),
                      _actionBtn('Annuler', AdminTheme.red,
                          () => widget.onStatus(f, 'cancelled', 0)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}
