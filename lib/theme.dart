import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Notifier global du mode sombre. Change → toute l'app se reconstruit.
final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);

class AdminTheme {
  // ── Couleurs de marque (identiques dans les 2 modes) ──
  static const Color navy = Color(0xFF0F1F4D);
  static const Color navyLight = Color(0xFF1B2A5A);
  static const Color red = Color(0xFFE2001A);
  static const Color green = Color(0xFF00875A);
  static const Color orange = Color(0xFFE68900);

  static bool get _dark => isDarkMode.value;

  // ── Couleurs dépendantes du mode ──
  static Color get bg => _dark ? const Color(0xFF0E131C) : const Color(0xFFF4F6FB);
  static Color get card => _dark ? const Color(0xFF1A212E) : const Color(0xFFFFFFFF);
  static Color get border => _dark ? const Color(0xFF2A3340) : const Color(0xFFE4E8F0);
  static Color get textPrimary => _dark ? const Color(0xFFF2F5FA) : const Color(0xFF1A1F36);
  static Color get textSecondary => _dark ? const Color(0xFFA6B0C2) : const Color(0xFF6B7280);
  static Color get textMuted => _dark ? const Color(0xFF6B7589) : const Color(0xFF9AA4B8);

  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: bg,
        primaryColor: navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: navy,
          primary: navy,
          brightness: _dark ? Brightness.dark : Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(
          _dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
        ),
        useMaterial3: true,
      );

  static TextStyle get h1 => GoogleFonts.inter(
      fontSize: 26, fontWeight: FontWeight.w800, color: textPrimary);
  static TextStyle get h2 => GoogleFonts.inter(
      fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary);
  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 14, color: textPrimary);
  static TextStyle get muted =>
      GoogleFonts.inter(fontSize: 13, color: textSecondary);

  static BoxDecoration get cardDeco => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
