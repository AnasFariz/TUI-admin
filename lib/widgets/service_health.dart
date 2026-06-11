import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

/// Statut d'un service.
enum _State { ok, slow, down, checking }

class _ServiceStatus {
  final String name;
  final IconData icon;
  _State state;
  String detail;
  int? latencyMs;
  _ServiceStatus(this.name, this.icon)
      : state = _State.checking,
        detail = 'Vérification…';
}

/// Section « État des services » — vérifie en direct Base de données,
/// Authentification et Temps réel (Supabase). Aucun effet de bord.
class ServiceHealthSection extends StatefulWidget {
  const ServiceHealthSection({super.key});

  @override
  State<ServiceHealthSection> createState() => _ServiceHealthSectionState();
}

class _ServiceHealthSectionState extends State<ServiceHealthSection>
    with TickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  final _db = _ServiceStatus('Base de données', Icons.storage_rounded);
  final _auth = _ServiceStatus('Authentification', Icons.lock_rounded);
  final _realtime = _ServiceStatus('Temps réel', Icons.bolt_rounded);
  final _flights = _ServiceStatus('API Vols (synchro)', Icons.flight_rounded);

  bool _running = false;
  DateTime? _lastCheck;
  Timer? _timer;

  // Repli / dépli de la section (avec animation)
  bool _expanded = true;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  late final List<_ServiceStatus> _services = [_db, _auth, _realtime, _flights];

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnim =
        CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOutCubic);
    _checkAll();
    // Re-vérification automatique toutes les 60 s
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _checkAll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  Future<void> _checkAll() async {
    if (_running) return;
    setState(() {
      _running = true;
      for (final s in _services) {
        s.state = _State.checking;
        s.detail = 'Vérification…';
      }
    });
    await Future.wait(
        [_checkDb(), _checkAuth(), _checkRealtime(), _checkFlights()]);
    if (mounted) {
      setState(() {
        _running = false;
        _lastCheck = DateTime.now();
      });
    }
  }

  // ── Base de données : vraie requête + latence ──
  Future<void> _checkDb() async {
    final sw = Stopwatch()..start();
    try {
      await _sb.from('flights').select('id').limit(1);
      sw.stop();
      final ms = sw.elapsedMilliseconds;
      _db.latencyMs = ms;
      _db.state = ms > 1200 ? _State.slow : _State.ok;
      _db.detail = ms > 1200
          ? 'Réponse lente · ${ms}ms'
          : 'Opérationnel · ${ms}ms';
    } catch (e) {
      _db.state = _State.down;
      _db.detail = 'Injoignable';
    }
  }

  // ── Authentification : session + expiration du token ──
  Future<void> _checkAuth() async {
    final session = _sb.auth.currentSession;
    if (session == null) {
      _auth.state = _State.down;
      _auth.detail = 'Aucune session';
      return;
    }
    final expEpoch = session.expiresAt;
    if (expEpoch == null) {
      _auth.state = _State.ok;
      _auth.detail = 'Session active';
      return;
    }
    final exp = DateTime.fromMillisecondsSinceEpoch(expEpoch * 1000);
    final remaining = exp.difference(DateTime.now());
    if (remaining.isNegative) {
      _auth.state = _State.slow;
      _auth.detail = 'Token expiré (renouvellement auto)';
    } else {
      final mins = remaining.inMinutes;
      _auth.state = _State.ok;
      _auth.detail = mins > 60
          ? 'Session active · ${(mins / 60).floor()}h restantes'
          : 'Session active · ${mins}min restantes';
    }
  }

  // ── Temps réel : abonnement à un canal sonde ──
  Future<void> _checkRealtime() async {
    final token = _sb.auth.currentSession?.accessToken;
    if (token != null) _sb.realtime.setAuth(token);

    final completer = Completer<bool>();
    final sw = Stopwatch()..start();
    final probe = _sb.channel('health-probe-${DateTime.now().microsecondsSinceEpoch}');
    probe.subscribe((status, [error]) {
      if (completer.isCompleted) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        completer.complete(true);
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        completer.complete(false);
      }
    });

    final ok = await completer.future
        .timeout(const Duration(seconds: 6), onTimeout: () => false);
    sw.stop();
    await _sb.removeChannel(probe);

    if (ok) {
      final ms = sw.elapsedMilliseconds;
      _realtime.latencyMs = ms;
      _realtime.state = ms > 2500 ? _State.slow : _State.ok;
      _realtime.detail = ms > 2500
          ? 'Connexion lente · ${ms}ms'
          : 'Connecté · ${ms}ms';
    } else {
      _realtime.state = _State.down;
      _realtime.detail = 'Non connecté';
    }
  }

  // ── API Vols : fraîcheur de la dernière synchro (table flights) ──
  // Indicateur indirect : si les vols ont été mis à jour récemment, le
  // pipeline AviationStack → synchro fonctionne. Aucun effet de bord.
  Future<void> _checkFlights() async {
    try {
      final rows = await _sb
          .from('flights')
          .select('updated_at')
          .order('updated_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) {
        _flights.state = _State.down;
        _flights.detail = 'Aucune donnée vol';
        return;
      }
      final last =
          DateTime.tryParse(rows.first['updated_at']?.toString() ?? '')
              ?.toLocal();
      if (last == null) {
        _flights.state = _State.slow;
        _flights.detail = 'Date de synchro inconnue';
        return;
      }
      final age = DateTime.now().difference(last);
      _flights.detail = 'Dernière synchro ${_ago(age)}';
      if (age.inHours < 24) {
        _flights.state = _State.ok;
      } else if (age.inDays < 7) {
        _flights.state = _State.slow;
      } else {
        _flights.state = _State.down;
      }
    } catch (e) {
      _flights.state = _State.down;
      _flights.detail = 'Injoignable';
    }
  }

  String _ago(Duration d) {
    if (d.inMinutes < 1) return "à l'instant";
    if (d.inMinutes < 60) return 'il y a ${d.inMinutes}min';
    if (d.inHours < 24) return 'il y a ${d.inHours}h';
    return 'il y a ${d.inDays}j';
  }

  // Statut global (le pire de tous)
  _State get _global {
    if (_services.any((s) => s.state == _State.down)) return _State.down;
    if (_services.any((s) => s.state == _State.checking)) return _State.checking;
    if (_services.any((s) => s.state == _State.slow)) return _State.slow;
    return _State.ok;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête (toujours visible) : clic = replier / déplier ──
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text('État des services', style: AdminTheme.h2),
                  const SizedBox(width: 12),
                  _globalBadge(),
                  const Spacer(),
                  // Heure + rafraîchir : visibles uniquement quand déplié (fondu)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: _expanded
                        ? Row(
                            key: const ValueKey('actions'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_lastCheck != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                      'Vérifié à ${DateFormat('HH:mm:ss').format(_lastCheck!)}',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AdminTheme.textMuted)),
                                ),
                              InkWell(
                                onTap: _running ? null : _checkAll,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.bg,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: AdminTheme.border),
                                  ),
                                  child: Icon(Icons.refresh_rounded,
                                      size: 17,
                                      color: AdminTheme.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          )
                        : const SizedBox(key: ValueKey('empty')),
                  ),
                  // Chevron qui pivote selon l'état (replié / déplié)
                  RotationTransition(
                    turns: Tween<double>(begin: 0.0, end: 0.5)
                        .animate(_expandAnim),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AdminTheme.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminTheme.border),
                      ),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: AdminTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Contenu repliable : glissement vertical + fondu ──
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1.0,
            child: FadeTransition(
              opacity: _expandAnim,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _tilesGrid(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Grille responsive des voyants de services ──
  Widget _tilesGrid() {
    return LayoutBuilder(
      builder: (context, c) {
        // Responsive : 4 colonnes si large, 2 si moyen, 1 si étroit
        final cols = c.maxWidth >= 1080
            ? 4
            : c.maxWidth >= 640
                ? 2
                : 1;
        const gap = 14.0;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in _services)
              SizedBox(
                width: cols == 1
                    ? c.maxWidth
                    : (c.maxWidth - gap * (cols - 1)) / cols,
                child: _tile(s),
              ),
          ],
        );
      },
    );
  }

  // ── Badge de statut global ──
  Widget _globalBadge() {
    final (color, label) = switch (_global) {
      _State.ok => (AdminTheme.green, 'Tous opérationnels'),
      _State.slow => (AdminTheme.orange, 'Ralentissements'),
      _State.down => (AdminTheme.red, 'Incident détecté'),
      _State.checking => (AdminTheme.textMuted, 'Vérification…'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ── Tuile d'un service ──
  Widget _tile(_ServiceStatus s) {
    final color = switch (s.state) {
      _State.ok => AdminTheme.green,
      _State.slow => AdminTheme.orange,
      _State.down => AdminTheme.red,
      _State.checking => AdminTheme.textMuted,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, size: 21, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(s.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AdminTheme.textPrimary)),
                    ),
                    const SizedBox(width: 8),
                    _StatusDot(color: color, pulsing: s.state != _State.down),
                  ],
                ),
                const SizedBox(height: 3),
                Text(s.detail,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AdminTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Petit point de statut (pulse si actif).
class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulsing;
  const _StatusDot({required this.color, required this.pulsing});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulsing) {
      return Container(
        width: 9,
        height: 9,
        decoration:
            BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: widget.color.withValues(alpha: 0.4 + _c.value * 0.5),
                blurRadius: 4 + _c.value * 5,
                spreadRadius: _c.value * 2),
          ],
        ),
      ),
    );
  }
}
