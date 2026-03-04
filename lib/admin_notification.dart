//admin_notification.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zeai_project/user_provider.dart';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'message.dart';
import 'reports.dart';
import 'sidebar.dart';

class AdminNotificationsPage extends StatefulWidget {
  final String empId;
  const AdminNotificationsPage({required this.empId, super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final Color darkBlue = const Color(0xFF0F1020);

  late String selectedMonth;
  late int selectedYear;
  bool isLoading = false;
  String? error;
  String? expandedKey;

  final List<String> months = [
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
  ];

  List<Map<String, dynamic>> message = [];
  List<Map<String, dynamic>> performance = [];
  List<Map<String, dynamic>> holidays = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = months[now.month - 1];
    selectedYear = now.year;
    _markAllAsRead();
    fetchNotifs();
  }

  final Map<String, TextEditingController> _replyControllers = {};

  final Map<String, String> _employeeNames = {};

  final Map<String, List<PlatformFile>> _replyFiles = {};

  @override
  void dispose() {
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showPerformancePreview(
    BuildContext context,
    Map<String, dynamic> notif,
  ) {
    final flagColor = _getFlagColor(notif['flag'] ?? "");

    // Format the date to match your image: YYYY-MM-DD hh:mm AM/PM
    String formattedDate = "N/A";
    if (notif['createdAt'] != null) {
      try {
        DateTime dt = DateTime.parse(notif['createdAt']).toLocal();
        String hour = (dt.hour % 12 == 0 ? 12 : dt.hour % 12)
            .toString()
            .padLeft(2, '0');
        String min = dt.minute.toString().padLeft(2, '0');
        String amPm = dt.hour >= 12 ? "PM" : "AM";
        formattedDate =
            "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hour:$min $amPm";
      } catch (e) {
        formattedDate = notif['createdAt'];
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1EDF7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 6, width: double.infinity, color: flagColor),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Performance Review Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _imageStyleRow(
                      "Sent To",
                      "${notif['empName']} (${notif['receiverId']})",
                    ),
                    _imageStyleRow(
                      "Performance Review By",
                      "${notif['senderName']} (${notif['senderId']})",
                    ),
                    _imageStyleRow(
                      "Communication",
                      notif['communication'] ?? "good",
                    ),
                    _imageStyleRow("Attitude", notif['attitude'] ?? "good"),
                    _imageStyleRow(
                      "Technical Knowledge",
                      notif['technicalKnowledge'] ?? "good",
                    ),
                    _imageStyleRow("Business", notif['business'] ?? "good"),

                    // Flag Row
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          children: [
                            const TextSpan(text: "Flag: "),
                            TextSpan(
                              text: notif['flag'] ?? "Green Flag",
                              style: TextStyle(
                                color: flagColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _imageStyleRow("Reviewed At", formattedDate),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "CLOSE",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to match the plain text list style in your image
  Widget _imageStyleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        "$label: $value",
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }

  Color _getFlagColor(String flag) {
    final f = flag.toLowerCase();
    if (f.contains("green")) return Colors.green;
    if (f.contains("red")) return Colors.red;
    if (f.contains("yellow") || f.contains("orange")) return Colors.orange;
    return Colors.grey;
  }

  Future<void> _markAllAsRead() async {
    await http.put(
      Uri.parse(
        "https://company-04bz.onrender.com/notifications/mark-read/${widget.empId}",
      ),
    );
  }

  Future<void> fetchNotifs() async {
    setState(() {
      isLoading = true;
      error = null;
      message.clear();
      performance.clear();
      holidays.clear();
      expandedKey = null;
    });

    try {
      await Future.wait([
        fetchSmsNotifications(),
        fetchPerformanceNotifications(),
        fetchHolidayNotifications(),
      ]);
      setState(() {});
    } catch (e) {
      setState(() => error = "Server/network error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Uint8List bytes = response.bodyBytes;
        String extension = fileName.split('.').last.toLowerCase();

        // This saves the file directly to the device
        await FileSaver.instance.saveFile(
          name: fileName.split('.').first,
          bytes: bytes,
          ext: extension,
          mimeType: _getMimeType(extension),
        );

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Downloaded $fileName")));
        }
      } else {
        throw "Fetch failed";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Download error: $e")));
      }
    }
  }

  MimeType _getMimeType(String ext) {
    switch (ext) {
      case 'pdf':
        return MimeType.pdf;
      case 'png':
        return MimeType.png;
      case 'jpg':
      case 'jpeg':
        return MimeType.jpeg;
      default:
        return MimeType.other;
    }
  }

  /// 🔹 Fetch SMS Notifications (Filtered by Year and Month)
  Future<void> fetchSmsNotifications() async {
    final uri = Uri.parse(
      "https://company-04bz.onrender.com/notifications/employee/${widget.empId}?month=$selectedMonth&year=$selectedYear&category=message",
    );
    final resp = await http.get(uri);

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      if (decoded is List) {
        if (mounted) {
          setState(() {
            message = decoded.cast<Map<String, dynamic>>();
          });

          // ✅ AFTER setting the state, trigger fetching the names for the UI
          final myId = widget.empId;
          for (var notif in message) {
            String otherUserId =
                (notif['empId'] == myId
                    ? notif['receiverId']
                    : notif['empId']) ??
                "";
            _fetchEmployeeName(otherUserId);
          }
        }
      }
    } else if (resp.statusCode == 404) {
      if (mounted) setState(() => message = []);
    }
  }

  // ✅ NEW METHOD: Fetch the other person's name from the database
  Future<void> _fetchEmployeeName(String partnerId) async {
    if (partnerId.isEmpty || _employeeNames.containsKey(partnerId)) return;

    try {
      final response = await http.get(
        Uri.parse("https://company-04bz.onrender.com/api/employees/$partnerId"),
      );

      if (response.statusCode == 200) {
        final empData = json.decode(response.body);
        if (mounted) {
          setState(() {
            _employeeNames[partnerId] = empData['employeeName'] ?? "Unknown";
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching employee name for $partnerId: $e");
    }
  }

  Future<void> _sendQuickReply(
    String senderId,
    String receiverId,
    String text,
    String cardKey,
  ) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final senderName = userProvider.employeeName ?? "";

    final files = _replyFiles[cardKey] ?? [];

    if (text.trim().isEmpty && files.isEmpty) return;

    String month = months[DateTime.now().month - 1];

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://company-04bz.onrender.com/notifications/with-files"),
      );

      // ✅ ADD FIELDS (Exclude message initially)
      request.fields.addAll({
        "month": month,
        "year": DateTime.now().year.toString(),
        "category": "message",
        "empId": senderId,
        "receiverId": receiverId,
        "senderId": senderId,
        "senderName": senderName,
      });

      // ✅ ONLY add message if text is provided
      if (text.trim().isNotEmpty) {
        request.fields["message"] = text.trim();
      }

      // ✅ Add attachments
      for (final file in files) {
        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              "attachments",
              file.bytes!,
              filename: file.name,
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _replyControllers[cardKey]?.clear();
        _replyFiles[cardKey]?.clear();

        setState(() => expandedKey = null);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reply sent!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Quick Reply Error: $e");
    }
  }

  // ✅ NEW METHOD: Hide notification on the frontend and backend
  Future<void> _hideNotification(String notificationId, String category) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myId = userProvider.employeeId ?? "";

    try {
      final response = await http.put(
        Uri.parse("https://company-04bz.onrender.com/notifications/hide/$notificationId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"empId": myId}),
      );

      if (response.statusCode == 200) {
        // Remove from the local UI list immediately
        setState(() {
          if (category == 'message') {
            message.removeWhere((n) => n['_id'] == notificationId);
          } else if (category == 'performance') {
            performance.removeWhere((n) => n['_id'] == notificationId);
          } else if (category == 'holidays') {
            holidays.removeWhere((n) => n['_id'] == notificationId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notification removed"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error hiding notification: $e");
    }
  }

  Future<void> _pickReplyFiles(String cardKey) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _replyFiles.putIfAbsent(cardKey, () => []);
        _replyFiles[cardKey]!.addAll(result.files);
      });
    }
  }

  Future<void> fetchPerformanceNotifications() async {
    // This route hits the 'performance/admin/:adminId' endpoint in your JS
    final uri = Uri.parse(
      "https://company-04bz.onrender.com/notifications/performance/admin/${widget.empId}?month=$selectedMonth&year=$selectedYear",
    );

    final resp = await http.get(uri);

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      if (decoded is List) {
        setState(() {
          performance = decoded.cast<Map<String, dynamic>>().toList();
        });
      }
    } else {
      // ✅ Changed from 404 check to general else to ensure list clears on error
      setState(() => performance = []);
    }
  }

  Future<void> fetchHolidayNotifications() async {
    final uri = Uri.parse(
      "https://company-04bz.onrender.com/notifications/holiday/admin/$selectedMonth?year=$selectedYear",
    );
    final resp = await http.get(uri);

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      if (decoded is List) {
        setState(() => holidays = decoded.cast<Map<String, dynamic>>());
      }
    } else if (resp.statusCode == 404) {
      setState(() => holidays = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We calculate the total count from your three lists
    final int totalCount =
        performance.length + message.length + holidays.length;

    return PopScope(
      canPop: true,
      // This ensures that when the user goes back, the totalCount is sent to the Dashboard
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // If you have a back button in your Sidebar, make sure it calls:
          // Navigator.pop(context, totalCount);
        }
      },
      child: Sidebar(
        title: "Admin Notifications",
        body: Column(
          children: [
            _buildHeader(),
            // 1. Header Row with dynamic count display
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Updated this text to show the number of notifications found
                  Text(
                    "Notifications ($totalCount)",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      _dropdownYear(),
                      const SizedBox(width: 10),
                      _dropdownMonth(),
                    ],
                  ),
                ],
              ),
            ),

            // 2. The scrollable content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Center(
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(top: 14),
                        children: [
                          notificationCategory("Performance", performance),
                          notificationCategory("Message", message),
                          notificationCategory("Holidays", holidays),
                          const SizedBox(height: 20), // Bottom padding
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownYear() {
    final years = List.generate(5, (i) => DateTime.now().year - i);
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedYear,
          items: years
              .map((y) => DropdownMenuItem(value: y, child: Text("$y")))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => selectedYear = val);
              fetchNotifs();
            }
          },
        ),
      ),
    );
  }

