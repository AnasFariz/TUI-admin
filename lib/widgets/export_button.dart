import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// Bouton d'export PDF (style premium).
class ExportButton extends StatelessWidget {
  final VoidCallback onPdf;
  const ExportButton({super.key, required this.onPdf});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPdf,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AdminTheme.navy, Color(0xFF1B2A5A)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AdminTheme.navy.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_rounded,
                size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text('Exporter en PDF',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
