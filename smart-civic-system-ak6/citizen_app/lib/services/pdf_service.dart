import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class PdfService {
  /// Generates a professional complaint confirmation report PDF.
  static Future<File> generateComplaintReport(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    // Fetch network image if available
    // Fetch image: Try local path first (faster/reliable), then network
    pw.MemoryImage? netImage;
    final localPath = data['localImagePath'];
    final networkUrl = data['imageUrl'];

    if (localPath != null && File(localPath).existsSync()) {
      try {
        final bytes = File(localPath).readAsBytesSync();
        netImage = pw.MemoryImage(bytes);
      } catch (e) {
        print("PDF Service: Could not read local image. $e");
      }
    }

    if (netImage == null && networkUrl != null && networkUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(networkUrl));
        if (response.statusCode == 200) {
          netImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print("PDF Service: Could not fetch network image. $e");
      }
    }

    // Fetch BMC Logo
    pw.MemoryImage? logoImage;
    try {
      final logoResp = await http.get(Uri.parse('https://portal.mcgm.gov.in/com.mcgm.newframework/images/logo_V1.png'));
      if (logoResp.statusCode == 200) {
        logoImage = pw.MemoryImage(logoResp.bodyBytes);
      }
    } catch (e) {
      print("PDF Service: Could not fetch BMC logo. $e");
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final now = DateTime.now();

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ───── HEADER ─────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange800,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            height: 30,
                            width: 30,
                            margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.Image(logoImage),
                          ),
                        pw.Text("BMC SMART CIVIC SYSTEM",
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Date: ${now.day}/${now.month}/${now.year}",
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                        pw.Text("Region: asia-south1",
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                      ],
                    )
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ───── TRACKING ID BOX ─────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.orange400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("TRACKING ID",
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text(data['trackId'] ?? 'PENDING',
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        (data['status'] ?? 'registered').toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ───── PHOTO EVIDENCE (MOVED BELOW & BIGGER) ──
              if (netImage != null)
                pw.Center(
                  child: pw.Container(
                    height: 160,
                    width: 200,
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Image(netImage, fit: pw.BoxFit.cover),
                  ),
                ),

              pw.SizedBox(height: 12),

              // ───── TABLE STYLE DETAILS ────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    _tableRow("Name", data['userName'] ?? '—'),
                    _tableRow("Email", data['userEmail'] ?? '—'),
                    _tableRow("Ward No", data['wardNo']?.toString() ?? '—'),
                    _tableRow("Category", data['category'] ?? '—'),
                    _tableRow("Title", data['title'] ?? '—'),
                    _tableRow("Latitude", data['latitude']?.toString() ?? '—'),
                    _tableRow("Longitude", data['longitude']?.toString() ?? '—'),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ───── DESCRIPTION ───────────────────────
              pw.Text("DESCRIPTION",
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Text(data['description'] ?? 'No description provided.',
                    style: pw.TextStyle(fontSize: 10)),
              ),

              pw.SizedBox(height: 10),

              // ───── RESOLUTION ───────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200),
                ),
                child: pw.Text(
                  "Complaint registered successfully. Expected resolution within 3 working days.",
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.green800,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),

              pw.Spacer(),

              // ───── FOOTER ───────────────────────────
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  "Computer-generated document • BMC Smart Civic System",
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/complaint_${data['trackId']}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _tableRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(value,
                style: pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8, top: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          ),
          pw.Container(height: 1, width: 40, color: PdfColors.orange300),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
            ),
          ],
        ),
      ),
    );
  }
}
