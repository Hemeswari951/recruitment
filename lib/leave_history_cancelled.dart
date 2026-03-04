import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'sidebar.dart';
import 'user_provider.dart';

class LeaveHistoryCancelled extends StatefulWidget {
  const LeaveHistoryCancelled({super.key});

  @override
  State<LeaveHistoryCancelled> createState() =>
      _LeaveHistoryCancelledState();
}

class _LeaveHistoryCancelledState
    extends State<LeaveHistoryCancelled> {

  Future<List<Map<String, dynamic>>>? _cancelledLeavesFuture;
  final Set<String> _expandedReasons = {};

  static const String baseUrl =
      'https://company-04bz.onrender.com/apply/cancelled';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final employeeId =
          Provider.of<UserProvider>(context, listen: false)
              .employeeId;

      if (employeeId != null && employeeId.isNotEmpty) {
        setState(() {
          _cancelledLeavesFuture =
              fetchCancelledLeaves(employeeId);
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> fetchCancelledLeaves(
      String employeeId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/$employeeId'));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map &&
          decoded['items'] != null) {
        return (decoded['items'] as List)
            .cast<Map<String, dynamic>>();
      } else {
        throw Exception("Unexpected response format");
      }
    } else {
      throw Exception('Failed to load cancelled leaves');
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final parsedDate = DateTime.parse(dateStr);
      return DateFormat('yyyy/MM/dd')
          .format(parsedDate);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildStatusBadge(String? status) {
    final s = status ?? 'Cancelled';
    Color color = Colors.red;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        s,
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Leave Management',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// 🔹 Same Header Style as Leave Management
            Row(
              children: const [
                Text(
                  'Cancelled Leave History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _cancelledLeavesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Text(
                            'Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text(
                            'No cancelled leave history found.'));
                  } else {
                    final leaves = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: leaves.length,
                      itemBuilder: (context, index) {
                        final leave = leaves[index];
                        final id = leave['_id']?.toString() ?? '';
                        final status =
                            (leave['status'] ?? 'Cancelled').toString();

                        final String employeeName = leave['employeeName'] ??
                            Provider.of<UserProvider>(context, listen: false)
                                .employeeId ??
                            'Employee';

                        final String reasonText =
                            (leave['reason'] ?? '').toString();

                        final bool isLong = reasonText.length > 120;
                        final bool expanded = _expandedReasons.contains(id);

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12, top: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                  "Dates: ${formatDate(leave['fromDate'])} to ${formatDate(leave['toDate'])}",
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
                                      padding: const EdgeInsets.only(top: 6),
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