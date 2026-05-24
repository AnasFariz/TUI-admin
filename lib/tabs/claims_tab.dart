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
            content: Text('Demande $status'),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_claims.length} demandes', style: AdminTheme.h2),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualiser'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_claims.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(60),
              decoration: AdminTheme.cardDeco,
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 48, color: AdminTheme.textMuted),
                  const SizedBox(height: 12),
                  Text('Aucune demande de compensation',
                      style: AdminTheme.muted),
                ],
              ),
            )
          else
            Container(
              decoration: AdminTheme.cardDeco,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AdminTheme.bg,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        _h('MONTANT', 2),
                        _h('STATUT', 2),
                        _h('DATE', 3),
                        _h('ACTIONS', 3),
                      ],
                    ),
                  ),
                  ..._claims.map(_row),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _h(String t, int f) => Expanded(
      flex: f,
      child: Text(t,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AdminTheme.textMuted,
              letterSpacing: 0.8)));

  Widget _row(Map<String, dynamic> c) {
    final status = (c['status'] ?? 'pending').toString();
    final (color, label) = switch (status) {
      'approved' => (AdminTheme.green, 'Approuvée'),
      'rejected' => (AdminTheme.red, 'Rejetée'),
      'paid' => (AdminTheme.navy, 'Payée'),
      _ => (AdminTheme.orange, 'En attente'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AdminTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text('${c['amount_eur'] ?? '--'} €',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AdminTheme.textPrimary))),
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
              child: Text(
                  c['created_at']?.toString().substring(0, 10) ?? '',
                  style: AdminTheme.muted)),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              children: [
                _btn('Approuver', AdminTheme.green,
                    () => _setStatus(c, 'approved')),
                _btn('Rejeter', AdminTheme.red,
                    () => _setStatus(c, 'rejected')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => InkWell(
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
