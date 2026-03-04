// lib/view_offer_letter_page.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'sidebar.dart';
import 'offer_letter_pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb, setEquals;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';


String formatDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) return "N/A";
  try {
    return DateFormat("dd-MM-yyyy").format(DateTime.parse(dateString));
  } catch (_) {
    return dateString ?? "N/A";
  }
}
class ViewOfferLetterPage extends StatefulWidget {
  const ViewOfferLetterPage({super.key});

  @override
  State<ViewOfferLetterPage> createState() => _ViewOfferLetterPageState();
}

class _ViewOfferLetterPageState extends State<ViewOfferLetterPage> {
  List<Map<String, dynamic>> letters = [];
  final TextEditingController _searchController = TextEditingController();

  // This holds the currently visible (filtered) letters reported by the table.
  List<Map<String, dynamic>> _currentlyVisibleLetters = [];

  // Selection state (kept in parent so other UI like Share can use it)
  Set<String> _selectedIds = {};
  
  List<Map<String, dynamic>> _selectedRecords = [];

  String selectedMonth = "";
  String selectedYear = "";
  Map<String, int> yearCounts = {};
  Map<String, int> monthCounts = {};

  Timer? _debounce;

  // Fixed list of month names in order
  static const List<String> _monthNames = [
    "All Months",
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  @override
  void initState() {
    super.initState();
    selectedMonth = "All Months";
    selectedYear = "All Years";
    fetchLetters();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchLetters() async {
    try {
      final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/offerletter"));
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        if (body["success"] == true) {
          final List<dynamic> data = body["letters"] ?? [];
          setState(() {
            letters = data.map((e) => Map<String, dynamic>.from(e)).toList();
            _computeCounts();
          });
        }
      } else {
        debugPrint("Server returned status ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching offer letters: $e");
    }
  }

  void _computeCounts() {
    monthCounts = {for (var m in _monthNames) m: 0};
    yearCounts.clear();

    if (letters.isNotEmpty) yearCounts["All Years"] = letters.length;

    for (var l in letters) {
      final dateStr = l['createdAt']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;
      final dt = DateTime.parse(dateStr);
      final year = dt.year.toString();
      yearCounts[year] = (yearCounts[year] ?? 0) + 1;
    }

    for (var l in letters) {
      final dateStr = l['createdAt']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;
      final dt = DateTime.parse(dateStr);
      final year = dt.year.toString();
      final mName = _getMonthName(dt.month);
      if (selectedYear == "All Years" || year == selectedYear) {
        monthCounts["All Months"] = (monthCounts["All Months"] ?? 0) + 1;
        monthCounts[mName] = (monthCounts[mName] ?? 0) + 1;
      }
    }

    if (!monthCounts.containsKey(selectedMonth) && monthCounts.isNotEmpty) {
      selectedMonth = monthCounts.keys.first;
    }
    if (!yearCounts.containsKey(selectedYear) && yearCounts.isNotEmpty) {
      selectedYear = yearCounts.keys.first;
    }
  }

  String _getMonthName(int m) {
    if (m >= 1 && m <= 12) return _monthNames[m];
    return "All Months";
  }

  String formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat("dd-MM-yyyy").format(date);
    } catch (e) {
      return dateString;
    }
  }

  // ---------------- SHARE / DOWNLOAD helpers ----------------

  // Open Gmail compose for a single record (per-row Share)
  // Future<void> _shareSingle(Map<String, dynamic> item) async {
  //   final to = (item['email'] ?? '').toString();
  //   final pdfUrlRaw = (item['pdfUrl'] ?? '').toString();
  //   final pdfUrl = pdfUrlRaw.startsWith('http') ? pdfUrlRaw : 'https://company-04bz.onrender.com$pdfUrlRaw';
  //   final subject = Uri.encodeComponent("Job Offer – ${item['position'] ?? ''} at ZeAI Soft");
  //   final body = Uri.encodeComponent("Dear ${item['fullName'] ?? ''},\n\nPlease find your offer letter here: $pdfUrl\n\nBest Regards,\nHR Team");
  //   final gmailUri = Uri.parse("https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(to)}&su=$subject&body=$body");

