import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'tabs/stats_tab.dart';
import 'tabs/flights_tab.dart';
import 'tabs/claims_tab.dart';
import 'tabs/notifications_tab.dart';
import 'tabs/hotels_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  int _newClaims = 0; // badge temps réel pour Compensations
  RealtimeChannel? _claimsChannel;
  Timer? _pollTimer;
  int _lastKnownCount = 0;

  final _titles = [
    'Tableau de bord',
    'Gestion des vols',
    'Demandes de compensation',
    'Notifications',
    'Réseau hôtelier',
  ];

  final _pages = const [
    StatsTab(),
    FlightsTab(),
    ClaimsTab(),
    NotificationsTab(),
    HotelsTab(),
  ];

  String _adminName = 'Anas Fariz';
  final String _adminTitle = 'Mr';

  @override
  void initState() {
    super.initState();
    _loadAdminName();
    _initBaseline().then((_) {
      _subscribeNewClaims();
      _startPollingFallback();
    });
  }

  Future<void> _loadAdminName() async {
    try {
      final sb = Supabase.instance.client;
      final uid = sb.auth.currentUser?.id;
      if (uid == null) return;
      final prof = await sb
          .from('profiles')
          .select('full_name')
          .eq('id', uid)
          .maybeSingle();
      final raw = prof?['full_name']?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        if (mounted) setState(() => _adminName = raw);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _claimsChannel?.unsubscribe();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initBaseline() async {
    try {
      final rows = await Supabase.instance.client
          .from('compensation_claims')
          .select('id');
      _lastKnownCount = (rows as List).length;
    } catch (_) {}
  }

  /// S'assure que le JWT est attaché au websocket Realtime (sinon RLS bloque).
  void _subscribeNewClaims() {
    final sb = Supabase.instance.client;
    final token = sb.auth.currentSession?.accessToken;
    if (token != null) {
      sb.realtime.setAuth(token);
    }
    _claimsChannel = sb.channel('admin-new-claims')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'compensation_claims',
        callback: (_) => _onNewClaim(),
      )
      ..subscribe();
  }

  /// Fallback : si le websocket dort, on poll toutes les 15s.
  void _startPollingFallback() {
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _pollCount());
  }

  Future<void> _pollCount() async {
    if (!mounted) return;
    try {
      final rows = await Supabase.instance.client
          .from('compensation_claims')
          .select('id');
      final n = (rows as List).length;
      if (n > _lastKnownCount) {
        final delta = n - _lastKnownCount;
        _lastKnownCount = n;
        for (var i = 0; i < delta; i++) {
          _onNewClaim();
        }
      } else {
        _lastKnownCount = n;
      }
    } catch (_) {}
  }

  void _onNewClaim() {
    if (!mounted) return;
    if (_index == 2) return; // déjà sur l'onglet Compensations
    setState(() => _newClaims++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AdminTheme.orange,
        content: Row(
          children: const [
            Icon(Icons.notifications_active_rounded,
                color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Nouvelle demande de compensation reçue'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──
          Container(
            width: 268,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF13265E), AdminTheme.navy, Color(0xFF060E24)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(4, 0),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Orbe décoratif subtil en haut
                Positioned(
                  top: -70,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AdminTheme.red.withValues(alpha: 0.16),
                        AdminTheme.red.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Logo (centré) + titre ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                      child: Center(
                        child: Image.asset('assets/images/tui_logo.png',
                            height: 50, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: AdminTheme.green,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Text('CONSOLE D\'ADMINISTRATION',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  letterSpacing: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    // Séparateur fin
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.07)),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 0, 24, 10),
                      child: Text('MENU PRINCIPAL',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.3),
                              letterSpacing: 1.4)),
                    ),
                    _navItem(0, Icons.dashboard_rounded, 'Tableau de bord'),
                    _navItem(1, Icons.flight_rounded, 'Vols'),
                    _navItem(2, Icons.payments_rounded, 'Compensations',
                        badge: _newClaims),
                    _navItem(3, Icons.notifications_rounded, 'Notifications'),
                    _navItem(4, Icons.hotel_rounded, 'Hôtels'),
                    const Spacer(),
                    // ── Carte profil admin ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AdminTheme.red, Color(0xFFFF4D5E)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$_adminTitle $_adminName',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                  Text('Administrateur',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white
                                              .withValues(alpha: 0.55))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── Déconnexion ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      child: InkWell(
                        onTap: () =>
                            Supabase.instance.client.auth.signOut(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AdminTheme.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AdminTheme.red.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.logout_rounded,
                                  color: Color(0xFFFF6B78), size: 19),
                              const SizedBox(width: 12),
                              Text('Déconnexion',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFF6B78))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Contenu ──
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AdminTheme.card,
                    border: Border(
                        bottom: BorderSide(color: AdminTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Text(_titles[_index], style: AdminTheme.h2),
                      const Spacer(),
                      // Switch mode sombre (toggle pro)
                      const _ThemeSwitch(),
                    ],
                  ),
                ),
                // Page — fond animé subtil + transition douce entre onglets
                Expanded(
                  child: Container(
                    color: AdminTheme.bg,
                    child: Stack(
                      children: [
                        const Positioned.fill(child: _DashboardBackground()),
                        Positioned.fill(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.035, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(_index),
                              child: _pages[_index],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label, {int badge = 0}) {
    return _NavItem(
      icon: icon,
      label: label,
      active: _index == i,
      badge: badge,
      onTap: () => setState(() {
        _index = i;
        if (i == 2) _newClaims = 0; // reset compteur en ouvrant Compensations
      }),
    );
  }
}

// ──────────────────────────────────────────
// ÉLÉMENT DE NAVIGATION (hover + actif lumineux)
// ──────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [Color(0xFF26396E), Color(0xFF1A2A57)],
                    )
                  : null,
              color: active
                  ? null
                  : (_hover
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: active
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AdminTheme.red.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Barre d'accent rouge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 3,
                  height: active ? 22 : 0,
                  decoration: BoxDecoration(
                    color: AdminTheme.red,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: active ? 11 : 14),
                // Icône dans conteneur
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: active
                        ? AdminTheme.red
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon,
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                      size: 18),
                ),
                const SizedBox(width: 13),
                Text(widget.label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.62))),
                const Spacer(),
                if (widget.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AdminTheme.red, Color(0xFFFF4D5E)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AdminTheme.red.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                        widget.badge > 9 ? '9+' : widget.badge.toString(),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  )
                else if (active)
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.white.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// SWITCH MODE SOMBRE (toggle professionnel)
// ──────────────────────────────────────────
class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch();

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode.value;
    return InkWell(
      onTap: () => isDarkMode.value = !isDarkMode.value,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 64,
        height: 34,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? [const Color(0xFF1B2A5A), const Color(0xFF0F1F4D)]
                : [const Color(0xFFFFD27A), const Color(0xFFFFB347)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (dark ? AdminTheme.navy : AdminTheme.orange)
                  .withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Icônes de fond
            Positioned(
              left: 7,
              top: 6,
              child: Icon(Icons.wb_sunny_rounded,
                  size: 15,
                  color: dark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white),
            ),
            Positioned(
              right: 7,
              top: 6,
              child: Icon(Icons.nightlight_round,
                  size: 14,
                  color: dark
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4)),
            ),
            // Bouton glissant
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment:
                  dark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  size: 15,
                  color: dark ? AdminTheme.navy : AdminTheme.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// FOND ANIMÉ SUBTIL de la zone de contenu :
// deux orbes floutés qui dérivent lentement, très discrets, pour donner
// de la profondeur sans gêner la lecture des cartes.
// ──────────────────────────────────────────
class _DashboardBackground extends StatefulWidget {
  const _DashboardBackground();
  @override
  State<_DashboardBackground> createState() => _DashboardBackgroundState();
}

class _DashboardBackgroundState extends State<_DashboardBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 18))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Stack(
          children: [
            Positioned(
              top: -120 + t * 40,
              right: -80 - t * 30,
              child: _orb(360, AdminTheme.navy.withValues(alpha: 0.05)),
            ),
            Positioned(
              bottom: -140 - t * 30,
              left: -100 + t * 50,
              child: _orb(420, AdminTheme.red.withValues(alpha: 0.04)),
            ),
          ],
        );
      },
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}
