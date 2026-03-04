// lib/mail_dashboard.dart — UI tweaks: sidebar shows employee name & per-message layout adjusted
//ib/mail_dashboard.dart — everything related to lists, navigation, thread viewing and management.
//Loaders for Inbox/Sent/Trash/Drafts, thread view UI, trash/restore/delete flows, search, auto-refresh, and the integration points that open the compose and inline composer.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:zeai_project/user_provider.dart';
import 'mail_compose.dart'; // your compose file (MailComposePanel, InlineComposer)

class MailDashboard extends StatefulWidget {
  const MailDashboard({super.key});

  @override
  State<MailDashboard> createState() => _MailDashboardState();
}

class _MailDashboardState extends State<MailDashboard> {
  int selectedMenu = 0; // 0 = Inbox, 1 = Sent, 2 = Compose, 3 = View Mail, 4 = Trash, 5 = Drafts
  Map<String, dynamic>? selectedMail;

  List inbox = [];
  List sent = [];
  List trash = [];
  List drafts = [];

  bool loadingInbox = true;
  bool loadingSent = true;
  bool loadingTrash = true;
  bool loadingDrafts = true;

  // Inline reply state (dashboard-level flags)
  bool showInlineReply = false;
  int? replyTargetIndex;

  // Periodic auto-refresh
  Timer? _refreshTimer;

  // Search
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();

  // Prepared initial values to pass into compose panel when opening full compose
  String? preparedSubject;
  String? preparedBody;

  // Now split recipient buckets
  List<Map<String, dynamic>>? preparedToRecipients;
  List<Map<String, dynamic>>? preparedCcRecipients;
  List<Map<String, dynamic>>? preparedBccRecipients;
  List<dynamic>? preparedForwardedAttachments;

  String? preparedThreadId;

  Set<String> selectedThreads = {};

  // State for message expansion and header details
  Set<int> expandedMessages = {};
  Set<int> expandedHeaderDetails = {};

  // Notifier to request compose to save draft
  final ValueNotifier<int> composeSaveNotifier = ValueNotifier<int>(0);

