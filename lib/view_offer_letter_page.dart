import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'sidebar.dart';
import 'offer_letter_pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
// import 'offer_letter_pdf_service.dart';

import 'package:flutter/material.dart'; // Ensure this is imported

class ViewOfferLetterPage extends StatefulWidget {
  const ViewOfferLetterPage({super.key});

  @override
  State<ViewOfferLetterPage> createState() => _ViewOfferLetterPageState();
}

class _ViewOfferLetterPageState extends State<ViewOfferLetterPage> {
  List<Map<String, dynamic>> letters = [];
  final TextEditingController _searchController = TextEditingController();

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

    selectedMonth = "All Months"; // Default to "All" months
    selectedYear = "All Years"; // Default to "All" years

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
      final res = await http.get(
        Uri.parse("http://localhost:5000/api/offerletter"),
      );
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        if (body["success"] == true) {
          final List<dynamic> data = body["letters"] ?? [];
          setState(() {
            letters = data.map((e) => Map<String, dynamic>.from(e)).toList();
            _computeCounts(); // Recompute counts after fetching letters
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
    // Reset months & years
    monthCounts = {for (var m in _monthNames) m: 0}; // Include "All" in reset
    yearCounts.clear();

    // Add "All" option for years
    if (letters.isNotEmpty) {
      yearCounts["All Years"] = letters.length;
    }

    // First count all years
    for (var l in letters) {
      final dateStr = l['createdAt']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;

      final dt = DateTime.parse(dateStr);
      final year = dt.year.toString();
      yearCounts[year] = (yearCounts[year] ?? 0) + 1;
    }

    // Default year selection
    if (!yearCounts.containsKey(selectedYear) && yearCounts.isNotEmpty) {
      selectedYear = yearCounts.keys.first;
    }

    // Now count months ONLY for selected year
    for (var l in letters) {
      final dateStr = l['createdAt']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;

      final dt = DateTime.parse(dateStr);
      final year = dt.year.toString();
      final mName = _getMonthName(dt.month);

      if (selectedYear == "All Years" || year == selectedYear) {
        monthCounts["All Months"] =
            (monthCounts["All Months"] ?? 0) + 1; // Increment "All" count
        monthCounts[mName] = (monthCounts[mName] ?? 0) + 1;
      }
    }

    // Default month selection
    if (!monthCounts.containsKey(selectedMonth) && monthCounts.isNotEmpty) {
      selectedMonth = monthCounts.keys.first;
    }
  }

  String _getMonthName(int m) {
    if (m >= 1 && m <= 12) {
      return _monthNames[m]; // Adjust index for actual months
    }
    return "All Months"; // Fallback or for "All" option
  }

  void _editOfferLetter(Map<String, dynamic> item) {
    final nameController = TextEditingController(text: item['fullName'] ?? '');
    final idController = TextEditingController(text: item['employeeId'] ?? '');
    final positionController = TextEditingController(
      text: item['position'] ?? '',
    );
    final stipendController = TextEditingController(
      text: item['stipend']?.toString() ?? '',
    );
    final dojController = TextEditingController(
      text: item['joiningDate']?.toString() ?? '',
    );
    final signdateController = TextEditingController(
      text: item['signedDate']?.toString() ?? '',
    );

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
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Full Name"),
                ),
                TextField(
                  controller: idController, readOnly: true,
                  decoration: const InputDecoration(labelText: "Employee ID"),
                ),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(labelText: "Position"),
                ),
                TextField(
                  controller: stipendController,
                  decoration: const InputDecoration(
                    labelText: "Stipend/Salary",
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: dojController,
                  decoration: const InputDecoration(
                    labelText: "Date of Joining",
                  ),
                ),
                TextField(
                  controller: signdateController,
                  decoration: const InputDecoration(labelText: "Signed Date"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateOfferLetter(
                  id: item['_id'],
                  fullName: nameController.text.trim(),
                  employeeId: item['employeeId'],
                  position: positionController.text.trim(),
                  stipend: stipendController.text.trim(),
                  doj: dojController.text.trim(),
                  signdate: signdateController.text.trim(),
                );
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ---------------------- API UPDATE CALL ------------------------

  Future<void> _updateOfferLetter({
    required String id,
    required String fullName,
    required String employeeId,
    required String position,
    required String stipend,
    required String doj,
    required String signdate,
  }) async {
    final url = Uri.parse("http://localhost:5000/api/offerletter/$id");

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "fullName": fullName,
          "employeeId": employeeId,
          "position": position,
          "stipend": stipend,
          "joiningDate": doj,
          "signedDate": signdate,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Updated successfully!")));
        fetchLetters();
      }
    } catch (e) {
      debugPrint("ERROR: $e");
    }
  }

  Future<void> _previewPdf(Map<String, dynamic> item) async {
    try {
      final pdfUrl = item['pdfUrl'];
      if (pdfUrl == null || pdfUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No PDF file found for this letter.")),
          );
        }
        return;
      }

      // Construct the full URL and fetch the stored PDF from the backend
      final fullUrl = Uri.parse("http://localhost:5000$pdfUrl");
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
            child: PdfPreview(
              build: (format) => pdfBytes,
              canChangeOrientation: false,
              canDebug: false,
              useActions: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to open preview: $e")));
    }
  }

  Future<void> _exportFilteredPdf() async {
    try {
      final pdfService =
          OfferLetterPdfService(); // Assuming _OfferLetterDataTable has a way to expose its filtered list or we pass all filters to the service
      final pdfBytes = await pdfService.exportOfferLetterList(
        letters
            .where(
              (l) => _isLetterMatchingFilters(l, _searchController.text.trim()),
            )
            .toList(),
      );

      if (!mounted) return;

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'offer_letters_report_${selectedMonth}_$selectedYear.pdf',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF exported successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to export PDF: $e")));
    }
  }

  // Helper to check if a letter matches current filters (used for export)
  bool _isLetterMatchingFilters(Map<String, dynamic> l, String searchQuery) {
    final id = (l['employeeId'] ?? '').toString().toLowerCase();
    final name = (l['fullName'] ?? '').toString().toLowerCase();
    final pos = (l['position'] ?? '').toString().toLowerCase();

    bool matchesSearch =
        searchQuery.isEmpty ||
        id.contains(searchQuery) ||
        name.contains(searchQuery) ||
        pos.contains(searchQuery);

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
    // total count of all letters
    final totalLettersCount = letters.where((l) {
      final dateStr = l['createdAt']?.toString() ?? '';
      if (dateStr.isEmpty) return false;

      final dt = DateTime.parse(dateStr);
      return selectedYear == "All Years" || dt.year.toString() == selectedYear;
    }).length;

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
                    // Header row: title + total count + dropdown + refresh
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          // Title + total count
                          Row(
                            children: [
                              const Icon(
                                Icons.description_rounded,
                                color: Color.fromARGB(255, 145, 89, 155),
                                size: 22,
                              ),
                              const SizedBox(width: 8),

                              const Text(
                                "Offer Letters",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  letterSpacing: 0.3,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "$totalLettersCount Records",
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

                          // ✔ Year Dropdown
                          // ✅ Professional Year Dropdown
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                30,
                              ), // pill shape
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedYear,
                                isDense: true,
                                icon: const Icon(
                                  // tooltip: "Select Year",
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
                                          color: Color.fromARGB(
                                            255,
                                            145,
                                            89,
                                            155,
                                          ),
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
                                  // Filtering will be handled by the child table
                                },
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),
                          // Dropdown for month counts
                          // ✅ Professional Month Dropdown
                          // ✅ Professional Month Dropdown
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedMonth,
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
                                      width:
                                          110, // fixed width for clean alignment
                                      child: Row(
                                        children: [
                                          // Month Name - Left
                                          Expanded(
                                            child: Text(
                                              m,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),

                                          // Count Badge - Right
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(
                                                0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              count.toString(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color.fromARGB(
                                                  255,
                                                  145,
                                                  89,
                                                  155,
                                                ),
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
                                  // Filtering will be handled by the child table
                                },
                              ),
                            ),
                          ),

                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.download,
                              color: Color.fromARGB(255, 145, 89, 155),
                            ),
                            tooltip: "Export to PDF",
                            onPressed: _exportFilteredPdf,
                          ),

                          const SizedBox(width: 10),

                          IconButton(
                            tooltip: "Refresh",
                            icon: const Icon(Icons.refresh),
                            onPressed: fetchLetters,
                          ),
                        ],
                      ),
                    ),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 3,
                        right: 3,
                        bottom: 8,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search by ID, Name or Position...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                    ),

                    // Table of filtered letters
                    Expanded(
                      child: _OfferLetterDataTable(
                        allLetters: letters, // Pass the full list
                        searchController: _searchController,
                        selectedMonth: selectedMonth,
                        selectedYear: selectedYear,
                        getMonthName: _getMonthName,
                        onPreview: _previewPdf,
                        onEdit: _editOfferLetter,
                      ),
                    ),

                    // ✔ Bottom-Right Close Button Added
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Close",
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

