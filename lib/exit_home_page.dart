import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui'; // Needed for ImageFilter
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html; // Only for web
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'experience_page.dart';


import 'sidebar.dart';
import 'exit_detail_page.dart';

class ExitHomePage extends StatelessWidget {
  const ExitHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "Exit Management",
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
  "Exit Management",
  style: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
    color: Colors.white,
    shadows: [
      Shadow(
        blurRadius: 4,
        color: Colors.black45,
        offset: Offset(1, 1),
      ),
    ],
  ),
),

            const SizedBox(height: 50),

            Wrap(
              spacing: 30,
              runSpacing: 30,
              alignment: WrapAlignment.center,
              children: [
                _exitCard(
                  context,
                  title: "Exit Details",
                  icon: Icons.list_alt_rounded,
                  color: Colors.deepPurpleAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExitDetailsPage()),
                    );
                  },
                ),
                _exitCard(
                  context,
                  title: "Exit Form",
                  icon: Icons.note_add_rounded,
                  color: Colors.orangeAccent,
                  onTap: () => _showExitFormPopup(context),
                ),
                _exitCard(
                  context,
                  title: "Experience Certificate",
                  icon: Icons.badge_rounded,
                  color: Colors.greenAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExperiencePage()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------
  // Exit Form Popup
  // -------------------------------
  void _showExitFormPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Exit Form"),
          content: const Text("Choose an action for the Exit Form:"),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text("View"),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExitFormViewerPage()),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Download"),
              onPressed: () async {
                Navigator.pop(context);
                if (kIsWeb) {
                  await ExitFormViewerPage.downloadExitFormWeb();
                } else {
                  await ExitFormViewerPage.downloadExitFormMobile();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // -------------------------------
  // Card Widget for Exit Home Buttons
  // -------------------------------
  Widget _exitCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
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

// ---------------------------------------------------------------------
// Exit Form Viewer Page
// ---------------------------------------------------------------------
class ExitFormViewerPage extends StatefulWidget {
  const ExitFormViewerPage({super.key});

  @override
  State<ExitFormViewerPage> createState() => _ExitFormViewerPageState();

  // -------------------------------
  // DOWNLOAD FUNCTION FOR MOBILE / DESKTOP
  // -------------------------------
  static Future<void> downloadExitFormMobile() async {
    try {
      final data = await rootBundle.load("assets/exit_form.pdf");
      final bytes = data.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/Exit_Form.pdf");
      await file.writeAsBytes(bytes);

      OpenFilex.open(file.path);
    } catch (e) {
      print("Download Error: $e");
    }
  }

  // -------------------------------
  // DOWNLOAD FUNCTION FOR WEB
  // -------------------------------
  static Future<void> downloadExitFormWeb() async {
    final data = await rootBundle.load("assets/exit_form.pdf");
    final bytes = data.buffer.asUint8List();

    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

     html.AnchorElement(href: url)
      ..setAttribute("download", "Exit_Form.pdf")
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}

class _ExitFormViewerPageState extends State<ExitFormViewerPage> {
  Uint8List? pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final data = await rootBundle.load("assets/exit_form.pdf");
      setState(() {
        pdfBytes = data.buffer.asUint8List();
      });
    } catch (e) {
      print("PDF Load Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Exit Form"),
        backgroundColor: Colors.deepPurple,
      ),
      body: pdfBytes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: PdfPreview(
                    build: (context) => pdfBytes!,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 180,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}