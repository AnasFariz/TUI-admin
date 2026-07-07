import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
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
      // 1) Demandes + vol (relation FK valide)
      final rows = await _sb
          .from('compensation_claims')
          .select(
              '*, flight:flights(flight_number, departure_code, departure_city, arrival_code, arrival_city, distance_km, status, delay_minutes, flight_date)')
          .order('created_at', ascending: false);
      final claims = List<Map<String, dynamic>>.from(rows);

      // 2) Noms des passagers (chargés séparément — pas de FK directe)
      final userIds =
          claims.map((c) => c['user_id']?.toString()).whereType<String>().toSet();
      if (userIds.isNotEmpty) {
        try {
          final profs = await _sb
              .from('profiles')
              .select('id, full_name, email, phone')
              .inFilter('id', userIds.toList());
          final byId = {for (final p in (profs as List)) p['id'].toString(): p};
          for (final c in claims) {
            c['passenger'] = byId[c['user_id']?.toString()];
          }
        } catch (_) {
          // profiles non lisible (RLS) → on garde les demandes sans le nom
        }
      }
      _claims = claims;
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
      await _sb.from('compensation_claims').update({
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', claim['id']);
      if (mounted) {
        final (msg, bg) = switch (status) {
          'approved' => ('Demande approuvée', AdminTheme.green),
          'rejected' => ('Demande rejetée', AdminTheme.red),
          'paid' => ('Indemnisation marquée comme payée', AdminTheme.navy),
          _ => ('Statut mis à jour', AdminTheme.navy),
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(msg),
            backgroundColor: bg,
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
    return _filtered.map<List<String>>((c) {
      final p = c['passenger'] as Map<String, dynamic>?;
      final f = c['flight'] as Map<String, dynamic>?;
      final pax = (p?['full_name']?.toString().trim().isNotEmpty == true)
          ? p!['full_name'].toString()
          : (p?['email'] ?? '—').toString();
      final r = eu261(f);
      final cause = f == null
          ? '—'
          : (f['status'] == 'cancelled'
              ? 'Vol annule'
              : 'Retard ${(f['delay_minutes'] as num?)?.toInt() ?? 0} min');
      return [
        pax,
        (f?['flight_number'] ?? '—').toString(),
        '${f?['departure_code'] ?? '?'} - ${f?['arrival_code'] ?? '?'}',
        cause,
        '${c['amount_eur'] ?? '--'} EUR',
        r.eligible ? 'Oui (${r.amount} EUR)' : 'Non',
        _statusLabel((c['status'] ?? 'pending').toString()),
        (c['iban'] ?? '—').toString(),
        c['created_at']?.toString().substring(0, 10) ?? '',
      ];
    }).toList();
  }

  static const _exportHeaders = [
    'Passager',
    'Vol',
    'Trajet',
    'Cause',
    'Montant',
    'EU261',
    'Statut',
    'IBAN',
    'Date',
  ];

  Future<void> _exportPdf() async {
    final list = _filtered;
    final pending =
        list.where((c) => (c['status'] ?? 'pending') == 'pending').length;
    final approved = list.where((c) => c['status'] == 'approved').length;
    final totalApproved = list
        .where((c) => c['status'] == 'approved')
        .fold<double>(0, (s, c) => s + ((c['amount_eur'] as num?)?.toDouble() ?? 0));
    final rejected = list.where((c) => c['status'] == 'rejected').length;
    try {
      await ExportService.downloadPdf(
        title: 'Rapport des demandes de compensation',
        subtitle: 'Reglement (CE) n 261/2004 - Droits des passagers aeriens',
        filename: 'compensations_tui.pdf',
        tableTitle: 'Detail des demandes',
        landscape: true,
        intro:
            'Le present document recapitule l\'ensemble des demandes d\'indemnisation '
            'soumises par les passagers de TUI Belgium au titre du Reglement europeen '
            '(CE) n 261/2004. Ce reglement etablit des regles communes en matiere '
            'd\'indemnisation et d\'assistance des passagers en cas de refus d\'embarquement, '
            'd\'annulation ou de retard important d\'un vol. Chaque demande ci-dessous a ete '
            'evaluee selon la distance du vol et la nature de la perturbation. Genere le '
            '${DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(DateTime.now())}.',
        headers: _exportHeaders,
        rows: _exportRows(),
        summary: [
          ['Total demandes', '${list.length}'],
          ['En attente', '$pending'],
          ['Approuvees', '$approved'],
          ['Rejetees', '$rejected'],
          ['Montant approuve', '${totalApproved.toStringAsFixed(0)} EUR'],
        ],
        sections: [
          [
            'Bareme d\'indemnisation EU261',
            'Le montant de l\'indemnisation est determine en fonction de la distance du vol : '
                '250 EUR pour les vols de 1500 km ou moins ; 400 EUR pour les vols intracommunautaires '
                'de plus de 1500 km et tous les autres vols compris entre 1500 et 3500 km ; '
                '600 EUR pour les vols de plus de 3500 km. Le passager est eligible uniquement si '
                'le vol a ete annule ou retarde de trois heures ou plus a l\'arrivee, sauf circonstances '
                'extraordinaires echappant au controle du transporteur (conditions meteorologiques '
                'extremes, risques lies a la securite, greves externes, etc.).',
          ],
          [
            'Modalites de versement',
            'Les indemnisations approuvees sont versees par virement SEPA sur le compte bancaire '
                'communique par le passager (IBAN), dans un delai maximal de sept jours ouvres a compter '
                'de la date d\'approbation. Le passager recoit une confirmation par courrier electronique. '
                'Toute contestation peut etre adressee au service relation clients de TUI Belgium.',
          ],
          [
            'Total a verser',
            'Le montant total des indemnisations approuvees et en attente de versement s\'eleve a '
                '${totalApproved.toStringAsFixed(0)} EUR pour la periode consideree, '
                'correspondant a $approved demande(s) approuvee(s) sur un total de ${list.length} demande(s) traitee(s).',
          ],
        ],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur PDF : $e'),
              backgroundColor: AdminTheme.red,
              duration: const Duration(seconds: 8)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final pending =
        _claims.where((c) => (c['status'] ?? 'pending') == 'pending').length;
    final approved =
        _claims.where((c) => c['status'] == 'approved').length;
    final rejected = _claims.where((c) => c['status'] == 'rejected').length;
    final paid = _claims.where((c) => c['status'] == 'paid').length;
    final totalApproved = _sum((c) => c['status'] == 'approved');
    final totalPaid = _sum((c) => c['status'] == 'paid');
    final totalPending = _sum((c) => (c['status'] ?? 'pending') == 'pending');
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
              ExportButton(onPdf: _exportPdf),
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
              // Approuvées mais pas encore versées = argent à payer
              _amountCard('À payer', totalApproved, approved, AdminTheme.green,
                  Icons.account_balance_rounded, true),
              const SizedBox(width: 16),
              // Déjà versées
              _amountCard('Payé', totalPaid, paid, AdminTheme.navy,
                  Icons.payments_rounded, false),
              const SizedBox(width: 16),
              _miniCount('Rejetées', rejected, AdminTheme.red,
                  Icons.block_rounded),
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
              _filterChip('paid', 'Payées', paid),
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
    final iban = (c['iban'] ?? '').toString().trim();

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
                  // IBAN du passager (où virer l'argent) + bouton copier
                  if (iban.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _IbanRow(iban: iban),
                  ],
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
            // Actions selon le statut
            if (status == 'pending') ...[
              _btn('Approuver', AdminTheme.green, Icons.check_rounded,
                  () => widget.onStatus(c, 'approved')),
              const SizedBox(width: 8),
              _btn('Rejeter', AdminTheme.red, Icons.close_rounded,
                  () => widget.onStatus(c, 'rejected')),
              const SizedBox(width: 8),
            ] else if (status == 'approved') ...[
              // Approuvée → reste à verser l'argent puis marquer payée
              _btn('Marquer payée', AdminTheme.navy, Icons.payments_rounded,
                  () => widget.onStatus(c, 'paid')),
              const SizedBox(width: 8),
            ] else if (status == 'paid') ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: AdminTheme.green),
                  const SizedBox(width: 6),
                  Text('Versée',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.green)),
                ],
              ),
              const SizedBox(width: 12),
            ] else ...[
              Text('Rejetée',
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
// LIGNE IBAN (copiable) — où virer l'indemnisation
// ──────────────────────────────────────────
class _IbanRow extends StatefulWidget {
  final String iban;
  const _IbanRow({required this.iban});

  @override
  State<_IbanRow> createState() => _IbanRowState();
}

class _IbanRowState extends State<_IbanRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.iban));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AdminTheme.bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AdminTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_rounded,
                size: 13, color: AdminTheme.textMuted),
            const SizedBox(width: 6),
            Text('IBAN',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AdminTheme.textMuted)),
            const SizedBox(width: 8),
            Text(widget.iban,
                style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary)),
            const SizedBox(width: 10),
            Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 13,
                color: _copied ? AdminTheme.green : AdminTheme.textSecondary),
            const SizedBox(width: 3),
            Text(_copied ? 'Copié' : 'Copier',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _copied
                        ? AdminTheme.green
                        : AdminTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
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
