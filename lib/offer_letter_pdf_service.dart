// lib/offer_letter_pdf_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_content_model.dart';

/// - Requires assets/fonts/Calibri-Regular.ttf and assets/fonts/Calibri-Bold.ttf (recommended)
/// - If you need broader Unicode coverage (Devanagari etc.) add a Noto font to assets and pubspec.
/// - Place your template image under assets/offer_letter/offer_template.png (or assets/offer_template.png)
/// - Optional signature at assets/Sign_BG.png or assets/signature/Sign_BG.png
class OfferLetterPdfService {
  // Cached loaded fonts
  pw.Font? _baseFont;
  pw.Font? _boldFont;

  // Attempt to load fonts (Calibri by default). On failure fall back to the package default font.
  Future<void> _ensureFontsLoaded() async {
    if (_baseFont != null && _boldFont != null) return;

    try {
      // Try Calibri first (as declared in your pubspec)
      final ttfRegularData = await rootBundle.load('assets/fonts/Calibri-Regular.ttf');
      final ttfBoldData = await rootBundle.load('assets/fonts/Calibri-Bold.ttf');

      _baseFont = pw.Font.ttf(ttfRegularData);
      _boldFont = pw.Font.ttf(ttfBoldData);
      return;
    } catch (_) {
      // Try alternative font paths if you placed fonts differently
    }

    try {
      final ttfRegularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final ttfBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

      _baseFont = pw.Font.ttf(ttfRegularData);
      _boldFont = pw.Font.ttf(ttfBoldData);
      return;
    } catch (_) {
      // ignore
    }

    // Last resort fallback to the builtin (may have limited unicode coverage)
    _baseFont = pw.Font.helvetica();
    _boldFont = _baseFont!;
  }

  String _formatDateTime(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$month/$year';
  }

  String _formatDateString(String input) {
    if (input.isEmpty) return input;
    // Try ISO first (e.g. "2025-11-26")
    try {
      final parsed = DateTime.parse(input);
      return _formatDateTime(parsed);
    } catch (_) {
      // Try formats like "26-NOV-2025" or "26-Nov-2025"
      try {
        final parsed2 = DateFormat('dd-MMM-yyyy').parse(input);
        return _formatDateTime(parsed2);
      } catch (_) {
        // Fallback for "dd/MM/yyyy" format
      }
      try {
        final parsed2 = DateFormat('dd/MM/yyyy').parse(input);
        return _formatDateTime(parsed2);
      } catch (_) {
        // If parsing fails, return the original string unchanged
        return input;
      }
    }
  }

