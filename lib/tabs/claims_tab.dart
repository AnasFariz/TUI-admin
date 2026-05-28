import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../export_service.dart';
import '../widgets/export_button.dart';

class ClaimsTab extends StatefulWidget {
  const ClaimsTab({super.key});
  @override
  State<ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends State<ClaimsTab> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _claims = [];
  bool _loading = true;
  String _filter = 'all';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _sb.channel('claims-tab-live')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'compensation_claims',
        callback: (_) {
          if (mounted) _load();
        },
      )
      ..subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _sb
          .from('compensation_claims')
          .select(
              '*, flight:flights(flight_number, departure_code, arrival_code, distance_km, status, delay_minutes)')
          .order('created_at', ascending: false);
      _claims = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      _claims = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Calcul EU261 : 250€ <1500km, 400€ 1500-3500km, 600€ >3500km.
  /// Éligible si annulation OU retard ≥ 3h (180 min).
  static ({int amount, String reason, bool eligible}) eu261(
      Map<String, dynamic>? flight) {
    if (flight == null) {
      return (amount: 0, reason: 'Vol introuvable', eligible: false);
    }
    final status = (flight['status'] ?? '').toString();
    final delay = (flight['delay_minutes'] as num?)?.toInt() ?? 0;
    final dist = (flight['distance_km'] as num?)?.toInt() ?? 0;
    final eligible = status == 'cancelled' || delay >= 180;
    if (!eligible) {
      return (
        amount: 0,
        reason: 'Non éligible (retard < 3h et non annulé)',
        eligible: false
      );
    }
    final amount = dist <= 1500
        ? 250
        : dist <= 3500
            ? 400
            : 600;
    final cause = status == 'cancelled' ? 'Annulé' : 'Retard ${delay}min';
    final band = dist <= 1500
        ? '≤1500km'
        : dist <= 3500
            ? '1500-3500km'
            : '>3500km';
    return (
      amount: amount,
      reason: '$cause · $band',
      eligible: true,
    );
  }

  Future<void> _delete(Map<String, dynamic> claim) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer cette demande ?', style: AdminTheme.h2),
        content: Text(
          'La demande de ${claim['amount_eur'] ?? '--'} € sera définitivement supprimée.',
          style: AdminTheme.body,
        ),
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
      await _sb
          .from('compensation_claims')
          .delete()
          .eq('id', claim['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text('Demande supprimée'),
            backgroundColor: AdminTheme.red,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AdminTheme.red),
        );
      }
    }
  }

  Future<void> _setStatus(Map<String, dynamic> claim, String status) async {
    try {
      await _sb
          .from('compensation_claims')
          .update({'status': status}).eq('id', claim['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(status == 'approved'
                ? 'Demande approuvée'
                : 'Demande rejetée'),
            backgroundColor:
                status == 'approved' ? AdminTheme.green : AdminTheme.red,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  double _sum(bool Function(Map<String, dynamic>) test) {
    return _claims.where(test).fold<double>(
        0, (s, c) => s + ((c['amount_eur'] as num?)?.toDouble() ?? 0));
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _claims;
    return _claims.where((c) => (c['status'] ?? 'pending') == _filter).toList();
  }

  String _statusLabel(String st) => switch (st) {
        'approved' => 'Approuvée',
        'rejected' => 'Rejetée',
        'paid' => 'Payée',
        _ => 'En attente',
      };

  List<List<String>> _exportRows() {
    return _filtered
        .map((c) => [
              '${c['amount_eur'] ?? '--'} €',
              _statusLabel((c['status'] ?? 'pending').toString()),
              (c['iban'] ?? '—').toString(),
              c['created_at']?.toString().substring(0, 10) ?? '',
            ])
        .toList();
  }

  static const _exportHeaders = ['Montant', 'Statut', 'IBAN', 'Date'];

  void _exportCsv() {
    ExportService.downloadCsv(
        'compensations_tui.csv', _exportHeaders, _exportRows());
  }

  Future<void> _exportPdf() async {
    final list = _filtered;
    final pending =
        list.where((c) => (c['status'] ?? 'pending') == 'pending').length;
    final approved = list.where((c) => c['status'] == 'approved').length;
    final totalApproved = list
        .where((c) => c['status'] == 'approved')
        .fold<double>(0, (s, c) => s + ((c['amount_eur'] as num?)?.toDouble() ?? 0));
    final totalAll = list.fold<double>(
        0, (s, c) => s + ((c['amount_eur'] as num?)?.toDouble() ?? 0));
    await ExportService.downloadPdf(
      title: 'Demandes de compensation',
      subtitle: 'Règlement européen EU261 — indemnisations passagers',
      headers: _exportHeaders,
      rows: _exportRows(),
      filename: 'compensations_tui.pdf',
      summary: [
        ['Total demandes', '${list.length}'],
        ['En attente', '$pending'],
        ['Approuvées', '$approved'],
        ['Montant approuvé', '${totalApproved.toStringAsFixed(0)} €'],
        ['Montant total', '${totalAll.toStringAsFixed(0)} €'],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final pending =
        _claims.where((c) => (c['status'] ?? 'pending') == 'pending').length;
    final approved =
        _claims.where((c) => c['status'] == 'approved').length;
    final rejected = _claims.where((c) => c['status'] == 'rejected').length;
    final totalApproved = _sum((c) => c['status'] == 'approved');
    final totalPending =
        _sum((c) => (c['status'] ?? 'pending') == 'pending');
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
                  Text('Demandes de compensation', style: AdminTheme.h1),
                  const SizedBox(height: 2),
                  Text('Indemnisations passagers — Règlement EU261',
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

          // ── Cartes résumé montants ──
          Row(
            children: [
              _amountCard('À traiter', totalPending, pending, AdminTheme.orange,
                  Icons.hourglass_top_rounded, true),
              const SizedBox(width: 16),
              _amountCard('Approuvé', totalApproved, approved, AdminTheme.green,
                  Icons.verified_rounded, false),
              const SizedBox(width: 16),
              _miniCount('Rejetées', rejected, AdminTheme.red,
                  Icons.block_rounded),
              const SizedBox(width: 16),
              _miniCount('Total demandes', _claims.length, AdminTheme.navy,
                  Icons.receipt_long_rounded),
            ],
          ),
          const SizedBox(height: 24),

          // ── Filtres ──
          Row(
            children: [
              _filterChip('all', 'Toutes', _claims.length),
              const SizedBox(width: 8),
              _filterChip('pending', 'En attente', pending),
              const SizedBox(width: 8),
              _filterChip('approved', 'Approuvées', approved),
              const SizedBox(width: 8),
              _filterChip('rejected', 'Rejetées', rejected),
            ],
          ),
          const SizedBox(height: 18),

          if (list.isEmpty)
            _empty()
          else
            ...list.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ClaimCard(
                      claim: c, onStatus: _setStatus, onDelete: _delete),
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

  Widget _amountCard(String label, double amount, int count, Color color,
      IconData icon, bool highlight) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: highlight ? 0.16 : 0.10),
              color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text('$count',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
            const SizedBox(height: 14),
            Text('${amount.toStringAsFixed(0)} €',
                style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.textPrimary,
                    height: 1)),
            const SizedBox(height: 4),
            Text(label, style: AdminTheme.muted),
          ],
        ),
      ),
    );
  }

  Widget _miniCount(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AdminTheme.cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 14),
            Text('$value',
                style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.textPrimary,
                    height: 1)),
            const SizedBox(height: 4),
            Text(label, style: AdminTheme.muted),
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

  Widget _empty() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(60),
        decoration: AdminTheme.cardDeco,
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AdminTheme.textMuted),
            const SizedBox(height: 12),
            Text('Aucune demande de compensation', style: AdminTheme.muted),
          ],
        ),
      );
}

