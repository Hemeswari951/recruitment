import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:printing/printing.dart';
import 'sidebar.dart';
import 'package:intl/intl.dart';
import 'revised_offer_letter_pdf_service.dart';
import 'revised_pdf_content_model.dart';

class ViewRevisedOfferPage extends StatefulWidget {
  const ViewRevisedOfferPage({super.key});

  @override
  State<ViewRevisedOfferPage> createState() => _ViewRevisedOfferPageState();
}

class _ViewRevisedOfferPageState extends State<ViewRevisedOfferPage> {
  List<dynamic> _revisedOffers = [];
  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _yearCounts = {};
  Map<String, int> _monthCounts = {};
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();

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

  String _selectedMonth = "All Months";
  String _selectedYear = "All Years";

  @override
  void initState() {
    super.initState();
    _fetchRevisedOffers();
  }

  Future<void> _fetchRevisedOffers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/revisedofferletter'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _revisedOffers = json.decode(response.body);
          _computeCounts(); // This will trigger a rebuild, and the table will filter itself
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load revised offer letters');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _computeCounts() {
    final newYearCounts = <String, int>{"All Years": 0};
    final newMonthCounts = <String, int>{for (var m in _monthNames) m: 0};

    for (var offer in _revisedOffers) {
      final dateStr = offer['createdAt']?.toString();
      if (dateStr == null) continue;
      try {
        final dt = DateTime.parse(dateStr);
        newYearCounts["All Years"] = (newYearCounts["All Years"] ?? 0) + 1;
        final year = dt.year.toString();
        newYearCounts[year] = (newYearCounts[year] ?? 0) + 1;
      } catch (_) {
        // Ignore parsing errors
      }
    }

    if (!newYearCounts.containsKey(_selectedYear)) {
      _selectedYear = "All Years";
    }

    final offersForMonthCount = _revisedOffers.where((offer) {
      final dateStr = offer['createdAt']?.toString();
      if (dateStr != null) {
        if (_selectedYear == "All Years" ||
            DateTime.parse(dateStr).year.toString() == _selectedYear) {
          return true;
        }
      }
      return false;
    }).toList();

    newMonthCounts["All Months"] = offersForMonthCount.length;
    for (var offer in offersForMonthCount) {
      try {
        final dt = DateTime.parse(offer['createdAt']);
        newMonthCounts[_monthNames[dt.month]] =
            (newMonthCounts[_monthNames[dt.month]] ?? 0) + 1;
      } catch (_) {
        // Ignore parsing errors
      }
    }

