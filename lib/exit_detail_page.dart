import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import 'sidebar.dart';
import 'view_exit_details.dart';

class ExitDetailsPage extends StatefulWidget {
  const ExitDetailsPage({super.key});

  @override
  State<ExitDetailsPage> createState() => _ExitDetailsPageState();
}

class _ExitDetailsPageState extends State<ExitDetailsPage> {

  /// =========================================
  /// SAVE EXIT DETAILS
  /// =========================================
  Future<bool> saveExitDetails(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("http://localhost:5000/api/exitDetails"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return true;
      }
    } catch (e) {
      print("Error: $e");
    }
    return false;
  }

  /// =========================================
  /// UPLOAD DOCUMENT AFTER SAVING EXIT DETAILS
 Future<void> uploadExitDocument(String employeeId) async {
  final result = await FilePicker.platform.pickFiles();

  if (result == null) return;

  final fileBytes = result.files.single.bytes;
  final fileName = result.files.single.name;

  final request = http.MultipartRequest(
    'POST',
    Uri.parse("http://localhost:5000/api/exitDetails/upload"),
  );

  request.fields['employeeId'] = employeeId;
  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      fileBytes!,
      filename: fileName,
    ),
  );

  final response = await request.send();

  if (response.statusCode == 200) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Document Uploaded Successfully"),
        backgroundColor: Colors.green,      // ✅ SUCCESS → GREEN
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Upload Failed"),
        backgroundColor: Colors.red,        // ❌ ERROR → RED
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

  /// =========================================
  /// FETCH EMPLOYEE
  /// =========================================
  Future<Map<String, dynamic>?> fetchEmployeeById(String id) async {
    try {
      final response = await http.get(
        Uri.parse("http://localhost:5000/api/employees/$id"),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching employee: $e");
    }
    return null;
  }

  /// =========================================
  /// POPUP 2 — After Save → Upload Document
  /// =========================================
  /// =========================================
/// POPUP 2 — After Save → Upload Document
/// =========================================
void openUploadPopup(String employeeId) {
  showDialog(
    context: context,
    barrierDismissible: false,   // Prevent accidental closing
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text("Upload Exit Document"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Employee ID: $employeeId",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            /// Upload Button
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload File"),
              onPressed: () async {
                await uploadExitDocument(employeeId);
              },
            ),

            const SizedBox(height: 20),

            /// NEW CLOSE BUTTON BELOW UPLOAD
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(150, 45),
              ),
              onPressed: () {
                Navigator.pop(context); // <-- closes popup
              },
              child: const Text(
                "Close",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  /// =========================================
  /// FIRST POPUP — Add Exit Details
  /// =========================================
  void openExitDetailsPopup() {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final resignCtrl = TextEditingController();
    final acceptCtrl = TextEditingController();
    final noticeCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    DateTime? resignDate;
    DateTime? acceptDate;

    String fmt(DateTime? d) =>
        d == null ? "" : DateFormat("yyyy-MM-dd").format(d);

    Future<void> autoFill(String id) async {
      final emp = await fetchEmployeeById(id);
      if (emp != null) {
        nameCtrl.text = emp["employeeName"] ?? "";
        posCtrl.text = emp["position"] ?? "";
      } else {
        nameCtrl.clear();
        posCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Employee Not Found")),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopup) => AlertDialog(
          title: const Text("Exit Details"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: idCtrl,
                          decoration: const InputDecoration(
                            labelText: "Employee ID",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await autoFill(idCtrl.text.trim());
                          setPopup(() {});
                        },
                        child: const Text("Fetch"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Table(
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: FlexColumnWidth(),
                    },
                    children: [
                      _row("Name", nameCtrl),
                      _row("Position", posCtrl),

                      /// Resign Date
                      _dateRow("Resignation Date", resignCtrl, () async {
                        final pick = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pick != null) {
                          setPopup(() {
                            resignDate = pick;
                            resignCtrl.text = fmt(pick);
                          });
                        }
                      }),

                      /// Accept Date
                      _dateRow("Acceptance Date", acceptCtrl, () async {
                        final pick = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pick != null) {
                          setPopup(() {
                            acceptDate = pick;
                            acceptCtrl.text = fmt(pick);
                          });
                        }
                      }),

                      _row("Notice Period", noticeCtrl),
                      _bigRow("Experience", expCtrl),
                      _bigRow("Reason", reasonCtrl),
                    ],
                  )
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            /// SAVE BUTTON
            ElevatedButton(
              onPressed: () async {
                final employeeId = idCtrl.text.trim();

                final data = {
                  "employeeId": employeeId,
                  "name": nameCtrl.text.trim(),
                  "position": posCtrl.text.trim(),
                  "resignationDate":
                      resignDate?.toIso8601String() ?? resignCtrl.text,
                  "acceptanceDate":
                      acceptDate?.toIso8601String() ?? acceptCtrl.text,
                  "noticePeriod": noticeCtrl.text.trim(),
                  "experience": expCtrl.text.trim(),
                  "reason": reasonCtrl.text.trim(),
                };

                bool ok = await saveExitDetails(data);

                if (ok) {
                  Navigator.pop(context);

                  /// --------------------
                  /// OPEN UPLOAD POPUP
                  /// --------------------
                  openUploadPopup(employeeId);
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper fields
  TableRow _row(String label, TextEditingController ctrl) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(label)),
      Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      )
    ]);
  }

  TableRow _bigRow(String label, TextEditingController ctrl) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(label)),
      Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      )
    ]);
  }

  TableRow _dateRow(
      String label, TextEditingController ctrl, VoidCallback onTap) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(label)),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                readOnly: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
            IconButton(icon: const Icon(Icons.calendar_month), onPressed: onTap)
          ],
        ),
      ),
    ]);
  }

  /// MAIN UI
  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "Exit Details",
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
           ElevatedButton(
  onPressed: openExitDetailsPopup,
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.deepPurple,      // <-- Updated Color
    minimumSize: const Size(220, 50),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: const Text(
    "Add Exit Details",
    style: TextStyle(
      fontSize: 18,
      color: Colors.white,                   // <-- White Text
      fontWeight: FontWeight.w600,
    ),
  ),
),

const SizedBox(height: 25),

ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ViewExitPage()),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.teal,            // <-- Updated Color
    minimumSize: const Size(220, 50),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: const Text(
    "Show Exit Details",
    style: TextStyle(
      fontSize: 18,
      color: Colors.white,                   // <-- White Text
      fontWeight: FontWeight.w600,
    ),
  ),
),


          ],
        ),
      ),
    );
  }
}