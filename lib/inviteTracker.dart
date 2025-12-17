// lib/invite_tracker.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html; // ADD THIS ONLY FOR WEB

import 'sidebar.dart'; // your Sidebar widget file (you provided earlier)

const String _base = "http://localhost:5000/inviteTracker";

class InviteModel {
  String? id;
  String dateOfInvite;
  String collegeName;
  int totalStudents;
  String contactPerson;
  String dateOfRecruitment;
  String mode;
  DateTime? createdAt;
  DateTime? updatedAt;

  InviteModel({
    this.id,
    required this.dateOfInvite,
    required this.collegeName,
    required this.totalStudents,
    required this.contactPerson,
    required this.dateOfRecruitment,
    required this.mode,
    this.createdAt,
    this.updatedAt,
  });

  factory InviteModel.fromJson(Map<String, dynamic> json) {
    return InviteModel(
      id: json['_id']?.toString(),
      dateOfInvite: json['dateOfInvite']?.toString() ?? '',
      collegeName: json['collegeName']?.toString() ?? '',
      totalStudents: (json['totalStudents'] is int)
          ? json['totalStudents']
          : int.tryParse((json['totalStudents'] ?? '0').toString()) ?? 0,
      contactPerson: json['contactPerson']?.toString() ?? '',
      dateOfRecruitment: json['dateOfRecruitment']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'On-campus',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "dateOfInvite": dateOfInvite,
      "collegeName": collegeName,
      "totalStudents": totalStudents,
      "contactPerson": contactPerson,
      "dateOfRecruitment": dateOfRecruitment,
      "mode": mode,
    };
  }
}

class InviteTrackerPage extends StatefulWidget {
  const InviteTrackerPage({super.key});

  @override
  State<InviteTrackerPage> createState() => _InviteTrackerPageState();
}

class _InviteTrackerPageState extends State<InviteTrackerPage> {
  final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  List<InviteModel> _items = [];
  List<InviteModel> _filtered = [];
  bool _loading = false;
  final TextEditingController _searchCtrl = TextEditingController();

  List<String> _collegeNames = [];
  String? _selectedCollege;
  String? _selectedMode;

