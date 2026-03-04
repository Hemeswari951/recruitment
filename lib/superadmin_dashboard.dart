// lib/super_admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io' show File; // Only used on mobile
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';

import 'user_provider.dart';
import 'sidebar.dart';
import 'apply_leave.dart';
import 'todo_planner.dart';
// import 'emp_payroll.dart';
import 'payslip.dart';
import 'company_events.dart';
// import 'admin_notification.dart';
import 'attendance_login.dart';
import 'event_banner_slider.dart';
import 'leave_approval.dart';
//import 'adminperformance.dart'; // for Performance Review
import 'superadmin_performance.dart'; // ✅ for SuperadminPerformancePageReview
import 'employee_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recruitment.dart';
import 'mail_dashboard.dart';
import 'attendance_list.dart';
import 'holiday_master_screen.dart';
import 'superadmin_notification.dart';
import 'admin_payslip_viewer.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  String? employeeName;
  bool _isLoading = true;
  String? _error;

  int casualUsed = 0;
  int casualTotal = 0;
  int sickUsed = 0;
  int sickTotal = 0;
  int sadUsed = 0;
  int sadTotal = 0;
  int _mailCount = 0;

  // For mobile (File)
  File? _pickedImageFile;

  // For web (Bytes)
  Uint8List? _pickedImageBytes;
  String? _pickedFileName;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // fetchEmployeeName depends on Provider; call in initState but safe (we check for null inside).
    fetchEmployeeName();
    _fetchMailCount();
    _fetchNotificationCount();
    // remove duplicate fetchPendingCount call — UI uses FutureBuilder to fetch it.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchMailCount();
    // Refresh balances when dashboard is revisited
    _fetchLeaveBalance();
    _fetchNotificationCount();
  }

  int _notificationCount = 0; // ✅ New state variable

  Future<void> _fetchNotificationCount() async {
    final employeeId = Provider.of<UserProvider>(
      context,
      listen: false,
    ).employeeId;
    if (employeeId == null) return;

    final res = await http.get(
      Uri.parse("https://company-04bz.onrender.com/notifications/unread-count/$employeeId"),
    );

    if (res.statusCode == 200 && mounted) {
      final data = jsonDecode(res.body);
      setState(() => _notificationCount = data["count"] ?? 0);
    }
  }

  /// Fetch employee name from backend.
  /// Attempts the common /api/employees/:id route first, then falls back to /get-employee-name/:id.
  /// Fetch employee name from backend (single endpoint now).
  Future<void> fetchEmployeeName() async {
    final employeeId = Provider.of<UserProvider>(
      context,
      listen: false,
    ).employeeId;

    if (employeeId == null || employeeId.trim().isEmpty) {
      setState(() => employeeName = null);
      return;
    }

    try {
      final uri = Uri.parse("https://company-04bz.onrender.com/api/employees/$employeeId");
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          employeeName = data['employeeName']?.toString();
        });
      } else {
        setState(() => employeeName = null);
        debugPrint("❌ fetchEmployeeName failed: ${resp.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching employee name: $e");
      setState(() => employeeName = null);
    }
  }

  /// Fetch leave balances from backend.
  Future<void> _fetchLeaveBalance() async {
    try {
      final employeeId = Provider.of<UserProvider>(
        context,
        listen: false,
      ).employeeId?.trim();

      if (employeeId == null || employeeId.isEmpty) {
        setState(() {
          _error = "Employee ID not found";
          _isLoading = false;
        });
        return;
      }

      final year = DateTime.now().year;
      final url =
          "https://company-04bz.onrender.com/apply/leave-balance/$employeeId?year=$year";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          casualUsed = (data["balances"]?["casual"]?["used"] ?? 0) as int;
          casualTotal = (data["balances"]?["casual"]?["total"] ?? 12) as int;

          sickUsed = (data["balances"]?["sick"]?["used"] ?? 0) as int;
          sickTotal = (data["balances"]?["sick"]?["total"] ?? 12) as int;

          sadUsed = (data["balances"]?["sad"]?["used"] ?? 0) as int;
          sadTotal = (data["balances"]?["sad"]?["total"] ?? 12) as int;

          _error = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load balances (HTTP ${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Fetch pending count for a role (used by FutureBuilder)
  Future<int> fetchPendingCount(String userRole, String employeeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          // Pass both role and ID to the backend
          "https://company-04bz.onrender.com/apply/pending-count?approver=$userRole&approverId=$employeeId",
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['pendingCount'] ?? 0;
      } else {
        debugPrint("❌ Failed to fetch pending count: ${response.statusCode}");
        return 0;
      }
    } catch (e) {
      debugPrint("❌ Error fetching pending count: $e");
      return 0;
    }
  }

  /// Fetch pending change-request count for the current approverRole
  Future<int> fetchRequestPendingCount(String approverRole) async {
    try {
      final uri = Uri.parse(
        "https://company-04bz.onrender.com/requests/count?approverRole=$approverRole&status=pending",
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['pendingCount'] ?? 0;
      } else {
        debugPrint(
          "❌ Failed to fetch request pending count: ${response.statusCode}",
        );
        return 0;
      }
    } catch (e) {
      debugPrint("❌ Error fetching request pending count: $e");
      return 0;
    }
  }

  Future<void> _fetchMailCount() async {
    final employeeId = Provider.of<UserProvider>(
      context,
      listen: false,
    ).employeeId;
    if (employeeId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://company-04bz.onrender.com/api/mail/pending-count?employeeId=$employeeId',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _mailCount = data['pendingCount'] ?? 0;
          });
        }
      } else {
        print('❌ Failed to fetch mail count: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching mail count: $e');
    }
  }

  /// Delete employee comment
  Future<void> _deleteEmployeeComment(String id) async {
    try {
      final response = await http.delete(
        Uri.parse("https://company-04bz.onrender.com/review-decision/$id"),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑 Comment deleted successfully")),
        );
        Navigator.of(context).pop(); // close current dialog
        await _showEmployeeComments(); // refresh dialog
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to delete (${response.statusCode})"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }

  /// Employee comments popup
  Future<void> _showEmployeeComments() async {
    try {
      final response = await http.get(
        Uri.parse("https://company-04bz.onrender.com/review-decision"),
        headers: {"Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text(
              "Employee Feedback",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: data.isEmpty
                  ? const Text("No feedback available yet.")
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final item = data[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(
                              item["decision"] == "agree"
                                  ? Icons.thumb_up
                                  : Icons.thumb_down,
                              color: item["decision"] == "agree"
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(
                              item["employeeName"] ?? "Unknown",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item["position"] ?? ""),
                                const SizedBox(height: 4),
                                Text(
                                  item["comment"] ?? "",
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Submitted: ${_formatDate(item["createdAt"])}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: "Delete Comment",
                              onPressed: () async {
                                await _deleteEmployeeComment(item["_id"]);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load feedback (${response.statusCode})"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }

  // Utility: clear picked image after successful submit or cancel
  void _clearPickedImage() {
    setState(() {
      _pickedImageFile = null;
      _pickedImageBytes = null;
      _pickedFileName = null;
    });
  }

  /// Add Employee dialog:
  /// - Shows text fields for ID/name/position/domain
  /// - Shows a read-only text field for image filename
  /// - Browse button accepts only .jpg files
  /// - Submits multipart/form-data to /api/employees/add with field "employeeImage"
  void _showAddEmployeeDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final positionController = TextEditingController();
    final domainController = TextEditingController();
    final passwordController = TextEditingController();
    final imageController = TextEditingController();
    final dojController = TextEditingController();
    final workEmailController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        bool obscure = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              //builder: (_) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 60,
              ),
              child: Container(
                width: 420,
                height: 620, // 🔴 increased height for import button
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF873AB7), Color(0xFF673AB7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Add New Employee",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          //const SizedBox(height: 18),
                          const SizedBox(height: 10),

                          // Image Picker
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: imageController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: "Profile Image (.jpg)",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              //const SizedBox(width: 10),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  if (kIsWeb) {
                                    // Web: pick file as bytes
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: ['jpg', 'jpeg'],
                                          withData: true,
                                        );
                                    if (result != null &&
                                        result.files.single.bytes != null) {
                                      setState(() {
                                        _pickedImageBytes =
                                            result.files.single.bytes;
                                        // lowercase extension to satisfy Multer
                                        _pickedFileName = result
                                            .files
                                            .single
                                            .name
                                            .toLowerCase();
                                        imageController.text = _pickedFileName!;
                                      });
                                    }
                                  } else {
                                    // Mobile: pick image from gallery
                                    final picked = await _picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (picked != null) {
                                      final lower = picked.path.toLowerCase();
                                      if (lower.endsWith('.jpg') ||
                                          lower.endsWith('.jpeg')) {
                                        setState(() {
                                          _pickedImageFile = File(picked.path);
                                          _pickedFileName = picked.name
                                              .toLowerCase();
                                          imageController.text = picked.name;
                                        });
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "⚠ Please select a .jpg image only",
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Browse"),
                              ),
                            ],
                          ),
                          //const SizedBox(height: 16),
                          const SizedBox(height: 14),

                          // Employee ID
                          TextField(
                            controller: idController,
                            decoration: const InputDecoration(
                              labelText: "Employee ID",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          //const SizedBox(height: 12),
                          const SizedBox(height: 10),

                          // Employee Name
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: "Employee Name",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          //const SizedBox(height: 12),
                          const SizedBox(height: 10),

                          // Position
                          TextField(
                            controller: positionController,
                            decoration: const InputDecoration(
                              labelText: "Position",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          //const SizedBox(height: 12),
                          const SizedBox(height: 10),

                          // Domain
                          TextField(
                            controller: domainController,
                            decoration: const InputDecoration(
                              labelText: "Domain",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          //const SizedBox(height: 18),
                          const SizedBox(height: 10),

                          // Date of Joining (Optional)
                          TextField(
                            controller: dojController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: "Date of Joining (Optional)",
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            onTap: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate != null) {
                                String formattedDate = DateFormat('dd-MM-yyyy').format(pickedDate);
                                setState(() => dojController.text = formattedDate);
                              }
                            },
                          ),
                          const SizedBox(height: 10),

                          // Work Email (Optional)
                          TextField(
                            controller: workEmailController,
                            decoration: const InputDecoration(
                              labelText: "Work Email (Optional)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Password (new) - obscured with toggle
                          TextField(
                            controller: passwordController,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: "Password",
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscure = !obscure;
                                  });
                                },
                              ),
                            ),
                          ),
                          //const SizedBox(height: 18),
                          const SizedBox(height: 16),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                final empId = idController.text.trim();
                                final name = nameController.text.trim();
                                final position = positionController.text.trim();
                                final domain = domainController.text.trim();
                                final password = passwordController.text.trim();

                                if (empId.isEmpty ||
                                    name.isEmpty ||
                                    position.isEmpty ||
                                    domain.isEmpty ||
                                    password.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("⚠ Please fill all fields"),
                                    ),
                                  );
                                  return;
                                }

                                if (password.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "⚠ Password should be at least 6 characters",
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  var request = http.MultipartRequest(
                                    'POST',
                                    Uri.parse(
                                      "https://company-04bz.onrender.com/api/employees",
                                    ),
                                  );

                                  request.fields['employeeId'] = empId;
                                  request.fields['employeeName'] = name;
                                  request.fields['position'] = position;
                                  request.fields['domain'] = domain;
                                  request.fields['password'] =
                                      password; // <-- new

                                  // Optional fields
                                  if (dojController.text.isNotEmpty) {
                                    request.fields['dateOfAppointment'] = dojController.text.trim();
                                  }
                                  if (workEmailController.text.isNotEmpty) {
                                    request.fields['workEmail'] = workEmailController.text.trim();
                                  }

                                  if (kIsWeb && _pickedImageBytes != null) {
                                    request.files.add(
                                      http.MultipartFile.fromBytes(
                                        'employeeImage',
                                        _pickedImageBytes!,
                                        filename:
                                            _pickedFileName ?? 'upload.jpg',
                                        contentType: MediaType(
                                          'image',
                                          'jpeg',
                                        ), // Multer safe
                                      ),
                                    );
                                  } else if (!kIsWeb &&
                                      _pickedImageFile != null) {
                                    request.files.add(
                                      await http.MultipartFile.fromPath(
                                        'employeeImage',
                                        _pickedImageFile!.path,
                                        filename:
                                            _pickedFileName ??
                                            _pickedImageFile!.path
                                                .split('/')
                                                .last,
                                      ),
                                    );
                                  }

                                  final streamedResponse = await request.send();
                                  final response = await http
                                      .Response.fromStream(streamedResponse);

                                  if (response.statusCode == 200 ||
                                      response.statusCode == 201) {
                                    _clearPickedImage();
                                    imageController.clear();
                                    idController.clear();
                                    nameController.clear();
                                    positionController.clear();
                                    domainController.clear();
                                    passwordController.clear();
                                    dojController.clear();
                                    workEmailController.clear();

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "✅ Employee added successfully!",
                                        ),
                                      ),
                                    );
                                    Navigator.pop(context);

                                    // Refresh Employee List
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const EmployeeListScreen(),
                                      ),
                                    );
                                  } else {
                                    String msg =
                                        "❌ Failed: ${response.statusCode}";
                                    try {
                                      final body = jsonDecode(response.body);
                                      if (body is Map &&
                                          body['message'] != null) {
                                        msg = body['message'];
                                      }
                                    } catch (_) {}
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("❌ Error: $e")),
                                  );
                                }
                              },
                              child: const Text(
                                "Add Employee",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 4),
                          Text(
                            "OR",
                            style: TextStyle(color: Colors.grey.shade700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.upload_file),
                              label: const Text("Import from Excel"),
                              onPressed: () {
                                Navigator.of(context).pop(); // Close manual add dialog
                                _importEmployeesFromExcel();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.deepPurple,
                                side: const BorderSide(color: Colors.deepPurple),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _clearPickedImage();
      imageController.clear();
      idController.clear();
      nameController.clear();
      positionController.clear();
      domainController.clear();
      dojController.clear();
      workEmailController.clear();
    });
  }

  /// 🔹 Handles the entire Excel import flow
  Future<void> _importEmployeesFromExcel() async {
    // 1. Pick Excel file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true, // Necessary to get file bytes on web
    );

    if (result == null || result.files.single.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No file selected or file is empty.")),
      );
      return;
    }

    var bytes = result.files.single.bytes!;
    var excel = Excel.decodeBytes(bytes);

    // 2. Let user select a sheet
    String? selectedSheet = await _showSheetSelectionDialog(excel.tables.keys.toList());

    if (selectedSheet == null) return; // User cancelled

    var sheet = excel.tables[selectedSheet]!;
    if (sheet.maxRows < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sheet is empty or has only a header row.")),
      );
      return;
    }

    // 3. Process sheet data
    var headerRow = sheet.rows.first;
    Map<String, int> headerMap = {};
    for (var i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell != null && cell.value != null) {
        headerMap[cell.value.toString().trim().toLowerCase()] = i;
      }
    }

    // Check for mandatory headers
    final mandatoryHeaders = ['employee id', 'employee name', 'position', 'domain', 'password'];
    if (!headerMap.keys.toSet().containsAll(mandatoryHeaders)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing mandatory headers: employee id, employee name, position, domain, password.")),
      );
      return;
    }

    List<Map<String, dynamic>> employeesToCreate = [];
    for (var i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      Map<String, dynamic> employee = {};

      dynamic getCellValue(String headerName) {
        if (headerMap.containsKey(headerName)) {
          int colIndex = headerMap[headerName]!;
          if (colIndex < row.length && row[colIndex] != null) {
            return row[colIndex]!.value;
          }
        }
        return null;
      }

      employee['employeeId'] = getCellValue('employee id')?.toString();
      employee['employeeName'] = getCellValue('employee name')?.toString();
      employee['position'] = getCellValue('position')?.toString();
      employee['domain'] = getCellValue('domain')?.toString();
      employee['password'] = getCellValue('password')?.toString();
      employee['workEmail'] = getCellValue('work email')?.toString();

      var doj = getCellValue('date of joining');
      if (doj is double) { // Excel date serial number
        final date = DateTime(1899, 12, 30).add(Duration(days: doj.toInt()));
        employee['dateOfAppointment'] = DateFormat('yyyy-MM-dd').format(date);
      } else if (doj != null) {
        employee['dateOfAppointment'] = doj.toString();
      }

      if (employee['employeeId'] != null && employee['employeeName'] != null) {
        employeesToCreate.add(employee);
      }
    }

    if (employeesToCreate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No valid employee data found in the selected sheet.")),
      );
      return;
    }

    // 4. Send to backend
    try {
      final response = await http.post(
        Uri.parse("https://company-04bz.onrender.com/api/employees/bulk"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(employeesToCreate),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Import complete. Success: ${result['successCount']}, Failures: ${result['failureCount']}. Errors: ${result['errors'].join(', ')}"),
            duration: const Duration(seconds: 8),
          ),
        );
        // Refresh employee list by navigating to it
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmployeeListScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error during import: $e")));
    }
  }

  /// 🔹 Shows a dialog for the user to pick a sheet from the Excel file
  Future<String?> _showSheetSelectionDialog(List<String> sheetNames) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Sheet to Import'),
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sheetNames.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(title: Text(sheetNames[index]), onTap: () => Navigator.of(context).pop(sheetNames[index]));
              },
            ),
          ),
        );
      },
    );
  }

  /// Helper: format date in YYYY-MM-DD hh:mm with zero padding
  String _formatDate(dynamic iso) {
    if (iso == null) return 'N/A';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return DateFormat('yyyy-MM-dd hh:mm a').format(dt); // 2025-10-03 12:09 PM
    } catch (_) {
      return iso.toString();
    }
  }

  /// 🔹 Fetch pending change requests
  /// 🔹 Fetch pending change requests (optionally filtered by approverRole)
  Future<List<dynamic>> _fetchPendingRequests({String? approverRole}) async {
    try {
      String url = "https://company-04bz.onrender.com/requests?status=pending";
      if (approverRole != null && approverRole.isNotEmpty) {
        url += "&approverRole=$approverRole";
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {"Accept": "application/json"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> _approveRequest(String requestId) async {
    try {
      final response = await http.post(
        Uri.parse('https://company-04bz.onrender.com/requests/$requestId/approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'resolvedBy':
              Provider.of<UserProvider>(context, listen: false).employeeId ??
              'superadmin',
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Request approved')));
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  Future<void> _declineRequest(String requestId) async {
    try {
      final response = await http.post(
        Uri.parse('https://company-04bz.onrender.com/requests/$requestId/decline'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'resolvedBy':
              Provider.of<UserProvider>(context, listen: false).employeeId ??
              'superadmin',
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Request declined')));
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  Future<void> _showChangeRequests() async {
    final role =
        Provider.of<UserProvider>(
          context,
          listen: false,
        ).position?.toLowerCase() ??
        'founder';
    // map UI roles to our backend approverRole values
    final approverRole = (role == 'hr')
        ? 'hr'
        : (role == 'founder' ? 'founder' : 'hr');
    final requests = await _fetchPendingRequests(approverRole: approverRole);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Pending Change Requests"),
        content: SizedBox(
          width: double.maxFinite,
          child: requests.isEmpty
              ? const Text("No pending requests.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: requests.length,
                  itemBuilder: (context, idx) {
                    final r = requests[idx];
                    final createdAt = r['createdAt'] != null
                        ? _formatDate(r['createdAt'])
                        : '';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(
                          '${r['full_name'] ?? 'Unknown'} — ${r['field']}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Old: ${r['oldValue'] ?? ''}'),
                            Text('New: ${r['newValue'] ?? ''}'),
                            Text('Requested by: ${r['requestedBy'] ?? ''}'),
                            Text(
                              'Created: $createdAt',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _approveRequest(r['_id']);
                                await _showChangeRequests();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _declineRequest(r['_id']);
                                await _showChangeRequests();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    return Sidebar(
      title: 'AdminDashboard',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Welcome, ${employeeName ?? '...'}!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildQuickActions(context),
            const SizedBox(height: 40),
            _buildCardLayout(context),
            const SizedBox(height: 40),
            const EventBannerSlider(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final role =
        Provider.of<UserProvider>(
          context,
          listen: false,
        ).position?.toLowerCase() ??
        "founder";
    // final approverRole = (role == "hr") ? "hr" : "founder";
    final approverRole = (role == "superadmin")
        ? "superadmin"
        : (role == "hr")
        ? "hr"
        : (role == "founder")
        ? "founder"
        : (role == "tl")
        ? "tl"
        : "employee";

    return Center(
      child: Wrap(
        spacing: 90,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        children: [
          _quickActionButton('Apply Leave', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ApplyLeave()),
            );
          }),
          _quickActionButton('Download Payslip', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PayslipScreen()),
            );
          }),
          _quickActionButton('Mark Attendance', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceLoginPage()),
            );
          }),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _quickActionButton('Mail', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MailDashboard()),
                ).then((_) => _fetchMailCount());
              }),
              if (_mailCount > 0)
                Positioned(
                  right: -10,
                  top: -10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_mailCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // ✅ Notifications Preview with Badge logic
          Stack(
            clipBehavior: Clip.none,
            children: [
              _quickActionButton('Notifications Preview', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SuperadminNotificationsPage(
                      empId:
                          Provider.of<UserProvider>(
                            context,
                            listen: false,
                          ).employeeId ??
                          '',
                    ),
                  ),
                ).then((_) {
                  // This triggers when you come BACK to the dashboard
                  _fetchNotificationCount();
                });
              }),
              if (_notificationCount > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          _quickActionButton('Performance Review', () {
            final userProvider = Provider.of<UserProvider>(
              context,
              listen: false,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SuperadminPerformancePage(
                  currentUserId: userProvider.employeeId!,
                ),
              ),
            );
          }),
          _quickActionButton('Employee Feedback', _showEmployeeComments),

          //_quickActionButton('Request', _showChangeRequests),
          // 🔹 Request Button with Badge
          FutureBuilder<int>(
            future: fetchRequestPendingCount(
              (Provider.of<UserProvider>(context, listen: false).position ??
                      'founder')
                  .toLowerCase(),
            ),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _quickActionButton('Request', () {
                    _showChangeRequests();
                  }),
                  if (count > 0)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "$count",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          _quickActionButton('Company Events', () async {
            final prefs = await SharedPreferences.getInstance();
            final position = prefs.getString('position') ?? '';

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CompanyEventsScreen(isHR: position == 'HR'),
              ),
            );
          }),

          if (approverRole == 'hr' || approverRole == 'founder')
            _quickActionButton('View Employee Payslips', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPayslipViewer()),
              );
            }),

          _quickActionButton('Add Employee', _showAddEmployeeDialog),
          _quickActionButton('Employee List', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeListScreen()),
            );
          }),
          _quickActionButton('Attendance List', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceListScreen()),
            );
          }),
          _quickActionButton('Holiday Master', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HolidayMasterScreen()),
            );
          }),
          _quickActionButton('Recruitment', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecruitmentHomePage()),
            );
          }),

          FutureBuilder<int>(
            future: fetchPendingCount(
              approverRole,
              Provider.of<UserProvider>(context, listen: false).employeeId ??
                  '',
            ),
            builder: (context, snapshot) {
              // Re-fetch on state change if needed, or just rely on future builder
              final count = snapshot.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _quickActionButton('Leave Approval', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LeaveApprovalPage(userRole: approverRole),
                      ),
                    );
                  }),
                  if (count > 0)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "$count",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton(String title, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 214, 226, 231),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 3,
      ),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _buildCardLayout(BuildContext context) {
    final currentDate = DateTime.now();
    final formattedDate =
        '${currentDate.day}/${currentDate.month}/${currentDate.year}';
    final currentTime = TimeOfDay.now().format(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 60,
          runSpacing: 20,
          children: [
            _AdminDashboardTile(
              icon: Icons.lightbulb,
              title: currentTime,
              subtitle: 'Today: $formattedDate',
              buttonLabel: 'To Do List',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ToDoPlanner()),
                );
              },
            ),
            _leaveCardTile(
              icon: Icons.beach_access,
              title: 'Casual Leave',
              subtitle:
                  'Used: $casualUsed/$casualTotal\nRemaining: ${casualTotal - casualUsed}',
              buttonLabel: 'View',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ApplyLeave()),
                );
              },
            ),
            _leaveCardTile(
              icon: Icons.local_hospital,
              title: 'Sick Leave',
              subtitle:
                  'Used: $sickUsed/$sickTotal\nRemaining: ${sickTotal - sickUsed}',
              buttonLabel: 'View',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ApplyLeave()),
                );
              },
            ),
            _leaveCardTile(
              icon: Icons.mood_bad,
              title: 'Sad Leave',
              subtitle:
                  'Used: $sadUsed/$sadTotal\nRemaining: ${sadTotal - sadUsed}',
              buttonLabel: 'View',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ApplyLeave()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _AdminDashboardTile({
    required IconData icon,
    required dynamic title,
    required String subtitle,
    required String buttonLabel,
    VoidCallback? onTap,
  }) {
    return Container(
      width: 200,
      height: 250,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.6),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: Colors.deepPurple),
              ),
              const SizedBox(height: 12),
              Text(
                title is String ? title : title.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  Widget _leaveCardTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    VoidCallback? onTap,
  }) {
    return _AdminDashboardTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      buttonLabel: buttonLabel,
      onTap: onTap,
    );
  }
}