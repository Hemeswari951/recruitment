// lib/experience_certificate_pdf_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExperienceCertificatePdfService {
  Future<Uint8List> generateExperienceCertificate({
    required String companyName,
    required String fullName,
    required String position,
    required String startDate,
    required String endDate,
    String? issuedAt,
  }) async {
    final doc = pw.Document();

    // Load template (full-page artwork)
    final templateData = await rootBundle.load('assets/offer_template.png');
    final templateImage = pw.MemoryImage(templateData.buffer.asUint8List());

    // Load signature image (optional)
    pw.MemoryImage? signatureImage;
    try {
      final sig = await rootBundle.load('assets/Sign_BG.png');
      signatureImage = pw.MemoryImage(sig.buffer.asUint8List());
    } catch (_) {
      signatureImage = null;
    }

    // Load fonts
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      final fReg = await rootBundle.load('assets/fonts/Calibri-Regular.ttf');
      final fBold = await rootBundle.load('assets/fonts/Calibri-Bold.ttf');
      fontRegular = pw.Font.ttf(fReg);
      fontBold = pw.Font.ttf(fBold);
    } catch (e) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    // A4 page setup
    final pageFormat = PdfPageFormat.a4;
    
    // Formatting helpers
    final issuedDate = issuedAt ?? _formatDate(DateTime.now());
    final titleStyle = pw.TextStyle(font: fontBold, fontSize: 18);
    final paraStyle = pw.TextStyle(font: fontRegular, fontSize: 14, lineSpacing: 2.5);
    final boldPara = pw.TextStyle(font: fontBold, fontSize: 14, lineSpacing: 2.5);

    // <-- Added: define boldStyle so it's available where you used it further down
    final boldStyle = pw.TextStyle(font: fontBold, fontSize: 14);

    // Margins inside the white content area
    const leftPad = 50.0;
    const topPad = 130.0; 
    const rightPad = 50.0;
    
    // INCREASED bottomPad to 210.0. 
    // This stops the Spacer() from pushing the signature too low, 
    // effectively moving the signature "above" the footer graphics.
    const bottomPad = 210.0;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Background Image (Template includes address footer now)
              pw.Positioned.fill(
                child: pw.Image(templateImage, fit: pw.BoxFit.fill),
              ),

              // 2. Main Content Overlay
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(leftPad, topPad, rightPad, bottomPad),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Date (Aligned Right)
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Date: $issuedDate',
                        style: pw.TextStyle(font: fontRegular, fontSize: 14),
                      ),
                    ),

                    pw.SizedBox(height: 22),

                    // Title
                    pw.Center(
                      child: pw.Text('EXPERIENCE CERTIFICATE', style: titleStyle),
                    ),

                    pw.SizedBox(height: 22),

                    // Paragraph 1
                    pw.RichText(
                      textAlign: pw.TextAlign.justify,
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(text: 'This is to certify that ', style: paraStyle),
                          pw.TextSpan(text: fullName.trim(), style: boldPara),
                          pw.TextSpan(text: ', was employed with ', style: paraStyle),
                          pw.TextSpan(text: companyName.trim(), style: boldPara),
                          pw.TextSpan(text: ' as a ', style: paraStyle),
                          pw.TextSpan(text: position.trim(), style: boldPara),
                          pw.TextSpan(text: ' from ', style: paraStyle),
                          pw.TextSpan(text: startDate.trim(), style: boldPara),
                          pw.TextSpan(text: ' to ', style: paraStyle),
                          pw.TextSpan(text: endDate.trim(), style: boldPara),
                          pw.TextSpan(text: '.', style: paraStyle),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 14),

                    // Paragraph 2
                    pw.RichText(
                      textAlign: pw.TextAlign.justify,
                      text: pw.TextSpan(
                        children: [
                        
                          pw.TextSpan(text: 'During their tenure, ', style: paraStyle),
                            pw.TextSpan(text:fullName.trim(),style:boldPara),
                        //  pw.TextSpan(text: _firstName(fullName), style: boldPara),
                          pw.TextSpan(
                            text:
                                ' performed their duties with sincerity, dedication, and professionalism. They contributed positively towards the company\'s goals and maintained good conduct throughout their employment.',
                            style: paraStyle,
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 14),

                    // Paragraph 3
                    pw.RichText(
                      textAlign: pw.TextAlign.justify,
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(text: 'We found ', style: paraStyle),
                          pw.TextSpan(text:fullName.trim(),style:boldPara),
                         // pw.TextSpan(text: _firstName(fullName), style: boldPara),
                          pw.TextSpan(
                            text:
                                ' to be a hardworking and committed individual. We are confident that they will excel in their future career endeavors.',
                            style: paraStyle,
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 14),
                    // Paragraph 4
                    pw.Text(
                      'We wish them all the best in their future pursuits.',
                      style: paraStyle,
                    ),
                    // This spacer pushes the signature down, but only as far as 'bottomPad' allows.
                    // Since we increased bottomPad to 160, the signature will stay higher up.
                    pw.Spacer(),
                    // Signature Block
                    // Signature Block (stacked underline so it can overlap under the signature)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 0),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'For $companyName,',
                            style: pw.TextStyle(font: fontBold, fontSize: 14),
                          ),
                          pw.SizedBox(height: 6),

                          // Container containing signature + positioned underline (no variable declarations here)
                          pw.Container(
                            // container height should be signature height + a little extra for underline
                            height: 100, // 90 signature + 10 room
                            width: 200,  // adjust if your signature is wider; keep consistent with image width
                            child: pw.Stack(
                              children: [
                                // Signature image (preserve original visual size)
                                if (signatureImage != null)
                                  pw.Positioned(
                                    left: 0,
                                    top: 0,
                                    child: pw.Image(
                                      signatureImage,
                                      width: 200, // image width (tweak if you want)
                                      height: 90, // keep the same signature height you used earlier
                                      fit: pw.BoxFit.contain,
                                    ),
                                  )
                                else
                                  pw.Positioned(
                                    left: 0,
                                    top: 0,
                                    child: pw.SizedBox(width: 200, height: 90),
                                  ),

                                // Underline positioned to overlap the signature bottom.
                                // Calculation: top = signatureHeight - overlapGap -> 90 - 22 = 68
                                // Decrease the number after `top:` to move underline closer to signature.
                                pw.Positioned(
                                  left: 0,
                                  top: 68, // adjust this: smaller => underline moves up (try 60..74)
                                  child: pw.Text("__________________", style: boldStyle),
                                ),
                              ],
                            ),
                          ),

                          // small gap between underline and name (tweak as needed)
                          pw.SizedBox(height: 6),

                          // Name & Designation
                          pw.Text(
                            'Hari Baskaran',
                            style: pw.TextStyle(font: fontBold, fontSize: 14),
                          ),
                          pw.Text(
                            'Co-Founder & Chief Technology Officer',
                            style: pw.TextStyle(font: fontRegular, fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // helper to extract first name
  // String _firstName(String fullName) {
  //   final t = fullName.trim();
  //   if (t.isEmpty) return '';
  //   final parts = t.split(RegExp(r'\s+'));
  //   return parts.isNotEmpty ? parts.first : t;
  // }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }
}
