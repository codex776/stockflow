import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'format.dart';

// ====================================================================
// CSV / PDF export helpers (ports of ui.js report toolbar — CSV + print).
// ====================================================================

Future<void> shareCsv(
  String filename,
  List<List<dynamic>> rows,
) async {
  final sb = StringBuffer();
  for (final r in rows) {
    sb.write(csvRow(r));
    sb.write('\r\n');
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString('\uFEFF$sb'); // BOM so Excel shows UTF-8
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    text: filename,
  );
}

Future<void> sharePdf(
  String title,
  List<String> headers,
  List<List<String>> data, {
  String? note,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('StockFlow', style: const pw.TextStyle(color: PdfColors.grey)),
        ],
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
      ),
      build: (ctx) => [
        if (note != null && note.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(note,
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
          ),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A5F)),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight,
          },
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
        ),
      ],
    ),
  );
  final bytes = await doc.save();
  await Printing.sharePdf(
      bytes: bytes, filename: '${title.toLowerCase().replaceAll(' ', '-')}.pdf');
}