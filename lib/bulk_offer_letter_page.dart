import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

/// Adjust these imports to match your project structure:
import 'offer_letter_pdf_service.dart'; // <-- path to your service
import 'pdf_content_model.dart'; // <-- path to your content model

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'view_offer_letter_page.dart'; // page that lists generated letters

class BulkOfferLetterPage extends StatefulWidget {
  final bool isModal;
  const BulkOfferLetterPage({super.key, this.isModal = false});

  @override
  State<BulkOfferLetterPage> createState() => _BulkOfferLetterPageState();
}

class _BulkOfferLetterPageState extends State<BulkOfferLetterPage> {
  bool loading = false;
  int? total;
  int? processed;
  int? failed;

  List<Map<String, dynamic>> previewRecords = [];

  static const String backendBase = "https://company-04bz.onrender.com";
  // ===== THEME COLORS =====
  static const Color primaryPurple = Color(0xFF6A1B9A);
  static const Color bgGrey = Color(0xFFF4F4F6);
  static const Color textDark = Color(0xFF1F1F1F);
  static const Color borderGrey = Color(0xFFE0E0E0);

  /// ---------- PREVIEW DIALOG (ver1 UI with email + validation) ----------
  Future<void> _showPreviewDialog(List<Map<String, dynamic>> records) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.78,
            height: MediaQuery.of(context).size.height * 0.62,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: primaryPurple, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(
                    children: [
                      const Icon(Icons.table_chart, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(child: Text("Preview Parsed Records", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        Expanded(
                          child: records.isEmpty
                              ? const Center(child: Text("No records to preview."))
                              : ListView.separated(
                                  itemCount: records.length,
                                  separatorBuilder: (_, __) => const Divider(height: 8),
                                  itemBuilder: (context, index) {
                                    final r = records[index];
                                    final salaryFrom = (r['salaryFrom'] ?? r['salaryfrom'] ?? r['salary from'] ?? "-").toString();
                                    final email = (r['email'] ?? r['Email'] ?? "").toString().trim();
                                    final emailValid = r.containsKey('emailValid')
                                        ? (r['emailValid'] == true)
                                        : (email.isNotEmpty ? RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) : false);

                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      leading: CircleAvatar(
                                        backgroundColor: primaryPurple.withOpacity(0.08),
                                        child: Text("${index + 1}", style: const TextStyle(color: primaryPurple)),
                                      ),
                                      title: Text("${r['fullName'] ?? r['name'] ?? '-'}"),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Position: ${r['position'] ?? '-'}"),
                                          Text("Stipend: ${r['stipend'] ?? '-'}  |  CTC: ${r['ctc'] ?? '-'}"),
                                          Text("Salary From: $salaryFrom"),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(child: Text("Email: ${email.isNotEmpty ? email : '-'}", style: const TextStyle(fontSize: 13))),
                                              if (!emailValid && email.isNotEmpty)
                                                Row(children: const [
                                                  Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                                                  SizedBox(width: 6),
                                                  Text("Invalid email", style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                                ]),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: Text(r['employeeId'] ?? "", style: const TextStyle(fontSize: 12)),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel"))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _processRecords(records);
                                },
                                child: const Text("Confirm & Generate"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showResultDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 20,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: IntrinsicHeight(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    decoration: BoxDecoration(color: primaryPurple, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
                    child: Row(
                      children: [
                        const Icon(Icons.upload_file, color: Colors.white),
                        const SizedBox(width: 12),
                        const Expanded(child: Text("Bulk Upload Completed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18))),
                        GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close, color: Colors.white)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: primaryPurple..withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.picture_as_pdf, color: primaryPurple)),
                        const SizedBox(width: 14),
                        const Expanded(child: Text("Your Excel has been processed. PDFs were generated and saved to Offer Letters.", style: TextStyle(fontSize: 14))),
                      ]),
                      const SizedBox(height: 18),
                      Row(children: [Expanded(child: Text("Total Records :", style: TextStyle(color: Colors.grey[800]))), Text("${total ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 6),
                      Row(children: [Expanded(child: Text("Generated PDFs :", style: TextStyle(color: Colors.grey[800]))), Text("${processed ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 6),
                      Row(children: [Expanded(child: Text("Failed Records :", style: TextStyle(color: Colors.grey[800]))), Text("${failed ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))]),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text("View Offer Letters"),
                            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            onPressed: () {
                              if (widget.isModal) {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ViewOfferLetterPage()));
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewOfferLetterPage()));
                              }
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close"))])
                    ]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _processRecords(List<Map<String, dynamic>> records) async {
    setState(() {
      loading = true;
      total = records.length;
      processed = 0;
      failed = 0;
    });

    final pdfService = OfferLetterPdfService();
    final contentModel = PdfContentModel();

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final rowLabel = "row ${r['row'] ?? (i + 1)}";

      try {
        final salaryFromValue =
            (r['salaryFrom'] ?? r['salary_from'] ?? r['salary from'] ?? '').toString();

        final Uint8List pdfBytes = await pdfService.generateOfferLetter(
          fullName: (r['fullName'] ?? r['name'] ?? '').toString(),
          employeeId: (r['employeeId'] ?? '').toString(),
          position: (r['position'] ?? '').toString(),
          stipend: (r['stipend'] ?? '').toString(),
          ctc: (r['ctc'] ?? '').toString(),
          doj: (r['doj'] ?? '').toString(),
          signdate: (r['signdate'] ?? '').toString(),
          salaryFrom: salaryFromValue,
          content: contentModel,
        );

        final String pdfBase64 = base64Encode(pdfBytes);
        final Map<String, dynamic> payload = {
          "fullName": r['fullName'] ?? r['name'] ?? "",
          "position": r['position'] ?? "",
          "stipend": r['stipend'] ?? "",
          "doj": r['doj'] ?? "",
          "signdate": r['signdate'] ?? "",
          "employeeId": r['employeeId'] ?? "",
          "salaryFrom": salaryFromValue,
          "email": r['email'] ?? r['Email'] ?? "",
          "pdfFile": pdfBase64,
        };

        final String payloadJson = jsonEncode(payload);
        final String shortLog = payloadJson.length > 200 ? '${payloadJson.substring(0, 200)}...' : payloadJson;
        debugPrint("Uploading payload: $shortLog"); // shortened log

        // set per-request timeout (e.g. 60s). .timeout will throw TimeoutException if exceeded.
        final uploadResp = await http
            .post(Uri.parse("$backendBase/api/offerletter"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode(payload))
            .timeout(const Duration(seconds: 60));

        if (!mounted) return;

        if (uploadResp.statusCode == 201 || uploadResp.statusCode == 200) {
          setState(() => processed = (processed ?? 0) + 1);
        } else {
          setState(() => failed = (failed ?? 0) + 1);
          debugPrint("Upload failed for ${r['employeeId'] ?? rowLabel}: ${uploadResp.statusCode} ${uploadResp.body}");
        }
      } on TimeoutException catch (e) {
        debugPrint("Upload timed out for ${r['employeeId'] ?? rowLabel}: $e");
        if (!mounted) return;
        setState(() => failed = (failed ?? 0) + 1);
      } catch (e, st) {
        debugPrint("Exception processing ${r['employeeId'] ?? rowLabel}: $e");
        debugPrint("$st");
        if (!mounted) return;
        setState(() => failed = (failed ?? 0) + 1);
      }

      if (!mounted) return;
      setState(() {}); // update progress UI after each record
    }

    // After loop finishes ensure loading is cleared and show result.
    setState(() => loading = false);
    await _showResultDialog();
  }

  Future<void> uploadBulk() async {
    // ---- STEP 0: Reset state ----
    setState(() {
      total = null;
      processed = 0;
      failed = 0;
      previewRecords = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;

      // ---- STEP: get sheet names from server ----
      final sheets = await _fetchSheetNames(picked);

      if (sheets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No sheets found in Excel")));
        return;
      }

      // Show sheet picker
      final selectedSheet = await _showSheetPicker(sheets);
      if (selectedSheet == null) return;

      // ---- STEP: Upload to backend with sheetName ----
      final uri = Uri.parse("$backendBase/api/offerletter/bulk");
      final request = http.MultipartRequest('POST', uri);
      request.fields["sheetName"] = selectedSheet;

      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('file', picked.bytes!, filename: picked.name));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', picked.path!, filename: p.basename(picked.path!)));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final resp = await http.Response.fromStream(streamed);

      debugPrint("Bulk upload status: ${resp.statusCode}");
      debugPrint("Bulk response body: ${resp.body}");

      if (!mounted) return;

      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bulk upload failed: ${resp.statusCode}")));
        return;
      }

      final Map<String, dynamic> jsonBody = jsonDecode(resp.body) as Map<String, dynamic>;
      final Map<String, dynamic> summary = (jsonBody['summary'] ?? {}) as Map<String, dynamic>;
      final List<Map<String, dynamic>> records = ((jsonBody['records'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();

      setState(() {
        total = summary['total'] ?? records.length;
        previewRecords = records;
      });

      await _showPreviewDialog(previewRecords);
    } catch (e, st) {
      debugPrint("Upload error: $e");
      debugPrint("$st");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<List<String>> _fetchSheetNames(PlatformFile picked) async {
    final uri = Uri.parse("$backendBase/api/offerletter/bulk/sheets");
    final req = http.MultipartRequest("POST", uri);

    if (kIsWeb) {
      req.files.add(http.MultipartFile.fromBytes("file", picked.bytes!, filename: picked.name));
    } else {
      req.files.add(await http.MultipartFile.fromPath("file", picked.path!));
    }

    final respStream = await req.send();
    final body = await http.Response.fromStream(respStream);

    if (respStream.statusCode != 200) {
      throw Exception("Failed to read sheets");
    }

    final json = jsonDecode(body.body);
    return List<String>.from(json["sheets"] ?? []);
  }

  Future<String?> _showSheetPicker(List<String> sheets) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String selected = sheets.first;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ===== HEADER =====
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: primaryPurple,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.table_view, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Select Excel Sheet",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== BODY =====
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Your Excel file contains multiple sheets."),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selected,
                        isExpanded: true,
                        items: sheets.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) {
                          if (v != null) selected = v;
                        },
                        decoration: InputDecoration(
                          labelText: "Sheet name",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: bgGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== ACTIONS =====
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgGrey,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: textDark, side: const BorderSide(color: borderGrey)),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, selected),
                          child: const Text("Continue"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bulk Offer Letter Upload")),
      body: Stack(
        children: [
          // CENTER the upload control (and preview summary card if present)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: loading ? null : uploadBulk,
                  icon: const Icon(Icons.upload_file),
                  label: const Text(
                    "Upload Excel",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // small inline preview summary under the button (optional)
                if (!loading && previewRecords.isNotEmpty)
                  Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Parsed Records (preview)", style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text("Total parsed: ${previewRecords.length}"),
                          Text("First row: ${previewRecords.isNotEmpty ? (previewRecords[0]['fullName'] ?? previewRecords[0]['name'] ?? '-') : '-'}"),
                        ]),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _showPreviewDialog(previewRecords),
                          icon: const Icon(Icons.preview),
                          label: const Text("Preview & Confirm"),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // CENTERED modal overlay shown while processing
          if (loading)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Card(
                      elevation: 12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 88,
                                height: 88,
                                child: CircularProgressIndicator(
                                  strokeWidth: 7,
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text("Processing... ${processed ?? 0}/${total ?? '?'}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.6,
                                child: LinearProgressIndicator(
                                  value: (total != null && total! > 0) ? ((processed ?? 0) / (total ?? 1)) : null,
                                  minHeight: 8,
                                  color: primaryPurple,
                                  backgroundColor: primaryPurple.withOpacity(0.14),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text("Please wait while PDFs are generated...", style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
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
