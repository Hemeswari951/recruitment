// lib/offcampus_student_details_page.dart
import 'dart:async'; // <- for Timer debounce
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;

import 'services/offcampus_service.dart';
import 'sidebar.dart';

class OffCampusStudentDetailsPage extends StatefulWidget {
  final String driveId;
  const OffCampusStudentDetailsPage({super.key, required this.driveId});

  @override
  State<OffCampusStudentDetailsPage> createState() =>
      _OffCampusStudentDetailsPageState();
}

class _OffCampusStudentDetailsPageState
    extends State<OffCampusStudentDetailsPage> {
  Map<String, dynamic>? drive;
  List<dynamic> students = [];

  final TextEditingController _search = TextEditingController();
  bool loading = true;

  // only horizontal scroll controller — prevents Scrollbar crash on web
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDrive();
    // IMPORTANT: parent does NOT add a search listener — child table will handle it.
  }

  @override
  void dispose() {
    // parent must NOT try to remove a listener it didn't add
    _search.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadDrive() async {
    final d = await OffCampusService.fetchDrive(widget.driveId);
    setState(() {
      drive = d;
      students = d?['students'] ?? [];
      loading = false;
    });
  }

  // ----------------------------
  // ADD / EDIT STUDENT (with upload state)
  // ----------------------------
  Future<void> _addOrEditStudent({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;

    final nameCtl = TextEditingController(text: existing?['name'] ?? '');
    final mobileCtl = TextEditingController(text: existing?['mobile'] ?? '');
    final emailCtl = TextEditingController(text: existing?['email'] ?? '');

    PlatformFile? pickedFile;
    String fileName = existing?['resumePath']?.split('/').last ?? '';
    bool uploading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Student' : 'Add Student'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: mobileCtl, decoration: const InputDecoration(labelText: 'Mobile')),
                TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                            withData: true,
                          );
                          if (result != null) {
                            pickedFile = result.files.first;
                            setDialog(() => fileName = pickedFile!.name);
                          }
                        },
                  icon: const Icon(Icons.upload_file),
                  label: Text(fileName.isEmpty ? 'Upload Resume' : fileName),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: uploading
                  ? null
                  : () async {
                      try {
                        setDialog(() => uploading = true);
                        final fields = {
                          'name': nameCtl.text,
                          'mobile': mobileCtl.text,
                          'email': emailCtl.text,
                        };

                        if (isEdit) {
                          await OffCampusService.updateStudent(
                            widget.driveId,
                            existing!['_id'],
                            fields,
                            pickedFile,
                          );
                        } else {
                          await OffCampusService.addStudent(
                            widget.driveId,
                            fields,
                            pickedFile,
                          );
                        }

                        Navigator.pop(ctx);
                        await _loadDrive();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Updated' : 'Student added')),
                        );
                      } catch (e) {
                        setDialog(() => uploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
              child: uploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------
  // helpers: basename, open, download
  // ----------------------------
  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : normalized;
  }

  // open inline in new tab (backend: /api/offcampus/resume/view/:filename)
  void _openResumeInNewTab(String resumePath) {
    final fileName = _basename(resumePath);
    if (fileName.isEmpty) return;
    final encoded = Uri.encodeComponent(fileName);
    final url = '${OffCampusService.baseUrl}/api/offcampus/resume/view/$encoded';
    html.window.open(url, '_blank');
  }

  // trigger download (backend: /api/offcampus/resume/:filename)
  void _downloadResumeWeb(String resumePath) {
    final fileName = _basename(resumePath);
    if (fileName.isEmpty) return;
    final encoded = Uri.encodeComponent(fileName);
    final url = '${OffCampusService.baseUrl}/api/offcampus/resume/$encoded';

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<void> _deleteStudent(String sid) async {
    await OffCampusService.deleteStudent(widget.driveId, sid);
    await _loadDrive();
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Off-Campus Student Details',
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // header row (college + total + search)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text('College: ${drive?['collegeName'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(width: 20),
                      Text('Total Students: ${students.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 18)),
                      const Spacer(),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            hintText: 'Search by name / mobile / email',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // TABLE (white background, full width)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.white,
                      child: _StudentsTable(
                        items: students,
                        searchController: _search,
                        horizontalController: _horizontalController,
                        onEdit: (s) => _addOrEditStudent(existing: s),
                        onDelete: (sid) => _deleteStudent(sid),
                        onOpenResume: (resume) => _openResumeInNewTab(resume),
                        onDownloadResume: (resume) => _downloadResumeWeb(resume),
                        basename: _basename,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ADD BUTTON
                ElevatedButton.icon(
                  onPressed: () => _addOrEditStudent(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Student'),
                ),

                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

/// Child widget that manages filtering and the table so typing doesn't rebuild parent.
class _StudentsTable extends StatefulWidget {
  final List<dynamic> items;
  final TextEditingController searchController;
  final ScrollController horizontalController;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String) onDelete;
  final void Function(String) onOpenResume;
  final void Function(String) onDownloadResume;
  final String Function(String) basename;

  const _StudentsTable({
    required this.items,
    required this.searchController,
    required this.horizontalController,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenResume,
    required this.onDownloadResume,
    required this.basename,
  });

  @override
  State<_StudentsTable> createState() => _StudentsTableState();
}

class _StudentsTableState extends State<_StudentsTable> {
  List<dynamic> _filtered = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _StudentsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _filtered = List.from(widget.items);
      _applyFilter(); // apply active search
    }
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
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _applyFilter);
  }

  void _applyFilter() {
    final q = widget.searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(widget.items);
      } else {
        _filtered = widget.items.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final mobile = (s['mobile'] ?? '').toString().toLowerCase();
          final email = (s['email'] ?? '').toString().toLowerCase();
          return name.contains(q) || mobile.contains(q) || email.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_filtered.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No students found.')));
    }

    return Scrollbar(
      controller: widget.horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: widget.horizontalController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 50),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
              columnSpacing: 50,
              dataRowHeight: 60,
              headingRowHeight: 60,
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Mobile')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Resume File')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _filtered.map((s) {
                final resume = s['resumePath'] ?? '';
                final sid = s['_id']?.toString() ?? '';
                final fileName = resume.isEmpty ? '' : widget.basename(resume);

                return DataRow(
                  cells: [
                    DataCell(Text(s['name'] ?? '')),
                    DataCell(Text(s['mobile'] ?? '')),
                    DataCell(Text(s['email'] ?? '')),
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
                          onPressed: () => widget.onEdit(s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: sid.isEmpty ? null : () => widget.onDelete(sid),
                        ),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
