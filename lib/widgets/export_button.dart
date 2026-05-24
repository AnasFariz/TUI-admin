import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// Bouton d'export avec menu CSV / PDF (style premium).
class ExportButton extends StatelessWidget {
  final VoidCallback onCsv;
  final VoidCallback onPdf;
  const ExportButton({super.key, required this.onCsv, required this.onPdf});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Exporter',
      offset: const Offset(0, 48),
      color: AdminTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AdminTheme.border),
      ),
      onSelected: (v) => v == 'csv' ? onCsv() : onPdf(),
      itemBuilder: (_) => [
        _item('csv', Icons.table_chart_rounded, 'Exporter en CSV', 'Excel',
            AdminTheme.green),
        _item('pdf', Icons.picture_as_pdf_rounded, 'Exporter en PDF',
            'Rapport', AdminTheme.red),
      ],
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
            const Icon(Icons.download_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text('Exporter',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(
      String value, IconData icon, String label, String tag, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.textPrimary)),
              Text(tag, style: AdminTheme.muted),
            ],
          ),
        ],
      ),
    );
  }
}
