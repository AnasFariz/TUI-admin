import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminTheme {
  // Palette TUI admin — bleu marine + rouge + fond clair
  static const Color navy = Color(0xFF0F1F4D);
  static const Color navyLight = Color(0xFF1B2A5A);
  static const Color red = Color(0xFFE2001A);
  static const Color green = Color(0xFF00875A);
  static const Color orange = Color(0xFFE68900);
  static const Color bg = Color(0xFFF4F6FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E8F0);
  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9AA4B8);

  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: bg,
        primaryColor: navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: navy,
          primary: navy,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      );

  static TextStyle h1 = GoogleFonts.inter(
      fontSize: 26, fontWeight: FontWeight.w800, color: textPrimary);
  static TextStyle h2 = GoogleFonts.inter(
      fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary);
  static TextStyle body = GoogleFonts.inter(
      fontSize: 14, color: textPrimary);
  static TextStyle muted = GoogleFonts.inter(
      fontSize: 13, color: textSecondary);

  static BoxDecoration cardDeco = BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: navy.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
