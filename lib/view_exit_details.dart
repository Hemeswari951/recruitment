import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sidebar.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewExitPage extends StatefulWidget {
  const ViewExitPage({super.key});

  @override
  State<ViewExitPage> createState() => _ViewExitPageState();
}

class _ViewExitPageState extends State<ViewExitPage> {
  List<dynamic> exitList = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchExitDetails();
  }

  /// =============================
  /// FETCH EXIT DETAILS
  /// =============================
  Future<void> fetchExitDetails() async {
    try {
      final response = await http.get(
        Uri.parse("http://localhost:5000/api/exitDetails"),
      );

      if (response.statusCode == 200) {
        setState(() {
          exitList = jsonDecode(response.body);
          loading = false;
        });
      }
    } catch (e) {
      print("Error fetching exit details: $e");
    }
  }

  /// =============================
  /// DELETE EXIT RECORD
  /// =============================
  Future<void> deleteExitRecord(String id) async {
    try {
      final response = await http.delete(
        Uri.parse("http://localhost:5000/api/exitDetails/$id"),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Record deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
        fetchExitDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete record"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Delete error: $e");
    }
  }

  /// =============================
  /// CONFIRM DELETE POPUP
  /// =============================
  void confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Record"),
          content: const Text("Are you sure you want to delete this record?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                deleteExitRecord(id);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
   /// =============================
  /// OPEN PDF FUNCTION
  /// =============================
  void _openPDF(String url) async {
    final Uri fileUri = Uri.parse(url);

    if (await canLaunchUrl(fileUri)) {
      await launchUrl(
        fileUri,
        mode: LaunchMode.externalApplication, // Opens PDF viewer
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to open PDF"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "Exit Details",
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : exitList.isEmpty
              ? const Center(
                  child: Text(
                    "No Exit Records Found",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                )
              : _buildViewExitTable(),
    );
  }

  /// =============================
  /// CENTERED + EXPANDED TABLE
  /// =============================
  Widget _buildViewExitTable() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 5),
              )
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "View Exit Details",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 20),

              /// ============================
              /// EXPANDED TABLE WITH FIX
              /// ============================
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 600, // <-- Vertical expand fix
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,

                        child: DataTable(
                          headingRowHeight: 55,
                          dataRowHeight: 70, // <-- Bigger row height
                          columnSpacing: 60, // <-- More spacing

                          columns: const [
                            DataColumn(
                              label: Text(
                                "Sl.No",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Employee ID",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Name",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Position",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Resignation Date",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Acceptance Date",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Notice Period",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Actions",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],

                          rows: List.generate(exitList.length, (index) {
                            final e = exitList[index];

                            return DataRow(
                              cells: [
                                DataCell(Text("${index + 1}")),
                                DataCell(Text(e["employeeId"].toString())),
                                DataCell(Text(e["name"].toString())),
                                DataCell(Text(e["position"].toString())),
                                DataCell(Text(
                                    e["resignationDate"]?.toString().substring(0, 10) ?? "--")),
                                DataCell(Text(
                                    e["acceptanceDate"]?.toString().substring(0, 10) ?? "--")),
                                DataCell(Text(e["noticePeriod"] ?? "--")),
                               DataCell(
  Row(
    children: [
      // ============================
      // VIEW PDF BUTTON
      // ============================
      if (e["exitDocument"] != null && e["exitDocument"].toString().isNotEmpty)
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
          onPressed: () {
            final fileName = e["exitDocument"];
            final url = "http://localhost:5000/api/exitDetails/file/$fileName";

            // Open in browser (Web) or launch externally
            _openPDF(url);
          },
        )
      else
        const Text(
          "No File",
          style: TextStyle(color: Colors.red, fontSize: 12),
        ),

      // ============================
      // DELETE BUTTON
      // ============================
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => confirmDelete(e["_id"]),
      ),
    ],
  ),
),

                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}