  //   if (await canLaunchUrl(gmailUri)) {
  //     await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
  //   } else {
  //     final mailto = Uri(
  //       scheme: 'mailto',
  //       path: to,
  //       queryParameters: {'subject': "Job Offer – ${item['position'] ?? ''}", 'body': "Please find your offer letter here: $pdfUrl"},
  //     );
  //     if (await canLaunchUrl(mailto)) {
  //       await launchUrl(mailto);
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot open email client.")));
  //     }
  //   }
  // }
  // Replace existing _shareSingle with this
// Future<void> _shareSingle(Map<String, dynamic> item) async {
//   final to = (item['email'] ?? '').toString().trim();
//   if (to.isEmpty) {
//     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email missing for this record.")));
//     return;
//   }

//   final pdfUrlRaw = (item['pdfUrl'] ?? '').toString();
//   final pdfUrl = pdfUrlRaw.startsWith('http') ? pdfUrlRaw : 'https://company-04bz.onrender.com$pdfUrlRaw';

//   // Prepare sign date text: prefer signdate, then signedDate, then placeholder
//   String signDate = (item['signdate'] ?? item['signedDate'] ?? '').toString();
//   if (signDate.isEmpty) {
//     // Optional: fallback to a formatted createdAt or a static placeholder
//     final created = item['createdAt']?.toString() ?? '';
//     try {
//       signDate = created.isNotEmpty ? DateFormat("dd/MM/yyyy").format(DateTime.parse(created)) : "27/09/2025";
//     } catch (_) {
//       signDate = "27/09/2025";
//     }
//   }

//   final subject = "Job Offer – ${item['position'] ?? ''} at ZeAI Soft";

//   final bodyPlain = '''
// Dear ${item['fullName'] ?? item['name'] ?? ''},

// Greetings from ZeAI Soft!

// We are pleased to offer you the position of ${item['position'] ?? 'Tech Trainee'} with our organization. After careful evaluation of your skills and performance, we believe that you will be a valuable addition to our team.

// Please find attached your official offer letter outlining the terms and conditions of your employment, including your compensation details, role, and responsibilities.

// We kindly request you to review the document and confirm your acceptance by replying to this email and sharing a signed copy of the offer letter on or before $signDate.

// Should you have any questions or require further clarification, please feel free to reach out to us.

// We look forward to welcoming you to the ZeAI Soft family and working together towards mutual growth and success.

// Best Regards,
// Srivatsini R
// Human resource
// +91 9789097196 | srivatsini.r@zeaisoft.com | www.zeaisoft.com
// ZeAI Soft Private Limited
// SKCL Tech Square

// Offer letter: $pdfUrl
// ''';

//   final encodedSubject = Uri.encodeComponent(subject);
//   final encodedBody = Uri.encodeComponent(bodyPlain);

//   final gmailUri = Uri.parse("https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(to)}&su=$encodedSubject&body=$encodedBody");

//   try {
//     if (await canLaunchUrl(gmailUri)) {
//       await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
//     } else {
//       // fallback to mailto
//       final mailto = Uri(
//         scheme: 'mailto',
//         path: to,
//         queryParameters: {'subject': subject, 'body': bodyPlain},
//       );
//       if (await canLaunchUrl(mailto)) {
//         await launchUrl(mailto);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot open email client.")));
//       }
//     }
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error opening email client: $e")));
//   }
// }
Future<void> _shareSingle(Map<String, dynamic> item) async {
  // Debug (uncomment if you want to inspect what's in the item)
  debugPrint("shareSingle item: $item");

  final to = (item['email'] ?? '').toString().trim();
  if (to.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email missing for this record.")));
    return;
  }

  // Build a safe PDF URL
  final pdfUrlRaw = (item['pdfUrl'] ?? '').toString();
  final pdfUrl = pdfUrlRaw.startsWith('http') ? pdfUrlRaw : 'https://company-04bz.onrender.com$pdfUrlRaw';

  // Name & Position
  final name = (item['fullName'] ?? item['name'] ?? '').toString().trim();
  final position = (item['position'] ?? '').toString().trim();

  // Sign date: accept several possible keys and format to dd-MM-yyyy when possible
  String signDateRaw = (item['signdate'] ??
                        item['signedDate'] ??
                        item['signed_date'] ??
                        item['signdateExcel'] ??
                        '').toString().trim();

  String signDate = signDateRaw.isEmpty ? "27/09/2025" : signDateRaw;
  if (signDateRaw.isNotEmpty) {
    try {
      final dt = DateTime.parse(signDateRaw);
      signDate = DateFormat("dd-MM-yyyy").format(dt);
    } catch (_) {
      // If parse fails (maybe already dd-mm-yyyy string), leave as-is
      signDate = signDateRaw;
    }
  }

  final subject = "Job Offer – ${position.isNotEmpty ? position : 'Tech Trainee'} at ZeAI Soft";

  final bodyPlain = '''
Dear ${name.isNotEmpty ? name : 'Candidate'},
Position: ${position.isNotEmpty ? position : 'Tech Trainee'}

Greetings from ZeAI Soft!

We are pleased to offer you the position of ${position.isNotEmpty ? position : 'Tech Trainee'} with our organization. After careful evaluation of your skills and performance, we believe that you will be a valuable addition to our team.

Please find attached your official offer letter outlining the terms and conditions of your employment, including your compensation details, role, and responsibilities.

We kindly request you to review the document and confirm your acceptance by replying to this email and sharing a signed copy of the offer letter on or before $signDate.

Should you have any questions or require further clarification, please feel free to reach out to us.

We look forward to welcoming you to the ZeAI Soft family and working together towards mutual growth and success.

Best Regards,
Varsha Ravichandran 
Human resource
+91 9150274009 | Varsha@zeaisoft.com | www.zeaisoft.com
ZeAI Soft Private Limited
SKCL Tech Square


''';

  final encodedSubject = Uri.encodeComponent(subject);
  final encodedBody = Uri.encodeComponent(bodyPlain);

  final gmailUri = Uri.parse("https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(to)}&su=$encodedSubject&body=$encodedBody");

  try {
    if (await canLaunchUrl(gmailUri)) {
      await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
    } else {
      // fallback to mailto
      final mailto = Uri(
        scheme: 'mailto',
        path: to,
        queryParameters: {'subject': subject, 'body': bodyPlain},
      );
      if (await canLaunchUrl(mailto)) {
        await launchUrl(mailto);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot open email client.")));
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error opening email client: $e")));
  }
}


  // Download single record (used by per-row Download icon)
  Future<void> _downloadSingle(Map<String, dynamic> item) async {
    final id = item['_id']?.toString();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid record id")));
      return;
    }
    final rawName = (item['fullName'] ?? 'offerletter').toString();
    final safeName = rawName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    final filename = '${safeName}_Offerletter.pdf';
    final downloadUri = Uri.parse('https://company-04bz.onrender.com/api/offerletter/download/$id');

    try {
      if (kIsWeb) {
        if (await canLaunchUrl(downloadUri)) {
          await launchUrl(downloadUri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot open download link.")));
        }
      } else {
        final resp = await http.get(downloadUri).timeout(const Duration(seconds: 30));
        if (resp.statusCode == 200) {
          final bytes = resp.bodyBytes;
          await Printing.sharePdf(bytes: bytes, filename: filename);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: ${resp.statusCode}")));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download error: $e")));
    }
  }

  // Download all selected records ONE BY ONE
  Future<void> _downloadSelected() async {
    if (_selectedRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records selected")));
      return;
    }

    for (var item in List<Map<String, dynamic>>.from(_selectedRecords)) {
      await _downloadSingle(item);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // ---------- Bulk share selected records ----------
Future<void> _shareSelectedRecords() async {
  if (_selectedRecords.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records selected for sharing")));
    return;
  }

  // ensure all selected rows have emails
  final missing = _selectedRecords.where((r) => (r['email'] ?? '').toString().trim().isEmpty).toList();
  if (missing.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Some selected records are missing email addresses. Please fix them first.")));
    return;
  }

  // Confirmation dialog before opening multiple compose windows
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text("Share ${_selectedRecords.length} offer letters?"),
      content: const Text("This will open a Gmail compose window for each selected record. Continue?"),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("Yes, Share")),
      ],
    ),
  );