  static String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  /// Export a simple table (report) of many offer letters. Ensures fonts are loaded.
  Future<Uint8List> exportOfferLetterList(
    List<Map<String, dynamic>> letters,
  ) async {
    await _ensureFontsLoaded();
    final pdf = pw.Document();

    final baseFont = _baseFont ?? pw.Font.helvetica();
    final boldFont = _boldFont ?? baseFont;

    // Prepare data rows safely
    final rows = letters.map((l) {
      final createdAt = l['createdAt']?.toString() ?? '';
      String dateText = 'N/A';
      if (createdAt.isNotEmpty) {
        try {
          dateText = createdAt.substring(0, 10);
        } catch (_) {
          dateText = createdAt;
        }
      }
      return [
        l['employeeId']?.toString() ?? 'N/A',
        l['fullName']?.toString() ?? 'N/A',
        l['position']?.toString() ?? 'N/A',
        l['stipend']?.toString() ?? 'N/A',
        dateText,
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Offer Letter Report', style: pw.TextStyle(font: boldFont, fontSize: 20)),
                  pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: pw.TextStyle(font: baseFont)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['ID', 'Name', 'Position', 'Stipend', 'Date'],
              data: rows,
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 11),
              cellStyle: pw.TextStyle(font: baseFont, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 12),
            pw.Text('Total records: ${rows.length}', style: pw.TextStyle(font: baseFont)),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateOfferLetter({
    required String fullName,
    required String employeeId,
    required String position,
    required String stipend, // numeric as string, e.g. "10000"
    required String ctc,
    required String doj, // yyyy-mm-dd
    required String signdate, // yyyy-mm-dd
    required String salaryFrom, // <-- new param
    required PdfContentModel content,
  }) async {
    await _ensureFontsLoaded();
    final pdf = pw.Document();

    // Prepare fonts
    final baseFont = _baseFont ?? pw.Font.helvetica();
    final boldFont = _boldFont ?? baseFont;

    // Load template image with robust fallbacks
    late pw.MemoryImage templateImage;

try {
  final data = await rootBundle.load('assets/offer_template.png');
  templateImage = pw.MemoryImage(data.buffer.asUint8List());
} catch (e) {
  throw Exception(
    'Offer template image not found at assets/offer_template.png',
  );
}

    // Optional signature image
    pw.MemoryImage? signatureImage;
    final signaturePaths = [
      'assets/Sign_BG.png',
      'assets/signature/Sign_BG.png',
      'assets/signature/sign_bg.png',
    ];
    for (final p in signaturePaths) {
      try {
        final data = await rootBundle.load(p);
        signatureImage = pw.MemoryImage(data.buffer.asUint8List());
        break;
      } catch (_) {
        // ignore
      }
    }
    if (signatureImage == null && !kIsWeb) {
      try {
        final f = File('/mnt/data/Sign_BG.png');
        if (await f.exists()) {
          final b = await f.readAsBytes();
          signatureImage = pw.MemoryImage(b);
        }
      } catch (_) {}
    }

    final double bodyFontSize = 12.0;

    pw.TextStyle bodyStyle = pw.TextStyle(
      font: baseFont,
      fontSize: bodyFontSize,
      height: 2.0,
      letterSpacing: 0.5,
    );

    pw.TextStyle boldStyle = pw.TextStyle(
      font: boldFont,
      fontSize: bodyFontSize,
      height: 1.6,
      letterSpacing: 0.5,
    );

    pw.TextStyle headingStyle = boldStyle;

    // pw.TextStyle smallStyle = pw.TextStyle(
    //   font: baseFont,
    //   fontSize: 11.0,
    //   height: 1.3,
    // );

    pw.TextStyle smallItalicStyle = pw.TextStyle(
      font: baseFont,
      fontSize: 11.0,
      height: 1.3,
      fontStyle: pw.FontStyle.italic,
    );

    final now = DateTime.now();
    final monthYear = "${_getMonthName(now.month)} ${now.year}";
    final formattedDoj = _formatDateString(doj);
    final formattedSigndate = _formatDateString(signdate);

    // stipend formatting with commas
    String stipendFormatted;
    try {
      final sanitizedStipend = stipend.replaceAll(RegExp(r'[^0-9.]'), '');
      final n = double.parse(sanitizedStipend);
      stipendFormatted = NumberFormat('#,##0').format(n);
    } catch (_) {
      stipendFormatted = stipend;
    }

    // Helper: build page with background image and content padding that matches template
    pw.Page buildTemplatePage(List<pw.Widget> bodyContent) {
      final contentPadding = const pw.EdgeInsets.fromLTRB(48, 125, 38, 20);

      final pageW = PdfPageFormat.a4.width;
      final pageH = PdfPageFormat.a4.height;

      return pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Stack(
            children: [
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.Image(
                  templateImage,
                  width: pageW,
                  height: pageH,
                  fit: pw.BoxFit.fill,
                ),
              ),
              pw.Padding(
                padding: contentPadding,
                child: pw.DefaultTextStyle(
                  style: bodyStyle,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: bodyContent,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Helper to convert a template string with placeholders into a pw.TextSpan
    pw.TextSpan buildTextSpanFromTemplate(
      String template,
      Map<String, String> values,
      pw.TextStyle normal,
      pw.TextStyle bold,
    ) {
      final tokenRegex = RegExp(r'(\{stipend\}|\{ctc\}|\{salaryFrom\}|\{fullName\})');
      final parts = template.splitMapJoin(
        tokenRegex,
        onMatch: (m) => '||${m.group(0)}||', // mark tokens
        onNonMatch: (n) => n,
      ).split('||');

      final children = <pw.TextSpan>[];
      for (final part in parts) {
        if (part == '') continue;
        if (part == '{stipend}') {
          children.add(pw.TextSpan(text: "Rs. $stipendFormatted/-", style: bold));
        } else if (part == '{ctc}') {
          children.add(pw.TextSpan(text: ctc, style: bold));
        } else if (part == '{salaryFrom}') {
          children.add(pw.TextSpan(text: values['salaryFrom'] ?? '', style: bold));
        } else if (part == '{fullName}') {
          children.add(pw.TextSpan(text: fullName, style: bold));
        } else {
          children.add(pw.TextSpan(text: part, style: normal));
        }
      }
      return pw.TextSpan(children: children, style: normal);
    }

    pw.Widget numberedPoint({
  required String number,
  required String title,
  required String body,
  required pw.TextStyle bodyStyle,
  required pw.TextStyle boldStyle,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Number column (fixed width)
      pw.SizedBox(
        width: 18,
        child: pw.Text("$number.", style: boldStyle),
      ),

      // Text column (wraps with proper indentation)
      pw.Expanded(
        child: pw.RichText(
          textAlign: pw.TextAlign.justify,
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: "$title ", style: boldStyle),
              pw.TextSpan(text: body, style: bodyStyle),
            ],
          ),
        ),
      ),
    ],
  );
}
pw.Widget hangingNumberPoint({
  required String number,
  required String text,
  required pw.TextStyle bodyStyle,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 18,
        child: pw.Text("$number.", style: bodyStyle),
      ),
      pw.Expanded(
        child: pw.Text(
          text,
          style: bodyStyle,
          textAlign: pw.TextAlign.justify,
        ),
      ),
    ],
  );
}

    // ---------------- PAGE 1 ----------------
    final page1 = <pw.Widget>[
      // Top row: left -> Full name + Employee ID ; right -> month/year
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text("Full Name     :", style: boldStyle),
                    pw.SizedBox(width: 6),
                    pw.Text(fullName, style: boldStyle),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Text("Employee ID :", style: boldStyle),
                    pw.SizedBox(width: 6),
                    pw.Text(employeeId, style: boldStyle),
                  ],
                ),
              ],
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Container(
              alignment: pw.Alignment.topRight,
              child: pw.Text(monthYear, style: boldStyle), // <-- month in bold
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 14),