  final List<String> _modes = ['On-campus', 'Off-campus'];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applySearch() {
    // final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _items.where((item) {
        final collegeMatch =
            _selectedCollege == null || item.collegeName == _selectedCollege;
        final modeMatch = _selectedMode == null || item.mode == _selectedMode;

        return collegeMatch && modeMatch;
      }).toList();
    });
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$_base/all'));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        _items = data
            .map((e) => InviteModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _filtered = List.from(_items);
        _collegeNames = _items.map((e) => e.collegeName).toSet().toList()
          ..sort();
        // Reset selection if previously selected college is no longer there
        if (_selectedCollege != null &&
            !_collegeNames.contains(_selectedCollege)) {
          _selectedCollege = null;
        }
      } else {
        _showSnack('Failed to load invites (${res.statusCode})');
      }
    } catch (e) {
      _showSnack('Failed to load invites: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createInvite(InviteModel invite) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(invite.toJson()),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        _showSnack('Invite created');
        await _fetchAll();
      } else {
        _showSnack('Create failed (${res.statusCode})');
      }
    } catch (e) {
      _showSnack('Create failed: $e');
    }
  }

  Future<void> _updateInvite(String id, InviteModel invite) async {
    try {
      final res = await http.put(
        Uri.parse('$_base/update/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(invite.toJson()),
      );
      if (res.statusCode == 200) {
        _showSnack('Invite updated');
        await _fetchAll();
      } else {
        _showSnack('Update failed (${res.statusCode})');
      }
    } catch (e) {
      _showSnack('Update failed: $e');
    }
  }

  Future<void> _deleteInvite(String id) async {
    try {
      final res = await http.delete(Uri.parse('$_base/delete/$id'));
      if (res.statusCode == 200) {
        _showSnack('Invite deleted');
        await _fetchAll();
      } else {
        _showSnack('Delete failed (${res.statusCode})');
      }
    } catch (e) {
      _showSnack('Delete failed: $e');
    }
  }

  void _showSnack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _showAddEditDialog({InviteModel? existing}) async {
    final isEdit = existing != null;

    DateTime? inviteDate = existing != null && existing.dateOfInvite.isNotEmpty
        ? DateTime.tryParse(existing.dateOfInvite)
        : null;
    DateTime? recruitDate =
        existing != null && existing.dateOfRecruitment.isNotEmpty
        ? DateTime.tryParse(existing.dateOfRecruitment)
        : null;

    final dateInviteCtrl = TextEditingController(
      text: inviteDate != null ? _fmt.format(inviteDate) : '',
    );
    final collegeCtrl = TextEditingController(
      text: existing?.collegeName ?? '',
    );
    final totalCtrl = TextEditingController(
      text: existing?.totalStudents.toString() ?? '',
    );
    final contactCtrl = TextEditingController(
      text: existing?.contactPerson ?? '',
    );
    final dateRecruitCtrl = TextEditingController(
      text: recruitDate != null ? _fmt.format(recruitDate) : '',
    );

    String modeValue = existing?.mode ?? _modes.first;

    String? error;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            Future<void> pickDate(TextEditingController ctrl) async {
              final now = DateTime.now();
              final initial = ctrl.text.isNotEmpty
                  ? DateTime.tryParse(ctrl.text) ?? now
                  : now;
              final picked = await showDatePicker(
                context: ctx2,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                ctrl.text = _fmt.format(picked);
                setStateDialog(() {});
              }
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Invite' : 'Add Invite'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date of Invite
                    TextField(
                      controller: dateInviteCtrl,
                      readOnly: true,
                      onTap: () => pickDate(dateInviteCtrl),
                      decoration: const InputDecoration(
                        labelText: 'Date of Invite',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // College Name
                    TextField(
                      controller: collegeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'College Name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Total Students
                    TextField(
                      controller: totalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Total Students (Count)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    // Contact Person Details
                    TextField(
                      controller: contactCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Person Details',
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Date of Recruitment
                    TextField(
                      controller: dateRecruitCtrl,
                      readOnly: true,
                      onTap: () => pickDate(dateRecruitCtrl),
                      decoration: const InputDecoration(
                        labelText: 'Date of Recruitment',
                        suffixIcon: Icon(Icons.calendar_month),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Mode dropdown
                    DropdownButtonFormField<String>(
                      value: modeValue,
                      items: _modes
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => modeValue = v ?? _modes.first),
                      decoration: const InputDecoration(labelText: 'Mode'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.red)),
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
                    // basic validation
                    if (dateInviteCtrl.text.trim().isEmpty) {
                      setStateDialog(
                        () => error = 'Please pick Date of Invite.',
                      );
                      return;
                    }
                    if (collegeCtrl.text.trim().isEmpty) {
                      setStateDialog(
                        () => error = 'Please enter College Name.',
                      );
                      return;
                    }

                    final inv = InviteModel(
                      dateOfInvite: dateInviteCtrl.text.trim(),
                      collegeName: collegeCtrl.text.trim(),
                      totalStudents: int.tryParse(totalCtrl.text.trim()) ?? 0,
                      contactPerson: contactCtrl.text.trim(),
                      dateOfRecruitment: dateRecruitCtrl.text.trim(),
                      mode: modeValue,
                    );

                    try {
                      if (isEdit) {
                        await _updateInvite(existing.id!, inv);
                      } else {
                        await _createInvite(inv);
                      }
                      if (mounted) Navigator.pop(ctx2);
                    } catch (e) {
                      setStateDialog(() => error = 'Save failed: $e');
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

  Widget _buildTable() {
    if (_filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No invites yet. Tap + to add an invite.'),
        ),
      );
    }

    final rows = _filtered.map((it) {
      final id = it.id ?? '';
      return DataRow(
        cells: [
          DataCell(
            Text(it.dateOfInvite),
            onTap: () => _showAddEditDialog(existing: it),
          ),
          DataCell(
            Text(it.collegeName),
            onTap: () => _showAddEditDialog(existing: it),
          ),
          DataCell(
            Text(it.totalStudents.toString()),
            onTap: () => _showAddEditDialog(existing: it),
          ),
          DataCell(
            Text(it.contactPerson),
            onTap: () => _showAddEditDialog(existing: it),
          ),
          DataCell(
            Text(it.dateOfRecruitment),
            onTap: () => _showAddEditDialog(existing: it),
          ),
          DataCell(
            Text(it.mode),
            onTap: () => _showAddEditDialog(existing: it),
          ),
          DataCell(
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showAddEditDialog(existing: it),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Invite'),
                        content: const Text(
                          'Are you sure you want to delete this invite? This action cannot be undone.',
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
                      await _deleteInvite(id);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width,
        ),
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 12,
          columns: const [
            DataColumn(label: Text('Date of Invite')),
            DataColumn(label: Text('College Name')),
            DataColumn(label: Text('Total Students')),
            DataColumn(label: Text('Contact Person')),
            DataColumn(label: Text('Date of Recruitment')),
            DataColumn(label: Text('Mode')),
            DataColumn(label: Text('Actions')),
          ],
          rows: rows,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCompleted = _items.length;
    // place the main UI inside your Sidebar as the body
    final body = SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          // top controls row
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total no.of Drives: $totalCompleted',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Dropdown for college selection
                if (_collegeNames.isNotEmpty)
                  Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCollege,
                        isExpanded: true,
                        hint: const Text('Select College (Employee Directory)'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Colleges'),
                          ),
                          ..._collegeNames.map((name) {
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCollege = value;
                            _searchCtrl.text = value ?? '';
                            _applySearch();
                          });
                        },
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                // Mode Dropdown
                Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMode,
                      isExpanded: true,
                      hint: const Text('Select Mode'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Modes'),
                        ),
                        ..._modes.map((name) {
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedMode = value;
                          _applySearch();
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Invite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _fetchAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),

          // table / content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8,
                    ),
                    child: Card(
                      elevation: 2,
                      clipBehavior: Clip.hardEdge,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SingleChildScrollView(child: _buildTable()),
                      ),
                    ),
                  ),
          ),

          // export JSON button like your reference (shows raw JSON)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () async {
                    try {
                      final url = "$_base/download/pdf";
                      final response = await http.get(Uri.parse(url));

                      if (response.statusCode == 200) {
                        // ---------- WEB DOWNLOAD ----------
                        if (kIsWeb) {
                          final blob = html.Blob([
                            response.bodyBytes,
                          ], 'application/pdf');
                          final url = html.Url.createObjectUrlFromBlob(blob);

                          html.AnchorElement(href: url)
                            ..download = "invite_tracker.pdf"
                            ..click();

                          html.Url.revokeObjectUrl(url);
                          _showSnack("PDF downloaded (browser)");
                          return;
                        }

                        // ---------- DESKTOP DOWNLOAD ----------
                        final directory = await getDownloadsDirectory();
                        final path = "${directory!.path}/invite_tracker.pdf";

                        final file = File(path);
                        await file.writeAsBytes(response.bodyBytes);

                        _showSnack("PDF saved to Downloads folder");
                        OpenFilex.open(path);
                      } else {
                        _showSnack(
                          "Failed to download PDF (${response.statusCode})",
                        );
                      }
                    } catch (e) {
                      _showSnack("Download failed: $e");
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Sidebar(body: body, title: 'Invite Tracker');
  }
}
