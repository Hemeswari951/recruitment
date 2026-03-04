// lib/on_campus_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:html' as html; // for web download anchor
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;

import '../sidebar.dart';
import '../services/oncampus_service.dart';
import '../student_details_page.dart';

class OnCampusPage extends StatefulWidget {
  const OnCampusPage({super.key});

  @override
  State<OnCampusPage> createState() => _OnCampusPageState();
}

class _OnCampusPageState extends State<OnCampusPage> {
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  List<Map<String, dynamic>> _drives = [];
  List<Map<String, dynamic>> _filteredDrives = [];
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;

  // search filter options
  final String _searchField = 'All';
  final List<String> _searchFields = [
    'All',
    'Date',
    'College',
    'Position',
    'BG Verification',
    'Contact Person',
  ];

  // Dropdown options
  final List<String> _bgOptions = [
    'Pending',
    'In Progress',
    'Verified',
    'Unable to Verify',
  ];
  final List<String> _positionOptions = ['Intern', 'Tech Trainee'];

  @override
  void initState() {
    super.initState();
    _loadDrives();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDrives() async {
    setState(() => _loading = true);
    try {
      final data = await OnCampusService.fetchDrives();
      setState(() {
        _drives = data
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
        _filteredDrives = List.from(_drives); // Keep for initial state
      });
    } catch (e) {
      debugPrint('load drives error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load drives')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createOrUpdateDrive(
    Map<String, dynamic> payload, {
    String? id,
  }) async {
    try {
      if (id == null) {
        await OnCampusService.createDrive(payload);
      } else {
        await OnCampusService.updateDrive(id, payload);
      }
      await _loadDrives();
    } catch (e) {
      debugPrint('save drive error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save drive')));
    }
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Drive'),
        content: const Text(
          'Are you sure you want to delete this record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await OnCampusService.deleteDrive(id);
        await _loadDrives();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Drive deleted')));
      } catch (e) {
        debugPrint('delete drive error: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete')));
      }
    }
  }

  /// Non-web PDF open (keeps original behavior for desktop/mobile)
  Future<void> _exportPdfAndOpen(
    String driveId, {
    String? suggestedName,
  }) async {
    final url = '${OnCampusService.baseUrl}/api/oncampus/$driveId/export';

    // ⭐ IMPORTANT: Web download
    if (kIsWeb) {
       html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          suggestedName ?? 'oncampus_drive_$driveId.pdf',
        )
        ..click();
      return;
    }

    // ⭐ Desktop & Mobile code
    try {
      final resp = await OnCampusService.exportDrivePdf(driveId);
      if (resp.statusCode == 200) {
        final bytes = resp.bodyBytes;

        Directory baseDir =
            (await getDownloadsDirectory()) ??
            await getApplicationDocumentsDirectory();

        final fileName =
            suggestedName ??
            'oncampus_drive_${driveId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

        final file = File('${baseDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        await OpenFilex.open(file.path);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Export failed')));
      }
    } catch (e) {
      debugPrint('export error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export failed')));
    }
  }

  // Show Add/Edit dialog (unchanged)
  Future<void> _showAddOrEditDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    DateTime? chosenDate = existing != null
        ? DateTime.tryParse(existing['dateOfRecruitment'] ?? '')
        : null;
    final dateController = TextEditingController(
      text: chosenDate != null ? _dateFmt.format(chosenDate) : '',
    );

    final collegeController = TextEditingController(
      text: existing?['collegeName'] ?? '',
    );
    final totalStudentsController = TextEditingController(
      text: existing?['totalStudents']?.toString() ?? '',
    );
    final aptitudeController = TextEditingController(
      text: existing?['aptitudeSelected']?.toString() ?? '',
    );
    final techController = TextEditingController(
      text: existing?['techSelected']?.toString() ?? '',
    );
    final hrController = TextEditingController(
      text: existing?['hrSelected']?.toString() ?? '',
    );

    String bgValue =
        existing?['bgVerificationStatus']?.toString() ?? _bgOptions.first;
    String positionValue =
        existing?['selectedPosition']?.toString() ?? _positionOptions.first;
    final contactPersonController = TextEditingController(
      text: existing?['contactPerson'] ?? '',
    );
    final studentContactController = TextEditingController(
      text: existing?['studentContactDetails'] ?? '',
    );

    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx2,
                initialDate: chosenDate ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                chosenDate = picked;
                dateController.text = _dateFmt.format(picked);
                setStateDialog(() {});
              }
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Drive' : 'Add Drive'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      onTap: pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Date of Recruitment',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: collegeController,
                      decoration: const InputDecoration(
                        labelText: 'College Name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: totalStudentsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Students (Count)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: aptitudeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Aptitude Selected (Count)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: techController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tech Selected (Count)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hrController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'HR Selected (Count)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: bgValue,
                      items: _bgOptions
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => bgValue = v ?? _bgOptions.first),
                      decoration: const InputDecoration(
                        labelText: 'BG Verification Status',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: positionValue,
                      items: _positionOptions
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setStateDialog(
                        () => positionValue = v ?? _positionOptions.first,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Selected Position',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactPersonController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Person',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: studentContactController,
                      decoration: const InputDecoration(
                        labelText: 'Student Contact details (CSV or notes)',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (dateController.text.trim().isEmpty) {
                      setStateDialog(() => errorText = 'Please pick a date.');
                      return;
                    }
                    if (collegeController.text.trim().isEmpty) {
                      setStateDialog(
                        () => errorText = 'Please enter college name.',
                      );
                      return;
                    }

                    int parseOrZero(String s) {
                      try {
                        return int.parse(s.trim());
                      } catch (_) {
                        return 0;
                      }
                    }

                    final payload = <String, dynamic>{
                      'dateOfRecruitment': chosenDate!.toIso8601String(),
                      'collegeName': collegeController.text.trim(),
                      'totalStudents': parseOrZero(
                        totalStudentsController.text,
                      ),
                      'aptitudeSelected': parseOrZero(aptitudeController.text),
                      'techSelected': parseOrZero(techController.text),
                      'hrSelected': parseOrZero(hrController.text),
                      'bgVerificationStatus': bgValue,
                      'selectedPosition': positionValue,
                      'contactPerson': contactPersonController.text.trim(),
                      'studentContactDetails': studentContactController.text
                          .trim(),
                    };

                    try {
                      if (isEdit) {
                        final id = existing['_id'] ?? existing['id'];
                        await _createOrUpdateDrive(payload, id: id);
                      } else {
                        await _createOrUpdateDrive(payload);
                      }
                      Navigator.pop(ctx2);
                    } catch (e) {
                      setStateDialog(() => errorText = 'Save failed');
                    }
                  },
                  child: Text(isEdit ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Export ALL drives -> single PDF download (web-friendly)
  Future<void> _downloadAllDrivesPdf() async {
    final url = '${OnCampusService.baseUrl}/api/oncampus/export-all';
    try {
      if (kIsWeb) {
        // Trigger direct download via anchor
         html.AnchorElement(href: url)
          ..setAttribute('download', 'oncampus_all_drives.pdf')
          ..click();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Download started — check your browser downloads."),
          ),
        );
      } else {
        // Non-web: fetch bytes and save locally
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200) {
          final bytes = resp.bodyBytes;
          Directory baseDir;
          try {
            baseDir =
                (await getDownloadsDirectory()) ??
                await getApplicationDocumentsDirectory();
          } catch (_) {
            baseDir = await getApplicationDocumentsDirectory();
          }
          final filePath =
              '${baseDir.path}/oncampus_all_drives_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Saved PDF to ${file.path}')));
          await OpenFilex.open(file.path);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed (${resp.statusCode})')),
          );
        }
      }
    } catch (e) {
      debugPrint('Export all error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCompleted = _drives.length;
    return Sidebar(
      title: 'On Campus Recruitment',
      body: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total no.of Completed Drives: $totalCompleted',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Search field + filter dropdown
                  SizedBox(
                    width: 500, // increased width
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search...',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        // The listener in _DrivesTable will handle the filtering
                      },
                    ),
                  ),

                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddOrEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Drive'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loadDrives,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Refresh'),
                  ),
                  // const SizedBox(width: 12),
                  // ElevatedButton(
                  //   onPressed: () {
                  //     showDialog(
                  //       context: context,
                  //       builder: (_) => AlertDialog(
                  //         title: const Text('Menu'),
                  //         content: const Text('Menu options (add your items)'),
                  //         actions: [
                  //           TextButton(
                  //             onPressed: () => Navigator.pop(context),
                  //             child: const Text('Close'),
                  //           ),
                  //         ],
                  //       ),
                  //     );
                  //   },
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.white,
                  //     foregroundColor: Colors.black,
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(50),
                  //     ),
                  //     padding: const EdgeInsets.symmetric(
                  //       horizontal: 16,
                  //       vertical: 12,
                  //     ),
                  //   ),
                  //   child: const Text('Menu'),
                  // ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Card(
                        elevation: 2,
                        clipBehavior: Clip.hardEdge,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: _DrivesTable(
                            allDrives: _drives,
                            searchController: _searchController,
                            searchField: _searchField,
                            onEdit: (drive) =>
                                _showAddOrEditDialog(existing: drive),
                            onDelete: (id) => _confirmDelete(id),
                            onExport: (id, name) =>
                                _exportPdfAndOpen(id, suggestedName: name),
                            dateFormatter: _dateFmt,
                          ),
                        ),
                      ),
                    ),
            ),

            // Export All Drives -> single PDF (removed legacy JSON)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    tooltip: 'Export all drives to single PDF (backend)',
                    onPressed: () async {
                      if (_drives.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No drives to export')),
                        );
                        return;
                      }
                      await _downloadAllDrivesPdf();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stateful widget to display and filter the drives table, preventing focus issues.