  // Month names (same as before)
  static const List<String> _monthNames = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];

  @override
  void initState() {
    super.initState();
    loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      loadAll(silent: true);
    });

    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ------------------ Date helpers ------------------ //
  String formatRelativeDate(dynamic dateValue) {
    if (dateValue == null) return "";
    DateTime dt;
    try {
      if (dateValue is DateTime) {
        dt = dateValue.toLocal();
      } else {
        final s = dateValue.toString();
        dt = DateTime.parse(s).toLocal();
      }
    } catch (e) {
      return dateValue.toString();
    }

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return "${diff.inSeconds}s ago";
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m == 1 ? "1 min ago" : "$m min ago";
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return h == 1 ? "1 hour ago" : "$h hours ago";
    }

    final today = DateTime(now.year, now.month, now.day);
    final then = DateTime(dt.year, dt.month, dt.day);
    final days = today.difference(then).inDays;

    if (days == 1) return "Yesterday";
    return "${_monthNames[dt.month - 1]} ${dt.day}";
  }

  String formatFullDateTime(dynamic dateValue) {
    if (dateValue == null) return "";
    DateTime dt;
    try {
      if (dateValue is DateTime) {
        dt = dateValue.toLocal();
      } else {
        dt = DateTime.parse(dateValue.toString()).toLocal();
      }
    } catch (e) {
      return dateValue.toString();
    }

    final hour = dt.hour;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final minute = dt.minute.toString().padLeft(2, "0");
    final ampm = hour >= 12 ? "PM" : "AM";
    final shortDate = "${_monthNames[dt.month - 1]} ${dt.day}, $displayHour:$minute $ampm";

    final now = DateTime.now();
    final daysDiff = DateTime(now.year, now.month, now.day).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (daysDiff <= 7) {
      final rel = formatRelativeDate(dateValue);
      return "$shortDate ($rel)";
    }
    return shortDate;
  }

  String formatMailDate(String isoDate) {
    try {
      final mailDate = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final isToday = mailDate.year == now.year && mailDate.month == now.month && mailDate.day == now.day;
      if (isToday) {
        return DateFormat('hh:mm a').format(mailDate);
      } else {
        return DateFormat('MMM dd').format(mailDate);
      }
    } catch (e) {
      return isoDate;
    }
  }

  dynamic _extractLastActivityDate(dynamic item) {
    if (item == null) return null;
    try {
      if (item is Map) {
        if (item['lastUpdated'] != null) return item['lastUpdated'];
        if (item['updatedAt'] != null) return item['updatedAt'];
        if (item['messages'] is List && (item['messages'] as List).isNotEmpty) {
          final last = (item['messages'] as List).last;
          if (last is Map) {
            return last['createdAt'] ?? last['updatedAt'];
          }
        }
        if (item['createdAt'] != null) return item['createdAt'];
      }
      return null;
    } catch (e) {
      debugPrint("extractLastActivityDate error: $e");
      return null;
    }
  }
  // ------------------ end date helpers ------------------ //

  Future<void> loadAll({bool silent = false}) async {
    if (!silent) setState(() { loadingInbox = loadingSent = loadingTrash = loadingDrafts = true; });
    await Future.wait([
      loadInbox(silent: silent),
      loadSent(silent: silent),
      loadTrash(silent: silent),
      loadDrafts(silent: silent)
    ]);
  }

  Future<void> loadInbox({bool silent = false}) async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final empId = user.employeeId;
    try {
      final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/mail/inbox/$empId"));
      if (res.statusCode == 200) {
        setState(() {
          inbox = json.decode(res.body);
          try {
            inbox.sort((a, b) {
              final aDt = a['createdAt']?.toString() ?? a['lastUpdated']?.toString() ?? "";
              final bDt = b['createdAt']?.toString() ?? b['lastUpdated']?.toString() ?? "";
              return bDt.compareTo(aDt);
            });
          } catch (_) {}
          loadingInbox = false;
        });
      }
    } catch (e) {
      debugPrint("Inbox error: $e");
      setState(() => loadingInbox = false);
    }
  }

  Future<void> loadSent({bool silent = false}) async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final empId = user.employeeId;
    try {
      final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/mail/sent/$empId"));
      if (res.statusCode == 200) {
        setState(() {
          sent = json.decode(res.body);
          try {
            sent.sort((a, b) {
              final aDt = a['createdAt']?.toString() ?? "";
              final bDt = b['createdAt']?.toString() ?? "";
              return bDt.compareTo(aDt);
            });
          } catch (_) {}
          loadingSent = false;
        });
      }
    } catch (e) {
      debugPrint("Sent error: $e");
      setState(() => loadingSent = false);
    }
  }

  Future<void> loadTrash({bool silent = false}) async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final empId = user.employeeId;
    try {
      final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/mail/trash/$empId"));
      if (res.statusCode == 200) {
        setState(() {
          trash = json.decode(res.body);
          try {
            trash.sort((a, b) {
              final aDt = a['createdAt']?.toString() ?? "";
              final bDt = b['createdAt']?.toString() ?? "";
              return bDt.compareTo(aDt);
            });
          } catch (_) {}
          loadingTrash = false;
        });
      }
    } catch (e) {
      debugPrint("Trash load error: $e");
      setState(() => loadingTrash = false);
    }
  }

  Future<void> loadDrafts({bool silent = false}) async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final empId = user.employeeId;
    try {
      final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/mail/drafts/$empId"));
      if (res.statusCode == 200) {
        setState(() {
          drafts = json.decode(res.body);
          loadingDrafts = false;
        });
      }
    } catch (e) {
      debugPrint("Drafts load error: $e");
      setState(() => loadingDrafts = false);
    }
  }

  // OPEN MAIL -> thread endpoint (marks read)
  Future<void> openMail(String id) async {
    setState(() {
      selectedMenu = 3;
      selectedMail = null;
      showInlineReply = false;
      replyTargetIndex = null;
      preparedSubject = null;
      preparedBody = null;
      preparedToRecipients = null;
      preparedCcRecipients = null;
      preparedBccRecipients = null;
      preparedForwardedAttachments = null;
      preparedThreadId = null;
    });
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final empId = user.employeeId;
      final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/mail/thread/$id/$empId"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          selectedMail = data;
          // Reduce unread locally if present in inbox list
          final index = inbox.indexWhere((m) => m['_id'] == id);
          if (index != -1) {
            inbox[index]['unread'] = false;
            inbox[index]['isRead'] = true;
          }
        });
      } else {
        debugPrint("Mail view failed: ${res.body}");
      }
    } catch (e) {
      debugPrint("Mail view error: $e");
    }
  }

  // ------------------ Trash / Restore / Delete Forever ------------------ //
  Future<void> _moveToTrash(String threadId) async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final empId = user.employeeId;
      final res = await http.put(Uri.parse("https://company-04bz.onrender.com/api/mail/trash/$threadId/$empId"));
      if (res.statusCode == 200) {
        await loadInbox();
        await loadTrash();
        setState(() => selectedMenu = 4);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Moved to Trash"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error moving to trash: ${res.body}")));
      }
    } catch (e) {
      debugPrint("Trash error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to move to trash")));
    }
  }

  Future<void> _restoreMail(String threadId) async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final empId = user.employeeId;
      final res = await http.put(Uri.parse("https://company-04bz.onrender.com/api/mail/restore/$threadId/$empId"));
      if (res.statusCode == 200) {
        await loadTrash();
        await loadInbox();
        setState(() => selectedMenu = 0);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restored from Trash"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error restoring: ${res.body}")));
      }
    } catch (e) {
      debugPrint("Restore error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to restore")));
    }
  }

  Future<void> _deleteForever(String threadId) async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final empId = user.employeeId;
      final res = await http.delete(Uri.parse("https://company-04bz.onrender.com/api/mail/delete-permanent/$threadId/$empId"));
      if (res.statusCode == 200) {
        await loadTrash();
        setState(() => selectedMenu = 4);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted permanently"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting permanently: ${res.body}")));
      }
    } catch (e) {
      debugPrint("Delete forever error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete permanently")));
    }
  }

  Future<void> _confirmDeleteForever(String threadId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Delete permanently?"),
        content: const Text(
          "This will remove this thread from your mailbox only.\nThis action cannot be undone."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    await _deleteForever(threadId);
  }
}


  Future<void> _confirmRestore(String threadId) async {
    await _restoreMail(threadId);
  }

  /// Try to find employee info (name, image) inside thread messages.
  /// Falls back to returning employeeId as name when not found.
  Map<String, String?> _resolveEmployeeFromThread(Map thread, String empId) {
    final result = {"employeeId": empId, "employeeName": empId, "employeeImage": null};

    try {
      final messages = (thread['messages'] as List?) ?? [];
      for (final m in messages) {
        if (m is Map) {
          final from = m['from'];
          if (from is Map && (from['employeeId']?.toString() ?? "") == empId) {
            result['employeeName'] = from['employeeName']?.toString() ?? empId;
            result['employeeImage'] = from['employeeImage']?.toString();
            return result;
          } else if (from is String && from == empId) {
            // keep searching
          }
          if (m['to'] is List) {
            for (final t in (m['to'] as List)) {
              if (t is Map && (t['employeeId']?.toString() ?? "") == empId) {
                result['employeeName'] = t['employeeName']?.toString() ?? empId;
                result['employeeImage'] = t['employeeImage']?.toString();
                return result;
              }
            }
          }
          if (m['cc'] is List) {
            for (final c in (m['cc'] as List)) {
              if (c is Map && (c['employeeId']?.toString() ?? "") == empId) {
                result['employeeName'] = c['employeeName']?.toString() ?? empId;
                result['employeeImage'] = c['employeeImage']?.toString();
                return result;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("resolveEmployeeFromThread error: $e");
    }

    return result;
  }

  Future<void> _bulkDeleteSelected() async {
  if (selectedThreads.isEmpty) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Move to Trash?"),
      content: Text("Delete ${selectedThreads.length} selected mails?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    for (final id in selectedThreads) {
      await _moveToTrash(id);
    }

    setState(() => selectedThreads.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Moved to Trash"), backgroundColor: Colors.green),
    );
  }
}

  // ========== Compose triggers & inline reply helpers ==========

  // Show inline reply below a message
  void _showInlineReply(Map thread, {int? targetIndex}) {
    final messages = (thread['messages'] as List?) ?? [];
    final idx = targetIndex ?? (messages.isNotEmpty ? messages.length - 1 : 0);
    setState(() {
      showInlineReply = true;
      replyTargetIndex = idx;
    });
  }

  // Open full compose prefilled for "Reply all" (passes recipients to MailComposePanel)
  void _openComposeForReplyAll(Map thread) {
    final user = Provider.of<UserProvider>(context, listen: false);
    final me = user.employeeId;
    final participants = (thread['participants'] as List?)?.map((p) => p.toString()).toList() ?? [];

    // Collect CCs from messages
    final ccFromMessages = <String>{};
    final messages = (thread['messages'] as List?) ?? [];
    for (final m in messages) {
      if (m is Map && m['cc'] is List) {
        for (final c in (m['cc'] as List)) {
          if (c is Map && c['employeeId'] != null) {
            ccFromMessages.add(c['employeeId'].toString());
          } else if (c is String) ccFromMessages.add(c);
        }
      }
    }

    final toList = participants.where((p) => p != me).toList();
    final ccList = ccFromMessages.where((p) => p != me && !toList.contains(p)).toList();

    final resolvedTo = <Map<String, dynamic>>[];
    for (final t in toList) {
      final info = _resolveEmployeeFromThread(thread, t);
      resolvedTo.add({
        "employeeId": info['employeeId'],
        "employeeName": info['employeeName'],
        "employeeImage": info['employeeImage'],
      });
    }

    final resolvedCc = <Map<String, dynamic>>[];
    for (final c in ccList) {
      final info = _resolveEmployeeFromThread(thread, c);
      resolvedCc.add({
        "employeeId": info['employeeId'],
        "employeeName": info['employeeName'],
        "employeeImage": info['employeeImage'],
      });
    }

    setState(() {
      preparedSubject = "Re: ${thread['subject'] ?? ''}";
      preparedBody = "";
      preparedToRecipients = resolvedTo;
      preparedCcRecipients = resolvedCc;
      preparedBccRecipients = [];
      preparedForwardedAttachments = [];
      preparedThreadId = thread['_id']?.toString();
      selectedMenu = 2; // open MailComposePanel
    });
  }

  // Open full compose for forwarding (subject/body prefilled) and collect forwarded attachments
  void _openComposeForForward(Map thread) {
    final messages = (thread['messages'] as List?) ?? [];
    final last = messages.isNotEmpty ? messages.last : {};
    final fromInfo = (last is Map) ? (last['from'] ?? {}) : {};
    final fromText = (fromInfo is Map) ? "${fromInfo['employeeName'] ?? ''} (${fromInfo['employeeId'] ?? ''})" : fromInfo.toString();
    final bodyText = (last is Map) ? (last['body'] ?? '') : "";

    // collect attachments from messages and thread-level attachments
    final fwdFilenames = <dynamic>{};
    for (final m in messages) {
      if (m is Map && m['attachments'] is List) {
        for (final a in (m['attachments'] as List)) {
          if (a is Map && a['filename'] != null) {
            fwdFilenames.add(a);
          } else if (a is String) {
            fwdFilenames.add(a);
          }
        }
      }
    }
    if (thread['attachments'] is List) {
      for (final a in (thread['attachments'] as List)) {
        if (a is Map) fwdFilenames.add(a);
      }
    }

    setState(() {
      preparedSubject = "Fwd: ${thread['subject'] ?? ''}";
      preparedBody = "----- Forwarded Message -----\nFrom: $fromText\n\n$bodyText";
      preparedToRecipients = [];
      preparedCcRecipients = [];
      preparedBccRecipients = [];
      preparedForwardedAttachments = fwdFilenames.toList();
      preparedThreadId = null; // new thread on forward
      selectedMenu = 2;
    });
  }

  // ------------------ Helpers ------------------ //
  int _countUnread(List list) {
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final myId = user.employeeId;

      return list.where((m) {
        if (m is Map) {
          if (m.containsKey('readBy') && m['readBy'] is List) {
            final readBy = (m['readBy'] as List).map((e) => e.toString()).toList();
            final hasOtherMessages = (m['messages'] as List?)?.any((msg) {
              final from = msg?['from'];
              final fromId = (from is String) ? from : (from?['employeeId']?.toString() ?? "");
              return fromId != "" && fromId != myId;
            }) ?? false;
            return !readBy.contains(myId) && hasOtherMessages;
          }
          if (m.containsKey('unread')) return m['unread'] == true;
          if (m.containsKey('isRead')) return m['isRead'] == false;
          return false;
        }
        return false;
      }).length;
    } catch (e) {
      return 0;
    }
  }

  List _applySearchFilter(List source) {
  if (_searchQuery.isEmpty) return source;

  return source.where((item) {
    if (item is! Map) return false;

    final q = _searchQuery;

    // ---- Subject ----
    final subject = (item['subject'] ?? "").toString().toLowerCase();

    // ---- Preview / Body ----
    final preview =
        (item['lastMessagePreview'] ?? item['body'] ?? "").toString().toLowerCase();

    // ---- Participants ----
    final participants = (item['participants'] is List)
        ? (item['participants'] as List)
            .map((e) => e.toString().toLowerCase())
            .join(" ")
        : "";

    // ---- Sender Name & ID (from last message) ----
    String sender = "";
    try {
      if (item['messages'] is List && (item['messages'] as List).isNotEmpty) {
        final last = (item['messages'] as List).last;
        if (last is Map && last['from'] != null) {
          final from = last['from'];
          if (from is Map) {
            sender =
                "${from['employeeName'] ?? ''} ${from['employeeId'] ?? ''}"
                    .toLowerCase();
          } else {
            sender = from.toString().toLowerCase();
          }
        }
      }
    } catch (_) {}

    // ---- CC & BCC ----
    String ccBcc = "";
    try {
      if (item['messages'] is List) {
        for (final m in (item['messages'] as List)) {
          if (m is Map) {
            if (m['cc'] is List) {
              ccBcc += " ${(m['cc'] as List)
                      .map((e) {
                        if (e is Map) {
                          return "${e['employeeName'] ?? ''} ${e['employeeId'] ?? ''}";
                        }
                        return e.toString();
                      })
                      .join(" ")
                      .toLowerCase()}";
            }
            if (m['bcc'] is List) {
              ccBcc += " ${(m['bcc'] as List)
                      .map((e) {
                        if (e is Map) {
                          return "${e['employeeName'] ?? ''} ${e['employeeId'] ?? ''}";
                        }
                        return e.toString();
                      })
                      .join(" ")
                      .toLowerCase()}";
            }
          }
        }
      }
    } catch (_) {}

    return subject.contains(q) ||
        preview.contains(q) ||
        sender.contains(q) ||
        participants.contains(q) ||
        ccBcc.contains(q);
  }).toList();
}


  Widget _menuButton(icon, text, index) {
    final selected = selectedMenu == index;
    int badge = 0;
    if (index == 0) badge = _countUnread(inbox);
    if (index == 1) badge = 0;
    if (index == 4) badge = _countUnread(trash);
    if (index == 5) badge = drafts.length;

    return InkWell(
      onTap: () => setState(() {
        // request save if leaving compose
        if (selectedMenu == 2 && index != 2) {
          composeSaveNotifier.value = composeSaveNotifier.value + 1;
        }
        selectedMenu = index;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.deepPurple : Colors.black54, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.deepPurple : Colors.black87,
                  )),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  badge > 99 ? '99+' : badge.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (selectedMenu) {
      case 0:
        return _buildInbox();
      case 1:
        return _buildSent();
      case 2:
        // Full compose panel — pass prepared values (may be null)
        return MailComposePanel(
          initialSubject: preparedSubject,
          initialBody: preparedBody,
          initialToRecipients: preparedToRecipients,
          initialCcRecipients: preparedCcRecipients,
          initialBccRecipients: preparedBccRecipients,
          initialForwardedAttachments: preparedForwardedAttachments,
          initialThreadId: preparedThreadId,
          saveRequestNotifier: composeSaveNotifier,
          onSendSuccess: () async {
            await loadAll(silent: true);
            setState(() {
              selectedMenu = 0;
              preparedSubject = null;
              preparedBody = null;
              preparedToRecipients = null;
              preparedCcRecipients = null;
              preparedBccRecipients = null;
              preparedForwardedAttachments = null;
              preparedThreadId = null;
            });
          },
          onDraftSaved: () async {
            await loadDrafts(silent: true);
          },
          onCancel: () {
            setState(() {
              selectedMenu = 0;
              preparedSubject = null;
              preparedBody = null;
              preparedToRecipients = null;
              preparedCcRecipients = null;
              preparedBccRecipients = null;
              preparedForwardedAttachments = null;
              preparedThreadId = null;
            });
          },
        );
      case 3:
        return _buildViewMail();
      case 4:
        return _buildTrash();
      case 5:
        return _buildDrafts();
      default:
        return const SizedBox();
    }
  }

  // ------------------ Lists (Inbox, Sent, Trash, Drafts) ------------------ //
  Widget _buildInbox() {
  if (loadingInbox) return const Center(child: CircularProgressIndicator());
  final displayed = _applySearchFilter(inbox);
  if (displayed.isEmpty) return const Center(child: Text("No inbox mails"));

  return Column(
    children: [
      // TOP TOOLBAR (only when mails selected)
      if (selectedThreads.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Text("${selectedThreads.length} selected",
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: "Delete",
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _bulkDeleteSelected,
              ),
              IconButton(
                tooltip: "Clear selection",
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => selectedThreads.clear()),
              ),
            ],
          ),
        ),

      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => await loadInbox(silent: false),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: displayed.length,
            itemBuilder: (context, i) {
              final mail = displayed[i];
              final id = mail["_id"];
              final preview = mail['lastMessagePreview'] ?? "";
              final fromName =
                  (mail['messages'] is List && (mail['messages'] as List).isNotEmpty)
                      ? ((mail['messages'].last['from'] is Map)
                          ? (mail['messages'].last['from']['employeeName'] ?? '')
                          : mail['messages'].last['from'].toString())
                      : '';

              final dateIso = _extractLastActivityDate(mail);

              return Row(
                children: [
                  Checkbox(
                    value: selectedThreads.contains(id),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedThreads.add(id);
                        } else {
                          selectedThreads.remove(id);
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: _mailCard(
                      subject: mail["subject"] ?? "",
                      subtitle:
                          "$fromName • ${preview.toString().length > 120 ? '${preview.toString().substring(0, 120)}...' : preview}",
                      onTap: () {
                        if (selectedThreads.isNotEmpty) {
                          setState(() {
                            if (selectedThreads.contains(id)) {
                              selectedThreads.remove(id);
                            } else {
                              selectedThreads.add(id);
                            }
                          });
                        } else {
                          openMail(id);
                        }
                      },
                      dateIso: dateIso,
                      isUnread:
                          mail['unread'] == true || mail['isRead'] == false,
                      avatarText: fromName,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );
}

  Widget _buildSent() {
    if (loadingSent) return const Center(child: CircularProgressIndicator());
    final displayed = _applySearchFilter(sent);
    if (displayed.isEmpty) return const Center(child: Text("No sent mails"));
    return RefreshIndicator(
      onRefresh: () async => await loadSent(silent: false),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: displayed.length,
        itemBuilder: (context, i) {
          final mail = displayed[i];
          final preview = mail['lastMessagePreview'] ?? "";
          final dateIso = _extractLastActivityDate(mail);
          return _mailCard(
            subject: mail["subject"] ?? "",
            subtitle: "You • ${preview.toString().length > 120 ? '${preview.toString().substring(0, 120)}...' : preview}",
            onTap: () => openMail(mail["_id"]),
            dateIso: dateIso,
            isUnread: false,
            avatarText: 'You',
          );
        },
      ),
    );
  }

  Widget _buildTrash() {
    if (loadingTrash) return const Center(child: CircularProgressIndicator());
    final displayed = _applySearchFilter(trash);
    if (displayed.isEmpty) return const Center(child: Text("Trash is empty"));
    return RefreshIndicator(
      onRefresh: () async => await loadTrash(silent: false),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: displayed.length,
        itemBuilder: (context, i) {
          final mail = displayed[i];
          final preview = mail['lastMessagePreview'] ?? "";
          final dateIso = _extractLastActivityDate(mail);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: Text(mail["subject"] ?? "", style: const TextStyle(color: Colors.deepPurple)),
              subtitle: Text(preview.toString().length > 120 ? '${preview.toString().substring(0, 120)}...' : preview),
              onTap: () {
                setState(() {
                  selectedMenu = 4;
                });
                openMail(mail["_id"]);
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(tooltip: "Restore", icon: const Icon(Icons.restore, color: Colors.green), onPressed: () => _confirmRestore(mail["_id"])),
                  IconButton(tooltip: "Delete forever", icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () => _confirmDeleteForever(mail["_id"])),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrafts() {
    if (loadingDrafts) return const Center(child: CircularProgressIndicator());
    final displayed = _applySearchFilter(drafts);
    if (displayed.isEmpty) return const Center(child: Text("No drafts"));
    return RefreshIndicator(
      onRefresh: () async => await loadDrafts(silent: false),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: displayed.length,
        itemBuilder: (context, i) {
          final d = displayed[i];
          final subject = d['subject'] ?? "(No subject)";
          final preview = (d['body'] ?? "").toString();
          final dateIso = _extractLastActivityDate(d);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(subject.isNotEmpty ? subject[0].toUpperCase() : "D"),
              ),
              title: Text(subject, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
              subtitle: Text(preview.length > 120 ? '${preview.substring(0, 120)}...' : preview),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(formatRelativeDate(dateIso), style: const TextStyle(color: Colors.black54)),
                  ),
                  IconButton(icon: const Icon(Icons.edit, color: Colors.green), onPressed: () async {
                    // open draft in full compose — fetch single draft and pass to compose
                    final draftId = d['_id']?.toString();
                    if (draftId != null) {
                      try {
                        final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/mail/draft/$draftId"));
                        if (res.statusCode == 200) {
                          final dd = json.decode(res.body);
                          // Convert to recipient chip maps if needed
                          final toChips = (dd['to'] as List?)?.map<Map<String, dynamic>>((e) {
                            if (e is Map) return Map<String, dynamic>.from(e);
                            return {"employeeId": e.toString(), "employeeName": e.toString()};
                          }).toList() ?? [];
                          setState(() {
                            preparedSubject = dd['subject'] ?? "";
                            preparedBody = dd['body'] ?? "";
                            preparedToRecipients = toChips;
                            preparedCcRecipients = (dd['cc'] as List?)?.map<Map<String, dynamic>>((e) {
                              if (e is Map) return Map<String, dynamic>.from(e);
                              return {"employeeId": e.toString(), "employeeName": e.toString()};
                            }).toList() ?? [];
                            preparedBccRecipients = (dd['bcc'] as List?)?.map<Map<String, dynamic>>((e) {
                              if (e is Map) return Map<String, dynamic>.from(e);
                              return {"employeeId": e.toString(), "employeeName": e.toString()};
                            }).toList() ?? [];
                            preparedThreadId = null;
                            selectedMenu = 2;
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching draft: ${res.body}")));
                        }
                      } catch (e) {
                        debugPrint("Fetch draft error: $e");
                      }
                    }
                  }),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                    final draftId = d['_id']?.toString() ?? "";
                    try {
                      final user = Provider.of<UserProvider>(context, listen: false);
                      final empId = user.employeeId;
                      final res = await http.delete(Uri.parse("https://company-04bz.onrender.com/api/mail/draft/$draftId/$empId"));
                      if (res.statusCode == 200) {
                        await loadDrafts();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Draft deleted"), backgroundColor: Colors.green));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting draft: ${res.body}")));
                      }
                    } catch (e) {
                      debugPrint("Draft delete error: $e");
                    }
                  }),
                ],
              ),
              onTap: () async {
                // open draft for edit in compose
                final draftId = d['_id']?.toString();
                if (draftId != null) {
                  try {
                    final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/mail/draft/$draftId"));
                    if (res.statusCode == 200) {
                      final dd = json.decode(res.body);
                      final toChips = (dd['to'] as List?)?.map<Map<String, dynamic>>((e) {
                        if (e is Map) return Map<String, dynamic>.from(e);
                        return {"employeeId": e.toString(), "employeeName": e.toString()};
                      }).toList() ?? [];
                      setState(() {
                        preparedSubject = dd['subject'] ?? "";
                        preparedBody = dd['body'] ?? "";
                        preparedToRecipients = toChips;
                        preparedCcRecipients = (dd['cc'] as List?)?.map<Map<String, dynamic>>((e) {
                          if (e is Map) return Map<String, dynamic>.from(e);
                          return {"employeeId": e.toString(), "employeeName": e.toString()};
                        }).toList() ?? [];
                        preparedBccRecipients = (dd['bcc'] as List?)?.map<Map<String, dynamic>>((e) {
                          if (e is Map) return Map<String, dynamic>.from(e);
                          return {"employeeId": e.toString(), "employeeName": e.toString()};
                        }).toList() ?? [];
                        preparedThreadId = null;
                        selectedMenu = 2;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching draft: ${res.body}")));
                    }
                  } catch (e) {
                    debugPrint("Fetch draft error: $e");
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _mailCard({required String subject, required String subtitle, required VoidCallback onTap, dynamic dateIso, bool isUnread = false, String? avatarText}) {
    final dateText = (dateIso != null && dateIso.toString().isNotEmpty)
        ? (dateIso is String ? formatMailDate(dateIso) : formatRelativeDate(dateIso))
        : null;
    final initials = (avatarText ?? subject).toString().trim().isNotEmpty ? (avatarText ?? subject).toString().trim()[0].toUpperCase() : '?';
    return Card(
      elevation: isUnread ? 3 : 1,
      color: isUnread ? Colors.white : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: isUnread ? Colors.deepPurple.shade100 : Colors.grey.shade200,
          child: Text(initials, style: TextStyle(color: isUnread ? Colors.white : Colors.black87)),
        ),
        title: Text(subject,
            style: TextStyle(
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              color: Colors.deepPurple,
            )),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.black54, fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dateText != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(dateText, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  // ------------------ View Thread ------------------ //
  Widget _buildViewMail() {
    if (selectedMail == null) return const Center(child: CircularProgressIndicator());
    final thread = selectedMail!;
    final bool isTrash = selectedMenu == 4;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
                tooltip: "Back to list",
                onPressed: () {
                  setState(() {
                    // Logic to return to the previously selected folder
                    // If you want it to always go to Inbox, set to 0.
                    // Otherwise, just changing the view is enough if selectedMenu
                    // still holds the index of the list (0, 1, 4, or 5).
                    // Since openMail sets selectedMenu to 3, we restore it:
                    if (isTrash) {
                      selectedMenu = 4;
                    } else if (sent.any((m) => m['_id'] == thread['_id'])) {
                      selectedMenu = 1;
                    } else {
                      selectedMenu = 0; // Default to Inbox
                    }
                    selectedMail = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showInlineReply(thread),
                icon: const Icon(Icons.reply),
                label: const Text("Reply"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _openComposeForReplyAll(thread),
                icon: const Icon(Icons.reply_all),
                label: const Text("Reply all"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _openComposeForForward(thread),
                icon: const Icon(Icons.forward),
                label: const Text("Forward"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              if (!isTrash)
                ElevatedButton.icon(
                  onPressed: () => _moveToTrash(thread["_id"]),
                  icon: const Icon(Icons.delete),
                  label: const Text("Trash"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (isTrash) ...[
                ElevatedButton.icon(
                  onPressed: () => _restoreMail(thread["_id"]),
                  icon: const Icon(Icons.restore),
                  label: const Text("Restore"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _confirmDeleteForever(thread["_id"]),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("Delete Forever"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 20),
          Text(
            thread["subject"] ?? "",
            style: const TextStyle(
              color: Colors.deepPurple,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: (thread["messages"] ?? []).length,
              itemBuilder: (context, idx) {
                final msg = thread["messages"][idx];
                final isExpanded = expandedMessages.contains(idx);
                final bodyText = (msg["body"] ?? "").toString();
                final preview = bodyText.split("\n").take(3).join("\n");
                final from = msg['from'] is Map ? msg['from'] : {'employeeName': msg['from'], 'employeeId': msg['from']};
                final fromName = from['employeeName'] ?? from['employeeId'] ?? "";
                final fromId = from['employeeId'] ?? "";

                final messageCreated = msg['createdAt'];

                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipOval(
                                  child: (from['employeeImage'] != null)
                                      ? Image.network(
                                          "https://company-04bz.onrender.com${from['employeeImage']}",
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Image.asset('assets/profile.png', width: 44, height: 44),
                                        )
                                      : Image.asset('assets/profile.png', width: 44, height: 44),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Sender name
                                      Row(
                                        children: [
                                          Expanded(child: Text("$fromName ($fromId)", style: const TextStyle(fontWeight: FontWeight.bold))),
                                          // KEEP only expand and info icons (removed per-message reply/reply_all/forward)
                                          IconButton(
                                            icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                                            tooltip: isExpanded ? 'Collapse message' : 'Expand message',
                                            onPressed: () {
                                              setState(() {
                                                if (isExpanded) {
                                                  expandedMessages.remove(idx);
                                                } else {
                                                  expandedMessages.add(idx);
                                                }
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(expandedHeaderDetails.contains(idx) ? Icons.info_outline : Icons.info, size: 18),
                                            tooltip: expandedHeaderDetails.contains(idx) ? 'Hide details' : 'Show details',
                                            onPressed: () {
                                              setState(() {
                                                if (expandedHeaderDetails.contains(idx)) {
                                                  expandedHeaderDetails.remove(idx);
                                                } else {
                                                  expandedHeaderDetails.add(idx);
                                                }
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Time & date immediately after sender name
                                      if (messageCreated != null) Text(formatFullDateTime(messageCreated), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      // Header details (To/Cc/Bcc) shown directly under date when toggled
                                      if (expandedHeaderDetails.contains(idx))
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 8),
                                            const Text("Details:", style: TextStyle(fontWeight: FontWeight.bold)),
                                            if (msg['to'] is List)
                                              _buildHeaderDetailRow("To", (msg['to'] as List).map((e) {
                                                if (e is Map) return e['employeeName'] ?? e['employeeId'] ?? e.toString();
                                                return e.toString();
                                              }).join(", ")),
                                            if (msg['cc'] is List)
                                              _buildHeaderDetailRow("Cc", (msg['cc'] as List).map((e) {
                                                if (e is Map) return e['employeeName'] ?? e['employeeId'] ?? e.toString();
                                                return e.toString();
                                              }).join(", ")),
                                            if (msg['bcc'] is List)
                                              _buildHeaderDetailRow("Bcc", (msg['bcc'] as List).map((e) {
                                                if (e is Map) return e['employeeName'] ?? e['employeeId'] ?? e.toString();
                                                return e.toString();
                                              }).join(", ")),
                                          ],
                                        ),
                                      const SizedBox(height: 8),
                                      // show preview or full body (body goes after name/date/details)
                                      if (isExpanded)
                                        Text(bodyText, style: const TextStyle(fontSize: 15))
                                      else
                                        Text(preview, style: const TextStyle(fontSize: 15)),
                                      const SizedBox(height: 8),
                                      // attachments below the body
                                      if (msg["attachments"] != null && (msg["attachments"] as List).isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: (msg["attachments"] as List).map<Widget>((file) {
                                            final filename = file["filename"] ?? file.toString().split("/").last;
                                            final fileUrl = "https://company-04bz.onrender.com/uploads/${file['filename'] ?? file['path']?.split('/')?.last}";
                                            final originalName = file["originalName"] ?? filename;
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(Icons.attach_file, color: Colors.deepPurple),
                                              title: Text(originalName),
                                              onTap: () async {
                                                final uri = Uri.parse(fileUrl);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri);
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open attachment")));
                                                }
                                              },
                                            );
                                          }).toList(),
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
                    // inline composer insertion point:
                    if (showInlineReply && replyTargetIndex == idx)
                      InlineComposer(
                        threadId: thread['_id']?.toString() ?? "",
                        prefillRecipient: _resolveEmployeeFromThread(thread, fromId?.toString() ?? ""),
                        onReplySent: () async {
                          // reload thread and lists
                          final tid = thread['_id']?.toString();
                          if (tid != null) await openMail(tid);
                          await loadAll(silent: true);
                          setState(() {
                            showInlineReply = false;
                            replyTargetIndex = null;
                          });
                        },
                        onInlineDraftSaved: () async {
                          await loadDrafts(silent: true);
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (thread["attachments"] != null && (thread["attachments"] as List).isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Attachments:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 16)),
                const SizedBox(height: 10),
                ...((thread["attachments"] as List)).map<Widget>((file) {
                  final filename = file["filename"] ?? file.toString().split("/").last;
                  final fileUrl = "https://company-04bz.onrender.com/uploads/${file['filename'] ?? file['path']?.split('/')?.last}";
                  final originalName = file["originalName"] ?? filename;
                  return InkWell(
                    onTap: () async {
                      final uri = Uri.parse(fileUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open attachment")));
                      }
                    },
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.attach_file, color: Colors.deepPurple),
                        title: Text(originalName),
                      ),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ build ------------------ //
  @override
  Widget build(BuildContext context) {
    // Get current user to display name in sidebar header
    final user = Provider.of<UserProvider>(context);
final displayName =
    (user.employeeName != null && user.employeeName!.isNotEmpty)
        ? user.employeeName!
        : (user.employeeId ?? "Mail");

    // final user = Provider.of<UserProvider>(context, listen: false);
    // final displayName = (user.employeeName ?? user.fullName ?? user.name ?? user.employeeId ?? "Mail Portal").toString();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search mail (subject, sender, preview)',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => loadAll(silent: false),
            ),
            const SizedBox(width: 6),
          ],
        ),
        backgroundColor: Colors.deepPurple,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            selectedMenu = 2; // open compose
            preparedSubject = null;
            preparedBody = null;
            preparedToRecipients = null;
            preparedCcRecipients = null;
            preparedBccRecipients = null;
            preparedForwardedAttachments = null;
            preparedThreadId = null;
          });
        },
        backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
        child: const Icon(Icons.create),
      ),
      body: Row(
        children: [
          Container(
            width: 260,
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // CircleAvatar(
                    //   backgroundColor: Colors.deepPurple.shade200,
                    //   child: const Icon(Icons.mail, color: Colors.white),
                    // ),
                    CircleAvatar(
  backgroundColor: Colors.deepPurple,
  child: Text(
    displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
),

                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _menuButton(Icons.inbox, "Inbox", 0),
                const SizedBox(height: 6),
                _menuButton(Icons.send, "Sent", 1),
                const SizedBox(height: 6),
                _menuButton(Icons.delete, "Trash", 4),
                const SizedBox(height: 6),
                _menuButton(Icons.edit, "Compose", 2),
                const SizedBox(height: 6),
                _menuButton(Icons.drafts, "Drafts", 5),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),
                Text('Auto-refresh: every 30s', style: TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  onPressed: () => loadAll(silent: false),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh now'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }
}
