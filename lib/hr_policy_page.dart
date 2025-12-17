import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

class HrPolicyPage extends StatefulWidget {
  const HrPolicyPage({super.key});

  @override
  State<HrPolicyPage> createState() => _HrPolicyPageState();
}

class _HrPolicyPageState extends State<HrPolicyPage> {
  Uint8List? pdfBytes;

  @override
  void initState() {
    super.initState();
    loadPdf();
  }

  Future<void> loadPdf() async {
    final data = await rootBundle.load("assets/hr_policy.pdf");
    setState(() {
      pdfBytes = data.buffer.asUint8List();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HR Policy"),
        backgroundColor: Colors.black,
      ),

      body: pdfBytes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // PDF PREVIEW AREA
                Expanded(
                  child: PdfPreview(
                    build: (context) => pdfBytes!,
                  ),
                ),

                // CLOSE BUTTON
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 180,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
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