class _DrivesTable extends StatefulWidget {
  final List<Map<String, dynamic>> allDrives;
  final TextEditingController searchController;
  final String searchField;
  final Function(Map<String, dynamic>) onEdit;
  final Function(String) onDelete;
  final Function(String, String) onExport;
  final DateFormat dateFormatter;

  const _DrivesTable({
    required this.allDrives,
    required this.searchController,
    required this.searchField,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
    required this.dateFormatter,
  });

  @override
  State<_DrivesTable> createState() => _DrivesTableState();
}

class _DrivesTableState extends State<_DrivesTable> {
  List<Map<String, dynamic>> _filteredDrives = [];

  late final ScrollController _hController; // horizontal
  late final ScrollController _vController; // vertical

  @override
  void initState() {
    super.initState();
    _filteredDrives = List.from(widget.allDrives);
    widget.searchController.addListener(_filterDrives);

    _hController = ScrollController();
    _vController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant _DrivesTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allDrives != oldWidget.allDrives ||
        widget.searchField != oldWidget.searchField) {
      _filterDrives();
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_filterDrives);
    _hController.dispose();
    _vController.dispose();
    super.dispose();
  }

  void _filterDrives() {
    final qRaw = widget.searchController.text.trim().toLowerCase();
    setState(() {
      if (qRaw.isEmpty) {
        _filteredDrives = List.from(widget.allDrives);
        return;
      }

      _filteredDrives = widget.allDrives.where((d) {
        final dateStr = d['dateOfRecruitment'] != null
            ? widget.dateFormatter.format(
                DateTime.parse(d['dateOfRecruitment']),
              )
            : '';

        final college = (d['collegeName'] ?? '').toString().toLowerCase();
        final position = (d['selectedPosition'] ?? '').toString().toLowerCase();
        final bg = (d['bgVerificationStatus'] ?? '').toString().toLowerCase();
        final contact = (d['contactPerson'] ?? '').toString().toLowerCase();
        final studentContacts = (d['studentContactDetails'] ?? '')
            .toString()
            .toLowerCase();

        switch (widget.searchField) {
          case 'Date':
            return dateStr.contains(qRaw);
          case 'College':
            return college.contains(qRaw);
          case 'Position':
            return position.contains(qRaw);
          case 'BG Verification':
            return bg.contains(qRaw);
          case 'Contact Person':
            return contact.contains(qRaw) || studentContacts.contains(qRaw);
          default:
            final combined =
                ('$dateStr $college $position $bg $contact $studentContacts')
                    .toLowerCase();
            return combined.contains(qRaw);
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredDrives.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            widget.searchController.text.trim().isEmpty
                ? 'No drives yet. Tap + to add a drive.'
                : 'No results for "${widget.searchController.text.trim()}"',
          ),
        ),
      );
    }

    final rows = _filteredDrives.map((row) {
      final id = (row['_id'] ?? row['id'])?.toString() ?? '';
      final dateText = row['dateOfRecruitment'] != null
          ? widget.dateFormatter.format(
              DateTime.parse(row['dateOfRecruitment']),
            )
          : '';

      return DataRow(
        cells: [
          DataCell(SizedBox(width: 95, child: Text(dateText))),
          DataCell(SizedBox(width: 180, child: Text(row['collegeName'] ?? ''))),
          DataCell(
            SizedBox(
              width: 110,
              child: Text((row['totalStudents'] ?? 0).toString()),
            ),
          ),
          DataCell(
            SizedBox(
              width: 120,
              child: Text((row['aptitudeSelected'] ?? 0).toString()),
            ),
          ),
          DataCell(
            SizedBox(
              width: 110,
              child: Text((row['techSelected'] ?? 0).toString()),
            ),
          ),
          DataCell(
            SizedBox(
              width: 110,
              child: Text((row['hrSelected'] ?? 0).toString()),
            ),
          ),
          DataCell(
            SizedBox(
              width: 140,
              child: Text(row['bgVerificationStatus'] ?? 'Pending'),
            ),
          ),
          DataCell(
            SizedBox(width: 140, child: Text(row['selectedPosition'] ?? '')),
          ),
          DataCell(
            SizedBox(width: 140, child: Text(row['contactPerson'] ?? '')),
          ),
          DataCell(
            IconButton(
              icon: const Icon(Icons.remove_red_eye, color: Colors.green),
              onPressed: () => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => StudentDetailsPage(
      key: ValueKey(id), // 🔥 THIS LINE FIXES THE BUG
      driveId: id,
       isOffCampus: false,
    ),
  ),
),

            ),
          ),
          DataCell(
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () {
                    final suggestedName =
                        'drive_${dateText}_${row['collegeName']?.toString().replaceAll(" ", "")}.pdf';
                    widget.onExport(id, suggestedName);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => widget.onEdit(row),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => widget.onDelete(id),
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();

     return Scrollbar(
      controller: _hController,
      thumbVisibility: true,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        controller: _hController,
        scrollDirection: Axis.horizontal,
        child: Scrollbar(
          controller: _vController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _vController,
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width,
              ),
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 12,
            headingRowColor: WidgetStateProperty.resolveWith(
              (states) => Colors.grey.shade200,
            ),
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('College Name')),
              DataColumn(label: Text('Total Students')),
              DataColumn(label: Text('Aptitude Selected')),
              DataColumn(label: Text('Tech Selected')),
              DataColumn(label: Text('HR Selected')),
              DataColumn(label: Text('BG Verification')),
              DataColumn(label: Text('Selected Position')),
              DataColumn(label: Text('Contact Person')),
              DataColumn(label: Text('Students')),
              DataColumn(label: Text('Actions')),
            ],
            rows: rows,
          ),
        ),
      ),
    ),
  ),
);

  }
  


}
