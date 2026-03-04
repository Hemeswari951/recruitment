//offcampus_student_details_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'services/oncampus_service.dart';
import 'services/offcampus_service.dart';
import 'sidebar.dart';
import 'dart:html' as html;

import 'drive_bulk_offerletter_page.dart';

class StudentDetailsPage extends StatefulWidget {
  final String driveId;
  final bool isOffCampus;
   // ✅ NEW
  
  const StudentDetailsPage({super.key, required this.driveId,required this.isOffCampus,});

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  Map<String, dynamic>? drive;
  // ✅ ADD HERE
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final FocusNode _searchFocus = FocusNode();
  final ValueNotifier<List<dynamic>> filteredNotifier = ValueNotifier([]);


 // Track selected students
  Map<String, bool> selectedStudents = {};
  List<dynamic> students = [];
  List<dynamic> filteredStudents = [];

  final TextEditingController _search = TextEditingController();
  bool loading = true;

@override
void initState() {
  super.initState();
  _loadDrive();              // ✅ LOAD STUDENTS
  
}

  @override
void dispose() {
  _verticalController.dispose();
  _horizontalController.dispose();
  _search.dispose();
  _searchFocus.dispose();
  filteredNotifier.dispose();
  super.dispose();
}


 @override
void didUpdateWidget(covariant StudentDetailsPage oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (oldWidget.driveId != widget.driveId) {
    setState(() {
      loading = true;
      students.clear();
      filteredStudents.clear();
    });
    _loadDrive(); // reload correct drive
  }
}
void _doSearchSmooth(String value) {
  final q = value.trim().toLowerCase();

  if (q.isEmpty) {
    filteredNotifier.value = List.from(students);
  } else {
    filteredNotifier.value = students.where((s) {
      return (s['name'] ?? '').toLowerCase().contains(q) ||
          (s['mobile'] ?? '').toLowerCase().contains(q) ||
          (s['email'] ?? '').toLowerCase().contains(q);
    }).toList();
  }
}

  Future<void> _loadDrive() async {
  final d = widget.isOffCampus
      ? await OffCampusService.fetchDrive(widget.driveId)
      : await OnCampusService.fetchDrive(widget.driveId);

  if (!mounted) return;

  final loadedStudents = List.from(d?['students'] ?? []);

  setState(() {
    drive = d;
    students = loadedStudents;
    filteredStudents = List.from(students);
    filteredNotifier.value = List.from(students);

    selectedStudents.clear();
    for (var s in students) {
      selectedStudents[s['_id']] = false;
    }

    loading = false;
  });
}

List<dynamic> get selectedStudentList {
  return students.where((s) {
    final id = s['_id'];
    return selectedStudents[id] == true;
  }).toList();
}

