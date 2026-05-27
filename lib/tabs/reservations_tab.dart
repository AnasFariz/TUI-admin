import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../export_service.dart';
import '../widgets/export_button.dart';

class ReservationsTab extends StatefulWidget {
  const ReservationsTab({super.key});
  @override
  State<ReservationsTab> createState() => _ReservationsTabState();
}

class _ReservationsTabState extends State<ReservationsTab> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;
  String _query = '';
  String _classFilter = 'all'; // all | economy | business | first

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _sb
          .from('reservations')
          .select(
              '*, passenger:profiles(full_name, email, phone), flight:flights(flight_number, departure_code, departure_city, arrival_code, arrival_city, flight_date, status)')
          .order('created_at', ascending: false);
      _reservations = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      _reservations = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.toLowerCase();
    return _reservations.where((r) {
      if (_classFilter != 'all' && r['class'] != _classFilter) return false;
      if (q.isEmpty) return true;
      final ref = (r['booking_reference'] ?? '').toString().toLowerCase();
      final pname =
          (r['passenger']?['full_name'] ?? '').toString().toLowerCase();
      final pmail = (r['passenger']?['email'] ?? '').toString().toLowerCase();
      final fnum =
          (r['flight']?['flight_number'] ?? '').toString().toLowerCase();
      return ref.contains(q) ||
          pname.contains(q) ||
          pmail.contains(q) ||
          fnum.contains(q);
    }).toList();
  }

  List<List<String>> _exportRows() {
    return _filtered.map<List<String>>((r) {
      final p = r['passenger'] as Map<String, dynamic>?;
      final f = r['flight'] as Map<String, dynamic>?;
      return [
        (r['booking_reference'] ?? '').toString(),
        (p?['full_name'] ?? p?['email'] ?? '—').toString(),
        (p?['email'] ?? '—').toString(),
        (f?['flight_number'] ?? '—').toString(),
        '${f?['departure_code'] ?? ''} → ${f?['arrival_code'] ?? ''}',
        (f?['flight_date'] ?? '').toString(),
        (r['seat'] ?? '—').toString(),
        (r['class'] ?? 'economy').toString(),
      ];
    }).toList();
  }

  static const _exportHeaders = [
    'Réf.',
    'Passager',
    'Email',
    'Vol',
    'Trajet',
    'Date',
    'Siège',
    'Classe',
  ];

  void _exportCsv() => ExportService.downloadCsv(
      'reservations_tui.csv', _exportHeaders, _exportRows());

  Future<void> _exportPdf() => ExportService.downloadPdf(
        title: 'Liste des réservations',
        subtitle: '${_filtered.length} réservation(s) — TUI Belgium',
        headers: _exportHeaders,
        rows: _exportRows(),
        filename: 'reservations_tui.pdf',
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final econ = _reservations.where((r) => r['class'] == 'economy').length;
    final biz = _reservations.where((r) => r['class'] == 'business').length;
    final first = _reservations.where((r) => r['class'] == 'first').length;
    final list = _filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Réservations', style: AdminTheme.h1),
                  const SizedBox(height: 2),
                  Text('Tous les billets émis sur la plateforme',
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
              _stat('Total', _reservations.length,
                  Icons.confirmation_number_rounded, AdminTheme.navy),
              const SizedBox(width: 16),
              _stat('Économie', econ, Icons.airline_seat_recline_normal_rounded,
                  AdminTheme.green),
              const SizedBox(width: 16),
              _stat('Business', biz, Icons.airline_seat_flat_rounded,
                  AdminTheme.orange),
              const SizedBox(width: 16),
              _stat('Première', first, Icons.workspace_premium_rounded,
                  AdminTheme.red),
            ],
          ),
          const SizedBox(height: 24),
          // ── Filtres + recherche ──
          Row(
            children: [
              _filterChip('all', 'Toutes', _reservations.length),
              const SizedBox(width: 8),
              _filterChip('economy', 'Économie', econ),
              const SizedBox(width: 8),
              _filterChip('business', 'Business', biz),
              const SizedBox(width: 8),
              _filterChip('first', 'Première', first),
              const Spacer(),
              SizedBox(
                width: 280,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: AdminTheme.body,
                  decoration: InputDecoration(
                    hintText: 'Passager, email, vol, référence…',
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
          const SizedBox(height: 18),
          if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(60),
              decoration: AdminTheme.cardDeco,
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 48, color: AdminTheme.textMuted),
                  const SizedBox(height: 12),
                  Text('Aucune réservation', style: AdminTheme.muted),
                ],
              ),
            )
          else
            ...list.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ResvCard(reservation: r),
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

  Widget _stat(String label, int value, IconData icon, Color color) {
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
    final active = _classFilter == value;
    return InkWell(
      onTap: () => setState(() => _classFilter = value),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AdminTheme.navy : AdminTheme.card,
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: active ? AdminTheme.navy : AdminTheme.border),
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
}

