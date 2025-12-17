// lib/offer_letter_pdf_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_content_model.dart';

/// - Requires assets/fonts/Calibri-Regular.ttf and assets/fonts/Calibri-Bold.ttf
/// - Requires assets/offer_letter/offer_template.png
/// - Optional signature at assets/signature/Sign_BG.png
class OfferLetterPdfService {
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

  // String _getAcceptanceDateFormatted(DateTime now) {
  //   final acceptanceDate = now.add(const Duration(days: 7));
  //   return _formatDateTime(acceptanceDate);
  // }

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

  Future<Uint8List> exportOfferLetterList(
    List<Map<String, dynamic>> letters,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Offer Letter Report", style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 20),

            pw.Table.fromTextArray(
              headers: ["ID", "Name", "Position", "Stipend", "Date"],
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

  Future<Uint8List> generateOfferLetter({
    required String fullName,
    required String employeeId,
    required String position,
    required String stipend, // numeric as string, e.g. "10000"
    required String ctc,
    required String doj, // yyyy-mm-dd
    required String signdate, // yyyy-mm-dd
    required PdfContentModel content,
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

    // --- STYLES: Calibri (MS) at 12pt as requested ---
    // Body and inline bold both use 12pt. Headings use bold 12pt as well (to match the request exactly).
    // final double bodyFontSize = 13.0;
    // pw.TextStyle bodyStyle = pw.TextStyle(font: baseFont, fontSize: bodyFontSize, height: 2.5, letterSpacing: 0.5);
    // pw.TextStyle boldStyle = pw.TextStyle(font: boldFont, fontSize: bodyFontSize, height: 2.5, letterSpacing: 0.5);
    // pw.TextStyle headingStyle = boldStyle;
    // pw.TextStyle smallStyle = pw.TextStyle(font: baseFont, fontSize: 13.0, height: 1.0);
    final double bodyFontSize = 13.0;

    // body line spacing — set here (1.4 = comfortable, 1.6 = airy, 2.0 = very loose)
    pw.TextStyle bodyStyle = pw.TextStyle(
      font: baseFont,
      fontSize: bodyFontSize,
      height: 2.0, // <-- increase this to increase space between lines
      letterSpacing: 0.5, // usually 0.0 for normal tracking
    );

    pw.TextStyle boldStyle = pw.TextStyle(
      font: boldFont,
      fontSize: bodyFontSize,
      height: 1.6, // keep same leading for bold for consistency
      letterSpacing: 0.5,
    );

    pw.TextStyle headingStyle = boldStyle;

    // small captions slightly tighter
    pw.TextStyle smallStyle = pw.TextStyle(
      font: baseFont,
      fontSize: 11.0,
      height: 1.3,
    );

    // NEW 👉 Italic style for positions under signature
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
      // Sanitize the stipend string before parsing to handle inputs like "10,000" or "INR 10000"
      final sanitizedStipend = stipend.replaceAll(RegExp(r'[^0-9.]'), '');
      final n = double.parse(sanitizedStipend);
      stipendFormatted = NumberFormat('#,##0').format(n);
    } catch (_) {
      stipendFormatted = stipend;
    }

    // Helper: build page with background image and content padding that matches template
    pw.Page buildTemplatePage(List<pw.Widget> bodyContent) {
      // Adjust top padding if you need to nudge content up/down relative to the PNG header
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
      pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          style: bodyStyle,
          children: [
            pw.TextSpan(text: content.compensationBody.split('{stipend}')[0]),
            pw.TextSpan(text: "Rs. $stipendFormatted/-", style: boldStyle),
            pw.TextSpan(
              text: content.compensationBody
                  .split('{stipend}')[1]
                  .split('{ctc}')[0],
            ),
            pw.TextSpan(text: ctc, style: boldStyle),
            pw.TextSpan(text: content.compensationBody.split('{ctc}')[1]),
          ],
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
            // 1
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

            // 2
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

            // 3
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

            // 4
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

            // 5
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

            // 6
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
            pw.Text(content.terminationPoint1, style: bodyStyle),
            pw.SizedBox(height: 4),
            pw.Text(content.terminationPoint2, style: bodyStyle),
            pw.SizedBox(height: 4),
            pw.Text(content.terminationPoint3, style: bodyStyle),
            pw.SizedBox(height: 4),
            pw.Text(content.terminationPoint4, style: bodyStyle),
          ],
        ),
      ),

      pw.SizedBox(height: 12),
      pw.Text("Pre Employment Screening", style: headingStyle),
      pw.SizedBox(height: 6),
      pw.Paragraph(
        text: content.preEmploymentScreeningBody,
        style: bodyStyle,
        textAlign: pw.TextAlign.justify,
      ),

      pw.Spacer(),
    ];

    pdf.addPage(buildTemplatePage(page3));

    // ---------------- PAGE 4 ----------------
    final page4 = <pw.Widget>[
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

      // push the signature row down towards the footer image
      pw.Spacer(),
      // signature / acceptance row — aligned to the bottom
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Left block (HR) - left aligned
          // LEFT BLOCK (HR) — keep signature size, move underline up with a Stack
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text("For ZeAI Soft,", style: boldStyle),
                pw.SizedBox(height: 6),

                // Container holds the signature and the underline (stacked)
                pw.Container(
                  height: 100, // signatureHeight (90) + a bit of room
                  width: 280,  // signatureWidth
                  child: pw.Stack(
                    children: [
                      // signature at top-left (keeps original visual size)
                      if (signatureImage != null)
                        pw.Positioned(
                          left: 0,
                          top: 0,
                          child: pw.Image(
                            signatureImage,
                            width: 280, // same as Container width (or slightly less)
                            height: 90, // signatureHeight — preserve the size you want
                            fit: pw.BoxFit.contain,
                          ),
                        )
                      else
                        pw.Positioned(
                          left: 0,
                          top: 0,
                          child: pw.SizedBox(height: 90, width: 280),
                        ),

                      // underline positioned to overlap the bottom of the signature
                      // (signatureHeight - overlapGap) -> 90 - 22 = 68
                      pw.Positioned(
                        left: 0,
                        top: 68, // adjust this number to tune gap (smaller => tighter)
                        child: pw.Text("__________________", style: boldStyle),
                      ),
                    ],
                  ),
                ),

                // small gap to name (reduce if you want name to move up)
                pw.SizedBox(height: 2),
                pw.Text("Hari Baskaran", style: boldStyle),
                pw.Text(
                  "Co-Founder & Chief Technology Officer",
                  style: smallItalicStyle,
                ),
              ],
            ),

          // --------------------------------------------------------


          // Right block (Candidate) - RIGHT aligned
          pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.end, // <-- align children to right
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text("To ZeAI Soft,", style: boldStyle),
              pw.SizedBox(height: 68),
              pw.Text("___________________", style: boldStyle),
              pw.SizedBox(height: 6),
              pw.Text(
                fullName,
                style: boldStyle,
                textAlign: pw.TextAlign.right,
              ),
              // candidate position in italic and right-aligned
              pw.Text(
                position,
                style: smallItalicStyle,
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
        ],
      ),

      // small gap between signature row and bottom of content area (optional)
      pw.SizedBox(height: 11),

      pw.Spacer(),
    ];

    pdf.addPage(buildTemplatePage(page4));

    return pdf.save();
  }
}