import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Service d'export CSV / PDF pour le dashboard admin TUI.
class ExportService {
  static const _navy = PdfColor.fromInt(0xFF0F1F4D);
  static const _red = PdfColor.fromInt(0xFFE2001A);
  static const _grey = PdfColor.fromInt(0xFFF4F6FB);

  /// Téléchargement robuste via Blob + ancre ajoutée au DOM.
  static void _download(String filename, Uint8List bytes, String mime) {
    final blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mime),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    final parent = web.document.body ?? web.document.documentElement;
    parent?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  // ──────────────────────────────────────────
  // CSV
  // ──────────────────────────────────────────
  static void downloadCsv(
      String filename, List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escape).join(','));
    for (final r in rows) {
      buffer.writeln(r.map(_escape).join(','));
    }
    // BOM UTF-8 pour Excel
    final content = '﻿${buffer.toString()}';
    _download(filename, Uint8List.fromList(utf8.encode(content)),
        'text/csv;charset=utf-8');
  }

  static String _escape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  // ──────────────────────────────────────────
  // PDF (rapport professionnel)
  // ──────────────────────────────────────────
  static Future<void> downloadPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    required String filename,
    List<List<String>> summary = const [], // chaque entrée : [label, valeur]
  }) async {
    // Polices intégrées (Helvetica WinAnsi) — aucune dépendance réseau.
    final pw.Font bold = pw.Font.helveticaBold();
    final pw.Font semi = pw.Font.helveticaBold();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );
    final now = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
    final ref =
        'TUI-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 40),
        header: (ctx) =>
            ctx.pageNumber == 1 ? _brandHeader(now, ref, semi) : pw.SizedBox(),
        footer: (ctx) => _footer(ctx, semi),
        build: (ctx) => [
          if (ctx.pageNumber == 1) ...[
            pw.SizedBox(height: 18),
            _titleBlock(title, subtitle, bold),
            if (summary.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              _summaryCards(summary, bold, semi),
            ],
            pw.SizedBox(height: 20),
          ],
          _table(headers, rows, bold, semi),
        ],
      ),
    );

    final bytes = await doc.save();
    _download(filename, bytes, 'application/pdf');
  }

  // En-tête de marque
  static pw.Widget _brandHeader(String date, String ref, pw.Font semi) {
    return pw.Column(children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('TUI',
                style: pw.TextStyle(
                    fontSize: 26, fontWeight: pw.FontWeight.bold, color: _red)),
            pw.SizedBox(width: 6),
            pw.Text('Belgium',
                style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('CONSOLE D\'ADMINISTRATION',
                style: pw.TextStyle(
                    font: semi,
                    fontSize: 8,
                    color: PdfColors.grey500,
                    letterSpacing: 1.2)),
            pw.SizedBox(height: 3),
            pw.Text('Généré le $date',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text('Réf. $ref',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ]),
        ],
      ),
      pw.SizedBox(height: 12),
      // Filet bicolore (rouge + navy)
      pw.Row(children: [
        pw.Expanded(flex: 1, child: pw.Container(height: 3, color: _red)),
        pw.Expanded(flex: 6, child: pw.Container(height: 3, color: _navy)),
      ]),
    ]);
  }

  static pw.Widget _titleBlock(String title, String subtitle, pw.Font bold) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title,
          style: pw.TextStyle(
              font: bold, fontSize: 20, color: _navy, letterSpacing: -0.3)),
      pw.SizedBox(height: 3),
      pw.Text(subtitle,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
    ]);
  }

  // Cartes de synthèse (KPI)
  static pw.Widget _summaryCards(
      List<List<String>> summary, pw.Font bold, pw.Font semi) {
    return pw.Row(
      children: [
        for (var i = 0; i < summary.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: pw.BoxDecoration(
                color: _grey,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.grey300, width: .5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(summary[i][0].toUpperCase(),
                      style: pw.TextStyle(
                          font: semi,
                          fontSize: 7.5,
                          color: PdfColors.grey600,
                          letterSpacing: 0.8)),
                  pw.SizedBox(height: 5),
                  pw.Text(summary[i][1],
                      style: pw.TextStyle(
                          font: bold, fontSize: 17, color: _navy)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _table(List<String> headers, List<List<String>> rows,
      pw.Font bold, pw.Font semi) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          font: semi, color: PdfColors.white, fontSize: 9, letterSpacing: 0.3),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      headerHeight: 30,
      cellStyle: const pw.TextStyle(fontSize: 9.5, color: PdfColor.fromInt(0xFF1A1F36)),
      cellHeight: 26,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      oddRowDecoration: const pw.BoxDecoration(color: _grey),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: .4)),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  static pw.Widget _footer(pw.Context ctx, pw.Font semi) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300, width: .5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('TUI Belgium — Document confidentiel',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: semi, fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }
}
