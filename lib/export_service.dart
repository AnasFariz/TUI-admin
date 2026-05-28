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
    web.document.body!.appendChild(anchor);
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
  // PDF
  // ──────────────────────────────────────────
  static Future<void> downloadPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    required String filename,
  }) async {
    final doc = pw.Document();
    final now = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(title, subtitle, now),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'TUI Belgium · Page ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _navy),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellHeight: 24,
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: .5)),
            ),
            oddRowDecoration: const pw.BoxDecoration(color: _grey),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    _download(filename, bytes, 'application/pdf');
  }

  static pw.Widget _header(String title, String subtitle, String date) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Text('TUI',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _red)),
                pw.SizedBox(width: 8),
                pw.Text('Belgium',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy)),
              ]),
              pw.SizedBox(height: 6),
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.Text(subtitle,
                  style:
                      const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Console d\'administration',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 2),
              pw.Text('Généré le $date',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }
}
