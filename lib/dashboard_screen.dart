import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'tui_smile.dart';
import 'tabs/stats_tab.dart';
import 'tabs/flights_tab.dart';
import 'tabs/claims_tab.dart';
import 'tabs/notifications_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  final _titles = [
    'Tableau de bord',
    'Gestion des vols',
    'Demandes de compensation',
    'Notifications',
  ];

  final _pages = const [
    StatsTab(),
    FlightsTab(),
    ClaimsTab(),
    NotificationsTab(),
  ];

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
                    // ── Logo + titre ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 32, 24, 0),
                      child: Image.asset('assets/images/tui_logo.png',
                          height: 46, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: Row(
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
                    _navItem(2, Icons.payments_rounded, 'Compensations'),
                    _navItem(3, Icons.notifications_rounded, 'Notifications'),
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
                                  Text('Administrateur',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                  Text(
                                    Supabase.instance.client.auth.currentUser
                                            ?.email ??
                                        'TUI',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withValues(alpha: 0.55)),
                                  ),
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
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AdminTheme.bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: AdminTheme.navy,
                              child: Icon(Icons.person,
                                  size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Supabase.instance.client.auth.currentUser
                                      ?.email ??
                                  'Admin',
                              style: AdminTheme.muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Page
                Expanded(
                  child: Container(
                    color: AdminTheme.bg,
                    child: _pages[_index],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    return _NavItem(
      icon: icon,
      label: label,
      active: _index == i,
      onTap: () => setState(() => _index = i),
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
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
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
                if (active)
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
