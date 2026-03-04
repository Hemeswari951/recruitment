//lib/onboard.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:html' as html; // <-- IMPORTANT: Only for WEB
// import 'dart:convert'; // Import for json.decode
import 'sidebar.dart';
import 'offer_letter_page.dart';
import 'hr_policy_page.dart';
// import 'pdf_content_model.dart';
// import 'edit_pdf_content_page.dart';
import 'view_offer_letter_page.dart';
import 'generate_revised_offer_page.dart';
import 'view_revised_offer_page.dart';
import 'bulk_offer_letter_page.dart';

class OnBoardPage extends StatelessWidget {
  const OnBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Sidebar(title: "", body: _buildBody(context));
  }

  Future<void> downloadHrPolicy(BuildContext context) async {
    try {
      final data = await rootBundle.load("assets/hr_policy.pdf");
      final bytes = data.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/hr_policy_downloaded.pdf");

      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("HR Policy downloaded to: ${file.path}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error downloading file: $e")));
    }
  }

  Future<void> downloadHrPolicyWeb() async {
    final data = await rootBundle.load("assets/hr_policy.pdf");
    final bytes = data.buffer.asUint8List();

    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = "hr_policy.pdf"
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  Widget _buildBody(BuildContext context) {
    return Material(
      color: const Color(0xFF0F1020),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Wrap(
                  spacing: 35,
                  runSpacing: 35,
                  children: [
                    _buildOfferLetterCard(context),
                    _buildRevisedOfferLetterCard(context),
                    _buildHrPolicyCard(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // OFFER LETTER CARD with popup + Recruitment design
  Widget _buildOfferLetterCard(BuildContext context) {
    return _menuCard(
      context,
      "Offer Letter",
      Icons.description,
      Colors.greenAccent,
      () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Offer Letter Options"),
              content: const Text("What would you like to do?"),
              actions: <Widget>[
  TextButton(
    child: const Text("Generate Offer Letter"),
    onPressed: () {
      Navigator.of(context).pop(); // Close the dialog
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const OfferLetterPage(),
        ),
      );
    },
  ),
  TextButton(
    child: const Text("View Offer Letter"),
    onPressed: () {
      Navigator.of(context).pop(); // Close dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ViewOfferLetterPage(),
        ),
      );
    },
  ),
  // === NEW BUTTON: Bulk Upload ===
  TextButton(
  child: const Text("Bulk Upload (Excel)"),
  onPressed: () {
    Navigator.of(context).pop(); // Close dialog
    showGeneralDialog(
      context: context,
      barrierLabel: "Bulk Upload",
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.86,
                height: MediaQuery.of(context).size.height * 0.86,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BulkOfferLetterPage(isModal: true),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = Curves.easeOut.transform(animation.value);
        return Opacity(
          opacity: animation.value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * curved),
            child: child,
          ),
        );
      },
    );
  },
),

],

            );
          },
        );
      },
    );
  }

  // REVISED OFFER LETTER CARD
  Widget _buildRevisedOfferLetterCard(BuildContext context) {
    return _menuCard(
      context,
      "Revised Offer Letter",
      Icons.note_add_outlined,
      Colors.orangeAccent,
      () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Revised Offer Letter Options"),
              content: const Text("What would you like to do?"),
              actions: <Widget>[
                TextButton(
                  child: const Text("Generate Revised Offer"),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const GenerateRevisedOfferPage(),
                      ),
                    );
                  },
                ),
                TextButton(
                  child: const Text("View Revised Offers"),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ViewRevisedOfferPage(),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // HR POLICY CARD with popup + Recruitment design
  Widget _buildHrPolicyCard(BuildContext context) {
    return _menuCard(
      context,
      "HR Policy",
      Icons.admin_panel_settings_outlined,
      const Color.fromARGB(255, 241, 107, 181),
      () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("HR Policy Options"),
              content: const Text("Choose an action"),
              actions: <Widget>[
                TextButton(
                  child: const Text("View HR Policy"),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HrPolicyPage()),
                    );
                  },
                ),
                TextButton(
                  child: const Text("Download HR Policy"),
                  onPressed: () async {
                    Navigator.of(context).pop();

                    if (kIsWeb) {
                      await downloadHrPolicyWeb(); // WEB DOWNLOAD
                    } else {
                      await downloadHrPolicy(
                        context,
                      ); // MOBILE / DESKTOP DOWNLOAD
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // RECRUITMENT STYLE CARD  (Beautiful + Elevated)
  Widget _menuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 260,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 55, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}