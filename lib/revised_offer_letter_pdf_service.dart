//revised_offer_letter_pdf_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'revised_pdf_content_model.dart';

/// - Requires assets/fonts/Calibri-Regular.ttf and assets/fonts/Calibri-Bold.ttf
/// - Requires assets/offer_letter/offer_template.png
/// - Optional signature at assets/signature/Sign_BG.png
class RevisedOfferLetterPdfService {
  String _formatDateTime(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$month/$year';
  }

  String _formatDateString(String input) {
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

  /// Parse input and return Month Year (e.g. "February 2026").
  /// If parsing fails, return the original input unchanged.
  String _formatToMonthYear(String input) {
    // Try ISO first (e.g. "2026-02-01" or "2026-02-01T00:00:00Z")
    try {
      final parsed = DateTime.parse(input);
      return "${_getMonthName(parsed.month)} ${parsed.year}";
    } catch (_) {
      // Try 'dd-MMM-yyyy' or 'dd/MM/yyyy'
      try {
        final parsed2 = DateFormat('dd-MMM-yyyy').parse(input);
        return "${_getMonthName(parsed2.month)} ${parsed2.year}";
      } catch (_) {}
      try {
        final parsed3 = DateFormat('dd/MM/yyyy').parse(input);
        return "${_getMonthName(parsed3.month)} ${parsed3.year}";
      } catch (_) {}
      // If the input is already like "February 2026" or can't be parsed, return it
      return input;
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
    return months[month - 1];
  }

  Future<Uint8List> exportRevisedOfferLetterList(
    List<Map<String, dynamic>> letters,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "Revised Offer Letter Report",
              style: pw.TextStyle(fontSize: 24),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ["ID", "Name", "Position", "Salary", "Date"],
              data: letters
                  .map(
                    (l) => [
                      l["employeeId"],
                      l["fullName"],
                      l["position"],
                      l["stipend"].toString(),
                      l["createdAt"].toString().substring(0, 10),
                    ],
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateRevisedOfferLetter({
    required String fullName,
    required String employeeId,
    required String fromposition, // New parameter
    required String position,
    required String stipend, // numeric as string, e.g. "10000"
    required String ctc,
    required String doj, // yyyy-mm-dd
    required String signdate, // yyyy-mm-dd
    required String salaryFrom, // NEW: effective salary from date (e.g. "2026-02-01" or "February 2026")
    required RevisedPdfContentModel content,
  }) async {
    final pdf = pw.Document();

    // Load template image
    late pw.MemoryImage templateImage;
    try {
      final templateData = await rootBundle.load('assets/offer_template.png');
      templateImage = pw.MemoryImage(templateData.buffer.asUint8List());
    } catch (e) {
      if (!kIsWeb) {
        final file = File('/mnt/data/Relieving Letter - ZEAI Soft (1)-1.png');
        final bytes = await file.readAsBytes();
        templateImage = pw.MemoryImage(bytes);
      } else {
        throw Exception(
          'Failed to load offer_template.png from assets (running on web, no fallback).',
        );
      }
    }

    // Load Calibri fonts from assets
    final ttfRegularData = await rootBundle.load(
      'assets/fonts/Calibri-Regular.ttf',
    );
    final ttfBoldData = await rootBundle.load('assets/fonts/Calibri-Bold.ttf');

    final baseFont = pw.Font.ttf(ttfRegularData);
    final boldFont = pw.Font.ttf(ttfBoldData);

    // Optional signature image
    pw.MemoryImage? signatureImage;
    try {
      final sigData = await rootBundle.load('assets/Sign_BG.png');
      signatureImage = pw.MemoryImage(sigData.buffer.asUint8List());
    } catch (_) {
      if (!kIsWeb) {
        try {
          final f = File('/mnt/data/Sign_BG.png');
          final b = await f.readAsBytes();
          signatureImage = pw.MemoryImage(b);
        } catch (_) {
          signatureImage = null;
        }
      }
    }

    final double bodyFontSize = 13.0;

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
    final formattedSalaryFrom = _formatToMonthYear(salaryFrom);

    String stipendFormatted;
    try {
      final sanitizedStipend = stipend.replaceAll(RegExp(r'[^0-9.]'), '');
      final n = double.parse(sanitizedStipend);
      stipendFormatted = NumberFormat('#,##0').format(n);
    } catch (_) {
      stipendFormatted = stipend;
    }

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
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: bodyContent,
                ),
              ),
            ],
          );
        },
      );
    }

    // ---------------- PAGE 1 ----------------
    final page1 = <pw.Widget>[
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
              child: pw.Text(monthYear, style: boldStyle),
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
        text: content.intro.replaceAll('{fromposition}', fromposition),
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 12),
      pw.Text(content.positionTitle, style: headingStyle),
      pw.SizedBox(height: 6),
      pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          style: bodyStyle,
          children:
              _buildTextSpans(content.positionBody, bodyStyle, boldStyle, {
            '{fromposition}': fromposition,
            '{position}': position,
            '{doj}': formattedDoj,
          }),
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Text(content.compensationTitle, style: headingStyle),
      pw.SizedBox(height: 6),

      // Use the generic placeholder builder so we can support {stipend}, {ctc}, and {salaryFrom}
      pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          style: bodyStyle,
          children: _buildTextSpans(content.compensationBody, bodyStyle,
              boldStyle, {
            '{stipend}': "Rs. $stipendFormatted/-",
            '{ctc}': ctc,
            '{salaryFrom}': formattedSalaryFrom,
          }),
        ),
      ),

      pw.SizedBox(height: 12),
      pw.Text(content.confidentialityTitle, style: headingStyle),
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
      pw.Text(content.workingHoursTitle, style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.workingHoursBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 12),
      pw.Text(content.leaveEligibilityTitle, style: headingStyle),
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
            pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: "1. Leave Accrual: ", style: boldStyle),
                  pw.TextSpan(
                    text: content.leaveAccrual.substring(17),
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: "2. Public Holidays: ", style: boldStyle),
                  pw.TextSpan(
                    text: content.publicHolidays.substring(18),
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: "3. Special Leave: ", style: boldStyle),
                  pw.TextSpan(
                    text: content.specialLeave.substring(16),
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: "4. Add Ons For Men: ", style: boldStyle),
                  pw.TextSpan(
                    text: content.addOnsForMen.substring(18),
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: "5. Add Ons For Women: ", style: boldStyle),
                  pw.TextSpan(
                    text: content.addOnsForWomen.substring(20),
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: "6. Leave Requests: ", style: boldStyle),
                  pw.TextSpan(
                    text: content.leaveRequests.substring(17),
                    style: bodyStyle,
                  ),
                ],
              ),
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
      pw.Text(content.noticePeriodTitle, style: headingStyle),
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
      pw.Text(content.professionalConductTitle, style: headingStyle),
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
      pw.Text(content.terminationAndRecoveryTitle, style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(content.terminationPoint1, style: bodyStyle),
            pw.SizedBox(height: 4),
            pw.Text(content.terminationPoint2, style: bodyStyle),
            pw.SizedBox(height: 4),
            pw.Text(content.terminationPoint3, style: bodyStyle),
            pw.SizedBox(height: 4),
            pw.Text(content.terminationPoint4, style: bodyStyle),
            pw.SizedBox(height: 4),
            pw.Text(content.terminationPoint5, style: bodyStyle),
            pw.SizedBox(height: 4),
            pw.Text(content.terminationPoint6, style: bodyStyle),
            pw.SizedBox(height: 4),
            pw.Text(content.terminationPoint7, style: bodyStyle),
          ],
        ),
      ),
    ];

    pdf.addPage(buildTemplatePage(page3));

    // ---------------- PAGE 4 ----------------
    final page4 = <pw.Widget>[
      pw.SizedBox(height: 12),
      pw.Text(content.preEmploymentScreeningTitle, style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.preEmploymentScreeningBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),

      pw.Text(content.disputeTitle, style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.disputeBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 6),
      pw.Text(content.declarationTitle, style: headingStyle),
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

      // instead of a single full Spacer, use a small top spacer
      pw.Spacer(flex: 1),

      // signature / acceptance row — aligned to the bottom
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Left block (HR) - left aligned
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text("For ZeAI Soft,", style: boldStyle),
              pw.SizedBox(height: 6),

              // Container holds the signature and the underline (stacked)
              pw.Container(
                height: 90, // slightly reduced if you want
                width: 280, // signatureWidth
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
                      top: 68, // tune this if underline overlaps signature differently
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

          // Right block (Candidate) - RIGHT aligned
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text("To ZeAI Soft,", style: boldStyle),

              // reduced gap here so the right-side underline aligns higher
              pw.SizedBox(height: 70), // was 68 — lower it to lift candidate block up
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

      pw.SizedBox(height: 1),

      // increase bottom flex so signature moves up (more empty space below)
      pw.Spacer(flex: 4),
    ];

    pdf.addPage(buildTemplatePage(page4));

    return pdf.save();
  }

  List<pw.TextSpan> _buildTextSpans(
    String template,
    pw.TextStyle defaultStyle,
    pw.TextStyle highlightStyle,
    Map<String, String> replacements,
  ) {
    final spans = <pw.TextSpan>[];
    final regExp = RegExp(replacements.keys.map(RegExp.escape).join('|'));

    int lastMatchEnd = 0;
    for (final match in regExp.allMatches(template)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          pw.TextSpan(
            text: template.substring(lastMatchEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final placeholder = match.group(0)!;
      spans.add(
        pw.TextSpan(text: replacements[placeholder], style: highlightStyle),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < template.length) {
      spans.add(pw.TextSpan(text: template.substring(lastMatchEnd), style: defaultStyle));
    }

    return spans;
  }
}