import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as path;

class PDFGenerator {
  static Future<Directory> _getPdfDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${appDir.path}/pdfs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  static Future<List<File>> getAllPDFs() async {
    final pdfDir = await _getPdfDirectory();
    final List<File> pdfs = [];

    if (await pdfDir.exists()) {
      await for (final entity in pdfDir.list()) {
        if (entity is File && entity.path.endsWith('.pdf')) {
          pdfs.add(entity);
        }
      }
    }

    return pdfs;
  }

  static Future<File> generatePdf(String text, {String? title}) async {
    // Create a new PDF document
    final PdfDocument document = PdfDocument();

    // Add a new page
    final PdfPage page = document.pages.add();

    // Create a PDF text format for the title
    final PdfFont titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold);
    final PdfFont contentFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    // Create text elements
    final PdfLayoutResult titleLayout = PdfTextElement(
      text: title ?? 'Transcription',
      font: titleFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
    ).draw(
      page: page,
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 50),
    )!;

    // Add the main content
    PdfTextElement(
      text: text,
      font: contentFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
    ).draw(
      page: page,
      bounds: Rect.fromLTWH(
        0,
        titleLayout.bounds.bottom + 20,
        page.getClientSize().width,
        page.getClientSize().height,
      ),
    );

    // Generate a unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedTitle = (title ?? 'Transcription')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final filename = '${sanitizedTitle}_$timestamp.pdf';

    // Save the PDF
    final pdfDir = await _getPdfDirectory();
    final file = File('${pdfDir.path}/$filename');
    await file.writeAsBytes(await document.save());

    // Dispose the document
    document.dispose();

    return file;
  }

  static Future<void> deletePDF(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
