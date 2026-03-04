//adminperformance.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

import 'admin_notification.dart';
import 'sidebar.dart';
import 'user_provider.dart';

class PerformanceReviewPage extends StatefulWidget {
  final String currentUserId; // ✅ logged-in admin’s empId

  const PerformanceReviewPage({super.key, required this.currentUserId});
  @override
  State<PerformanceReviewPage> createState() => _PerformanceReviewPageState();
}

class _PerformanceReviewPageState extends State<PerformanceReviewPage> {
  String selectedEmpId = "EMP ID";
  String selectedEmpName = "EMP NAME";

  Map<String, String> empMap = {}; // Will be fetched from API
  late Map<String, String> nameToIdMap = {};

  final Map<String, Color> flagColors = {
    "Green Flag": Colors.green,
    "Yellow Flag": Colors.yellow,
    "Red Flag": Colors.red,
  };

  String selectedFlag = "Green Flag";

  TextEditingController communicationController = TextEditingController();
  TextEditingController attitudeController = TextEditingController();
  TextEditingController technicalKnowledgeController = TextEditingController();
  TextEditingController businessKnowledgeController = TextEditingController();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Fetch employees when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDomainEmployees();
    });
  }

  String getCurrentMonth() {
    return [
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
    ][DateTime.now().month - 1];
  }

  // Fetch employees based on the TL's domain
  Future<void> _fetchDomainEmployees() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final domain = userProvider.domain;

    try {
      final response = await http.get(
        Uri.parse('https://company-04bz.onrender.com/api/employees/domain/$domain'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> employees = jsonDecode(response.body);
        setState(() {
          empMap = {
            for (var e in employees) e['employeeId']: e['employeeName'],
          };
          nameToIdMap = {for (var e in empMap.entries) e.value: e.key};
        });
      }
    } catch (e) {
      print('Error fetching domain employees: $e');
    }
  }

  Future<void> submitReview() async {
      if (selectedEmpId == "EMP ID" ||
          selectedEmpName == "EMP NAME" ||
          communicationController.text.trim().isEmpty ||
          attitudeController.text.trim().isEmpty ||
          technicalKnowledgeController.text.trim().isEmpty ||
          businessKnowledgeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠ Please fill in all fields before submitting."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      setState(() => isLoading = true); // Added loading state

      final url = Uri.parse('https://company-04bz.onrender.com/reviews');
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final reviewerName = userProvider.employeeName ?? 'Admin';
      
      final body = {
        "empId": selectedEmpId,
        "empName": selectedEmpName,
        "communication": communicationController.text,
        "attitude": attitudeController.text,
        "technicalKnowledge": technicalKnowledgeController.text,
        "business": businessKnowledgeController.text,
        "reviewedBy": reviewerName,
        "flag": selectedFlag,
      };

      try {
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );

        if (response.statusCode == 201) {
            final reviewData = jsonDecode(response.body);
            final String reviewId = (reviewData['id'] ?? reviewData['_id'] ?? "").toString();
            final String currentMonth = getCurrentMonth();
            final int currentYear = DateTime.now().year;

            final notifUrl = Uri.parse("https://company-04bz.onrender.com/notifications");

            // 🔹 Shared Performance Data (The actual review content)
            final Map<String, dynamic> performanceFields = {
              "month": currentMonth,
              "year": currentYear,
              "category": "performance",
              "flag": selectedFlag,
              "senderName": reviewerName, 
              // "receiverId": selectedEmpId,  
              "senderId": widget.currentUserId,
              "reviewId": reviewId,
              "empName": selectedEmpName, // Always store the Subject's name
              "communication": communicationController.text,
              "attitude": attitudeController.text,
              "technicalKnowledge": technicalKnowledgeController.text,
              "business": businessKnowledgeController.text,
            };

            // 🔹 1. Notification for the EMPLOYEE (The one being reviewed)
            await http.post(
              notifUrl,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                ...performanceFields,
                "empId": selectedEmpId,
                "receiverId": selectedEmpId,      
                "message": "Performance review received from $reviewerName - $currentMonth",
              }),
            );

            // 🔹 2. Notification for the ADMIN (Self-copy for history)
            await http.post(
              notifUrl,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                ...performanceFields,
                "empId": widget.currentUserId,
                "receiverId": selectedEmpId,  
                "message": "Performance review sent to $selectedEmpName - $currentMonth",
              }),
            );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Review submitted successfully"),
              backgroundColor: Colors.green,
            ),
          );

          // ✅ Reset form
          _clearForm();

          // ✅ Navigate to Notification screen
          Future.delayed(const Duration(milliseconds: 300), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AdminNotificationsPage(empId: widget.currentUserId),
              ),
            );
          });
        } else {
          // Handle errors (Duplicate reviews, etc.)
          final data = jsonDecode(response.body);
          _showError(data['message'] ?? "Failed to submit");
        }
      } catch (e) {
        _showError("Error: $e");
      } finally {
        setState(() => isLoading = false);
      }
    }

    // Helper methods to keep code clean
    void _clearForm() {
      communicationController.clear();
      attitudeController.clear();
      technicalKnowledgeController.clear();
      businessKnowledgeController.clear();
      setState(() {
        selectedEmpId = "EMP ID";
        selectedEmpName = "EMP NAME";
        selectedFlag = "Green Flag";
      });
    }

    void _showError(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "Performance Review",
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Employee selectors + Flag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Performance Review",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 🔹 Employee Name Dropdown FIRST
                    empDropdown(
                      ["EMP NAME", ...nameToIdMap.keys],
                      selectedEmpName,
                      (val) {
                        setState(() {
                          selectedEmpName = val!;
                          selectedEmpId = val == "EMP NAME"
                              ? "EMP ID"
                              : nameToIdMap[val]!;
                        });
                      },
                      160,
                    ),
                    const SizedBox(width: 10),
                    // 🔹 Employee ID Dropdown (auto-filled, not editable)
                    empDropdown(
                      [selectedEmpId],
                      selectedEmpId,
                      (_) {},
                      120,
                      enabled: false,
                    ),
                  ],
                ),
                // Flag dropdown
                Container(
                  width: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: Colors.white,
                      value: selectedFlag,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                      ),
                      style: TextStyle(color: flagColors[selectedFlag]),
                      items: flagColors.keys.map((String val) {
                        return DropdownMenuItem(
                          value: val,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: flagColors[val],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                val,
                                style: TextStyle(color: flagColors[val]),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedFlag = val!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Flag bar
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: flagColors[selectedFlag],
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            const SizedBox(height: 20),

            // Review fields
            reviewField("Communication", communicationController),
            reviewField("Attitude", attitudeController),
            reviewField("Technical knowledge", technicalKnowledgeController),
            reviewField("Business", businessKnowledgeController),

            const SizedBox(height: 20),

            // 🔹 Send Button
            Align(
              alignment: Alignment.centerRight,
              child: _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final reviewerName =
        Provider.of<UserProvider>(context, listen: false).employeeName ??
        'Admin';
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text("Reviewed by", style: TextStyle(color: Colors.white70)),
            Text(
              reviewerName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          onPressed: isLoading ? null : submitReview,
          icon: const Icon(Icons.send),
          label: const Text("Send"),
        ),
      ],
    );
  }

  Widget reviewField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label:",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Text field for $label",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget empDropdown(
    List<String> items,
    String value,
    ValueChanged<String?> onChanged,
    double width, {
    bool enabled = true,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: Colors.white24,
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: const TextStyle(color: Colors.white),
          items: items
              .map(
                (String val) => DropdownMenuItem(
                  value: val,
                  child: Text(val, style: const TextStyle(color: Colors.white)),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}