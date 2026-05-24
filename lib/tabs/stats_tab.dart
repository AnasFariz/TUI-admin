import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  int _totalFlights = 0;
  int _onTime = 0;
  int _delayed = 0;
  int _cancelled = 0;
  int _reservations = 0;
  int _claims = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final flights =
          List<Map<String, dynamic>>.from(await _sb.from('flights').select());
      _totalFlights = flights.length;
      _onTime = flights.where((f) => f['status'] == 'on_time').length;
      _delayed = flights.where((f) => f['status'] == 'delayed').length;
      _cancelled = flights.where((f) => f['status'] == 'cancelled').length;

      try {
        final r = await _sb.from('reservations').select();
        _reservations = (r as List).length;
      } catch (_) {}
      try {
        final c = await _sb.from('compensation_claims').select();
        _claims = (c as List).length;
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final disrupted = _delayed + _cancelled;
    final disruptRate =
        _totalFlights > 0 ? (disrupted / _totalFlights * 100).round() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards
          Row(
            children: [
              _kpi('Vols totaux', '$_totalFlights', Icons.flight,
                  AdminTheme.navy),
              const SizedBox(width: 16),
              _kpi('À l\'heure', '$_onTime', Icons.check_circle,
                  AdminTheme.green),
              const SizedBox(width: 16),
              _kpi('Perturbés', '$disrupted', Icons.warning_amber,
                  AdminTheme.orange),
              const SizedBox(width: 16),
              _kpi('Taux perturbation', '$disruptRate%', Icons.trending_up,
                  AdminTheme.red),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _kpi('Réservations', '$_reservations', Icons.confirmation_number,
                  AdminTheme.navyLight),
              const SizedBox(width: 16),
              _kpi('Demandes compensation', '$_claims',
                  Icons.payments, AdminTheme.orange),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 28),

          // Graphique répartition des statuts
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AdminTheme.cardDeco,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Répartition des vols par statut',
                    style: AdminTheme.h2),
                const SizedBox(height: 24),
                SizedBox(
                  height: 240,
                  child: _totalFlights == 0
                      ? Center(
                          child: Text('Aucune donnée', style: AdminTheme.muted))
                      : Row(
                          children: [
                            Expanded(
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 50,
                                  sections: [
                                    if (_onTime > 0)
                                      PieChartSectionData(
                                        value: _onTime.toDouble(),
                                        color: AdminTheme.green,
                                        title: '$_onTime',
                                        radius: 60,
                                        titleStyle: _pieStyle,
                                      ),
                                    if (_delayed > 0)
                                      PieChartSectionData(
                                        value: _delayed.toDouble(),
                                        color: AdminTheme.orange,
                                        title: '$_delayed',
                                        radius: 60,
                                        titleStyle: _pieStyle,
                                      ),
                                    if (_cancelled > 0)
                                      PieChartSectionData(
                                        value: _cancelled.toDouble(),
                                        color: AdminTheme.red,
                                        title: '$_cancelled',
                                        radius: 60,
                                        titleStyle: _pieStyle,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _legend(AdminTheme.green, 'À l\'heure', _onTime),
                                const SizedBox(height: 12),
                                _legend(AdminTheme.orange, 'Retardés', _delayed),
                                const SizedBox(height: 12),
                                _legend(AdminTheme.red, 'Annulés', _cancelled),
                              ],
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _pieStyle => GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white);

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AdminTheme.cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: AdminTheme.muted),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label, int value) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Text('$label : ',
            style: GoogleFonts.inter(
                fontSize: 14, color: AdminTheme.textSecondary)),
        Text('$value',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AdminTheme.textPrimary)),
      ],
    );
  }
}