      pw.Text(
        content.dearName.replaceAll('{fullName}', fullName),
        style: boldStyle,
      ),
      pw.SizedBox(height: 6),

      pw.Paragraph(
        text: content.intro,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),

      pw.SizedBox(height: 12),
      pw.Text("Position", style: headingStyle),
      pw.SizedBox(height: 6),

      pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          style: bodyStyle,
          children: [
            pw.TextSpan(text: content.positionBody.split('{position}')[0]),
            pw.TextSpan(text: position, style: boldStyle),
            pw.TextSpan(
              text: content.positionBody
                  .split('{position}')[1]
                  .split('{doj}')[0],
            ),
            pw.TextSpan(text: formattedDoj, style: boldStyle),
            pw.TextSpan(text: content.positionBody.split('{doj}')[1]),
          ],
        ),
      ),

      pw.SizedBox(height: 12),
      pw.Text("Compensation", style: headingStyle),
      pw.SizedBox(height: 6),

      // Build compensation paragraph from template using placeholder replacement
      pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: buildTextSpanFromTemplate(
          content.compensationBody,
          {'salaryFrom': salaryFrom},
          bodyStyle,
          boldStyle,
        ),
      ),

      pw.SizedBox(height: 12),
      pw.Text("Confidentiality and Non Disclosure", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.confidentialityBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),

      pw.Spacer(),
    ];

    pdf.addPage(buildTemplatePage(page1));

    // ---------------- PAGE 2 ----------------
    final page2 = <pw.Widget>[
      pw.Text("Working Hours", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.workingHoursBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 12),

      pw.Text("Leave Eligibility", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.leaveEligibilityBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),

      pw.SizedBox(height: 6),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            numberedPoint(
        number: "1",
        title: "Leave Accrual:",
        body: content.leaveAccrual.substring(17),
        bodyStyle: bodyStyle,
        boldStyle: boldStyle,
      ),
      pw.SizedBox(height: 6),

      numberedPoint(
        number: "2",
        title: "Public Holidays:",
        body: content.publicHolidays.substring(18),
        bodyStyle: bodyStyle,
        boldStyle: boldStyle,
      ),
      pw.SizedBox(height: 6),

      numberedPoint(
        number: "3",
        title: "Special Leave:",
        body: content.specialLeave.substring(16),
        bodyStyle: bodyStyle,
        boldStyle: boldStyle,
      ),
      pw.SizedBox(height: 6),

      numberedPoint(
        number: "4",
        title: "Add Ons For Men:",
        body: content.addOnsForMen.substring(18),
        bodyStyle: bodyStyle,
        boldStyle: boldStyle,
      ),
      pw.SizedBox(height: 6),

      numberedPoint(
        number: "5",
        title: "Add Ons For Women:",
        body: content.addOnsForWomen.substring(20),
        bodyStyle: bodyStyle,
        boldStyle: boldStyle,
      ),
      pw.SizedBox(height: 6),

      numberedPoint(
        number: "6",
        title: "Leave Requests:",
        body: content.leaveRequests.substring(17),
        bodyStyle: bodyStyle,
        boldStyle: boldStyle,
      ),
          ],
        ),
      ),

      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.leaveResponsibly,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 6),
      pw.Text(content.leaveNote, style: boldStyle),

      pw.SizedBox(height: 12),
      pw.Text("Notice Period", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.noticePeriodBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),

      pw.Spacer(),
    ];

    pdf.addPage(buildTemplatePage(page2));

    // ---------------- PAGE 3 ----------------
    final page3 = <pw.Widget>[
      pw.Text("Professional Conduct", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.professionalConductBody1,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.professionalConductBody2,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),

      pw.SizedBox(height: 12),
      pw.Text("Termination and Recovery", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            hangingNumberPoint(
        number: "1",
        text: content.terminationPoint1,
        bodyStyle: bodyStyle,
      ),
      pw.SizedBox(height: 6),

      hangingNumberPoint(
        number: "2",
        text: content.terminationPoint2,
        bodyStyle: bodyStyle,
      ),
      pw.SizedBox(height: 6),

      hangingNumberPoint(
        number: "3",
        text: content.terminationPoint3,
        bodyStyle: bodyStyle,
      ),
      pw.SizedBox(height: 6),

      hangingNumberPoint(
        number: "4",
        text: content.terminationPoint4,
        bodyStyle: bodyStyle,
      ),
      pw.SizedBox(height: 6),

      hangingNumberPoint(
        number: "5",
        text: content.terminationPoint5,
        bodyStyle: bodyStyle,
      ),
      pw.SizedBox(height: 6),

      hangingNumberPoint(
        number: "6",
        text: content.terminationPoint6,
        bodyStyle: bodyStyle,
      ),
      pw.SizedBox(height: 6),

      hangingNumberPoint(
        number: "7",
        text: content.terminationPoint7,
        bodyStyle: bodyStyle,
      ),
          ],
        ),
      ),

      pw.Spacer(),
    ];

    pdf.addPage(buildTemplatePage(page3));

    // ---------------- PAGE 4 ----------------
    final page4 = <pw.Widget>[
      // Pre Employment Screening
      pw.Text("Pre Employment Screening", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.preEmploymentScreeningBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),

      pw.SizedBox(height: 12),
      pw.Text("Dispute", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.disputeBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 6),

      pw.Text("Declaration", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.declarationBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 0),
      pw.Paragraph(
        text:
            "Please sign below as a confirmation of your acceptance and return it to the undersigned by $formattedSigndate.",
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),

      // Use a fixed sized gap so signature doesn't sit flush on the footer
      pw.SizedBox(height: 100), // <-- tune this value to adjust final spacing

      // signature / acceptance row — aligned to the bottom of this section (but above the footer)
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Left block (HR)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text("For ZeAI Soft,", style: boldStyle),
              pw.SizedBox(height: 6),

              pw.Container(
                height: 90,
                width: 280,
                child: pw.Stack(
                  children: [
                    if (signatureImage != null)
                      pw.Positioned(
                        left: 0,
                        top: 0,
                        child: pw.Image(
                          signatureImage,
                          width: 280,
                          height: 90,
                          fit: pw.BoxFit.contain,
                        ),
                      )
                    else
                      pw.Positioned(
                        left: 0,
                        top: 0,
                        child: pw.SizedBox(height: 90, width: 280),
                      ),

                    pw.Positioned(
                      left: 0,
                      top: 68,
                      child: pw.Text("__________________", style: boldStyle),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 2),
              pw.Text("Hari Baskaran", style: boldStyle),
              pw.Text(
                "Co-Founder & Chief Technology Officer",
                style: smallItalicStyle,
              ),
            ],
          ),

          // Candidate block
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text("To ZeAI Soft,", style: boldStyle),
              pw.SizedBox(height: 70),
              pw.Text("___________________", style: boldStyle),
              pw.SizedBox(height: 14),
              pw.Text(
                fullName,
                style: boldStyle,
                textAlign: pw.TextAlign.right,
              ),
              pw.Text(
                position,
                style: smallItalicStyle,
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
        ],
      ),

      pw.SizedBox(height: 11),
    ];

    pdf.addPage(buildTemplatePage(page4));

    return pdf.save();
  }
}
