import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

// Même backend Supabase que l'app passager (instance auto-hébergée sur VPS)
const supabaseUrl = 'http://138.197.191.121:8000';
const supabaseKey = 'sb_publishable_tmLfCOpxbCLxj8zlIjhOdQ_7AZhUl1y';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const TuiAdminApp());
}

final supabase = Supabase.instance.client;

class TuiAdminApp extends StatelessWidget {
  const TuiAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (_, dark, _) {
        return MaterialApp(
          title: 'TUI Admin',
          debugShowCheckedModeBanner: false,
          theme: AdminTheme.theme,
          // Transition fluide en fondu au changement de mode
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: _AuthGate(key: ValueKey(dark)),
          ),
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) return const DashboardScreen();
        return const LoginScreen();
      },
    );
  }
}