// ──────────────────────────────────────────
// CARTE DEMANDE (hover + actions)
// ──────────────────────────────────────────
class _ClaimCard extends StatefulWidget {
  final Map<String, dynamic> claim;
  final Future<void> Function(Map<String, dynamic>, String) onStatus;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  const _ClaimCard(
      {required this.claim, required this.onStatus, required this.onDelete});

  @override
  State<_ClaimCard> createState() => _ClaimCardState();
}

class _ClaimCardState extends State<_ClaimCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.claim;
    final status = (c['status'] ?? 'pending').toString();
    final (color, label, icon) = switch (status) {
      'approved' => (AdminTheme.green, 'Approuvée', Icons.verified_rounded),
      'rejected' => (AdminTheme.red, 'Rejetée', Icons.block_rounded),
      'paid' => (AdminTheme.navy, 'Payée', Icons.payments_rounded),
      _ => (AdminTheme.orange, 'En attente', Icons.hourglass_top_rounded),
    };
    final pending = status == 'pending';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AdminTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _hover ? color.withValues(alpha: 0.4) : AdminTheme.border),
          boxShadow: [
            BoxShadow(
              color: _hover
                  ? color.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: isDarkMode.value ? 0.2 : 0.04),
              blurRadius: _hover ? 22 : 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône montant
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: 0.9), color],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.euro_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 18),
            // Montant + date + EU261
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${c['amount_eur'] ?? '--'} €',
                          style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AdminTheme.textPrimary)),
                      if (c['flight'] != null) ...[
                        const SizedBox(width: 10),
                        _Eu261Chip(flight: c['flight'] as Map<String, dynamic>),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 13, color: AdminTheme.textMuted),
                      const SizedBox(width: 5),
                      Text(
                          'Soumise le ${c['created_at']?.toString().substring(0, 10) ?? '—'}',
                          style: AdminTheme.muted),
                      if (c['flight']?['flight_number'] != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.flight_rounded,
                            size: 13, color: AdminTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(c['flight']['flight_number'],
                            style: AdminTheme.muted),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Statut
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
                    border: Border.all(color: color.withValues(alpha: 0.25)),
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
            if (pending) ...[
              _btn('Approuver', AdminTheme.green, Icons.check_rounded,
                  () => widget.onStatus(c, 'approved')),
              const SizedBox(width: 8),
              _btn('Rejeter', AdminTheme.red, Icons.close_rounded,
                  () => widget.onStatus(c, 'rejected')),
              const SizedBox(width: 8),
            ] else ...[
              Text('Traitée',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.textMuted)),
              const SizedBox(width: 12),
            ],
            // Bouton supprimer (toujours visible)
            Tooltip(
              message: 'Supprimer la demande',
              child: InkWell(
                onTap: () => widget.onDelete(c),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AdminTheme.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AdminTheme.red.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18, color: AdminTheme.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, Color color, IconData icon, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
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

// ──────────────────────────────────────────
// CHIP MONTANT SUGGÉRÉ EU261
// ──────────────────────────────────────────
class _Eu261Chip extends StatelessWidget {
  final Map<String, dynamic> flight;
  const _Eu261Chip({required this.flight});

  @override
  Widget build(BuildContext context) {
    final r = _ClaimsTabState.eu261(flight);
    if (!r.eligible) {
      return Tooltip(
        message: r.reason,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AdminTheme.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gavel_rounded, size: 11, color: AdminTheme.textMuted),
              const SizedBox(width: 4),
              Text('EU261 N/A',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.textMuted)),
            ],
          ),
        ),
      );
    }
    return Tooltip(
      message: 'EU261 — ${r.reason}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AdminTheme.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminTheme.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel_rounded, size: 11, color: AdminTheme.green),
            const SizedBox(width: 4),
            Text('EU261 · ${r.amount}€',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.green)),
          ],
        ),
      ),
    );
  }
}
