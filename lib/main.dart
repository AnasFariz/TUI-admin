import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

// Même backend Supabase que l'app passager
const supabaseUrl = 'https://epcswjogpfpsdgizrpry.supabase.co';
const supabaseKey = 'sb_publishable_C5ILIX6MoFROjAgY1MzIKg_TFo-Pvxg';

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

// Vérifie que le compte connecté figure bien dans public.admins
// (OWASP A01 - Broken Access Control) avant d'exposer le dashboard,
// y compris quand une session persistée est restaurée sans repasser
// par l'écran de connexion.
Future<bool> _isAdmin(String uid) async {
  try {
    final row = await supabase
        .from('admins')
        .select('user_id')
        .eq('user_id', uid)
        .maybeSingle();
    return row != null;
  } catch (_) {
    return false;
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
        if (session == null) return const LoginScreen();
        return FutureBuilder<bool>(
          key: ValueKey(session.user.id),
          future: _isAdmin(session.user.id),
          builder: (context, adminSnap) {
            if (!adminSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (adminSnap.data == true) return const DashboardScreen();
            supabase.auth.signOut();
            return const LoginScreen();
          },
        );
      },
    );
  }
}
