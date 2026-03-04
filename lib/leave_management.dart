// leave_management.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'apply_leave.dart';
import 'leave_history_cancelled.dart';
import 'sidebar.dart';

class LeaveManagement extends StatefulWidget {
  const LeaveManagement({super.key});

  @override
  State<LeaveManagement> createState() => _LeaveManagementState();
}

class _LeaveManagementState extends State<LeaveManagement> {
  late Future<List<Map<String, dynamic>>> _leavesFuture;
  String? employeeId;
  final Set<String> _expandedReasons = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        employeeId = userProvider.employeeId;
        _leavesFuture = fetchLeaves();
      });
    });
  }

  Future<List<Map<String, dynamic>>> fetchLeaves() async {
    if (employeeId == null) {
      throw Exception("Employee ID not found");
    }

    final String fetchUrl = 'https://company-04bz.onrender.com/apply/fetch/$employeeId';
    debugPrint("👉 Fetching leaves from: $fetchUrl");

    final response = await http.get(Uri.parse(fetchUrl));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      // Support either list or { items: [...] }
      final List<dynamic> data =
          decoded is List ? decoded : (decoded['items'] ?? []);

      final leaves = data.cast<Map<String, dynamic>>();

      // Filter out cancelled (same as before)
      return leaves
          .where((leave) => leave['status']?.toLowerCase() != 'cancelled')
          .toList();
    } else {
      throw Exception('Failed to load leave data');
    }
  }

  Future<void> _cancelLeave(String leaveId) async {
    if (employeeId == null) return;

    final String deleteUrl =
        'https://company-04bz.onrender.com/apply/delete/$employeeId/$leaveId';
    debugPrint('🔗 Deleting leave via: $deleteUrl');

    final response = await http.delete(Uri.parse(deleteUrl));
    debugPrint('🧾 Response status: ${response.statusCode}');
    debugPrint('📦 Response body: ${response.body}');

    if (response.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave cancelled successfully')),
      );
      setState(() {
        _leavesFuture = fetchLeaves();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel leave: ${response.body}')),
        );
      }
    }
  }

  void _confirmCancel(BuildContext context, String leaveId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content: const Text('Are you sure you want to cancel this leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _cancelLeave(leaveId);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final DateTime parsedDate = DateTime.parse(rawDate);
      return DateFormat('yyyy/MM/dd').format(parsedDate);
    } catch (e) {
      return rawDate;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.black;
    }
  }

  Widget _buildStatusBadge(String? status) {
    final s = (status ?? 'Pending');
    Color color = Colors.orange;
    if (s.toLowerCase() == 'approved') color = Colors.green;
    if (s.toLowerCase() == 'rejected') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        s,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Leave Management',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: employeeId == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Leave Status',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LeaveHistoryCancelled(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('Cancelled History'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _leavesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text('No leave history found.'),
                          );
                        } else {
                          final leaves = snapshot.data!;
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: leaves.length,
                            itemBuilder: (context, index) {
                              final leave = leaves[index];
                              final id = leave['_id']?.toString() ?? '';
                              final status = (leave['status'] ?? 'Pending')
                                  .toString();
                              final isActionable = status.toLowerCase() !=
                                      'approved' &&
                                  status.toLowerCase() != 'rejected';

                              final String employeeName =
                                  leave['employeeName'] ??
                                      Provider.of<UserProvider>(context,
                                              listen: false)
                                          .employeeId ??
                                      'Employee';

                              final String reasonText =
                                  (leave['reason'] ?? '').toString();

                              final bool isLong = reasonText.length > 120;
                              final bool expanded = _expandedReasons.contains(id);

                              return Card(
                                elevation: 3,
                                margin:
                                    const EdgeInsets.only(bottom: 12, top: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            employeeName,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          _buildStatusBadge(status),
                                        ],
                                      ),
                                      const Divider(),
                                      Text("Leave Type: ${leave['leaveType'] ?? ''}"),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Dates: ${_formatDate(leave['fromDate'])} to ${_formatDate(leave['toDate'])}",
                                      ),
                                      const SizedBox(height: 8),
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
                                                _expandedReasons.remove(id);
                                              } else {
                                                _expandedReasons.add(id);
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(
                                              expanded ? "Show Less" : "Show More",
                                              style: const TextStyle(
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            tooltip: "Edit",
                                            icon: Icon(
                                              Icons.edit,
                                              color: isActionable
                                                  ? Colors.blue
                                                  : Colors.blue.withOpacity(0.4),
                                            ),
                                            onPressed: isActionable
                                                ? () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            ApplyLeave(
                                                                existingLeave:
                                                                    leave),
                                                      ),
                                                    ).then((_) {
                                                      // refresh after return
                                                      setState(() {
                                                        _leavesFuture =
                                                            fetchLeaves();
                                                      });
                                                    });
                                                  }
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: "Cancel",
                                            icon: Icon(
                                              Icons.delete,
                                              color: isActionable
                                                  ? Colors.red
                                                  : Colors.red.withOpacity(0.4),
                                            ),
                                            onPressed: isActionable
                                                ? () => _confirmCancel(context, id)
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}