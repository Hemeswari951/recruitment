// lib/experience_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import 'sidebar.dart';
import 'experience_certificate_pdf_service.dart';

class Experience {
  String? id;
  String companyName;
  String fullName;
  String position;
  String startDate;
  String endDate;
  String issuedAt;

  Experience({
    this.id,
    required this.companyName,
    required this.fullName,
    required this.position,
    required this.startDate,
    required this.endDate,
    required this.issuedAt,
  });

  factory Experience.fromJson(Map<String, dynamic> j) {
    return Experience(
      id: j['_id']?.toString() ?? j['id']?.toString(),
      companyName: j['companyName']?.toString() ?? '',
      fullName: j['fullName']?.toString() ?? '',
      position: j['position']?.toString() ?? '',
      startDate: j['startDate']?.toString() ?? '',
      endDate: j['endDate']?.toString() ?? '',
      issuedAt: j['issuedAt']?.toString() ?? j['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'companyName': companyName,
        'fullName': fullName,
        'position': position,
        'startDate': startDate,
        'endDate': endDate,
        'issuedAt': issuedAt,
      };
}

class ExperiencePage extends StatefulWidget {
  const ExperiencePage({super.key});

  @override
  State<ExperiencePage> createState() => _ExperiencePageState();
}

class _ExperiencePageState extends State<ExperiencePage> {
  final _fullNameController = TextEditingController();
  final _roleController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Replace with your backend base URL
  final String backendBaseUrl = "http://localhost:5000";

  List<Experience> _items = [];
  bool _loading = false;

  String selectedMonth = "All";
  String selectedYear = "All";
  Map<String, int> yearCounts = {};
  Map<String, int> monthCounts = {};
  // Note: removed parent's _debounce and _onSearchChanged to avoid parent rebuilds
  // Child table handles debouncing/filtering.

  static const List<String> _monthNames = [
    "All",
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
    selectedMonth = "All";
    selectedYear = "All";
    _loadExperiences();
    // IMPORTANT: do NOT attach a search listener here. The child table manages search listener/debounce.
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _roleController.dispose();
    _fromController.dispose();
    _toController.dispose();
    // do NOT try to remove parent's search listener (we didn't add one)
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExperiences() async {
    setState(() {
      _loading = true;
    });
    try {
      final apiUrl = Uri.parse('$backendBaseUrl/api/expericence');
      final resp = await http.get(apiUrl);
      if (resp.statusCode == 200) {
        final body = resp.body;
        final parsed = jsonDecode(body);
        List<dynamic> list;
        if (parsed is List) {
          list = parsed;
        } else if (parsed is Map && parsed['data'] is List) {
          list = parsed['data'];
        } else if (parsed is Map && parsed['experiences'] is List) {
          list = parsed['experiences'];
        } else {
          list = [];
        }
        _items = list.map((e) => Experience.fromJson(e)).toList();
        _computeCounts();
      } else {
        debugPrint('Load experiences failed: ${resp.statusCode} ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load experiences (server error).'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Load experiences error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load experiences: $e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _computeCounts() {
    monthCounts = {for (var m in _monthNames) m: 0};
    yearCounts.clear();

    if (_items.isNotEmpty) {
      yearCounts['All'] = _items.length;
    }

    for (var it in _items) {
      final dateStr = it.issuedAt;
      if (dateStr.isEmpty) continue;
      try {
        final dt = DateTime.parse(dateStr);
        final year = dt.year.toString();
        yearCounts[year] = (yearCounts[year] ?? 0) + 1;
      } catch (_) {
        // ignore parse errors
      }
    }

    if (!yearCounts.containsKey(selectedYear) && yearCounts.isNotEmpty) {
      // default to first year (keeps selection sensible)
      selectedYear = yearCounts.keys.first;
    }

    for (var it in _items) {
      final dateStr = it.issuedAt;
      if (dateStr.isEmpty) continue;
      try {
        final dt = DateTime.parse(dateStr);
        final year = dt.year.toString();
        final mName = _getMonthName(dt.month);
        if (selectedYear == 'All' || year == selectedYear) {
          monthCounts['All'] = (monthCounts['All'] ?? 0) + 1;
          monthCounts[mName] = (monthCounts[mName] ?? 0) + 1;
        }
      } catch (_) {}
    }

    if (!monthCounts.containsKey(selectedMonth) && monthCounts.isNotEmpty) {
      selectedMonth = monthCounts.keys.first;
    }

    setState(() {});
  }

  String _getMonthName(int m) {
    if (m >= 1 && m <= 12) return _monthNames[m];
    return 'All';
  }

  Future<void> _deleteExperience(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm delete'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final apiUrl = Uri.parse('$backendBaseUrl/api/expericence/$id');
      final resp = await http.delete(apiUrl);
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted.')));
        await _loadExperiences();
      } else {
        debugPrint('Delete failed: ${resp.statusCode} ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed.')));
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e')));
    }
  }

  Future<void> _downloadPdf(Experience exp) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final service = ExperienceCertificatePdfService();
      final bytes = await service.generateExperienceCertificate(
        companyName: exp.companyName,
        fullName: exp.fullName,
        position: exp.position,
        startDate: exp.startDate,
        endDate: exp.endDate,
      );

      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final safeName = exp.fullName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
        final filePath = '${dir.path}/${safeName}_experience.pdf';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        Navigator.of(context, rootNavigator: true).pop(); // close loader
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved PDF: $filePath')));
        try {
          await Printing.sharePdf(bytes: bytes, filename: '${safeName}_experience.pdf');
        } catch (e) {
          debugPrint('Printing.sharePdf error: $e');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF saved — open from file manager.')));
        }
      } else {
        // web: open print preview
        await Printing.layoutPdf(onLayout: (_) => bytes);
        Navigator.of(context, rootNavigator: true).pop(); // close loader
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opened print/preview for PDF (web).')));
      }
    } catch (e, st) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
      debugPrint('Error generating or saving PDF: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e')));
    }
  }

  // NOTE: updated to accept optional existingIssuedAt so edits preserve original issued date
  Future<void> _saveExperience({String? id, String? existingIssuedAt}) async {
    if (!_formKey.currentState!.validate()) return;

    final fullName = _fullNameController.text.trim();
    final position = _roleController.text.trim();
    final start = _fromController.text.trim();
    final end = _toController.text.trim();

    // generate PDF first (keeps the same behavior as old file)
    final pdfService = ExperienceCertificatePdfService();
    final pdfBytes = await pdfService.generateExperienceCertificate(
      companyName: 'ZeAI Soft',
      fullName: fullName,
      position: position,
      startDate: start,
      endDate: end,
      issuedAt: DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );

    // show loader while saving
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final base64Pdf = base64Encode(pdfBytes);

      // preserve existing issuedAt if provided (for edit), else use now
      final issuedAtForPayload = existingIssuedAt ?? DateTime.now().toIso8601String();

      final payload = {
        'companyName': 'ZeAI Soft',
        'fullName': fullName,
        'position': position,
        'startDate': start,
        'endDate': end,
        'issuedAt': issuedAtForPayload,
        'pdfBase64': base64Pdf,
        'fileName': '${fullName.replaceAll(' ', '_')}_experience.pdf',
      };

      Uri apiUrl;
      http.Response resp;
      if (id != null) {
        apiUrl = Uri.parse('$backendBaseUrl/api/expericence/$id');
        resp = await http.put(apiUrl, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      } else {
        apiUrl = Uri.parse('$backendBaseUrl/api/expericence');
        resp = await http.post(apiUrl, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      }

      Navigator.of(context, rootNavigator: true).pop(); // close loader

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved experience and PDF.')));

        // save locally for convenience (optional) and open print/etc
        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          final safeName = fullName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
          final filePath = '${dir.path}/${safeName}_experience.pdf';
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved PDF: $filePath')));
        } else {
          // on web show print preview
          await Printing.layoutPdf(onLayout: (_) => pdfBytes);
        }

        // close form dialog (if any)
        if (Navigator.canPop(context)) Navigator.of(context).pop();
        await _loadExperiences();
      } else {
        debugPrint('Save failed: ${resp.statusCode} ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save failed (server).')));
      }
    } catch (e, st) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
      debugPrint('Save experience error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  Future<void> _showExperienceDialog({Experience? exp}) async {
    // prefill if editing
    if (exp != null) {
      _fullNameController.text = exp.fullName;
      _roleController.text = exp.position;
      _fromController.text = exp.startDate;
      _toController.text = exp.endDate;
    } else {
      _fullNameController.clear();
      _roleController.clear();
      _fromController.clear();
      _toController.clear();
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(exp == null ? 'Generate Experience Certificate' : 'Edit Experience'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Company (fixed)
                  Row(
                    children: const [
                      Text('Company: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text('ZeAI Soft')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Employee name', hintText: 'Enter name'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _roleController,
                    decoration: const InputDecoration(labelText: 'Role', hintText: 'Enter role / position'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter role' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fromController,
                    readOnly: true,
                    onTap: () => _pickDate(_fromController),
                    decoration: const InputDecoration(labelText: 'From (start date)', hintText: 'dd/mm/yyyy'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Select start date' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _toController,
                    readOnly: true,
                    onTap: () => _pickDate(_toController),
                    decoration: const InputDecoration(labelText: 'To (end date)', hintText: 'dd/mm/yyyy'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Select end date' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              // pass existing issuedAt when editing so we don't overwrite it
              onPressed: () => _saveExperience(id: exp?.id, existingIssuedAt: exp?.issuedAt),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    try {
      if (controller.text.isNotEmpty) {
        initial = DateFormat('dd/MM/yyyy').parse(controller.text);
      }
    } catch (_) {}
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _exportFilteredPdf() async {
    try {
      final filtered = _items.where((it) => _isMatchingFilters(it, _searchController.text.trim())).toList();
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No records to export.')));
        return;
      }

      final doc = pw.Document();
      for (final e in filtered) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context ctx) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Experience Certificate',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Company: ${e.companyName}'),
                    pw.Text('Employee: ${e.fullName}'),
                    pw.Text('Position: ${e.position}'),
                    pw.SizedBox(height: 6),
                    pw.Text('Start Date: ${e.startDate}'),
                    pw.Text('End Date: ${e.endDate}'),
                    pw.SizedBox(height: 6),
                    pw.Text('Issued At: ${e.issuedAt}'),
                  ],
                ),
              );
            },
          ),
        );
      }

      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'experience_report_${selectedMonth}_$selectedYear.pdf');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF exported successfully!')));
    } catch (e) {
      debugPrint('Export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
    }
  }

  bool _isMatchingFilters(Experience e, String searchQuery) {
    final q = searchQuery.toLowerCase();
    final id = (e.id ?? '').toLowerCase();
    final name = e.fullName.toLowerCase();
    final pos = e.position.toLowerCase();

    final matchesSearch = q.isEmpty || id.contains(q) || name.contains(q) || pos.contains(q);

    bool matchesMonth = true;
    bool matchesYear = true;
    final dateStr = e.issuedAt;
    if (dateStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateStr);
        final mName = _getMonthName(dt.month);
        final year = dt.year.toString();
        matchesYear = (selectedYear == 'All' || year == selectedYear);
        matchesMonth = (selectedMonth == 'All' || mName == selectedMonth);
      } catch (_) {}
    }

    return matchesSearch && matchesMonth && matchesYear;
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _items.where((it) {
      if (it.issuedAt.isEmpty) return false;
      try {
        final dt = DateTime.parse(it.issuedAt);
        return selectedYear == 'All' || dt.year.toString() == selectedYear;
      } catch (_) {
        return false;
      }
    }).length;

    return Sidebar(
      title: 'Experience Certificates',
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          children: [
            // Top action row above the card (keeps the old "Get your certificate")
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showExperienceDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Get your certificate'),
                ),
                const SizedBox(width: 12),
                // REMOVED the top-level Refresh button here (as requested).
                const Spacer(),
                if (_loading) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header row: title + total count + dropdown + refresh (in header) + export
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.work_outline,
                                color: Color.fromARGB(255, 145, 89, 155),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Experience Certificates',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$totalCount Records',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 158, 27, 219),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Year dropdown
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                              color: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: yearCounts.containsKey(selectedYear)
                                    ? selectedYear
                                    : (yearCounts.keys.isNotEmpty ? yearCounts.keys.first : 'All'),
                                isDense: true,
                                icon: const Icon(
                                  Icons.expand_more_rounded,
                                  size: 24,
                                  color: Color.fromARGB(255, 145, 89, 155),
                                ),
                                items: yearCounts.keys.toList().map((y) {
                                  return DropdownMenuItem<String>(
                                    value: y,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                          color: Color.fromARGB(255, 145, 89, 155),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          y,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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

                          // Month dropdown
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                              color: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: monthCounts.containsKey(selectedMonth) ? selectedMonth : 'All',
                                isDense: true,
                                icon: const Icon(
                                  Icons.expand_more_rounded,
                                  size: 24,
                                  color: Color.fromARGB(255, 145, 89, 155),
                                ),
                                items: _monthNames.map((m) {
                                  final count = monthCounts[m] ?? 0;
                                  return DropdownMenuItem<String>(
                                    value: m,
                                    child: SizedBox(
                                      width: 110,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              m,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              count.toString(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color.fromARGB(255, 145, 89, 155),
                                              ),
                                            ),
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

                          IconButton(
                            icon: const Icon(Icons.download, color: Color.fromARGB(255, 145, 89, 155)),
                            tooltip: 'Export to PDF',
                            onPressed: _exportFilteredPdf,
                          ),
                          const SizedBox(width: 10),
                          // Keep refresh here (inside header/table) — this is the one refresh we keep.
                          IconButton(
                            tooltip: 'Refresh',
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              // close keyboard if open
                              FocusScope.of(context).unfocus();

                              // clear search and reset filters so refresh shows full list
                              setState(() {
                                _searchController.clear();
                                selectedMonth = 'All';
                                selectedYear = 'All';
                              });

                              // reload from backend and rebuild
                              await _loadExperiences();

                              // ensure UI updates immediately
                              setState(() {});
                            },
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
                          hintText: 'Search by Name or Position...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                    ),

                    // Table of filtered experiences (child manages search listener/debounce)
                    Expanded(
                      child: _ExperienceDataTable(
                        allItems: _items,
                        searchController: _searchController,
                        selectedMonth: selectedMonth,
                        selectedYear: selectedYear,
                        getMonthName: _getMonthName,
                        onDownload: _downloadPdf,
                        onEdit: (exp) => _showExperienceDialog(exp: exp),
                        onDelete: (id) => _deleteExperience(id),
                      ),
                    ),

                    // Close button
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

class _ExperienceDataTable extends StatefulWidget {
  final List<Experience> allItems;
  final TextEditingController searchController;
  final String selectedMonth;
  final String selectedYear;
  final String Function(int) getMonthName;
  final void Function(Experience) onDownload;
  final void Function(Experience) onEdit;
  final void Function(String) onDelete;

  const _ExperienceDataTable({
    required this.allItems,
    required this.searchController,
    required this.selectedMonth,
    required this.selectedYear,
    required this.getMonthName,
    required this.onDownload,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ExperienceDataTable> createState() => _ExperienceDataTableState();
}

// class _ExperienceDataTableState extends State<_ExperienceDataTable> {
//   List<Experience> _filtered = [];
//   Timer? _debounce;
class _ExperienceDataTableState extends State<_ExperienceDataTable> {
  List<Experience> _filtered = [];
  Timer? _debounce;
  final ScrollController _verticalController = ScrollController();


  @override
  void initState() {
    super.initState();
    _filter();
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _ExperienceDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allItems != oldWidget.allItems ||
        widget.searchController.text != oldWidget.searchController.text ||
        widget.selectedMonth != oldWidget.selectedMonth ||
        widget.selectedYear != oldWidget.selectedYear) {
      _filter();
    }
    // If parent replaced the searchController instance, rewire listener
    if (widget.searchController != oldWidget.searchController) {
      try {
        oldWidget.searchController.removeListener(_onSearchChanged);
      } catch (_) {}
      widget.searchController.addListener(_onSearchChanged);
    }
  }

    @override
  void dispose() {
    try {
      widget.searchController.removeListener(_onSearchChanged);
    } catch (_) {}
    _debounce?.cancel();
    _verticalController.dispose();
    super.dispose();
  }


  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _filter);
  }

  void _filter() {
    final q = widget.searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.allItems.where((e) {
        final name = e.fullName.toLowerCase();
        final pos = e.position.toLowerCase();
        final id = (e.id ?? '').toLowerCase();
        final matchesSearch = q.isEmpty || name.contains(q) || pos.contains(q) || id.contains(q);

        bool matchesMonth = true;
        bool matchesYear = true;
        final dateStr = e.issuedAt;
        if (dateStr.isNotEmpty) {
          try {
            final dt = DateTime.parse(dateStr);
            final mName = widget.getMonthName(dt.month);
            final year = dt.year.toString();
            matchesYear = (widget.selectedYear == 'All' || year == widget.selectedYear);
            matchesMonth = (widget.selectedMonth == 'All' || mName == widget.selectedMonth);
          } catch (_) {}
        }

        return matchesSearch && matchesMonth && matchesYear;
      }).toList();
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_filtered.isEmpty) {
      return const Center(child: Text('No experiences available.'));
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController, // attach same controller
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: screenWidth - 48),
            child: DataTable(
              columnSpacing: 30,
              headingRowHeight: 56,
              dataRowHeight: 64,
              columns: const [
                DataColumn(label: Text('Sl.No', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Issued Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Position', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('End Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _filtered.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final it = entry.value;
                return DataRow(cells: [
                  DataCell(Text(idx.toString())),
                  DataCell(Text(_formatDate(it.issuedAt))),
                  DataCell(Text(it.fullName)),
                  DataCell(Text(it.position)),
                  DataCell(Text(it.startDate)),
                  DataCell(Text(it.endDate)),
                  DataCell(Row(
                    children: [
                      IconButton(
                        tooltip: 'Download PDF',
                        icon: const Icon(Icons.picture_as_pdf, color: Color.fromARGB(255, 145, 89, 155)),
                        onPressed: () => widget.onDownload(it),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => widget.onEdit(it),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: it.id == null ? null : () => widget.onDelete(it.id!),
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
