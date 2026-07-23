import 'dart:ui';
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
      final client = Supabase.instance.client;
      await client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Contrôle d'accès (OWASP A01 - Broken Access Control) : seuls les
      // comptes listés dans public.admins peuvent utiliser cette console.
      final uid = client.auth.currentUser?.id;
      final isAdmin = uid != null &&
          await client
                  .from('admins')
                  .select('user_id')
                  .eq('user_id', uid)
                  .maybeSingle() !=
              null;
      if (!isAdmin) {
        await client.auth.signOut();
        setState(() => _error =
            'Accès refusé : ce compte n\'est pas autorisé pour la console admin.');
      }
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
      body: Stack(
        children: [
          // Photo plein écran, en arrière-plan de toute la page
          Positioned.fill(
            child: Image.asset('assets/images/login_background.jpg',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                isAntiAlias: true),
          ),
          // Voile en dégradé : plus sombre à gauche (lisibilité du texte),
          // plus clair à droite pour laisser la photo bien visible.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AdminTheme.navy.withValues(alpha: 0.78),
                    AdminTheme.navy.withValues(alpha: 0.45),
                    AdminTheme.navy.withValues(alpha: 0.18),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Orbes décoratifs flous
          Positioned(
            top: -80,
            left: -60,
            child: _orb(260, AdminTheme.red.withValues(alpha: 0.18)),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: _orb(320, const Color(0xFF2E6BFF).withValues(alpha: 0.12)),
          ),
          // Contenu
          Row(
            children: [
              // Panneau gauche (branding)
              Expanded(
                flex: 5,
                child: Padding(
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
                            color: Colors.white.withValues(alpha: 0.75),
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
                              color: Colors.white.withValues(alpha: 0.45))),
                    ],
                  ),
                ),
              ),
              // Panneau droit (formulaire) — carte "verre dépoli" flottant sur la photo
              Expanded(
                flex: 4,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              // Verre dépoli sombre translucide : la photo reste
                              // visible à travers la carte, le texte blanc reste net.
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.30),
                                  width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.30),
                                  blurRadius: 48,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.20)),
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
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text('Bienvenue',
                                    style: GoogleFonts.inter(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5)),
                                const SizedBox(height: 8),
                                Text('Connectez-vous à la console d\'administration',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color:
                                            Colors.white.withValues(alpha: 0.70))),
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
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFFF8A80))),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AdminTheme.navy,
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
                                                    AdminTheme.navy)))
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
                ),
              ),
            ],
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
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.55), fontSize: 15),
        prefixIcon:
            Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.70)),
        suffixIcon: suffix != null
            ? IconTheme(
                data: IconThemeData(
                    color: Colors.white.withValues(alpha: 0.70)),
                child: suffix)
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.80), width: 1.5),
        ),
      ),
    );
  }
}