    _yearCounts = newYearCounts;
    _monthCounts = newMonthCounts;
  }

  Future<void> _exportFilteredPdf() async {
    // This is a simplified version. For an exact match, you'd need a way
    // for the DataTable to expose its currently filtered list.
    // For now, we re-filter here for the export.
    try {
      final pdfService = RevisedOfferLetterPdfService();
      final pdfBytes = await pdfService.exportRevisedOfferLetterList(
        _revisedOffers.map((e) => Map<String, dynamic>.from(e)).toList(),
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'revised_offer_letters_${_selectedYear}_$_selectedMonth.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to export PDF: $e")));
    }
  }

  Future<void> _viewPdf(String pdfBase64) async {
    try {
      final pdfBytes = base64Decode(pdfBase64);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not display PDF: $e')));
    }
  }

  Future<void> _deleteRevisedOffer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
          'Are you sure you want to delete this revised offer letter? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('http://localhost:5000/api/revisedofferletter/$id'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revised offer deleted successfully!')),
        );
        _fetchRevisedOffers(); // Refresh the list
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to delete revised offer');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> offer) async {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController(text: offer['fullName']);
    final employeeIdController = TextEditingController(
      text: offer['employeeId'],
    );
    final fromPositionController = TextEditingController(
      text: offer['fromposition'],
    );
    final positionController = TextEditingController(text: offer['position']);
    final stipendController = TextEditingController(text: offer['stipend']);
    final ctcController = TextEditingController(text: offer['ctc']);
    final dojController = TextEditingController(text: offer['doj']);
    final signdateController = TextEditingController(text: offer['signdate']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Revised Offer'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                TextFormField(
                  controller: employeeIdController,
                  decoration: const InputDecoration(labelText: 'Employee ID'),
                ),
                TextFormField(
                  controller: fromPositionController,
                  decoration: const InputDecoration(
                    labelText: 'Previous Position',
                  ),
                ),
                TextFormField(
                  controller: positionController,
                  decoration: const InputDecoration(labelText: 'Position'),
                ),
                TextFormField(
                  controller: stipendController,
                  decoration: const InputDecoration(labelText: 'Salary'),
                ),
                TextFormField(
                  controller: ctcController,
                  decoration: const InputDecoration(labelText: 'CTC'),
                ),
                TextFormField(
                  controller: dojController,
                  decoration: const InputDecoration(
                    labelText: 'Date of Joining',
                  ),
                ),
                TextFormField(
                  controller: signdateController,
                  decoration: const InputDecoration(labelText: 'Signed Date'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(); // Close dialog before processing
                await _updateRevisedOffer(offer['_id'], {
                  'fullName': fullNameController.text,
                  'employeeId': employeeIdController.text,
                  'fromposition': fromPositionController.text,
                  'position': positionController.text,
                  'stipend': stipendController.text,
                  'ctc': ctcController.text,
                  'doj': dojController.text,
                  'signdate': signdateController.text,
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRevisedOffer(
    String id,
    Map<String, String> updatedData,
  ) async {
    try {
      // 1. Regenerate the PDF with the updated data
      final pdfService = RevisedOfferLetterPdfService();
      final pdfBytes = await pdfService.generateRevisedOfferLetter(
        fullName: updatedData['fullName']!,
        employeeId: updatedData['employeeId']!,
        fromposition: updatedData['fromposition']!,
        position: updatedData['position']!,
        stipend: updatedData['stipend']!,
        ctc: updatedData['ctc']!,
        doj: updatedData['doj']!,
        signdate: updatedData['signdate']!,
        content: RevisedPdfContentModel(), // Use default or fetched template
      );
      final pdfBase64 = base64Encode(pdfBytes);

      // 2. Send the updated data and new PDF to the backend
      final body = {...updatedData, 'pdfFile': pdfBase64};

      final response = await http.put(
        Uri.parse('http://localhost:5000/api/revisedofferletter/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Update successful!')));
        _fetchRevisedOffers(); // Refresh list
      } else {
        throw Exception(
          'Failed to update. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _revisedOffers.where((offer) {
      final dateStr = offer['createdAt']?.toString();
      if (dateStr == null) return false;
      try {
        final dt = DateTime.parse(dateStr);
        return _selectedYear == "All Years" ||
            dt.year.toString() == _selectedYear;
      } catch (_) {
        return false;
      }
    }).length;

    return Sidebar(
      title: 'View Revised Offer Letters',
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
                    _buildHeader(totalCount),
                    const SizedBox(height: 12),
                    _buildSearchBar(),
                    const SizedBox(height: 8),
                    Expanded(child: _buildBody()),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"),
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

  Widget _buildHeader(int totalCount) {
    return Row(
      children: [
        const Icon(
          Icons.note_add_outlined,
          color: Color.fromARGB(255, 145, 89, 155),
          size: 22,
        ),
        const SizedBox(width: 8),
        const Text(
          "Revised Offer Letters",
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
            "$totalCount Records",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color.fromARGB(255, 158, 27, 219),
            ),
          ),
        ),
        const Spacer(),
        _buildFilterDropdown(_yearCounts, _selectedYear, (val) {
          if (val == null) return;
          setState(() {
            _selectedYear = val;
            _computeCounts(); // This will trigger a rebuild and re-filter in the child
          });
        }),
        const SizedBox(width: 10),
        _buildFilterDropdown(_monthCounts, _selectedMonth, (val) {
          if (val == null) return;
          setState(() {
            _selectedMonth = val;
          });
        }),
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
          onPressed: _fetchRevisedOffers,
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    Map<String, int> counts,
    String selectedValue,
    void Function(String?) onChanged,
  ) {
    return Container(
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
          value: selectedValue,
          isDense: true,
          icon: const Icon(
            Icons.expand_more_rounded,
            size: 24,
            color: Color.fromARGB(255, 145, 89, 155),
          ),
          items: counts.keys.map((key) {
            return DropdownMenuItem<String>(
              value: key,
              child: SizedBox(
                width: 110,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        key,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        (counts[key] ?? 0).toString(),
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
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: TextField(
        controller: _searchController, // The listener is in the DataTable now
        // No focus node or onChanged needed here anymore
        decoration: InputDecoration(
          hintText: "Search by ID, Name or Position...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRevisedOffers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return _RevisedOfferDataTable(
      allOffers: _revisedOffers,
      searchController: _searchController,
      selectedMonth: _selectedMonth,
      selectedYear: _selectedYear,
      monthNames: _monthNames,
      onViewPdf: _viewPdf,
      onEdit: _showEditDialog,
      onDelete: _deleteRevisedOffer,
    );
  }
}

class _RevisedOfferDataTable extends StatefulWidget {
  final List<dynamic> allOffers;
  final TextEditingController searchController;

  final String selectedMonth;
  final String selectedYear;
  final List<String> monthNames;
  final Function(String) onViewPdf;
  final Function(Map<String, dynamic>) onEdit;
  final Function(String) onDelete;

  const _RevisedOfferDataTable({
    required this.allOffers,
    required this.searchController,
    required this.selectedMonth,
    required this.selectedYear,
    required this.monthNames,
    required this.onViewPdf,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_RevisedOfferDataTable> createState() => _RevisedOfferDataTableState();
}

class _RevisedOfferDataTableState extends State<_RevisedOfferDataTable> {
  List<dynamic> _filteredOffers = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _filterOffers();
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _RevisedOfferDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allOffers != oldWidget.allOffers ||
        widget.selectedMonth != oldWidget.selectedMonth ||
        widget.selectedYear != oldWidget.selectedYear) {
      _filterOffers();
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
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filterOffers();
    });
  }

  void _filterOffers() {
    final searchQuery = widget.searchController.text.trim().toLowerCase();
    setState(() {
      _filteredOffers = widget.allOffers.where((offer) {
        final name = (offer['fullName'] ?? '').toLowerCase();
        final id = (offer['employeeId'] ?? '').toLowerCase();
        final pos = (offer['position'] ?? '').toLowerCase();
        final fromPos = (offer['fromposition'] ?? '').toLowerCase();
        final matchesSearch =
            name.contains(searchQuery) ||
            id.contains(searchQuery) ||
            pos.contains(searchQuery) ||
            fromPos.contains(searchQuery);

        final dateStr = offer['createdAt']?.toString();
        if (dateStr == null) return matchesSearch;

        try {
          final dt = DateTime.parse(dateStr);
          final matchesYear =
              widget.selectedYear == "All Years" ||
              dt.year.toString() == widget.selectedYear;
          final matchesMonth =
              widget.selectedMonth == "All Months" ||
              widget.monthNames[dt.month] == widget.selectedMonth;
          return matchesSearch && matchesYear && matchesMonth;
        } catch (_) {
          return matchesSearch;
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredOffers.isEmpty) {
      return const Center(child: Text('No revised offer letters found.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Employee ID')),
                DataColumn(label: Text('Full Name')),
                DataColumn(label: Text('Previous Position')),
                DataColumn(label: Text('Position')),
                DataColumn(label: Text('Salary')),
                DataColumn(label: Text('Date of Joining')),
                DataColumn(label: Text('Created At')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _filteredOffers.map((offer) {
                return DataRow(
                  cells: [
                    DataCell(Text(offer['employeeId'] ?? 'N/A')),
                    DataCell(Text(offer['fullName'] ?? 'N/A')),
                    DataCell(Text(offer['fromposition'] ?? 'N/A')),
                    DataCell(Text(offer['position'] ?? 'N/A')),
                    DataCell(Text(offer['stipend'] ?? 'N/A')),
                    DataCell(Text(offer['doj'] ?? 'N/A')),
                    DataCell(
                      Text(
                        offer['createdAt'] != null
                            ? DateFormat(
                                'dd-MM-yyyy',
                              ).format(DateTime.parse(offer['createdAt']))
                            : 'N/A',
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.picture_as_pdf,
                              color: Color.fromARGB(255, 145, 89, 155),
                            ),
                            tooltip: 'View PDF',
                            onPressed: () => widget.onViewPdf(offer['pdfFile']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Edit',
                            onPressed: () => widget.onEdit(offer),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () => widget.onDelete(offer['_id']),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}