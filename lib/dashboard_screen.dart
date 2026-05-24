import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
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
            width: 250,
            color: AdminTheme.navy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('TUI',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AdminTheme.red)),
                      ),
                      const SizedBox(width: 10),
                      Text('Admin',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
                _navItem(0, Icons.dashboard_outlined, 'Tableau de bord'),
                _navItem(1, Icons.flight_outlined, 'Vols'),
                _navItem(2, Icons.payments_outlined, 'Compensations'),
                _navItem(3, Icons.notifications_outlined, 'Notifications'),
                const Spacer(),
                // Logout
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: InkWell(
                    onTap: () => Supabase.instance.client.auth.signOut(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.logout,
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
                  decoration: const BoxDecoration(
                    color: AdminTheme.card,
                    border: Border(
                        bottom: BorderSide(color: AdminTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Text(_titles[_index], style: AdminTheme.h2),
                      const Spacer(),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _index = i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                  size: 20),
              const SizedBox(width: 12),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }
}