class _OfferLetterDataTable extends StatefulWidget {
  final List<Map<String, dynamic>> allLetters;
  final TextEditingController searchController;
  final String selectedMonth;
  final String selectedYear;
  final String Function(int) getMonthName;
  final void Function(Map<String, dynamic>) onPreview;
  final void Function(Map<String, dynamic>) onEdit;

  const _OfferLetterDataTable({
    required this.allLetters,
    required this.searchController,
    required this.selectedMonth,
    required this.selectedYear,
    required this.getMonthName,
    required this.onPreview,
    required this.onEdit,
  });

  @override
  State<_OfferLetterDataTable> createState() => _OfferLetterDataTableState();
}

class _OfferLetterDataTableState extends State<_OfferLetterDataTable> {
  List<Map<String, dynamic>> _filteredLetters = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _filterLetters();
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _OfferLetterDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-filter if any of the filtering parameters change
    if (widget.allLetters != oldWidget.allLetters ||
        widget.searchController.text != oldWidget.searchController.text ||
        widget.selectedMonth != oldWidget.selectedMonth ||
        widget.selectedYear != oldWidget.selectedYear) {
      _filterLetters();
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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat("dd-MM-yyyy").format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _filterLetters() {
    final searchQuery = widget.searchController.text.trim().toLowerCase();

    setState(() {
      _filteredLetters = widget.allLetters.where((l) {
        final id = (l['employeeId'] ?? '').toString().toLowerCase();
        final name = (l['fullName'] ?? '').toString().toLowerCase();
        final pos = (l['position'] ?? '').toString().toLowerCase();

        bool matchesSearch =
            searchQuery.isEmpty ||
            id.contains(searchQuery) ||
            name.contains(searchQuery) ||
            pos.contains(searchQuery);

        bool matchesMonth = true;
        bool matchesYear = true;
        final dateStr = l['createdAt']?.toString() ?? '';

        if (dateStr.isNotEmpty) {
          final dt = DateTime.parse(dateStr);
          final mName = widget.getMonthName(dt.month);
          final year = dt.year.toString();

          matchesYear =
              (widget.selectedYear == "All Years" ||
              year == widget.selectedYear);
          if (widget.selectedMonth == "All Months") {
            matchesMonth = true; // Don't filter by month if "All" is selected
          } else {
            matchesMonth = (mName == widget.selectedMonth);
          }
        }
        return matchesSearch && matchesMonth && matchesYear;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (_filteredLetters.isEmpty) {
      return const Center(
        child: Text(
          "No offer letters available.",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: screenWidth - 48),
          child: DataTable(
            columnSpacing: 40,
            headingRowHeight: 56,
            dataRowHeight: 56,
            columns: const [
              DataColumn(
                label: Text(
                  "Sl.No",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Date",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Employee ID",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Name",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Position",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Stipend/Salary",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Actions",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: _filteredLetters.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              final dateValue = item['createdAt']?.toString() ?? "";
              return DataRow(
                cells: [
                  DataCell(Text(idx.toString())),
                  DataCell(Text(_formatDate(dateValue))),
                  DataCell(Text(item['employeeId']?.toString() ?? 'N/A')),
                  DataCell(Text(item['fullName']?.toString() ?? 'N/A')),
                  DataCell(Text(item['position']?.toString() ?? 'N/A')),
                  DataCell(Text(item['stipend']?.toString() ?? 'N/A')),
                  // DataCell(Text(item['joiningDate']?.toString() ?? 'N/A')),
                  // DataCell(Text(item['signedDate']?.toString() ?? 'N/A')),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: "Preview PDF",
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Color.fromARGB(255, 145, 89, 155),
                          ),
                          onPressed: () => widget.onPreview(item),
                        ),
                        IconButton(
                          tooltip: "Edit Letter",
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => widget.onEdit(item),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}