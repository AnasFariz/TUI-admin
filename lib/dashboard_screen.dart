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
            width: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AdminTheme.navy, Color(0xFF0A1738)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo TUI (ton image) dans un cartouche blanc
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset('assets/images/tui_logo.png',
                        height: 44, fit: BoxFit.contain),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                  child: Text('CONSOLE D\'ADMINISTRATION',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 1.5)),
                ),
                _navItem(0, Icons.dashboard_rounded, 'Tableau de bord'),
                _navItem(1, Icons.flight_rounded, 'Vols'),
                _navItem(2, Icons.payments_rounded, 'Compensations'),
                _navItem(3, Icons.notifications_rounded, 'Notifications'),
                const Spacer(),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                // Logout
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: InkWell(
                    onTap: () => Supabase.instance.client.auth.signOut(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 20),
                          const SizedBox(width: 12),
                          Text('Déconnexion',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                  ),
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
    final active = _index == i;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _index = i),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Barre d'accent rouge à gauche (actif)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: active ? AdminTheme.red : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon,
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                  size: 20),
              const SizedBox(width: 12),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55))),
            ],
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
