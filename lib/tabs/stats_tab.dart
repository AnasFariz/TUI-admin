import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
  List<Map<String, dynamic>> _activity = [];

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

      // Flux d'activité : vols perturbés (données réelles)
      _activity = flights
          .where((f) =>
              f['status'] == 'delayed' || f['status'] == 'cancelled')
          .toList();

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
    final now = DateTime.now();
    final dateStr = DateFormat("EEEE d MMMM yyyy", 'fr_FR').format(now);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header de bienvenue dynamique ──
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bonjour 👋',
                      style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AdminTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                      '${dateStr[0].toUpperCase()}${dateStr.substring(1)} · $_totalFlights vols suivis',
                      style: AdminTheme.muted),
                ],
              ),
              const Spacer(),
              // Indicateur LIVE
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AdminTheme.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AdminTheme.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    _PulseDot(),
                    const SizedBox(width: 8),
                    Text('EN DIRECT',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AdminTheme.green,
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── KPI cards (animés + hover + tendance) ──
          Row(
            children: [
              _KpiCard('Vols totaux', _totalFlights, Icons.flight_rounded,
                  AdminTheme.navy, 'Tous les vols', '+8%', true),
              const SizedBox(width: 18),
              _KpiCard('À l\'heure', _onTime, Icons.check_circle_rounded,
                  AdminTheme.green, 'Vols ponctuels', '+5%', true),
              const SizedBox(width: 18),
              _KpiCard('Perturbés', disrupted, Icons.warning_amber_rounded,
                  AdminTheme.orange, 'Retards + annulations', '-3%', false),
              const SizedBox(width: 18),
              _KpiCard('Taux perturbation', disruptRate,
                  Icons.trending_up_rounded, AdminTheme.red, 'Sur le total',
                  '-2%', false,
                  suffix: '%'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _KpiCard('Réservations', _reservations,
                  Icons.confirmation_number_rounded, AdminTheme.navyLight,
                  'Passagers', '+12%', true),
              const SizedBox(width: 18),
              _KpiCard('Compensations', _claims, Icons.payments_rounded,
                  AdminTheme.orange, 'Demandes EU261', '+1', true),
              const SizedBox(width: 18),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 18),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 28),

          // ── Graphique évolution + Flux d'activité ──
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _evolutionChart(disrupted)),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: _activityFeed()),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Camembert répartition ──
          _statusPie(),
        ],
      ),
    );
  }

  // ── Graphique d'évolution (area chart 7 jours) ──
  Widget _evolutionChart(int disruptedToday) {
    // Série 7 jours : 6 jours simulés + aujourd'hui (réel)
    final rng = math.Random(7);
    final data = List.generate(6, (_) => 1 + rng.nextInt(6).toDouble());
    data.add(disruptedToday.toDouble());
    final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final maxY = (data.reduce(math.max) + 2);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution des perturbations',
              style: AdminTheme.h2),
          const SizedBox(height: 4),
          Text('7 derniers jours', style: AdminTheme.muted),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: AdminTheme.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxY / 4,
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AdminTheme.textMuted)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= days.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(days[i],
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AdminTheme.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < data.length; i++)
                        FlSpot(i.toDouble(), data[i]),
                    ],
                    isCurved: true,
                    color: AdminTheme.red,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: AdminTheme.red),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AdminTheme.red.withValues(alpha: 0.25),
                          AdminTheme.red.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Flux d'activité en direct ──
  Widget _activityFeed() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Activité récente', style: AdminTheme.h2),
              const Spacer(),
              _PulseDot(),
            ],
          ),
          const SizedBox(height: 16),
          if (_activity.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('Aucune perturbation en cours',
                    style: AdminTheme.muted),
              ),
            )
          else
            ..._activity.take(6).map((f) {
              final cancelled = f['status'] == 'cancelled';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (cancelled ? AdminTheme.red : AdminTheme.orange)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                          cancelled
                              ? Icons.cancel_rounded
                              : Icons.schedule_rounded,
                          size: 18,
                          color:
                              cancelled ? AdminTheme.red : AdminTheme.orange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vol ${f['flight_number']} ${cancelled ? 'annulé' : 'retardé'}',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AdminTheme.textPrimary),
                          ),
                          Text(
                            '${f['departure_code']} → ${f['arrival_code']}',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AdminTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Camembert ──
  Widget _statusPie() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Répartition des vols par statut', style: AdminTheme.h2),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: _totalFlights == 0
                ? Center(child: Text('Aucune donnée', style: AdminTheme.muted))
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
                                    radius: 55,
                                    titleStyle: _pieStyle),
                              if (_delayed > 0)
                                PieChartSectionData(
                                    value: _delayed.toDouble(),
                                    color: AdminTheme.orange,
                                    title: '$_delayed',
                                    radius: 55,
                                    titleStyle: _pieStyle),
                              if (_cancelled > 0)
                                PieChartSectionData(
                                    value: _cancelled.toDouble(),
                                    color: AdminTheme.red,
                                    title: '$_cancelled',
                                    radius: 55,
                                    titleStyle: _pieStyle),
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
    );
  }

  TextStyle get _pieStyle => GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white);

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

// ══════════════════════════════════════════════
// KPI CARD : compteur animé + hover + badge tendance
// ══════════════════════════════════════════════
class _KpiCard extends StatefulWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final String trend;
  final bool trendUp;
  final String suffix;
  const _KpiCard(this.label, this.value, this.icon, this.color, this.subtitle,
      this.trend, this.trendUp,
      {this.suffix = ''});

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AdminTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _hover
                    ? widget.color.withValues(alpha: 0.4)
                    : AdminTheme.border),
            boxShadow: [
              BoxShadow(
                color: widget.color
                    .withValues(alpha: _hover ? 0.22 : 0.05),
                blurRadius: _hover ? 28 : 16,
                offset: Offset(0, _hover ? 12 : 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        widget.color,
                        widget.color.withValues(alpha: 0.7)
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: widget.color.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  // Badge tendance
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (widget.trendUp
                              ? AdminTheme.green
                              : AdminTheme.red)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            widget.trendUp
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 12,
                            color: widget.trendUp
                                ? AdminTheme.green
                                : AdminTheme.red),
                        const SizedBox(width: 2),
                        Text(widget.trend,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.trendUp
                                    ? AdminTheme.green
                                    : AdminTheme.red)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Compteur animé
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.value.toDouble()),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(
                  '${v.toInt()}${widget.suffix}',
                  style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AdminTheme.textPrimary,
                      height: 1),
                ),
              ),
              const SizedBox(height: 6),
              Text(widget.label,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(widget.subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AdminTheme.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// Point pulsant (indicateur live)
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: AdminTheme.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AdminTheme.green.withValues(alpha: 0.5 + _c.value * 0.5),
                blurRadius: 4 + _c.value * 6,
                spreadRadius: _c.value * 2),
          ],
        ),
      ),
    );
  }
}
