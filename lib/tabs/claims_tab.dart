import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _sb
          .from('compensation_claims')
          .select()
          .order('created_at', ascending: false);
      _claims = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      _claims = [];
    }
    if (mounted) setState(() => _loading = false);
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
                  child: _ClaimCard(claim: c, onStatus: _setStatus),
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
  const _ClaimCard({required this.claim, required this.onStatus});

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
            // Montant + date
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c['amount_eur'] ?? '--'} €',
                      style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AdminTheme.textPrimary)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 13, color: AdminTheme.textMuted),
                      const SizedBox(width: 5),
                      Text(
                          'Soumise le ${c['created_at']?.toString().substring(0, 10) ?? '—'}',
                          style: AdminTheme.muted),
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
            ] else
              Text('Traitée',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.textMuted)),
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