// ──────────────────────────────────────────
// CARTE RÉSERVATION
// ──────────────────────────────────────────
class _ResvCard extends StatefulWidget {
  final Map<String, dynamic> reservation;
  const _ResvCard({required this.reservation});

  @override
  State<_ResvCard> createState() => _ResvCardState();
}

class _ResvCardState extends State<_ResvCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final p = r['passenger'] as Map<String, dynamic>?;
    final f = r['flight'] as Map<String, dynamic>?;
    final name = p?['full_name']?.toString().trim().isNotEmpty == true
        ? p!['full_name']
        : (p?['email'] ?? 'Passager');
    final initials = (name as String)
        .split(RegExp(r'[\s.@]+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    final fStatus = (f?['status'] ?? 'on_time').toString();
    final (fColor, fLabel) = switch (fStatus) {
      'cancelled' => (AdminTheme.red, 'Annulé'),
      'delayed' => (AdminTheme.orange, 'Retardé'),
      _ => (AdminTheme.green, 'À l\'heure'),
    };

    final cls = (r['class'] ?? 'economy').toString();
    final (clsColor, clsLabel) = switch (cls) {
      'first' => (AdminTheme.red, 'Première'),
      'business' => (AdminTheme.orange, 'Business'),
      _ => (AdminTheme.navy, 'Économie'),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AdminTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _hover
                  ? AdminTheme.navy.withValues(alpha: 0.3)
                  : AdminTheme.border),
          boxShadow: [
            BoxShadow(
              color: _hover
                  ? AdminTheme.navy.withValues(alpha: 0.10)
                  : Colors.black
                      .withValues(alpha: isDarkMode.value ? 0.18 : 0.04),
              blurRadius: _hover ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AdminTheme.navy, Color(0xFF1B2A5A)],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(initials,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            // Passager
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(p?['email'] ?? '—', style: AdminTheme.muted),
                ],
              ),
            ),
            // Vol
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flight_rounded,
                          size: 14, color: AdminTheme.textMuted),
                      const SizedBox(width: 5),
                      Text(f?['flight_number'] ?? '—',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AdminTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                      '${f?['departure_code'] ?? ''} → ${f?['arrival_code'] ?? ''} · ${f?['flight_date'] ?? ''}',
                      style: AdminTheme.muted),
                ],
              ),
            ),
            // Réf + siège
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['booking_reference'] ?? '—',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AdminTheme.navy)),
                  const SizedBox(height: 2),
                  Text('Siège ${r['seat'] ?? '—'}',
                      style: AdminTheme.muted),
                ],
              ),
            ),
            // Badge classe
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: clsColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: clsColor.withValues(alpha: 0.25)),
              ),
              child: Text(clsLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: clsColor)),
            ),
            const SizedBox(width: 8),
            // Badge statut vol
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: fColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: fColor.withValues(alpha: 0.25)),
              ),
              child: Text(fLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: fColor)),
            ),
          ],
        ),
      ),
    );
  }
}
