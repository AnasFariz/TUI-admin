import 'dart:async';
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
  bool _refreshing = false;
  DateTime? _lastUpdate;

  int _totalFlights = 0;
  int _onTime = 0;
  int _delayed = 0;
  int _cancelled = 0;
  int _reservations = 0;
  int _claims = 0;

  List<Map<String, dynamic>> _activity = [];

  // Dates de création (pour les tendances semaine/semaine)
  List<DateTime> _flightDates = [];
  List<DateTime> _reservationDates = [];
  List<DateTime> _claimDates = [];

  // Vols perturbés avec leur date (pour la courbe réelle)
  List<DateTime> _disruptedFlightDays = [];

  // Période de la courbe : 7 ou 30 jours
  int _periodDays = 7;

  // Auto-refresh
  RealtimeChannel? _channel;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
    _poll = Timer.periodic(
        const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _poll?.cancel();
    super.dispose();
  }

  /// Réabonnement realtime sur les 3 tables clés → rechargement auto.
  void _subscribeRealtime() {
    final token = _sb.auth.currentSession?.accessToken;
    if (token != null) _sb.realtime.setAuth(token);
    _channel = _sb.channel('admin-dashboard');
    for (final table in ['flights', 'reservations', 'compensation_claims']) {
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _load(silent: true),
      );
    }
    _channel!.subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (silent) {
      setState(() => _refreshing = true);
    } else {
      setState(() => _loading = true);
    }
    try {
      final flights =
          List<Map<String, dynamic>>.from(await _sb.from('flights').select());
      _totalFlights = flights.length;
      _onTime = flights.where((f) => f['status'] == 'on_time').length;
      _delayed = flights.where((f) => f['status'] == 'delayed').length;
      _cancelled = flights.where((f) => f['status'] == 'cancelled').length;
      _flightDates = _datesOf(flights, 'created_at');

      // Flux d'activité : vols perturbés (données réelles)
      _activity = flights
          .where((f) =>
              f['status'] == 'delayed' || f['status'] == 'cancelled')
          .toList();

      // Jours de perturbation réels (basés sur flight_date) pour la courbe
      _disruptedFlightDays = _activity
          .map((f) => DateTime.tryParse(f['flight_date']?.toString() ?? ''))
          .whereType<DateTime>()
          .map((d) => DateTime(d.year, d.month, d.day))
          .toList();

      try {
        final r = List<Map<String, dynamic>>.from(
            await _sb.from('reservations').select());
        _reservations = r.length;
        _reservationDates = _datesOf(r, 'created_at');
      } catch (_) {}
      try {
        final c = List<Map<String, dynamic>>.from(
            await _sb.from('compensation_claims').select());
        _claims = c.length;
        _claimDates = _datesOf(c, 'created_at');
      } catch (_) {}
      _lastUpdate = DateTime.now();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  /// Extrait et parse une colonne timestamp d'une liste de lignes.
  List<DateTime> _datesOf(List<Map<String, dynamic>> rows, String col) => rows
      .map((r) => DateTime.tryParse(r[col]?.toString() ?? '')?.toLocal())
      .whereType<DateTime>()
      .toList();

  /// Tendance semaine vs semaine précédente. `null` si pas d'historique
  /// (on n'invente pas de pourcentage → honnête pour la soutenance).
  _Trend? _wowTrend(List<DateTime> dates, {bool goodWhenUp = true}) {
    final now = DateTime.now();
    int last = 0, prev = 0;
    for (final d in dates) {
      final diff = now.difference(d).inDays;
      if (diff >= 0 && diff < 7) {
        last++;
      } else if (diff >= 7 && diff < 14) {
        prev++;
      }
    }
    if (prev == 0) return null; // pas de base de comparaison fiable
    final pct = ((last - prev) / prev * 100).round();
    final up = pct >= 0;
    final good = goodWhenUp ? up : !up;
    return _Trend(
      '${up ? '+' : ''}$pct%',
      up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      good ? AdminTheme.green : AdminTheme.red,
    );
  }

  /// Pastille neutre (part / ratio), pas une fausse tendance.
  _Trend _flat(String text) =>
      _Trend(text, null, AdminTheme.textMuted);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final disrupted = _delayed + _cancelled;
    final disruptRate =
        _totalFlights > 0 ? (disrupted / _totalFlights * 100).round() : 0;
    final punctuality =
        _totalFlights > 0 ? (_onTime / _totalFlights * 100).round() : 0;
    final now = DateTime.now();
    final dateStr = DateFormat("EEEE d MMMM yyyy", 'fr_FR').format(now);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header de bienvenue dynamique ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 12),
              // Heure de dernière mise à jour
              if (_lastUpdate != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 4),
                  child: Text(
                      'Mis à jour à ${DateFormat('HH:mm:ss').format(_lastUpdate!)}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AdminTheme.textMuted)),
                ),
              // Bouton rafraîchir
              _RefreshButton(
                  spinning: _refreshing, onTap: () => _load(silent: true)),
              const SizedBox(width: 12),
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

          // ── KPI cards (animés + hover + tendance RÉELLE) ──
          Row(
            children: [
              _KpiCard('Vols totaux', _totalFlights, Icons.flight_rounded,
                  AdminTheme.navy, 'Tous les vols',
                  trend: _wowTrend(_flightDates)),
              const SizedBox(width: 18),
              _KpiCard('À l\'heure', _onTime, Icons.check_circle_rounded,
                  AdminTheme.green, 'Ponctualité',
                  trend: _flat('$punctuality%')),
              const SizedBox(width: 18),
              _KpiCard('Perturbés', disrupted, Icons.warning_amber_rounded,
                  AdminTheme.orange, 'Retards + annulations',
                  trend: _flat('$disruptRate% du total')),
              const SizedBox(width: 18),
              _KpiCard('Taux perturbation', disruptRate,
                  Icons.trending_up_rounded, AdminTheme.red, 'Sur le total',
                  suffix: '%'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _KpiCard('Réservations', _reservations,
                  Icons.confirmation_number_rounded, AdminTheme.navyLight,
                  'Passagers',
                  trend: _wowTrend(_reservationDates)),
              const SizedBox(width: 18),
              _KpiCard('Compensations', _claims, Icons.payments_rounded,
                  AdminTheme.orange, 'Demandes EU261',
                  trend: _wowTrend(_claimDates, goodWhenUp: false)),
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
                Expanded(flex: 3, child: _evolutionChart()),
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

  // ── Graphique d'évolution RÉEL (perturbations par jour) ──
  Widget _evolutionChart() {
    final days = _periodDays;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));

    // Comptage réel : perturbations par jour sur la fenêtre choisie
    final counts = List<double>.filled(days, 0);
    for (final d in _disruptedFlightDays) {
      final idx = d.difference(start).inDays;
      if (idx >= 0 && idx < days) counts[idx] += 1;
    }
    final maxY = math.max(counts.reduce(math.max) + 2, 4.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Évolution des perturbations', style: AdminTheme.h2),
                    const SizedBox(height: 4),
                    Text('$days derniers jours', style: AdminTheme.muted),
                  ],
                ),
              ),
              // Sélecteur de période
              _PeriodToggle(
                value: _periodDays,
                onChanged: (v) => setState(() => _periodDays = v),
              ),
            ],
          ),
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
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AdminTheme.border, strokeWidth: 1),
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
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= days) return const SizedBox();
                        final date = start.add(Duration(days: i));
                        // 7j → lettre du jour ; 30j → 1 label sur 5
                        final show = days <= 7 || i % 5 == 0 || i == days - 1;
                        if (!show) return const SizedBox();
                        final label = days <= 7
                            ? DateFormat('E', 'fr_FR')
                                .format(date)[0]
                                .toUpperCase()
                            : DateFormat('d/M').format(date);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label,
                              style: GoogleFonts.inter(
                                  fontSize: 10,
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
                      for (int i = 0; i < counts.length; i++)
                        FlSpot(i.toDouble(), counts[i]),
                    ],
                    isCurved: true,
                    color: AdminTheme.red,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: days <= 7,
                      getDotPainter: (s, _, _, _) => FlDotCirclePainter(
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
// Donnée de tendance (réelle) affichée dans une KPI card
// ══════════════════════════════════════════════
class _Trend {
  final String text;
  final IconData? icon; // null = pastille neutre (part/ratio)
  final Color color;
  const _Trend(this.text, this.icon, this.color);
}

// ══════════════════════════════════════════════
// Sélecteur de période 7j / 30j
// ══════════════════════════════════════════════
class _PeriodToggle extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _PeriodToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AdminTheme.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in const [7, 30]) _seg(p),
        ],
      ),
    );
  }

  Widget _seg(int p) {
    final active = value == p;
    return GestureDetector(
      onTap: () => onChanged(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AdminTheme.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('${p}j',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AdminTheme.textMuted)),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// Bouton rafraîchir (icône qui tourne pendant le chargement)
// ══════════════════════════════════════════════
class _RefreshButton extends StatefulWidget {
  final bool spinning;
  final VoidCallback onTap;
  const _RefreshButton({required this.spinning, required this.onTap});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void didUpdateWidget(_RefreshButton old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.spinning && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AdminTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminTheme.border),
        ),
        child: RotationTransition(
          turns: _c,
          child: Icon(Icons.refresh_rounded,
              size: 18, color: AdminTheme.textSecondary),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// KPI CARD : compteur animé + hover + pastille (tendance réelle / ratio)
// ══════════════════════════════════════════════
class _KpiCard extends StatefulWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final String suffix;
  final _Trend? trend;
  const _KpiCard(
      this.label, this.value, this.icon, this.color, this.subtitle,
      {this.suffix = '', this.trend});

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final trend = widget.trend;
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
                color: widget.color.withValues(alpha: _hover ? 0.22 : 0.05),
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
                  // Pastille (tendance réelle ou ratio) — masquée si null
                  if (trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: trend.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          if (trend.icon != null) ...[
                            Icon(trend.icon, size: 12, color: trend.color),
                            const SizedBox(width: 2),
                          ],
                          Text(trend.text,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: trend.color)),
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
                builder: (_, v, _) => Text(
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
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
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
      builder: (_, _) => Container(
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
