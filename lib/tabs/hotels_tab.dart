import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/hotel_form_dialog.dart';

class HotelsTab extends StatefulWidget {
  const HotelsTab({super.key});
  @override
  State<HotelsTab> createState() => _HotelsTabState();
}

class _HotelsTabState extends State<HotelsTab> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _hotels = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _sb
          .from('hotels')
          .select()
          .order('country', ascending: true)
          .order('name', ascending: true);
      _hotels = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      _hotels = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openForm([Map<String, dynamic>? hotel]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => HotelFormDialog(hotel: hotel),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> hotel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdminTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer l\'hôtel ?', style: AdminTheme.h2),
        content: Text(
          'Voulez-vous vraiment supprimer « ${hotel['name']} » ? Cette action est définitive.',
          style: AdminTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler',
                style: GoogleFonts.inter(color: AdminTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _sb.from('hotels').delete().eq('id', hotel['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hôtel « ${hotel['name']} » supprimé.'),
              backgroundColor: AdminTheme.green),
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
    final q = _query.toLowerCase();
    if (q.isEmpty) return _hotels;
    return _hotels.where((h) {
      return (h['name'] ?? '').toString().toLowerCase().contains(q) ||
          (h['city'] ?? '').toString().toLowerCase().contains(q) ||
          (h['country'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final countries = _hotels
        .map((h) => (h['country'] ?? '').toString())
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;
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
                  Text('Réseau hôtelier', style: AdminTheme.h1),
                  const SizedBox(height: 2),
                  Text('Gérez les hôtels d\'urgence (ajout, modification, suppression)',
                      style: AdminTheme.muted),
                ],
              ),
              const Spacer(),
              _addBtn(),
              const SizedBox(width: 10),
              _refreshBtn(),
            ],
          ),
          const SizedBox(height: 24),

          // ── Mini stats ──
          Row(
            children: [
              _miniStat('Hôtels', _hotels.length, Icons.hotel_rounded,
                  AdminTheme.navy),
              const SizedBox(width: 16),
              _miniStat('Pays couverts', countries, Icons.public_rounded,
                  AdminTheme.green),
            ],
          ),
          const SizedBox(height: 24),

          // ── Recherche ──
          Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 280,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: AdminTheme.body,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un hôtel, ville, pays…',
                    hintStyle: AdminTheme.muted,
                    prefixIcon: Icon(Icons.search,
                        size: 20, color: AdminTheme.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: AdminTheme.card,
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
            _empty()
          else
            ...list.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HotelCard(
                    hotel: h,
                    onEdit: () => _openForm(h),
                    onDelete: () => _delete(h),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _addBtn() => InkWell(
        onTap: () => _openForm(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AdminTheme.red, Color(0xFFFF3A4D)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AdminTheme.red.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text('Ajouter un hôtel',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
      );

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

  Widget _empty() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(60),
        decoration: AdminTheme.cardDeco,
        child: Column(
          children: [
            Icon(Icons.hotel_outlined, size: 48, color: AdminTheme.textMuted),
            const SizedBox(height: 12),
            Text('Aucun hôtel', style: AdminTheme.muted),
          ],
        ),
      );
}

// ──────────────────────────────────────────
// CARTE HÔTEL (hover + actions modifier/supprimer)
// ──────────────────────────────────────────
class _HotelCard extends StatefulWidget {
  final Map<String, dynamic> hotel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _HotelCard(
      {required this.hotel, required this.onEdit, required this.onDelete});

  @override
  State<_HotelCard> createState() => _HotelCardState();
}

class _HotelCardState extends State<_HotelCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.hotel;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: AdminTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _hover
                  ? AdminTheme.navy.withValues(alpha: 0.4)
                  : AdminTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: isDarkMode.value ? 0.2 : 0.04),
              blurRadius: _hover ? 18 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AdminTheme.navy, Color(0xFF1B2A5A)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.hotel_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h['name'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AdminTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13, color: AdminTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                            '${h['city'] ?? ''} · ${h['country'] ?? ''} (${h['country_code'] ?? ''})',
                            style: AdminTheme.muted),
                      ],
                    ),
                  ],
                ),
              ),
              // Marque
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminTheme.navy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${h['brand'] ?? ''}',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AdminTheme.navy)),
                  ),
                ),
              ),
              // Note
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFFFFB347)),
                  const SizedBox(width: 3),
                  Text('${h['rating'] ?? ''}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textSecondary)),
                ],
              ),
              const SizedBox(width: 16),
              // Actions
              _iconBtn(Icons.edit_rounded, AdminTheme.navy, widget.onEdit),
              const SizedBox(width: 8),
              _iconBtn(Icons.delete_outline_rounded, AdminTheme.red,
                  widget.onDelete),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