  if (confirm != true) return;

  for (var rec in List<Map<String, dynamic>>.from(_selectedRecords)) {
    await _shareSingle(rec);
    // small delay so browser opens multiple compose windows cleanly
    await Future.delayed(const Duration(milliseconds: 350));
  }

  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opened compose windows for selected records.")));
}


  // ---------------- Edit / Preview / Export (existing flows) ----------------

  void _editOfferLetter(Map<String, dynamic> item) {
    final nameController = TextEditingController(text: item['fullName'] ?? '');
    final idController = TextEditingController(text: item['employeeId'] ?? '');
    final positionController = TextEditingController(text: item['position'] ?? '');
    final stipendController = TextEditingController(text: item['stipend']?.toString() ?? '');
    final dojController = TextEditingController(text: item['joiningDate']?.toString() ?? '');
    final signdateController = TextEditingController(text: item['signedDate']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Offer Letter - ${item['fullName']}"),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
                TextField(controller: idController, readOnly: true, decoration: const InputDecoration(labelText: "Employee ID")),
                TextField(controller: positionController, decoration: const InputDecoration(labelText: "Position")),
                TextField(controller: stipendController, decoration: const InputDecoration(labelText: "Stipend/Salary"), keyboardType: TextInputType.number),
                TextField(controller: dojController, decoration: const InputDecoration(labelText: "Date of Joining")),
                TextField(controller: signdateController, decoration: const InputDecoration(labelText: "Signed Date")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                try {
                  final recordId = item['_id']?.toString() ?? '';
                  final fullName = (item['fullName'] ?? item['name'] ?? 'offerletter').toString();
                  final safeName = fullName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
                  final filename = '${safeName}_Offerletter.pdf';
                  final downloadUri = Uri.parse('https://company-04bz.onrender.com/api/offerletter/download/$recordId');

                  if (kIsWeb) {
                    if (await canLaunchUrl(downloadUri)) {
                      await launchUrl(downloadUri, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unable to open download URL.")));
                    }
                  } else {
                    final pdfUrl = item['pdfUrl'] != null && item['pdfUrl'].toString().isNotEmpty ? 'https://company-04bz.onrender.com${item['pdfUrl']}' : downloadUri.toString();
                    final resp = await http.get(Uri.parse(pdfUrl)).timeout(const Duration(seconds: 30));
                    if (resp.statusCode == 200) {
                      final bytes = resp.bodyBytes;
                      await Printing.sharePdf(bytes: bytes, filename: filename);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to fetch PDF: ${resp.statusCode}")));
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Share error: $e")));
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _previewPdf(Map<String, dynamic> item) async {
    try {
      final pdfUrl = item['pdfUrl'];
      if (pdfUrl == null || pdfUrl.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No PDF file found for this letter.")));
        return;
      }

      final fullUrl = Uri.parse("https://company-04bz.onrender.com$pdfUrl");
      final response = await http.get(fullUrl);
      final pdfBytes = response.bodyBytes;
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Offer Letter - ${item['fullName'] ?? ''}"),
          contentPadding: const EdgeInsets.all(16),
          insetPadding: const EdgeInsets.all(20),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            child: PdfPreview(build: (format) => pdfBytes, canChangeOrientation: false, canDebug: false, useActions: true),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close")),
            TextButton(
              onPressed: () async {
                try {
                  final pdfUrl = item['pdfUrl'];
                  if (pdfUrl == null || pdfUrl.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No PDF file to download")));
                    return;
                  }
                  final rawName = (item['fullName'] ?? 'offerletter').toString();
                  final safeName = rawName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
                  final filename = '${safeName}_Offerletter.pdf';
                  final downloadUri = Uri.parse('https://company-04bz.onrender.com/api/offerletter/download/${item["_id"]}');

                  if (kIsWeb) {
                    if (await canLaunchUrl(downloadUri)) {
                      await launchUrl(downloadUri, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot open download URL")));
                    }
                  } else {
                    final response = await http.get(Uri.parse("https://company-04bz.onrender.com${item['pdfUrl']}"));
                    final bytes = response.bodyBytes;
                    await Printing.sharePdf(bytes: bytes, filename: filename);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download error: $e")));
                }
              },
              child: const Text("Download"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to open preview: $e")));
    }
  }

  Future<void> _exportFilteredPdf() async {
    try {
      if (_currentlyVisibleLetters.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records to export")));
        return;
      }
      final pdfService = OfferLetterPdfService();
      final pdfBytes = await pdfService.exportOfferLetterList(_currentlyVisibleLetters);
      if (!mounted) return;
      await Printing.sharePdf(bytes: pdfBytes, filename: 'offer_letters_report_${selectedMonth}_$selectedYear.pdf');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF exported successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to export PDF: $e")));
    }
  }

  // Callback from child table when selection changes
  void _onSelectionChanged(List<Map<String, dynamic>> selected) {
    setState(() {
      _selectedRecords = List<Map<String, dynamic>>.from(selected);
      _selectedIds = selected.map((e) => e['_id']?.toString() ?? '').toSet();
    });
  }

  bool _isLetterMatchingFilters(Map<String, dynamic> l, String searchQuery) {
    final id = (l['employeeId'] ?? '').toString().toLowerCase();
    final name = (l['fullName'] ?? '').toString().toLowerCase();
    final pos = (l['position'] ?? '').toString().toLowerCase();

    bool matchesSearch = searchQuery.isEmpty || id.contains(searchQuery) || name.contains(searchQuery) || pos.contains(searchQuery);

    bool matchesMonth = true;
    bool matchesYear = true;
    final dateStr = l['createdAt']?.toString() ?? '';

    if (dateStr.isNotEmpty) {
      final dt = DateTime.parse(dateStr);
      final mName = _getMonthName(dt.month);
      final year = dt.year.toString();
      matchesYear = (selectedYear == "All Years" || year == selectedYear);
      matchesMonth = (selectedMonth == "All Months" || mName == selectedMonth);
    }
    return matchesSearch && matchesMonth && matchesYear;
  }

  @override
  Widget build(BuildContext context) {
    final totalLettersCount = letters.where((l) {
      final dateStr = l['createdAt']?.toString() ?? '';
      if (dateStr.isEmpty) return false;
      final dt = DateTime.parse(dateStr);
      return selectedYear == "All Years" || dt.year.toString() == selectedYear;
    }).length;

    // compute whether all visible rows are selected (for header toggle label/icon)
    final visibleIds = _currentlyVisibleLetters.map((e) => e['_id']?.toString() ?? '').toSet();
    final visibleAllSelected = visibleIds.isNotEmpty && visibleIds.difference(_selectedIds).isEmpty;

    return Sidebar(
      title: "Offer Letters",
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    // Header row: title + total count + dropdown + refresh
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_rounded, color: Color.fromARGB(255, 145, 89, 155), size: 22),
                              const SizedBox(width: 8),
                              const Text("Offer Letters", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87, letterSpacing: 0.3)),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                child: Text("$totalLettersCount Records", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 158, 27, 219))),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Year Dropdown
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: Offset(0, 3))], border: Border.all(color: Colors.grey.shade200)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedYear,
                                isDense: true,
                                icon: const Icon(Icons.expand_more_rounded, size: 24, color: Color.fromARGB(255, 145, 89, 155)),
                                items: yearCounts.keys.toList().map((y) {
                                  return DropdownMenuItem<String>(
                                    value: y,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color.fromARGB(255, 145, 89, 155)),
                                        const SizedBox(width: 6),
                                        Text(y, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    selectedYear = value;
                                    _computeCounts();
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Month Dropdown
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: Offset(0, 3))], border: Border.all(color: Colors.grey.shade200)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedMonth,
                                isDense: true,
                                icon: const Icon(Icons.expand_more_rounded, size: 24, color: Color.fromARGB(255, 145, 89, 155)),
                                items: _monthNames.map((m) {
                                  final count = monthCounts[m] ?? 0;
                                  return DropdownMenuItem<String>(
                                    value: m,
                                    child: SizedBox(
                                      width: 110,
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(m, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                                            child: Text(count.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 145, 89, 155))),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    selectedMonth = value;
                                  });
                                },
                              ),
                            ),
                          ),

                          const Spacer(),
                          IconButton(icon: const Icon(Icons.download, color: Color.fromARGB(255, 145, 89, 155)), tooltip: "Export to PDF", onPressed: _exportFilteredPdf),
                          const SizedBox(width: 10),
                          IconButton(tooltip: "Refresh", icon: const Icon(Icons.refresh), onPressed: () async {
                            _searchController.clear();
                            setState(() {
                              selectedMonth = "All Months";
                              selectedYear = "All Years";
                              _currentlyVisibleLetters = [];
                              _selectedIds.clear();
                              _selectedRecords.clear();
                            });
                            await fetchLetters();
                          }),

                          // Select All toggle + Download Selected
                          const SizedBox(width: 8),

                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                if (visibleAllSelected) {
                                  // unselect visible
                                  _selectedIds.removeAll(visibleIds);
                                  _selectedRecords.removeWhere((r) => visibleIds.contains(r['_id']?.toString() ?? ''));
                                } else {
                                  // select visible
                                  _selectedIds.addAll(visibleIds);
                                  final existingIds = _selectedRecords.map((r) => r['_id']?.toString() ?? '').toSet();
                                  for (var r in _currentlyVisibleLetters) {
                                    final id = r['_id']?.toString() ?? '';
                                    if (!existingIds.contains(id)) _selectedRecords.add(r);
                                  }
                                }
                              });
                            },
                            icon: Icon(visibleAllSelected ? Icons.check_box : Icons.select_all, size: 18),
                            label: Text(visibleAllSelected ? "Unselect All" : "Select All"),
                          ),

                          const SizedBox(width: 8),

                          IconButton(
                            tooltip: "Download Selected",
                            icon: const Icon(Icons.download, color: Color.fromARGB(255, 145, 89, 155)),
                            onPressed: _downloadSelected,
                          ),
                          // 🔥 NEW: Share Selected (Gmail)
                          IconButton(
                            tooltip: "Share Selected (Gmail)",
                            icon: const Icon(Icons.share, color: Colors.deepPurpleAccent),
                            onPressed: _shareSelectedRecords,
                          ),
                        ],
                      ),
                    ),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.only(left: 3, right: 3, bottom: 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search by ID, Name or Position...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                        onChanged: (_) {
                          // let child detect changes via controller listener
                          // parent doesn't need to do extra filtering here
                        },
                      ),
                    ),

                    // Table of filtered letters
                    Expanded(
                      child: _OfferLetterDataTable(
                        allLetters: letters,
                        searchController: _searchController,
                        selectedMonth: selectedMonth,
                        selectedYear: selectedYear,
                        getMonthName: _getMonthName,
                        onPreview: _previewPdf,
                        onEdit: _editOfferLetter,
                        onFilteredChanged: (list) {
                          _currentlyVisibleLetters = List<Map<String, dynamic>>.from(list);
                        },
                        onSelectionChanged: _onSelectionChanged,
                        parentSelectedIds: _selectedIds,
                        onShareSingle: _shareSingle,
                        onDownloadSingle: _downloadSingle,
                      ),
                    ),

                    // Bottom-Right Close Button
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("Close", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferLetterDataTable extends StatefulWidget {
  final List<Map<String, dynamic>> allLetters;
  final TextEditingController searchController;
  final String selectedMonth;
  final String selectedYear;
  final String Function(int) getMonthName;
  final void Function(Map<String, dynamic>) onPreview;
  final void Function(Map<String, dynamic>) onEdit;

  // New callback to notify parent of exactly which rows are visible
  final void Function(List<Map<String, dynamic>>) onFilteredChanged;

  // Callback to notify parent when selection changes
  final void Function(List<Map<String, dynamic>>) onSelectionChanged;

  // Parent-provided selected IDs so parent can control selection as well
  final Set<String> parentSelectedIds;

  // per-row share & download callbacks
  final void Function(Map<String, dynamic>) onShareSingle;
  final void Function(Map<String, dynamic>) onDownloadSingle;

  const _OfferLetterDataTable({
    required this.allLetters,
    required this.searchController,
    required this.selectedMonth,
    required this.selectedYear,
    required this.getMonthName,
    required this.onPreview,
    required this.onEdit,
    required this.onFilteredChanged,
    required this.onSelectionChanged,
    required this.parentSelectedIds,
    required this.onShareSingle,
    required this.onDownloadSingle,
  });

  @override
  State<_OfferLetterDataTable> createState() => _OfferLetterDataTableState();
}

class _OfferLetterDataTableState extends State<_OfferLetterDataTable> {
  List<Map<String, dynamic>> _filteredLetters = [];
  Timer? _debounce;

  // internal selection state mirrors parent's selected ids
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
    _filterLetters();
    _selectedIds = Set<String>.from(widget.parentSelectedIds);
  }

  @override
  void didUpdateWidget(covariant _OfferLetterDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.allLetters != oldWidget.allLetters || widget.searchController.text != oldWidget.searchController.text || widget.selectedMonth != oldWidget.selectedMonth || widget.selectedYear != oldWidget.selectedYear) {
      _filterLetters();
    }

    // if parent's selection changed, mirror it
    if (!setEquals(widget.parentSelectedIds, oldWidget.parentSelectedIds)) {
      setState(() {
        _selectedIds = Set<String>.from(widget.parentSelectedIds);
      });
      _notifyParent();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _filterLetters();
    });
  }

  void _filterLetters() {
    final searchQuery = widget.searchController.text.trim().toLowerCase();

    setState(() {
      _filteredLetters = widget.allLetters.where((l) {
        final id = (l['employeeId'] ?? '').toString().toLowerCase();
        final name = (l['fullName'] ?? '').toString().toLowerCase();
        final pos = (l['position'] ?? '').toString().toLowerCase();

        bool matchesSearch = searchQuery.isEmpty || id.contains(searchQuery) || name.contains(searchQuery) || pos.contains(searchQuery);

        bool matchesMonth = true;
        bool matchesYear = true;
        final dateStr = l['createdAt']?.toString() ?? '';

        if (dateStr.isNotEmpty) {
          final dt = DateTime.parse(dateStr);
          final mName = widget.getMonthName(dt.month);
          final year = dt.year.toString();

          matchesYear = (widget.selectedYear == "All Years" || year == widget.selectedYear);
          matchesMonth = (widget.selectedMonth == "All Months") ? true : (mName == widget.selectedMonth);
        }
        return matchesSearch && matchesMonth && matchesYear;
      }).toList();
    });

    try {
      widget.onFilteredChanged(_filteredLetters);
    } catch (_) {}

    // Ensure selection only contains ids that still exist in filtered list
    final filteredIds = _filteredLetters.map((e) => e['_id']?.toString() ?? '').toSet();
    final toRemove = _selectedIds.where((id) => !filteredIds.contains(id)).toList();
    if (toRemove.isNotEmpty) {
      setState(() => _selectedIds.removeAll(toRemove));
      _notifyParent();
    }
  }

  void _toggleSelectAll(bool? v) {
    setState(() {
      if (v == true) {
        _selectedIds = _filteredLetters.map((e) => e['_id']?.toString() ?? '').toSet();
      } else {
        _selectedIds.clear();
      }
    });
    _notifyParent();
  }

  void _toggleRow(String id, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
    _notifyParent();
  }

  void _notifyParent() {
    final selected = _filteredLetters.where((l) => _selectedIds.contains(l['_id']?.toString() ?? '')).toList();
    try {
      widget.onSelectionChanged(selected);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (_filteredLetters.isEmpty) {
      return const Center(child: Text("No offer letters available.", style: TextStyle(color: Colors.black54)));
    }

    final allSelected = _filteredLetters.isNotEmpty && _selectedIds.length == _filteredLetters.length;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: screenWidth - 48),
          child: DataTable(
            columnSpacing: 40,
            headingRowHeight: 56,
            dataRowHeight: 56,
            columns: [
              DataColumn(
                label: Checkbox(
                  value: allSelected,
                  onChanged: _toggleSelectAll,
                  shape: const CircleBorder(),
                  fillColor: WidgetStateProperty.all(Colors.deepPurple),
                ),
              ),
              const DataColumn(label: Text("Sl.No", style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text("Employee ID", style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text("Position", style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text("Stipend/Salary", style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredLetters.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              final dateValue = item['createdAt']?.toString() ?? "";
              final idStr = item['_id']?.toString() ?? '';

              final checked = _selectedIds.contains(idStr);

              return DataRow(cells: [
                DataCell(
                  Checkbox(
                    value: checked,
                    onChanged: (v) => _toggleRow(idStr, v),
                    shape: const CircleBorder(),
                    fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) || checked ? Colors.deepPurple : Colors.grey.shade400),
                  ),
                ),
                DataCell(Text(idx.toString())),
                DataCell(Text(formatDate(dateValue))),
                DataCell(Text(item['employeeId']?.toString() ?? 'N/A')),
                DataCell(Text(item['fullName']?.toString() ?? 'N/A')),
                DataCell(Text(item['position']?.toString() ?? 'N/A')),
                DataCell(Text(item['stipend']?.toString() ?? 'N/A')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        tooltip: "Preview PDF",
                        icon: const Icon(Icons.picture_as_pdf, color: Color.fromARGB(255, 145, 89, 155)),
                        onPressed: () => widget.onPreview(item),
                      ),
                      // IconButton(
                      //   tooltip: "Edit Letter",
                      //   icon: const Icon(Icons.edit, color: Colors.blue),
                      //   onPressed: () => widget.onEdit(item),
                      // ),
                      IconButton(
                        tooltip: "Share (Gmail)",
                        icon: const Icon(Icons.share, color: Colors.deepPurpleAccent),
                        onPressed: () => widget.onShareSingle(item),
                      ),
                      IconButton(
                        tooltip: "Download",
                        icon: const Icon(Icons.download, color: Colors.deepPurpleAccent),
                        onPressed: () => widget.onDownloadSingle(item),
                      ),
                    ],
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
