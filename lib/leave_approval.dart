// leave_approval.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'sidebar.dart';
import 'user_provider.dart';

class LeaveApprovalPage extends StatefulWidget {
  final String userRole;
  const LeaveApprovalPage({super.key, required this.userRole});

  @override
  State<LeaveApprovalPage> createState() => _LeaveApprovalPageState();
}

class _LeaveApprovalPageState extends State<LeaveApprovalPage> {
  final String apiUrl = "https://company-04bz.onrender.com/apply";

  final ValueNotifier<List<dynamic>> filteredLeavesNotifier = ValueNotifier([]);
  String selectedFilter = "Pending";
  List<dynamic> allLeaves = [];

  // DOMAIN RELATED
  String selectedDomain = "All";
  List<String> domains = ["All"];

  // EMPLOYEE RELATED
  List<dynamic> allEmployees = [];
  String? selectedEmployeeId;

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedReasons = {};

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime toDate = DateTime.now();
  DateTimeRange? customRange;
  final DateFormat _formatter = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    fetchEmployees().then((_) => _setupDomainsForEmployee());
  }

  /// Fetch all employees from backend
  Future<void> fetchEmployees() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl/employees"));
      if (response.statusCode == 200) {
        allEmployees = json.decode(response.body)["employees"];
      }
    } catch (e) {
      debugPrint("❌ Fetch employees error: $e");
    }
  }

  /// Setup domains based on selected employee or default user
  Future<void> _setupDomainsForEmployee() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final String role = (userProvider.position ?? "").toUpperCase();
    final String? domain = userProvider.domain;

    // 🔴 TL → ONLY their domain in dropdown
    if (role == "TL" && domain != null && domain.isNotEmpty) {
      setState(() {
        domains = [domain]; // 👈 ONLY ONE DOMAIN
        selectedDomain = domain;
      });
      applyFilter();
      return; // ⛔ VERY IMPORTANT (stops fetchDomains)
    }

    // 🟡 HR / Founder → all domains
    await fetchDomains();
    applyFilter();
  }

  /// Fetch all domains from backend
  Future<void> fetchDomains() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl/domains"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          domains = List<String>.from(data['domains']);
          if (!domains.contains("All")) domains.insert(0, "All");
          selectedDomain = "All";
        });
      }
    } catch (e) {
      debugPrint("❌ Fetch domains error: $e");
    }
  }

  @override
  void dispose() {
    filteredLeavesNotifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Fetch leaves based on filters
  Future<void> applyFilter() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final String role = userProvider.position ?? "";
      final String empId = selectedEmployeeId ?? userProvider.employeeId ?? "";

      String url = "$apiUrl/filter?role=$role&employeeId=$empId";

      if (selectedFilter == "Last 7 Days") {
        url +=
            "&status=All&fromDate=${_formatter.format(DateTime.now().subtract(const Duration(days: 6)))}"
            "&toDate=${_formatter.format(DateTime.now())}";
      } else if (selectedFilter == "Last 30 Days") {
        url +=
            "&status=All&fromDate=${_formatter.format(DateTime.now().subtract(const Duration(days: 29)))}"
            "&toDate=${_formatter.format(DateTime.now())}";
      } else if (selectedFilter == "Custom Range" && customRange != null) {
        url +=
            "&status=All&fromDate=${_formatter.format(customRange!.start)}"
            "&toDate=${_formatter.format(customRange!.end)}";
      } else {
        url += "&status=$selectedFilter";
      }

      if (selectedDomain != "All") {
        url += "&domain=$selectedDomain";
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final items = json.decode(response.body)["items"];
        setState(() {
          allLeaves = items;
          _expandedReasons.clear();
        });
        _applySearch();
      }
    } catch (e) {
      debugPrint("❌ Filter Error: $e");
    }
  }

  void _applySearch() {
    final query = searchQuery.toLowerCase();
    final results = allLeaves.where((leave) {
      final name = (leave['employeeName'] ?? '').toString().toLowerCase();
      final status = (leave['status'] ?? '').toString().toLowerCase();
      return name.contains(query) || status.contains(query);
    }).toList();

    filteredLeavesNotifier.value = results;
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "Leave Approval",
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                /// Search Bar
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      searchQuery = val;
                      _applySearch();
                    },
                    decoration: InputDecoration(
                      hintText: "Search by employee name or status",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                /// Filter Button
                ElevatedButton.icon(
                  onPressed: () async {
                    final val = await showMenu<String>(
                      context: context,
                      position: const RelativeRect.fromLTRB(1000, 80, 20, 0),
                      items: const [
                        PopupMenuItem(value: "Pending", child: Text("Pending")),
                        PopupMenuItem(
                          value: "Approved",
                          child: Text("Approved"),
                        ),
                        PopupMenuItem(
                          value: "Rejected",
                          child: Text("Rejected"),
                        ),
                        PopupMenuItem(value: "All", child: Text("All History")),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: "Last 7 Days",
                          child: Text("Last 7 Days"),
                        ),
                        PopupMenuItem(
                          value: "Last 30 Days",
                          child: Text("Last 30 Days"),
                        ),
                        PopupMenuItem(
                          value: "Custom Range",
                          child: Text("Custom Range"),
                        ),
                      ],
                    );

                    if (val == "Custom Range") {
                      await _pickDateRange(context);
                    } else if (val != null) {
                      setState(() {
                        selectedFilter = val;
                        searchQuery = "";
                        _searchController.clear();
                      });
                      applyFilter();
                    }
                  },
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: Text("Filter: $selectedFilter"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),

                /// Domain Button
                ElevatedButton(
                  onPressed: () async {
                    final val = await showMenu<String>(
                      context: context,
                      position: const RelativeRect.fromLTRB(1000, 80, 20, 0),
                      items: domains
                          .map((d) => PopupMenuItem(value: d, child: Text(d)))
                          .toList(),
                    );
                    if (val != null) {
                      setState(() {
                        selectedDomain = val;
                      });
                      applyFilter();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple, // same as filter button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.domain_outlined,
                        size: 18,
                      ), // optional icon
                      const SizedBox(width: 6),
                      Text(selectedDomain),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// Leave List
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ValueListenableBuilder<List<dynamic>>(
                valueListenable: filteredLeavesNotifier,
                builder: (context, currentFilteredLeaves, child) {
                  if (currentFilteredLeaves.isEmpty) {
                    return const Center(
                      child: Text(
                        "No data found for this filter",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: currentFilteredLeaves.length,
                    itemBuilder: (context, i) {
                      final leave = currentFilteredLeaves[i];
                      final String leaveId = leave['_id'];
                      final bool expanded = _expandedReasons.contains(leaveId);

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    leave['employeeName'],
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  _buildStatusBadge(leave['status']),
                                ],
                              ),
                              const Divider(),
                              Text("Leave Type: ${leave['leaveType']}"),
                              const SizedBox(height: 4),
                              Text(
                                "Dates: ${leave['fromDate']} to ${leave['toDate']}",
                              ),
                              const SizedBox(height: 6),

                              Builder(
                                builder: (context) {
                                  final String reasonText =
                                      leave['reason'] ?? 'N/A';
                                  // We use 90 characters as a safe estimate for 2 lines on most mobile screens
                                  final bool isLong = reasonText.length > 90;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reasonText,
                                        maxLines: expanded ? null : 2,
                                        overflow: expanded
                                            ? TextOverflow.visible
                                            : TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (isLong)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (expanded) {
                                                _expandedReasons.remove(
                                                  leaveId,
                                                );
                                              } else {
                                                _expandedReasons.add(leaveId);
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              expanded
                                                  ? "Show Less"
                                                  : "Show More",
                                              style: const TextStyle(
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),

                              if (leave['status'] == "Pending") ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => updateStatus(
                                        leave['_id'],
                                        "Rejected",
                                      ),
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        "Reject",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => updateStatus(
                                        leave['_id'],
                                        "Approved",
                                      ),
                                      icon: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      label: const Text("Approve"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    if (status == "Approved") color = Colors.green;
    if (status == "Rejected") color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> updateStatus(String id, String status) async {
    final response = await http.put(
      Uri.parse("$apiUrl/status/$id"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"status": status}),
    );
    if (response.statusCode == 200) applyFilter();
  }

  Future<void> _pickDateRange(BuildContext context) async {
    DateTime tempFrom = fromDate;
    DateTime tempTo = toDate;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Custom Date Range",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "From Date",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                controller: TextEditingController(
                  text: _formatter.format(tempFrom),
                ),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: tempFrom,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setModalState(() => tempFrom = p);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "To Date",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                controller: TextEditingController(
                  text: _formatter.format(tempTo),
                ),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: tempTo,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setModalState(() => tempTo = p);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    fromDate = tempFrom;
                    toDate = tempTo;
                    customRange = DateTimeRange(start: fromDate, end: toDate);
                    selectedFilter = "Custom Range";
                  });
                  Navigator.pop(context);
                  applyFilter();
                },
                child: const Text("Apply Filter"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}