  // ----------------------------
  // ADD / EDIT STUDENT
  // ----------------------------
  Future<void> _addOrEditStudent({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;

    final nameCtl = TextEditingController(text: existing?['name'] ?? '');
    final mobileCtl = TextEditingController(text: existing?['mobile'] ?? '');
    final emailCtl = TextEditingController(text: existing?['email'] ?? '');

    PlatformFile? pickedFile;
    String fileName = existing?['resumePath']?.split('/')?.last ?? '';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          title: Text(isEdit ? "Edit Student" : "Add Student"),
          content: SingleChildScrollView(
  child: Form(
    key: formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ NAME (Mandatory + only letters + spaces)
        TextFormField(
          controller: nameCtl,
          decoration: const InputDecoration(labelText: 'Name *'),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
          ],
          validator: (value) {
            final v = value?.trim() ?? "";
            if (v.isEmpty) return "Name is required";
            if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(v)) {
              return "Only letters allowed";
            }
            return null;
          },
        ),

        // ✅ MOBILE (Optional + only digits + max 10)
        TextFormField(
          controller: mobileCtl,
          decoration: const InputDecoration(labelText: 'Mobile'),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (value) {
            final v = value?.trim() ?? "";
            if (v.isEmpty) return null; // ✅ not mandatory
            if (v.length != 10) return "Mobile must be 10 digits";
            return null;
          },
        ),

        // ✅ EMAIL (Mandatory + email format)
        TextFormField(
          controller: emailCtl,
          decoration: const InputDecoration(labelText: 'Email *'),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            final v = value?.trim() ?? "";
            if (v.isEmpty) return "Email is required";
            if (!RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$").hasMatch(v)) {
              return "Enter valid email";
            }
            return null;
          },
        ),

        const SizedBox(height: 10),

        // ✅ Resume Upload (same as your code)
        ElevatedButton.icon(
          onPressed: () async {
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
          label: Text(fileName.isEmpty ? "Upload Resume" : fileName),
        ),
      ],
    ),
  ),
),

          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final fields = {
                  'name': nameCtl.text,
                  'mobile': mobileCtl.text,
                  'email': emailCtl.text,
                };

                if (isEdit) {
  widget.isOffCampus
      ? await OffCampusService.updateStudent(
          widget.driveId,
          existing['_id'],
          fields,
          pickedFile,
        )
      : await OnCampusService.updateStudent(
          widget.driveId,
          existing['_id'],
          fields,
          pickedFile,
        );
} else {
  widget.isOffCampus
      ? await OffCampusService.addStudent(
          widget.driveId,
          fields,
          pickedFile,
        )
      : await OnCampusService.addStudent(
          widget.driveId,
          fields,
          pickedFile,
        );
}


                Navigator.pop(ctx);
                await _loadDrive();
              },
              child: Text(isEdit ? "Save" : "Add"),
            )
          ],
        ),
      ),
    );
  }

  // ----------------------------
  // FIXED ACTIONS
  // ----------------------------
  void _openResumeInNewTab(String resumePath) {
  final fileName = resumePath.toString().split('/').last.split('\\').last;
  final base = widget.isOffCampus ? 'offcampus' : 'oncampus';

  // ✅ OPEN INLINE VIEW route
  final url = "${OnCampusService.baseUrl}/api/$base/resume/view/$fileName";

  html.window.open(url, "_blank");
}


  void _downloadResumeWeb(String resumePath) {
  final fileName = resumePath.toString().split('/').last.split('\\').last;
  final base = widget.isOffCampus ? 'offcampus' : 'oncampus';

  final url = "${OnCampusService.baseUrl}/api/$base/resume/$fileName";

  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
}

  Future<void> _deleteStudent(String sid) async {
  // Confirm with user first
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Confirm delete'),
      content: const Text('Are you sure you want to delete this student? This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );

  if (confirm != true) return;

  // Keep copies to rollback in case of error
  final beforeStudents = List<dynamic>.from(students);
  final beforeFiltered = List<dynamic>.from(filteredStudents);

  // Optimistically remove locally for instant UI feedback
  setState(() {
    students.removeWhere((s) => s['_id'] == sid);
    filteredStudents.removeWhere((s) => s['_id'] == sid);
    selectedStudents.remove(sid);
  });

  try {
    // Await the service call (service now throws on non-2xx)
    if (widget.isOffCampus) {
      await OffCampusService.deleteStudent(widget.driveId, sid);
    } else {
      await OnCampusService.deleteStudent(widget.driveId, sid);
    }

    // Reload authoritative data from server
    await _loadDrive();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student deleted')));
  } catch (err) {
    // rollback UI to previous state
    if (!mounted) return;
    setState(() {
      students = beforeStudents;
      filteredStudents = beforeFiltered;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $err')));
  }
}



  // ----------------------------
  // UI
  // ----------------------------
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
  focusNode: _searchFocus,
  onChanged: _doSearchSmooth, // ✅ simple and smooth
  decoration: const InputDecoration(
    hintText: "Search by name / mobile / email",
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
                // TABLE (FULL SCREEN)
                Expanded(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12.0),
    child: LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          // force the container to exactly the available height so scrollbars fill fully
          height: constraints.maxHeight,
          color: Colors.white,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: const PageStorageKey('student-table-vertical-scroll'),
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                // ensure horizontal area matches the visible width (no extra stray space)
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    scrollDirection: Axis.vertical,
                    child: IntrinsicHeight(
                      // IntrinsicHeight makes the child take full height if needed so
                      // the vertical scrollbar track reaches the bottom.
                      child: ValueListenableBuilder<List<dynamic>>(
  valueListenable: filteredNotifier,
  builder: (context, list, _) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
      columnSpacing: 50,
      dataRowHeight: 60,
      headingRowHeight: 60,
      columns: const [
        DataColumn(label: Text("Select")),
        DataColumn(label: Text("Name")),
        DataColumn(label: Text("Mobile")),
        DataColumn(label: Text("Email")),
        DataColumn(label: Text("Resume File")),
        DataColumn(label: Text("Actions")),
      ],
      rows: list.map((s) {
        final resume = s['resumePath'] ?? '';
        final sid = s['_id'];
        final fileName = resume.isEmpty ? "" : resume.split('/').last;

        return DataRow(
          key: ValueKey(sid),
          cells: [
            DataCell(
              Checkbox(
                value: selectedStudents[sid] ?? false,
                onChanged: (val) {
                  setState(() {
                    selectedStudents[sid] = val ?? false;
                  });
                },
              ),
            ),
            DataCell(Text(s['name'] ?? "")),
            DataCell(Text(s['mobile'] ?? "")),
            DataCell(Text(s['email'] ?? "")),
            DataCell(Text(fileName)),
            DataCell(
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                    onPressed: resume.isEmpty ? null : () => _openResumeInNewTab(resume),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.green),
                    onPressed: resume.isEmpty ? null : () => _downloadResumeWeb(resume),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _addOrEditStudent(existing: s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteStudent(sid),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  },
),

                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  ),
),


                const SizedBox(height: 10),

                // ADD BUTTON
               Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    ElevatedButton.icon(
      onPressed: () => _addOrEditStudent(),
      icon: const Icon(Icons.add),
      label: const Text("Add Student"),
    ),
    const SizedBox(width: 20),
   ElevatedButton.icon(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.deepPurple,
    foregroundColor: Colors.white,
  ),
  onPressed: selectedStudentList.isEmpty
      ? null // ❌ DISABLED
      : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriveOfferLetterPage(
                students: selectedStudentList,
                  position: drive?['selectedPosition'], // ✅ ONLY CHECKED
              ),
            ),
          );
        },
  icon: const Icon(Icons.picture_as_pdf),
  label: const Text("Generate Offer Letters"),
),


  ],
),


                const SizedBox(height: 20),
                
              ],
            ),
    );
  }
}