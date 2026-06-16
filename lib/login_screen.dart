import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Erreur de connexion');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Panneau gauche (branding luxe)
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF13265E), AdminTheme.navy, Color(0xFF050C1F)],
                ),
              ),
              child: Stack(
                children: [
                  // Orbes décoratifs flous
                  Positioned(
                    top: -80,
                    left: -60,
                    child: _orb(260, AdminTheme.red.withValues(alpha: 0.18)),
                  ),
                  Positioned(
                    bottom: -100,
                    right: -80,
                    child: _orb(320, const Color(0xFF2E6BFF).withValues(alpha: 0.15)),
                  ),
                  // Contenu
                  Padding(
                    padding: const EdgeInsets.all(56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Image.asset('assets/images/tui_logo.png',
                            height: 150, fit: BoxFit.contain),
                        const SizedBox(height: 40),
                        Text('Console d\'administration',
                            style: GoogleFonts.inter(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 14),
                        Text(
                          'Pilotez les opérations de TUI Belgium en temps réel :\nvols, perturbations, compensations et notifications.',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.65),
                              height: 1.6),
                        ),
                        const SizedBox(height: 40),
                        _feature(Icons.flight_rounded, 'Gestion des vols en direct'),
                        const SizedBox(height: 16),
                        _feature(Icons.bolt_rounded, 'Notifications temps réel'),
                        const SizedBox(height: 16),
                        _feature(Icons.shield_rounded, 'Sécurisé & conforme EU261'),
                        const Spacer(),
                        Text('© 2026 TUI Belgium — Tous droits réservés',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Panneau droit (formulaire)
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AdminTheme.navy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: AdminTheme.green,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text('Espace réservé au personnel TUI',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AdminTheme.navy)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Bienvenue', style: AdminTheme.h1),
                        const SizedBox(height: 8),
                        Text('Connectez-vous à la console d\'administration',
                            style: AdminTheme.muted),
                        const SizedBox(height: 32),
                        _field(_email, 'Email', Icons.mail_outline),
                        const SizedBox(height: 14),
                        _field(_password, 'Mot de passe', Icons.lock_outline,
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            )),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AdminTheme.red)),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white)))
                                : Text('Se connecter',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }

  Widget _feature(IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85))),
      ],
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AdminTheme.textMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: AdminTheme.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminTheme.navy, width: 1.5),
        ),
      ),
    );
  }
}
