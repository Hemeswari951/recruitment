// message.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class MsgPage extends StatefulWidget {
  final String? employeeId;
  const MsgPage({super.key, this.employeeId});
  @override
  State<MsgPage> createState() => _MsgPageState();
}

class _MsgPageState extends State<MsgPage> {
  List<dynamic> _chatSidebarList = [];
  String? _selectedEmployeeId;
  Map<String, String> _sidebarImages = {};
  Map<String, dynamic>? employeeData;
  Map<String, String> _sidebarNames = {};
  Map<String, int> _messageIndexMap = {};
  String? _highlightedMessageId;
  List<dynamic> _chatHistory = [];
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = true;
  bool _showEmoji = false;
  bool _isTyping = false;
  Timer? _refreshTimer;
  bool _selectionMode = false;
  Set<String> _selectedMessageIds = {};
  String? _conversationId;
  Map<String, dynamic>? _replyMessage;
  final List<PlatformFile> _selectedFiles = [];
  List<dynamic> _allEmployees = [];
  List<dynamic> _filteredEmployees = [];
  final TextEditingController _searchController = TextEditingController();
  bool _showEmployeeSearch = false;
  bool _sidebarBusy = false;
  bool _chatBusy = false;
  bool _isUserNearBottom = true;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      _isUserNearBottom = (maxScroll - currentScroll) <= 100;
    });
    _selectedEmployeeId = widget.employeeId;
    fetchAllEmployees();

    _searchController.addListener(() {
      _filterEmployees(_searchController.text);
    });

    fetchSidebarChats();

    if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
      fetchEmployeeDetails();
      fetchChatHistory();
    }

    _msgController.addListener(() {
      setState(() {
        _isTyping = _msgController.text.trim().isNotEmpty;
      });
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showEmoji = false);
      }
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      fetchSidebarChats(isBackground: true);
      if (_selectedEmployeeId != null) {
        fetchChatHistory(isBackground: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDate).inDays;

    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";

    return DateFormat("dd MMMM yyyy").format(date);
  }

  Future<void> fetchAllEmployees() async {
    try {
      final res = await http.get(
        Uri.parse("https://company-04bz.onrender.com/api/employees"),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _allEmployees = data;
            _filteredEmployees = [];
          });
        }
      }
    } catch (e) {
      debugPrint("employee fetch error $e");
    }
  }

  void _filterEmployees(String q) {
    q = q.toLowerCase().trim();

    if (q.isEmpty) {
      setState(() => _filteredEmployees = []);
      return;
    }

    setState(() {
      _filteredEmployees = _allEmployees.where((e) {
        return (e['employeeName'] ?? "").toString().toLowerCase().contains(q) ||
            (e['employeeId'] ?? "").toString().toLowerCase().contains(q);
      }).toList();
    });
  }

  void _openForwardDialog() {
    Set<String> selectedEmployees = {};
    TextEditingController forwardSearchController = TextEditingController();
    List<dynamic> dialogFiltered = List.from(_allEmployees);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Forward to"),
              content: SizedBox(
                width: 350,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: forwardSearchController,
                      decoration: const InputDecoration(
                        hintText: "Search employee...",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          dialogFiltered = _allEmployees.where((e) {
                            final name = (e['employeeName'] ?? "")
                                .toString()
                                .toLowerCase();
                            final id = (e['employeeId'] ?? "")
                                .toString()
                                .toLowerCase();
                            return name.contains(value.toLowerCase()) ||
                                id.contains(value.toLowerCase());
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: dialogFiltered.length,
                        itemBuilder: (context, index) {
                          final emp = dialogFiltered[index];
                          final empId = emp['employeeId'];
                          final empName = emp['employeeName'];

                          return CheckboxListTile(
                            value: selectedEmployees.contains(empId),
                            title: Text(empName),
                            subtitle: Text(empId),
                            onChanged: (val) {
                              setStateDialog(() {
                                if (val == true) {
                                  selectedEmployees.add(empId);
                                } else {
                                  selectedEmployees.remove(empId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: selectedEmployees.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _forwardMessages(selectedEmployees.toList());
                        },
                  child: const Text("Forward"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _forwardMessages(List<String> receiverIds) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final senderId = userProvider.employeeId;
    final senderName = userProvider.employeeName;

    if (senderId == null) return;

    for (String receiverId in receiverIds) {
      for (String msgId in _selectedMessageIds) {
        final msg = _chatHistory.firstWhere((m) => m['_id'] == msgId);

        var request = http.MultipartRequest(
          'POST',
          Uri.parse("https://company-04bz.onrender.com/notifications/with-files"),
        );

        request.fields.addAll({
          "month": DateFormat('MMMM').format(DateTime.now()),
          "year": DateTime.now().year.toString(),
          "category": "message",
          "empId": senderId,
          "receiverId": receiverId,
          "senderId": senderId,
          "senderName": senderName ?? "",
        });

        if (msg['text'] != null && msg['text'].toString().trim().isNotEmpty) {
          request.fields["message"] = msg['text'];
        }
        if (msg['replyTo'] != null) {
          request.fields["replyTo"] = json.encode(msg['replyTo']);
        }
        final List attachments = msg['attachments'] ?? [];

        for (final file in attachments) {
          final fileUrl =
              "https://company-04bz.onrender.com/${file['path'].replaceAll('\\', '/')}";

          final response = await http.get(Uri.parse(fileUrl));
          if (response.statusCode == 200) {
            request.files.add(
              http.MultipartFile.fromBytes(
                "attachments",
                response.bodyBytes,
                filename: file['originalName'] ?? file['filename'],
              ),
            );
          }
        }

        await request.send();
      }
    }

    _exitSelection();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Message forwarded")));
  }

  void _copySelectedMessages() {
    if (_selectedMessageIds.isEmpty) return;

    final selectedMessages =
        _chatHistory
            .where((m) => _selectedMessageIds.contains(m['_id']))
            .toList()
          ..sort(
            (a, b) => DateTime.parse(
              a['createdAt'],
            ).compareTo(DateTime.parse(b['createdAt'])),
          );

    final textOnly = selectedMessages
        .map((m) => (m['text'] ?? '').toString().trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (textOnly.isEmpty) return;

    Clipboard.setData(ClipboardData(text: textOnly.join('\n')));

    _exitSelection();

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 120,
        left: MediaQuery.of(context).size.width / 2 - 60,
        child: Material(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text("Copied", style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(milliseconds: 800), () {
      entry.remove();
    });
  }

  Future<void> deleteForMe() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myId = userProvider.employeeId;

    if (myId == null || _selectedEmployeeId == null) return;

    try {
      final res = await http.put(
        Uri.parse(
          "https://company-04bz.onrender.com/notifications/chat-conversation/$myId/$_selectedEmployeeId/delete-for-me",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"messageIds": _selectedMessageIds.toList()}),
      );

      if (res.statusCode == 200) {
        _exitSelection();
        await fetchChatHistory();
        await fetchSidebarChats();
      }
    } catch (e) {
      debugPrint("delete for me error $e");
    }
  }

  Future<void> deleteForEveryone() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myId = userProvider.employeeId;

    if (myId == null || _selectedEmployeeId == null) return;

    try {
      final res = await http.put(
        Uri.parse(
          "https://company-04bz.onrender.com/notifications/chat-conversation/$myId/$_selectedEmployeeId/delete-messages",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"messageIds": _selectedMessageIds.toList()}),
      );

      if (res.statusCode == 200) {
        _exitSelection();
        await fetchChatHistory();
        await fetchSidebarChats();
      }
    } catch (e) {
      debugPrint("delete everyone error $e");
    }
  }

  void _handleMessageMenu(String action, Map<String, dynamic> msg) {
    switch (action) {
      case 'select':
        _toggleSelection(msg['_id']);
        break;

      case 'reply':
        setState(() {
          _replyMessage = msg;
        });
        break;

      case 'copy':
        final text = (msg['text'] ?? "").toString();
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Copied")));
        break;

      case 'forward':
        setState(() {
          _selectedMessageIds = {msg['_id']};
          _selectionMode = true;
        });
        _openForwardDialog();
        break;

      case 'delete_me':
        setState(() {
          _selectedMessageIds = {msg['_id']};
        });
        deleteForMe();
        break;

      case 'delete_all':
        setState(() {
          _selectedMessageIds = {msg['_id']};
        });
        deleteForEveryone();
        break;
    }
  }

  void _toggleSelection(String messageId) {
    setState(() {
      _selectionMode = true;

      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }

      if (_selectedMessageIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> fetchSidebarChats({bool isBackground = false}) async {
    if (_sidebarBusy && isBackground) return;
    _sidebarBusy = true;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myId = userProvider.employeeId;

    if (myId == null) {
      _sidebarBusy = false;
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          "https://company-04bz.onrender.com/notifications/employee/$myId?source=chat",
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> decoded = json.decode(response.body);

        decoded.removeWhere((chat) {
          final lastMsg = chat['lastMessage'] ?? "";
          final deletedForMe = chat['deletedFor'] ?? [];
          if (deletedForMe.contains(myId)) return true;
          if (lastMsg.toString().trim().isEmpty) return true;
          return false;
        });
        decoded.sort((a, b) {
          final t1 = DateTime.tryParse(a['lastTime'] ?? "") ?? DateTime(0);
          final t2 = DateTime.tryParse(b['lastTime'] ?? "") ?? DateTime(0);
          return t2.compareTo(t1);
        });
        if (mounted) {
          setState(() {
            _chatSidebarList = decoded;
          });
        }

        _fetchSidebarUserImages(decoded, myId);
      }
    } catch (e) {
      debugPrint("Sidebar error: $e");
    } finally {
      _sidebarBusy = false;
    }
  }

  Future<void> _showDeleteDialog() async {
    if (_selectedMessageIds.isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myId = userProvider.employeeId;

    if (myId == null) return;

    // Check if ALL selected messages belong to me
    final bool allMine = _selectedMessageIds.every((id) {
      final msg = _chatHistory.firstWhere((m) => m['_id'] == id);
      return msg['senderId'] == myId;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Messages"),
          content: const Text("Choose delete option"),
          actions: [
            // Always show delete for me
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                deleteForMe();
              },
              child: const Text("Delete for me"),
            ),

            // Show delete for everyone ONLY if message belongs to me
            if (allMine)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  deleteForEveryone();
                },
                child: const Text("Delete for everyone"),
              ),
          ],
        );
      },
    );
  }

  Future<void> _fetchSidebarUserImages(List chats, String myId) async {
    for (var chat in chats) {
      final partnerId = chat['partnerId'] ?? "";

      if (partnerId.isEmpty || _sidebarNames.containsKey(partnerId)) continue;

      try {
        final response = await http.get(
          Uri.parse("https://company-04bz.onrender.com/api/employees/$partnerId"),
        );

        if (response.statusCode == 200) {
          final empData = json.decode(response.body);

          if (!mounted) return;

          setState(() {
            _sidebarNames[partnerId] = empData['employeeName'] ?? partnerId;

            if (empData['employeeImage'] != null &&
                empData['employeeImage'].toString().isNotEmpty) {
              _sidebarImages[partnerId] = empData['employeeImage'];
            }
          });
        }
      } catch (e) {
        debugPrint("sidebar profile fetch error $e");
      }
    }
  }

  Future<void> fetchEmployeeDetails() async {
    if (_selectedEmployeeId == null) return;
    try {
      final response = await http.get(
        Uri.parse("https://company-04bz.onrender.com/api/employees/$_selectedEmployeeId"),
      );
      if (response.statusCode == 200) {
        setState(() {
          employeeData = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching employee: $e");
    }
  }

  Future<void> fetchChatHistory({bool isBackground = false}) async {
    if (_chatBusy && isBackground) return;
    _chatBusy = true;

    if (_selectedEmployeeId == null) {
      _chatBusy = false;
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myId = userProvider.employeeId;

    if (myId == null) {
      _chatBusy = false;
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          "https://company-04bz.onrender.com/notifications/chat-conversation/$myId/$_selectedEmployeeId",
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetchedMsgs = json.decode(response.body);

        if (!listEquals(_chatHistory, fetchedMsgs)) {
          setState(() {
            _chatHistory = fetchedMsgs;
            _messageIndexMap.clear();
            for (int i = 0; i < _chatHistory.length; i++) {
              _messageIndexMap[_chatHistory[i]['_id']] = i;
            }
            if (!isBackground) _loading = false;
          });
          _scrollToBottom();

          if (!_initialLoadDone) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.maxScrollExtent,
                );
              }
            });
            _initialLoadDone = true;
          }
        }
      } else {
        if (!isBackground) setState(() => _loading = false);
      }
    } catch (e) {
      if (!isBackground) setState(() => _loading = false);
    } finally {
      _chatBusy = false;
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;

    if (force || _isUserNearBottom) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToMessage(String messageId) {
    final index = _messageIndexMap[messageId];
    if (index == null) return;

    _scrollController.animateTo(
      index * 90.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    setState(() {
      _highlightedMessageId = messageId;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  void _selectChat(String partnerId) {
    if (_selectedEmployeeId == partnerId) return;

    setState(() {
      _selectedEmployeeId = partnerId;
      _chatHistory.clear();
      employeeData = null;
      _loading = false;
      _msgController.clear();
      _selectedFiles.clear();
      _isTyping = false;
      _showEmoji = false;
    });
    _initialLoadDone = false;
    fetchEmployeeDetails();
    fetchChatHistory();
    fetchSidebarChats();
  }

  Future<void> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(result.files);
      });
    }
  }

  void removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> sendMessage() async {
    if (_selectedEmployeeId == null) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final senderId = userProvider.employeeId;
    final senderName = userProvider.employeeName;

    if ((_msgController.text.trim().isEmpty && _selectedFiles.isEmpty) ||
        senderId == null) {
      return;
    }

    String month = [
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

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://company-04bz.onrender.com/notifications/with-files"),
      );

      request.fields.addAll({
        "month": month,
        "year": DateTime.now().year.toString(),
        "category": "message",
        "empId": senderId,
        "receiverId": _selectedEmployeeId!,
        "senderId": senderId,
        "senderName": senderName ?? "",
      });
      if (_replyMessage != null) {
        request.fields["replyTo"] = json.encode({
          "messageId": _replyMessage!["_id"],
          "text": (_replyMessage!["text"] ?? "").toString(),
          "senderName": _replyMessage!["senderName"],
          "attachments": _replyMessage!["attachments"] ?? [],
        });
      }

      if (_msgController.text.trim().isNotEmpty) {
        request.fields["message"] = _msgController.text.trim();
      }

      for (final file in _selectedFiles) {
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
        final newText = _msgController.text.trim();

        setState(() {
          _chatHistory.add({
            "_id": DateTime.now().millisecondsSinceEpoch.toString(),
            "senderId": senderId,
            "text": newText,
            "attachments": _selectedFiles
                .map((f) => {"originalName": f.name, "path": ""})
                .toList(),
            "replyTo": _replyMessage,
            "createdAt": DateTime.now().toIso8601String(),
          });

          _selectedFiles.clear();
          _isTyping = false;
          _replyMessage = null;
          _msgController.clear();
        });

        _scrollToBottom(force: true);
      }
    } catch (e) {
      debugPrint("❌ Error sending message: $e");
    }
  }

  Future<void> _downloadFile(String url) async {
    final Uri uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("❌ Cannot launch: $url");
      }
    } catch (e) {
      debugPrint("❌ Download error: $e");
    }
  }

  bool _isImage(String? filename) {
    if (filename == null) return false;
    final ext = filename.split('.').last.toLowerCase();
    return ["jpg", "jpeg", "png", "gif", "webp"].contains(ext);
  }

  PopupMenuItem _buildMenuItem(
    IconData icon,
    String text,
    List<Color> colors,
    VoidCallback onTap,
  ) {
    return PopupMenuItem(
      onTap: onTap,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Icon(icon, color: colors.first),
          ),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final myId = userProvider.employeeId ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B2D8B), // strong purple
        foregroundColor: Colors.white,
        title: const Text(
          "Message",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              fetchSidebarChats();
              if (_selectedEmployeeId != null) fetchChatHistory();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              Container(
                width: 320,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(color: Colors.black12, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: "Search employee...",
                                prefixIcon: const Icon(Icons.search, size: 18),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            "Chat History",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4B2A7B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          _chatSidebarList.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No recent chats",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _chatSidebarList.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1, indent: 70),
                                  itemBuilder: (context, index) {
                                    final chat = _chatSidebarList[index];
                                    final partnerId = chat['partnerId'] ?? "";
                                    final partnerName =
                                        _sidebarNames[partnerId] ??
                                        "Loading...";
                                    final latestMessage =
                                        chat['lastMessage'] ?? "";
                                    final lastTime = chat['lastTime'];

                                    String timeStr = "";
                                    if (lastTime != null &&
                                        lastTime.toString().isNotEmpty) {
                                      final dt = DateTime.tryParse(
                                        lastTime.toString(),
                                      )?.toLocal();
                                      if (dt != null) {
                                        timeStr = DateFormat(
                                          'hh:mm a',
                                        ).format(dt);
                                      }
                                    }
                                    return ListTile(
                                      title: Text(
                                        partnerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        latestMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        timeStr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      onTap: () => _selectChat(partnerId),
                                    );
                                  },
                                ),

                          if (_searchController.text.isNotEmpty)
                            Positioned.fill(
                              child: Container(
                                color: Colors.white,
                                child: _filteredEmployees.isEmpty
                                    ? const Center(
                                        child: Text(
                                          "No employees found",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _filteredEmployees.length,
                                        itemBuilder: (context, index) {
                                          final emp = _filteredEmployees[index];
                                          final id = emp['employeeId'];
                                          final name = emp['employeeName'];

                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: const Color(
                                                0xFF9E77ED,
                                              ),
                                              child: Text(
                                                name[0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            title: Text(name),
                                            subtitle: Text(id),
                                            onTap: () {
                                              _selectChat(id);
                                              _searchController.clear();
                                              setState(() {
                                                _filteredEmployees.clear();
                                              });
                                            },
                                          );
                                        },
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _selectedEmployeeId == null
                    ? Container(
                        color: const Color(0xFFF0F2F5),
                        child: const Center(
                          child: Text(
                            "Select a chat to start messaging",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : _buildActiveChatArea(myId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChatArea(String myId) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 100, 2, 149),
        foregroundColor: Colors.white,
        leadingWidth: 30,
        title: _selectionMode
            ? Text("${_selectedMessageIds.length} selected")
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        (employeeData?['employeeImage'] != null &&
                            employeeData!['employeeImage'].isNotEmpty)
                        ? NetworkImage(
                            "https://company-04bz.onrender.com${employeeData!['employeeImage']}",
                          )
                        : const AssetImage("assets/profile.png")
                              as ImageProvider,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeData?['employeeName'] ?? "Loading...",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        employeeData?['position'] ?? "Employee",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        actions: _selectionMode
            ? [
                if (_selectedMessageIds.length == 1)
                  Tooltip(
                    message: "Reply",
                    child: IconButton(
                      icon: const Icon(Icons.reply),
                      onPressed: () {
                        final msgId = _selectedMessageIds.first;
                        final msg = _chatHistory.firstWhere(
                          (m) => m['_id'] == msgId,
                        );

                        setState(() {
                          _replyMessage = msg;
                        });

                        _exitSelection();
                      },
                    ),
                  ),
                if (_selectedMessageIds.isNotEmpty &&
                    _selectedMessageIds.every((id) {
                      final msg = _chatHistory.firstWhere(
                        (m) => m['_id'] == id,
                      );
                      final attachments = msg['attachments'] ?? [];
                      return attachments.isEmpty;
                    }))
                  Tooltip(
                    message: "Copy",
                    child: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: _copySelectedMessages,
                    ),
                  ),
                Tooltip(
                  message: "Forward",
                  child: IconButton(
                    icon: const Icon(Icons.forward),
                    onPressed: _openForwardDialog,
                  ),
                ),
                Tooltip(
                  message: "Delete",
                  child: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _showDeleteDialog,
                  ),
                ),
                Tooltip(
                  message: "Close",
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelection,
                  ),
                ),
              ]
            : [],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() => _showEmoji = false);
              },
              child: _chatHistory.isEmpty
                  ? const Center(
                      child: Text(
                        "No messages yet",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(10),
                      itemCount: _chatHistory.length,
                      itemBuilder: (context, index) {
                        final msg = _chatHistory[index];
                        final currentDate = DateTime.parse(
                          msg['createdAt'],
                        ).toLocal();

                        bool showDateHeader = false;

                        if (index == 0) {
                          showDateHeader = true;
                        } else {
                          final prevMsg = _chatHistory[index - 1];
                          final prevDate = DateTime.parse(
                            prevMsg['createdAt'],
                          ).toLocal();

                          if (currentDate.year != prevDate.year ||
                              currentDate.month != prevDate.month ||
                              currentDate.day != prevDate.day) {
                            showDateHeader = true;
                          }
                        }
                        final isMe = msg['senderId'] == myId;
                        final date = DateTime.parse(msg['createdAt']).toLocal();
                        final timeStr = DateFormat('hh:mm a').format(date);
                        final List attachments = msg['attachments'] ?? [];

                        final msgId = msg['_id'];

                        return Column(
                          children: [
                            if (showDateHeader)
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getDateLabel(currentDate),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                            GestureDetector(
                              onDoubleTap: () => _toggleSelection(msgId),
                              onSecondaryTap: () => _toggleSelection(msgId),
                              onTap: () {
                                if (_selectedMessageIds.isNotEmpty) {
                                  _toggleSelection(msgId);
                                }
                              },
                              child: Container(
                                color: _selectedMessageIds.contains(msgId)
                                    ? Colors.blue.withOpacity(0.2)
                                    : (_highlightedMessageId == msgId
                                          ? Colors.yellow.withOpacity(0.3)
                                          : Colors.transparent),
                                child: Align(
                                  alignment: isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 5,
                                      horizontal: 5,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? const Color.fromARGB(
                                              255,
                                              219,
                                              205,
                                              245,
                                            )
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.3),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),

                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Stack(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 22,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (msg['replyTo'] != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        final replyId =
                                                            msg['replyTo']['messageId'];
                                                        if (replyId != null) {
                                                          _scrollToMessage(
                                                            replyId,
                                                          );
                                                        }
                                                      },
                                                      child: Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 6,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          border: const Border(
                                                            left: BorderSide(
                                                              color: Colors
                                                                  .deepPurple,
                                                              width: 3,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              msg['replyTo']['senderName'] ??
                                                                  "",
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .deepPurple,
                                                              ),
                                                            ),
                                                            Builder(
                                                              builder: (_) {
                                                                final List
                                                                attachments =
                                                                    msg['replyTo']['attachments'] ??
                                                                    [];

                                                                if (attachments
                                                                    .isNotEmpty) {
                                                                  final fileName =
                                                                      attachments[0]['originalName'] ??
                                                                      attachments[0]['filename'] ??
                                                                      "Attachment";

                                                                  return Row(
                                                                    children: [
                                                                      const Icon(
                                                                        Icons
                                                                            .insert_drive_file,
                                                                        size:
                                                                            14,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            4,
                                                                      ),
                                                                      Expanded(
                                                                        child: Text(
                                                                          fileName,
                                                                          maxLines:
                                                                              1,
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  );
                                                                }

                                                                return Text(
                                                                  msg['replyTo']['text'] ??
                                                                      "",
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style:
                                                                      const TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                );
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  if (attachments.isNotEmpty)
                                                    ...attachments.map((file) {
                                                      final isImg = _isImage(
                                                        file['filename'],
                                                      );
                                                      final url =
                                                          "https://company-04bz.onrender.com/${file['path'].replaceAll('\\', '/')}";

                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom: 5,
                                                            ),
                                                        child: isImg
                                                            ? ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                                child:
                                                                    Image.network(
                                                                      url,
                                                                      width:
                                                                          200,
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    ),
                                                              )
                                                            : Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          6,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .grey[200],
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        10,
                                                                      ),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .insert_drive_file,
                                                                      color: Colors
                                                                          .deepPurple,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Flexible(
                                                                      child: Text(
                                                                        file['originalName'] ??
                                                                            "Document",
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                      );
                                                    }),

                                                  if (msg['text'] != null &&
                                                      msg['text']
                                                          .toString()
                                                          .isNotEmpty)
                                                    Text(
                                                      msg['text'],
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        color: Colors.black87,
                                                      ),
                                                    ),

                                                  const SizedBox(height: 4),

                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,

                                                    children: [
                                                      Text(
                                                        timeStr,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.black54,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      PopupMenuButton<String>(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        icon: const Icon(
                                                          Icons
                                                              .keyboard_arrow_down,
                                                          size: 16,
                                                          color: Colors.grey,
                                                        ),
                                                        onSelected: (value) {
                                                          _handleMessageMenu(
                                                            value,
                                                            msg,
                                                          );
                                                        },
                                                        itemBuilder: (context) {
                                                          List<
                                                            PopupMenuEntry<
                                                              String
                                                            >
                                                          >
                                                          items = [];

                                                          items.add(
                                                            const PopupMenuItem(
                                                              value: 'select',
                                                              child: Text(
                                                                "Select",
                                                              ),
                                                            ),
                                                          );

                                                          items.add(
                                                            const PopupMenuItem(
                                                              value: 'reply',
                                                              child: Text(
                                                                "Reply",
                                                              ),
                                                            ),
                                                          );

                                                          if ((msg['text'] ??
                                                                  "")
                                                              .toString()
                                                              .isNotEmpty) {
                                                            items.add(
                                                              const PopupMenuItem(
                                                                value: 'copy',
                                                                child: Text(
                                                                  "Copy",
                                                                ),
                                                              ),
                                                            );
                                                          }

                                                          items.add(
                                                            const PopupMenuItem(
                                                              value: 'forward',
                                                              child: Text(
                                                                "Forward",
                                                              ),
                                                            ),
                                                          );

                                                          items.add(
                                                            const PopupMenuItem(
                                                              value:
                                                                  'delete_me',
                                                              child: Text(
                                                                "Delete for me",
                                                              ),
                                                            ),
                                                          );

                                                          if (isMe) {
                                                            items.add(
                                                              const PopupMenuItem(
                                                                value:
                                                                    'delete_all',
                                                                child: Text(
                                                                  "Delete for everyone",
                                                                ),
                                                              ),
                                                            );
                                                          }

                                                          return items;
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
          if (_selectedFiles.isNotEmpty)
            Container(
              height: 100,
              color: Colors.grey[200],
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  final isImg = _isImage(file.name);
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isImg && file.bytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  file.bytes!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.insert_drive_file,
                                  color: Colors.deepPurple,
                                ),
                              ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => removeFile(index),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.red,
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (_replyMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  left: BorderSide(color: Colors.deepPurple, width: 4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyMessage!['senderName'] ?? "",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        Builder(
                          builder: (_) {
                            final List attachments =
                                _replyMessage!['attachments'] ?? [];

                            if (attachments.isNotEmpty) {
                              final fileName =
                                  attachments[0]['originalName'] ??
                                  attachments[0]['filename'] ??
                                  "Attachment";

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.insert_drive_file, size: 16),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Text(
                              _replyMessage!['text'] ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyMessage = null),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            child: Row(
              children: [
                PopupMenuButton(
                  icon: const Icon(Icons.add, color: Colors.grey, size: 28),
                  offset: const Offset(0, -320),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  itemBuilder: (context) => [
                    _buildMenuItem(Icons.description, "Document", [
                      Colors.deepPurple,
                      Colors.purple,
                    ], () => pickFiles()),
                    _buildMenuItem(Icons.image, "Photos & videos", [
                      Colors.blue,
                      Colors.lightBlue,
                    ], () => pickFiles()),
                    _buildMenuItem(Icons.audio_file_rounded, "Audio", [
                      Colors.blue,
                      Colors.lightBlue,
                    ], () => pickFiles()),
                  ],
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _showEmoji
                                ? Icons.keyboard
                                : Icons.emoji_emotions_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _showEmoji = !_showEmoji;
                              if (_showEmoji) {
                                _focusNode.unfocus();
                              } else {
                                _focusNode.requestFocus();
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _msgController,
                            focusNode: _focusNode,
                            maxLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => sendMessage(),
                            decoration: const InputDecoration(
                              hintText: "Type a message",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            onTap: () {
                              setState(() => _showEmoji = false);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color.fromARGB(255, 108, 3, 183),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 24),
                    onPressed: () {
                      sendMessage();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_showEmoji)
            SizedBox(
              height: 250,
              child: emoji.EmojiPicker(
                onEmojiSelected:
                    (emoji.Category? category, emoji.Emoji emojiData) {
                      setState(() {
                        _msgController.text =
                            _msgController.text + emojiData.emoji;
                        _isTyping = true;
                      });
                    },
                config: emoji.Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: emoji.EmojiViewConfig(
                    emojiSizeMax:
                        28 *
                        (kIsWeb
                            ? 1.0
                            : (defaultTargetPlatform == TargetPlatform.iOS
                                  ? 1.20
                                  : 1.0)),
                    columns: 7,
                    backgroundColor: const Color(0xFFF2F2F2),
                    noRecents: const Text(
                      'No Recents',
                      style: TextStyle(fontSize: 20, color: Colors.black26),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  viewOrderConfig: const emoji.ViewOrderConfig(
                    top: emoji.EmojiPickerItem.categoryBar,
                    middle: emoji.EmojiPickerItem.emojiView,
                    bottom: emoji.EmojiPickerItem.searchBar,
                  ),
                  skinToneConfig: const emoji.SkinToneConfig(
                    enabled: true,
                    dialogBackgroundColor: Colors.white,
                    indicatorColor: Colors.grey,
                  ),
                  categoryViewConfig: const emoji.CategoryViewConfig(
                    initCategory: emoji.Category.RECENT,
                    backgroundColor: Color(0xFFF2F2F2),
                    indicatorColor: Color.fromARGB(255, 205, 61, 248),
                    iconColor: Colors.grey,
                    iconColorSelected: Color.fromARGB(255, 155, 82, 244),
                    backspaceColor: Color.fromARGB(255, 163, 39, 251),
                    tabBarHeight: 46.0,
                  ),
                  bottomActionBarConfig: const emoji.BottomActionBarConfig(
                    enabled: false,
                  ),
                  searchViewConfig: const emoji.SearchViewConfig(
                    backgroundColor: Color(0xFFF2F2F2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
