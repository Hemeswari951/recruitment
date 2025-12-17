// lib/student_details_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'services/oncampus_service.dart';
import 'sidebar.dart';
import 'dart:html' as html; // for web resume open/download

class StudentDetailsPage extends StatefulWidget {
  final String driveId;
  const StudentDetailsPage({super.key, required this.driveId});

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  Map<String, dynamic>? drive;
  List<dynamic> students = [];
  final TextEditingController _search = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadDrive();
    // NOTE: do NOT add a listener here. Child table will manage search listener and debounce.
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadDrive() async {
    setState(() {
      loading = true;
    });

    try {
      final d = await OnCampusService.fetchDrive(widget.driveId);
      setState(() {
        drive = d;
        students = (d?['students'] ?? []) as List<dynamic>;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load drive: $e')));
    }
  }

  // Add / Edit student (unchanged behavior)
  Future<void> _addOrEditStudent({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;

    final nameCtl = TextEditingController(text: existing?['name'] ?? '');
    final mobileCtl = TextEditingController(text: existing?['mobile'] ?? '');
    final emailCtl = TextEditingController(text: existing?['email'] ?? '');

    PlatformFile? pickedFile;
    String fileName = existing?['resumePath']?.split('/')?.last ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          title: Text(isEdit ? "Edit Student" : "Add Student"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: mobileCtl, decoration: const InputDecoration(labelText: 'Mobile')),
                TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                      withData: true,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      pickedFile = result.files.first;
                      setDialog(() => fileName = pickedFile!.name);
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(fileName.isEmpty ? "Upload Resume" : fileName),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final fields = {
                  'name': nameCtl.text.trim(),
                  'mobile': mobileCtl.text.trim(),
                  'email': emailCtl.text.trim(),
                };

                try {
                  if (isEdit) {
                    await OnCampusService.updateStudent(
                      widget.driveId,
                      existing!['_id'],
                      fields,
                      pickedFile,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student updated')));
                  } else {
                    await OnCampusService.addStudent(
                      widget.driveId,
                      fields,
                      pickedFile,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student added')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
                } finally {
                  Navigator.pop(ctx);
                  await _loadDrive();
                }
              },
              child: Text(isEdit ? "Save" : "Add"),
            )
          ],
        ),
      ),
    );
  }

  // Resume helpers
  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : normalized;
  }

  void _openResumeInNewTab(String resumePath) {
    final fileName = _basename(resumePath);
    final encoded = Uri.encodeComponent(fileName);
    final url = "${OnCampusService.baseUrl}/api/oncampus/resume/view/$encoded";
    html.window.open(url, "_blank");
  }

  void _downloadResumeWeb(String resumePath) {
    final fileName = _basename(resumePath);
    final encoded = Uri.encodeComponent(fileName);
    final url = "${OnCampusService.baseUrl}/api/oncampus/resume/$encoded";

    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..setAttribute("target", "_blank");
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<void> _deleteStudent(String sid) async {
    try {
      await OnCampusService.deleteStudent(widget.driveId, sid);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student deleted')));
      await _loadDrive();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "Student Details",
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text("College: ${drive?['collegeName'] ?? ''}",
                          style: const TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(width: 20),
                      Text("Total Students: ${students.length}",
                          style: const TextStyle(color: Colors.white, fontSize: 18)),
                      const Spacer(),
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            hintText: "Search by name / mobile / email",
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // TABLE (moved to child so search listener doesn't cause parent rebuild/focus-loss)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.white,
                      child: _StudentsTable(
                        allStudents: students,
                        searchController: _search,
                        onEdit: (s) => _addOrEditStudent(existing: s),
                        onDelete: (sid) => _deleteStudent(sid),
                        onOpenResume: (path) => _openResumeInNewTab(path),
                        onDownloadResume: (path) => _downloadResumeWeb(path),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ADD BUTTON
                ElevatedButton.icon(
                  onPressed: () => _addOrEditStudent(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Student"),
                ),

                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

/// Child widget that owns the search listener + debounce and table rendering.
/// This prevents parent re-builds (when e.g. adding/editing) from interfering with keyboard/focus.
class _StudentsTable extends StatefulWidget {
  final List<dynamic> allStudents;
  final TextEditingController searchController;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String) onDelete;
  final void Function(String) onOpenResume;
  final void Function(String) onDownloadResume;

  const _StudentsTable({
    required this.allStudents,
    required this.searchController,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenResume,
    required this.onDownloadResume,
  });

  @override
  State<_StudentsTable> createState() => _StudentsTableState();
}

class _StudentsTableState extends State<_StudentsTable> {
  late List<dynamic> _filtered;
  Timer? _debounce;

  late final ScrollController _hController;
  late final ScrollController _vController;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.allStudents);
    widget.searchController.addListener(_onSearchChanged);
    _hController = ScrollController();
    _vController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant _StudentsTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If parent replaced the list of students, update filtered copy
    if (widget.allStudents != oldWidget.allStudents) {
      _filtered = List.from(widget.allStudents);
      _applyFilter(); // re-run filter when data changes
    }

    // If parent replaced search controller instance, rewire the listener
    if (widget.searchController != oldWidget.searchController) {
      try {
        oldWidget.searchController.removeListener(_onSearchChanged);
      } catch (_) {}
      widget.searchController.addListener(_onSearchChanged);
      _applyFilter();
    }
  }

  @override
  void dispose() {
    try {
      widget.searchController.removeListener(_onSearchChanged);
    } catch (_) {}
    _debounce?.cancel();
    _hController.dispose();
    _vController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _applyFilter);
  }

  void _applyFilter() {
    final q = widget.searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(widget.allStudents);
        return;
      }

      _filtered = widget.allStudents.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final mobile = (s['mobile'] ?? '').toString().toLowerCase();
        final email = (s['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || mobile.contains(q) || email.contains(q);
      }).toList();
    });
  }

  String _fileNameFromPath(String resume) {
    if (resume.isEmpty) return '';
    final normalized = resume.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : resume;
  }

  @override
  Widget build(BuildContext context) {
    if (_filtered.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No students found.')));
    }

    final screenWidth = MediaQuery.of(context).size.width;

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
              constraints: BoxConstraints(minWidth: screenWidth - 50),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                columnSpacing: 50,
                dataRowHeight: 60,
                headingRowHeight: 60,
                columns: const [
                  DataColumn(label: Text("Name")),
                  DataColumn(label: Text("Mobile")),
                  DataColumn(label: Text("Email")),
                  DataColumn(label: Text("Resume File")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: _filtered.map((s) {
                  final resume = s['resumePath'] ?? '';
                  final sid = (s['_id'] ?? s['id'])?.toString() ?? '';
                  final fileName = _fileNameFromPath(resume);

                  return DataRow(cells: [
                    DataCell(Text(s['name'] ?? "")),
                    DataCell(Text(s['mobile'] ?? "")),
                    DataCell(Text(s['email'] ?? "")),
                    DataCell(Text(fileName)),
                    DataCell(Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                          onPressed: resume.isEmpty ? null : () => widget.onOpenResume(resume),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download, color: Colors.green),
                          onPressed: resume.isEmpty ? null : () => widget.onDownloadResume(resume),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => widget.onEdit(s as Map<String, dynamic>),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: sid.isEmpty ? null : () => widget.onDelete(sid),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
