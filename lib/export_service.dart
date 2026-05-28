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
  // PDF (rapport professionnel — thème par défaut, sans Font explicite)
  // ──────────────────────────────────────────
  static Future<void> downloadPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    required String filename,
    List<List<String>> summary = const [], // chaque entrée : [label, valeur]
    String? intro, // paragraphe d'introduction
    List<List<String>> sections = const [], // [titre, corps] blocs de texte
    String tableTitle = 'Detail',
    bool landscape = false,
  }) async {
    final doc = pw.Document();
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final ref = 'TUI-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';

    doc.addPage(
      pw.MultiPage(
        pageFormat:
            landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 40),
        build: (ctx) => [
          _brandHeader(now, ref),
          pw.SizedBox(height: 18),
          _titleBlock(title, subtitle),
          if (intro != null) ...[
            pw.SizedBox(height: 14),
            _paragraph(intro),
          ],
          if (summary.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _summaryCards(summary),
          ],
          pw.SizedBox(height: 22),
          _sectionTitle(tableTitle),
          pw.SizedBox(height: 8),
          _table(headers, rows),
          for (final s in sections) ...[
            pw.SizedBox(height: 20),
            _sectionTitle(s[0]),
            pw.SizedBox(height: 6),
            _paragraph(s[1]),
          ],
          pw.SizedBox(height: 26),
          pw.Divider(color: PdfColors.grey300, thickness: .5),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TUI Belgium - Document confidentiel',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Genere automatiquement par la console d\'administration',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    _download(filename, bytes, 'application/pdf');
  }

  static pw.Widget _sectionTitle(String t) {
    return pw.Row(children: [
      pw.Container(width: 4, height: 14, color: _red),
      pw.SizedBox(width: 8),
      pw.Text(t,
          style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold, color: _navy)),
    ]);
  }

  static pw.Widget _paragraph(String text) {
    return pw.Text(text,
        textAlign: pw.TextAlign.justify,
        style: const pw.TextStyle(
            fontSize: 9.5, color: PdfColors.grey800, lineSpacing: 2.5));
  }

  static pw.Widget _brandHeader(String date, String ref) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: 'TUI ',
                  style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: _red)),
              pw.TextSpan(
                  text: 'Belgium',
                  style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('CONSOLE D\'ADMINISTRATION',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey500)),
            pw.SizedBox(height: 3),
            pw.Text('Genere le $date',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text('Ref. $ref',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ]),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Row(children: [
        pw.Expanded(flex: 1, child: pw.Container(height: 3, color: _red)),
        pw.Expanded(flex: 6, child: pw.Container(height: 3, color: _navy)),
      ]),
    ]);
  }

  static pw.Widget _titleBlock(String title, String subtitle) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy)),
          pw.SizedBox(height: 3),
          pw.Text(subtitle,
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        ]);
  }

  static pw.Widget _summaryCards(List<List<String>> summary) {
    return pw.Row(
      children: [
        for (var i = 0; i < summary.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: pw.BoxDecoration(
                color: _grey,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300, width: .5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(summary[i][0].toUpperCase(),
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  pw.SizedBox(height: 5),
                  pw.Text(summary[i][1],
                      style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: _navy)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _table(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellHeight: 24,
      cellAlignment: pw.Alignment.centerLeft,
      oddRowDecoration: const pw.BoxDecoration(color: _grey),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}