  Widget _dropdownMonth() {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedMonth,
          isExpanded: true,
          items: months
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => selectedMonth = val);
              fetchNotifs();
            }
          },
        ),
      ),
    );
  }

  Widget notificationCategory(String title, List<Map<String, dynamic>> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              "No $title found",
              style: const TextStyle(color: Colors.white70),
            ),
          )
        else
          ...list.asMap().entries.map(
            (entry) =>
                notificationCard(entry.value, entry.key, title.toLowerCase()),
          ),
      ],
    );
  }

  Widget notificationCard(
    Map<String, dynamic> notif,
    int index,
    String categoryParam,
  ) {
    final cardKey = "$categoryParam-$index";
    final isExpanded = expandedKey == cardKey;
    final category = (notif['category'] ?? "").toString().toLowerCase();
    // 1. Extract raw conversation history
    final List rawConversation = notif['messages'] ?? [];
    final String threadSenderId = notif['senderId'] ?? '';

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myId = userProvider.employeeId ?? "";

    String otherUserId =
        (notif['empId'] == myId ? notif['receiverId'] : notif['empId']) ?? "";

    // ✅ 2. Filter conversation to keep ONLY the latest message from each side
    List conversation = [];
    bool foundMine = false;
    bool foundTheirs = false;

    // Loop backwards to get the most recent messages first
    for (int i = rawConversation.length - 1; i >= 0; i--) {
      final msg = rawConversation[i];
      bool isMe = msg['senderId'] == myId;

      if (isMe && !foundMine) {
        // Insert at index 0 so older messages stay at the top visually
        conversation.insert(0, msg);
        foundMine = true;
      } else if (!isMe && !foundTheirs) {
        conversation.insert(0, msg);
        foundTheirs = true;
      }

      // Once we have found the latest message from both sides, stop searching
      if (foundMine && foundTheirs) break;
    }

    if (!_replyControllers.containsKey(cardKey)) {
      _replyControllers[cardKey] = TextEditingController();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) {
                      final userProvider = Provider.of<UserProvider>(
                        context,
                        listen: false,
                      );
                      final myId = userProvider.employeeId ?? "";
                      String chatPartnerName = "";

                      if (category == "message") {
                        // 1. Try to get the name from our API cache
                        if (_employeeNames.containsKey(otherUserId)) {
                          chatPartnerName = _employeeNames[otherUserId]!;
                        } else {
                          // 2. Fallback while API loads
                          if (notif['senderId'] == myId) {
                            chatPartnerName =
                                "Loading..."; // You started it, waiting for API
                          } else {
                            chatPartnerName =
                                notif['senderName'] ??
                                "Unknown"; // They started it
                          }
                        }
                      }

                      return Text(
                        category == "message"
                            ? "Chat with $chatPartnerName"
                            : "Notification",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: category == "message"
                              ? Colors.deepPurple
                              : Colors.blueGrey,
                        ),
                      );
                    },
                  ),

                  // 🔥 ADMIN PERFORMANCE LOGIC
                  if (category == "performance")
                    TextButton(
                      onPressed: () {
                        final userProvider = Provider.of<UserProvider>(
                          context,
                          listen: false,
                        );

                        final String? loggedInUserId = userProvider.employeeId;
                        final String senderId = notif['senderId'] ?? "";

                        if (loggedInUserId != null &&
                            loggedInUserId == senderId) {
                          _showPerformancePreview(context, notif);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => const ReportsAnalyticsPage(),
                            ),
                          );
                        }
                      },
                      child: const Text("View"),
                    ),
                  // Right: all 3 buttons clustered
                  if (category == "message")
                    Row(
                      mainAxisSize:
                          MainAxisSize.min, // Important: keeps buttons tight
                      children: [
                        // Open Chat
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          tooltip: "Open Chat",
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MsgPage(employeeId: otherUserId),
                              ),
                            );
                          },
                        ),

                        // Reply
                        IconButton(
                          icon: const Icon(Icons.reply, size: 18),
                          tooltip: "Reply",
                          color: expandedKey == cardKey
                              ? Colors.deepPurple
                              : Colors.deepPurple,
                          onPressed: () {
                            setState(() {
                              expandedKey = expandedKey == cardKey
                                  ? null
                                  : cardKey;
                            });
                          },
                        ),

                        // Delete
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          tooltip: "Remove",
                          onPressed: () {
                            if (notif['_id'] != null) {
                              _hideNotification(notif['_id'], categoryParam);
                            }
                          },
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 5),

              // Latest message preview
              Text(
                (notif['message'] != null &&
                        notif['message'].toString().isNotEmpty)
                    ? notif['message']
                    : "📎 Attachment",
                style: const TextStyle(color: Colors.black87),
                maxLines: isExpanded ? null : 1,
              ),

              // 🔥 CONVERSATION HISTORY
              if (isExpanded && category == "message") ...[
                const Divider(height: 30),
                const Text(
                  "Conversation History",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),

                ...conversation.map((msg) {
                  final userProvider = Provider.of<UserProvider>(
                    context,
                    listen: false,
                  );
                  bool isMe = msg['senderId'] == userProvider.employeeId;

                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.deepPurple[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMe ? "You" : msg['senderName'] ?? "Other",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.deepPurple : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((msg['text'] ?? "").isNotEmpty)
                                Text(
                                  msg['text'],
                                  style: const TextStyle(fontSize: 13),
                                ),

                              if (msg['attachments'] != null &&
                                  (msg['attachments'] as List).isNotEmpty)
                                ...((msg['attachments'] as List).map((file) {
                                  final String fileName =
                                      file['originalName'] ??
                                      file['filename'] ??
                                      "file";

                                  final String filePath =
                                      "https://company-04bz.onrender.com/uploads/notifications/${file['filename']}";

                                  return GestureDetector(
                                    onTap: () =>
                                        _downloadFile(filePath, fileName),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.insert_drive_file,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              fileName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 15),

                // 🔥 REPLY INPUT
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyControllers[cardKey],
                        decoration: InputDecoration(
                          hintText: "Write a reply...",
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // 📎 Upload Button
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file,
                        color: Colors.deepPurple,
                      ),
                      onPressed: () => _pickReplyFiles(cardKey),
                    ),

                    // 🚀 Send Button
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.deepPurple),
                      onPressed: () {
                        _sendQuickReply(
                          myId,
                          otherUserId,
                          _replyControllers[cardKey]!.text,
                          cardKey,
                        );
                      },
                    ),
                  ],
                ),

                if ((_replyFiles[cardKey] ?? []).isNotEmpty)
                  Column(
                    children: _replyFiles[cardKey]!
                        .map(
                          (file) => Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Row(
                              children: [
                                const Icon(Icons.insert_drive_file, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    file.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(height: 60, color: darkBlue);
}