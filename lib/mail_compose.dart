// lib/mail_compose.dart -//lib/mail_compose.dart — everything related to composing and inline replying.
// UI + send/draft autosave logic + file pickers + recipient chips/autocomplete for compose flows.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zeai_project/user_provider.dart';

// -------- MailComposePanel --------
class MailComposePanel extends StatefulWidget {
  final VoidCallback? onSendSuccess;
  final VoidCallback? onCancel;
  final VoidCallback? onDraftSaved;
  final String? initialSubject;
  final String? initialBody;

  // New separated recipient lists & forwarded attachments
  final List<Map<String, dynamic>>? initialToRecipients;
  final List<Map<String, dynamic>>? initialCcRecipients;
  final List<Map<String, dynamic>>? initialBccRecipients;
  final List<dynamic>? initialForwardedAttachments;

  // Notifier from dashboard to request a draft save when leaving compose
  final ValueNotifier<int>? saveRequestNotifier;

  final String? initialThreadId;

  const MailComposePanel({
    super.key,
    this.onSendSuccess,
    this.onCancel,
    this.onDraftSaved,
    this.initialSubject,
    this.initialBody,
    this.initialToRecipients,
    this.initialCcRecipients,
    this.initialBccRecipients,
    this.initialForwardedAttachments,
    this.saveRequestNotifier,
    this.initialThreadId,
  });

  @override
  State<MailComposePanel> createState() => _MailComposePanelState();
}

class _MailComposePanelState extends State<MailComposePanel> {
  final TextEditingController _subCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _ccCtrl = TextEditingController();
  final TextEditingController _bccCtrl = TextEditingController();

  List<PlatformFile> attachments = [];
  List<dynamic> _forwardedAttachments = [];
  bool sending = false;

  List<Map<String, dynamic>> selectedRecipients = [];
  List<Map<String, dynamic>> selectedCcRecipients = [];
  List<Map<String, dynamic>> selectedBccRecipients = [];
  TextEditingController recipientController = TextEditingController();
  TextEditingController ccController = TextEditingController();
  TextEditingController bccController = TextEditingController();

  bool showCc = false;
  bool showBcc = false;

  String? _editingDraftId;
  Timer? _draftDebounce;

  String? currentThreadId;

  // listener reference to remove later
  VoidCallback? _saveRequestListener;

  @override
  void initState() {
    super.initState();
    _subCtrl.text = widget.initialSubject ?? "";
    _bodyCtrl.text = widget.initialBody ?? "";

    // use the separate initial recipients if provided
    if (widget.initialToRecipients != null) selectedRecipients = List.from(widget.initialToRecipients!);
    if (widget.initialCcRecipients != null) selectedCcRecipients = List.from(widget.initialCcRecipients!);
    if (widget.initialBccRecipients != null) selectedBccRecipients = List.from(widget.initialBccRecipients!);
    if (widget.initialForwardedAttachments != null) _forwardedAttachments = List.from(widget.initialForwardedAttachments!);

    currentThreadId = widget.initialThreadId;
    _subCtrl.addListener(_onComposeChanged);
    _bodyCtrl.addListener(_onComposeChanged);
    _ccCtrl.addListener(_onComposeChanged);
    _bccCtrl.addListener(_onComposeChanged);
    _toCtrl.addListener(_onComposeChanged);

    // listen to save requests from the dashboard (when user navigates away)
    if (widget.saveRequestNotifier != null) {
      _saveRequestListener = () {
        // save draft silently when notifier changes
        _saveDraft(showSnack: false);
      };
      widget.saveRequestNotifier!.addListener(_saveRequestListener!);
    }
  }

  @override
  void dispose() {
    // remove listener if added
    if (widget.saveRequestNotifier != null && _saveRequestListener != null) {
      widget.saveRequestNotifier!.removeListener(_saveRequestListener!);
    }

    _draftDebounce?.cancel();
    _subCtrl.dispose();
    _bodyCtrl.dispose();
    _toCtrl.dispose();
    _ccCtrl.dispose();
    _bccCtrl.dispose();
    recipientController.dispose();
    ccController.dispose();
    bccController.dispose();
    super.dispose();
  }

  // File picker
  Future<void> pickFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (res != null) {
      setState(() {
        attachments.addAll(res.files);
      });
      _scheduleDraftSave();
    }
  }

  // Send mail (identical logic to your current sendMail) + delete server draft after success
  Future<void> sendMail() async {
    // cancel any pending draft save to avoid races
    _draftDebounce?.cancel();

    final user = Provider.of<UserProvider>(context, listen: false);
    final from = user.employeeId;
    final toList = selectedRecipients.isNotEmpty
        ? selectedRecipients.map((r) => r["employeeId"].toString()).toList()
        : _toCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (toList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Receiver required")));
      return;
    }

    setState(() => sending = true);

    // keep a local reference to the draft id so we can delete it after sending
    final String? draftIdToDelete = _editingDraftId;

    var req = http.MultipartRequest("POST", Uri.parse("https://company-04bz.onrender.com/api/mail/send"));
    req.fields["from"] = from!;
    req.fields["to"] = jsonEncode(toList);

    final ccList = selectedCcRecipients.isNotEmpty
        ? selectedCcRecipients.map((r) => r["employeeId"].toString()).toList()
        : _ccCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    req.fields["cc"] = jsonEncode(ccList);

    final bccList = selectedBccRecipients.isNotEmpty
        ? selectedBccRecipients.map((r) => r["employeeId"].toString()).toList()
        : _bccCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    req.fields["bcc"] = jsonEncode(bccList);

    req.fields["subject"] = _subCtrl.text;
    req.fields["body"] = _bodyCtrl.text;

    if (currentThreadId != null) req.fields["threadId"] = currentThreadId!;
    if (_forwardedAttachments.isNotEmpty) req.fields["forwardAttachments"] = jsonEncode(_forwardedAttachments);
    if (_editingDraftId != null) req.fields["draftId"] = _editingDraftId!;

    for (var f in attachments) {
      if (f.bytes != null) {
        req.files.add(http.MultipartFile.fromBytes("attachments", f.bytes!, filename: f.name));
      } else if (f.path != null) {
        req.files.add(await http.MultipartFile.fromPath("attachments", f.path!, filename: f.name));
      }
    }

    try {
      var resp = await req.send();
      var finalRes = await http.Response.fromStream(resp);
      if (finalRes.statusCode == 201 || finalRes.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mail Sent"), backgroundColor: Colors.green));

        // clear composer UI immediately (we already captured draftIdToDelete above)
        setState(() {
          attachments.clear();
          _forwardedAttachments.clear();
          currentThreadId = null;
          // clear local editing id in UI — actual server deletion done below using draftIdToDelete
          _editingDraftId = null;
          selectedRecipients.clear();
          selectedCcRecipients.clear();
          selectedBccRecipients.clear();
          _toCtrl.clear();
          _ccCtrl.clear();
          _bccCtrl.clear();
        });

        // Attempt to delete server-side draft if we were editing one (use the captured id)
        if (draftIdToDelete != null) {
          try {
            await http.delete(Uri.parse("https://company-04bz.onrender.com/api/mail/draft/$draftIdToDelete/$from"));
          } catch (e) {
            debugPrint("Failed to delete draft after send: $e");
          }
          // notify parent to refresh draft list/count
          widget.onDraftSaved?.call();
        }

        // callback to parent for send success (separate from draft refresh)
        widget.onSendSuccess?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${finalRes.body}")));
      }
    } catch (e) {
      debugPrint("Send error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send mail")));
    } finally {
      setState(() => sending = false);
    }
  }

  // Draft save (almost identical to your current _saveDraft)
  Future<void> _saveDraft({bool showSnack = true}) async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final from = user.employeeId;
    if (from == null) return;

    final toList = selectedRecipients.isNotEmpty
        ? selectedRecipients.map((r) => r["employeeId"].toString()).toList()
        : _toCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final ccList = selectedCcRecipients.isNotEmpty
        ? selectedCcRecipients.map((r) => r["employeeId"].toString()).toList()
        : _ccCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final bccList = selectedBccRecipients.isNotEmpty
        ? selectedBccRecipients.map((r) => r["employeeId"].toString()).toList()
        : _bccCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final hasContent = toList.isNotEmpty ||
        ccList.isNotEmpty ||
        bccList.isNotEmpty ||
        _subCtrl.text.trim().isNotEmpty ||
        _bodyCtrl.text.trim().isNotEmpty ||
        attachments.isNotEmpty ||
        _forwardedAttachments.isNotEmpty;

    if (!hasContent) {
      if (_editingDraftId != null) {
        try {
          await http.delete(Uri.parse("https://company-04bz.onrender.com/api/mail/draft/$_editingDraftId/$from"));
        } catch (e) {
          debugPrint("Delete empty draft error: $e");
        }
        setState(() {
          _editingDraftId = null;
        });
        widget.onDraftSaved?.call();
      }
      return;
    }

    var uri = Uri.parse("https://company-04bz.onrender.com/api/mail/drafts/save");
    var req = http.MultipartRequest("POST", uri);
    if (_editingDraftId != null) req.fields["draftId"] = _editingDraftId!;
    req.fields["from"] = from;
    req.fields["to"] = jsonEncode(toList);
    req.fields["cc"] = jsonEncode(ccList);
    req.fields["bcc"] = jsonEncode(bccList);
    req.fields["subject"] = _subCtrl.text;
    req.fields["body"] = _bodyCtrl.text;

    for (var f in attachments) {
      if (f.bytes != null) {
        req.files.add(http.MultipartFile.fromBytes("attachments", f.bytes!, filename: f.name));
      } else if (f.path != null) {
        req.files.add(await http.MultipartFile.fromPath("attachments", f.path!, filename: f.name));
      }
    }

    if (_forwardedAttachments.isNotEmpty) req.fields["forwardAttachments"] = jsonEncode(_forwardedAttachments);

    try {
      var resp = await req.send();
      var finalRes = await http.Response.fromStream(resp);
      if (finalRes.statusCode == 201 || finalRes.statusCode == 200) {
        final body = json.decode(finalRes.body);
        final d = body['draft'] ?? body;
        setState(() {
          _editingDraftId = d != null ? (d['_id'] ?? d['id'] ?? _editingDraftId) : _editingDraftId;
        });
        if (showSnack) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Draft saved"), backgroundColor: Colors.green));
        // notify parent so drafts list/count updates
        widget.onDraftSaved?.call();
      } else {
        debugPrint("Draft save server error: ${finalRes.body}");
      }
    } catch (e) {
      debugPrint("Draft save error: $e");
    }
  }

  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(seconds: 2), () {
      _saveDraft(showSnack: false);
    });
  }

  void _onComposeChanged() {
    _scheduleDraftSave();
  }

  // UI building (abbreviated, keep the structure you had)
  Widget _buildRecipientField({
    required String label,
    required List<Map<String, dynamic>> recipients,
    required TextEditingController controller,
    required Function(Map<String, dynamic>) onSelected,
  }) {
    // copy the implementation you already have in the big file
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          ...recipients.map((rec) {
            return Chip(
              avatar: CircleAvatar(
                backgroundImage: rec["employeeImage"] != null ? NetworkImage("https://company-04bz.onrender.com${rec['employeeImage']}") : const AssetImage("assets/profile.png") as ImageProvider,
              ),
              label: Text("${rec['employeeName']} (${rec['employeeId']})"),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() {
                  recipients.remove(rec);
                });
                _scheduleDraftSave();
              },
            );
          }),
          SizedBox(
            width: 220,
            child: Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (value) async {
                final query = value.text.trim();
                if (query.isEmpty) return const Iterable.empty();
                final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/employees/search/$query"));
                if (res.statusCode != 200) return const Iterable.empty();
                return (json.decode(res.body) as List).cast<Map<String, dynamic>>();
              },
              displayStringForOption: (opt) => "${opt['employeeName']} (${opt['employeeId']})",
              onSelected: (opt) {
                if (!recipients.any((r) => r["employeeId"] == opt["employeeId"])) {
                  setState(() => recipients.add(opt));
                  _scheduleDraftSave();
                }
                controller.clear();
              },
              fieldViewBuilder: (_, textCtrl, focusNode, __) {
                controller = textCtrl;
                return TextField(controller: textCtrl, focusNode: focusNode, decoration: InputDecoration(hintText: "Add $label", border: InputBorder.none));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _composeField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.deepPurple.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildRecipientField(
            label: "To",
            recipients: selectedRecipients,
            controller: recipientController,
            onSelected: (opt) => setState(() {
              if (!selectedRecipients.any((r) => r['employeeId'] == opt['employeeId'])) selectedRecipients.add(opt);
              _scheduleDraftSave();
            }),
          ),
          if (showCc)
            _buildRecipientField(
              label: "Cc",
              recipients: selectedCcRecipients,
              controller: ccController,
              onSelected: (opt) => setState(() {
                if (!selectedCcRecipients.any((r) => r['employeeId'] == opt['employeeId'])) selectedCcRecipients.add(opt);
                _scheduleDraftSave();
              }),
            ),
          if (showBcc)
            _buildRecipientField(
              label: "Bcc",
              recipients: selectedBccRecipients,
              controller: bccController,
              onSelected: (opt) => setState(() {
                if (!selectedBccRecipients.any((r) => r['employeeId'] == opt['employeeId'])) selectedBccRecipients.add(opt);
                _scheduleDraftSave();
              }),
            ),
          Row(children: [
            TextButton(onPressed: () => setState(() => showCc = !showCc), child: Text(showCc ? "Hide CC" : "Add CC")),
            const SizedBox(width: 8),
            TextButton(onPressed: () => setState(() => showBcc = !showBcc), child: Text(showBcc ? "Hide BCC" : "Add BCC"))
          ]),
          const SizedBox(height: 12),
          _composeField(_subCtrl, "Subject"),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [

  // ✍️ Text Field (starts from top like Gmail)
  Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 66), // give extra bottom space for chips + icon
    child: TextField(
      controller: _bodyCtrl,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        hintText: "Type your message...",
        border: InputBorder.none,
      ),
    ),
  ),

  // 📎 Bottom Left Attachment Icon
  Positioned(
    left: 8,
    bottom: 8,
    child: IconButton(
      icon: const Icon(Icons.attach_file),
      onPressed: pickFiles,
    ),
  ),

  // Optional: show attachment count badge (small)
  if (attachments.isNotEmpty || _forwardedAttachments.isNotEmpty)
    Positioned(
      left: 48,
      bottom: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "${attachments.length + _forwardedAttachments.length}",
          style: const TextStyle(
            fontSize: 12,
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),

  // ---------------- Attachment filename chips (horizontal scroll) ----------------
  if (attachments.isNotEmpty || _forwardedAttachments.isNotEmpty)
    Positioned(
      left: 12,
      right: 12,
      bottom: 44, // sits above the icon area
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [

            // Local picked files
            for (int i = 0; i < attachments.length; i++) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file, size: 16, color: Colors.deepPurple),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        attachments[i].name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          attachments.removeAt(i);
                        });
                        _scheduleDraftSave();
                      },
                      child: const Icon(Icons.close, size: 18, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],

            // Forwarded attachments (if any) — support Map or String entries
            // Forwarded attachments (if any)
for (int j = 0; j < _forwardedAttachments.length; j++) ...[
  Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.attach_file, size: 16, color: Colors.deepPurple),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            _forwardedAttachments[j] is Map
                ? (_forwardedAttachments[j]['originalName'] ??
                   _forwardedAttachments[j]['filename'] ??
                   _forwardedAttachments[j].toString())
                : _forwardedAttachments[j].toString(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            setState(() {
              _forwardedAttachments.removeAt(j);
            });
            _scheduleDraftSave();
          },
          child: const Icon(Icons.close, size: 18, color: Colors.black54),
        ),
      ],
    ),
  ),
],

          ],
        ),
      ),
    ),
],

              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton.icon(
              onPressed: sending ? null : sendMail,
              icon: const Icon(Icons.send),
              label: const Text("Send"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple,foregroundColor: Colors.white),
            ),
            const SizedBox(width: 20),
            ElevatedButton.icon(
              onPressed: () {
                _scheduleDraftSave();
                widget.onCancel?.call();
              },
              icon: const Icon(Icons.cancel),
              label: const Text("Cancel"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple,foregroundColor: Colors.white),
            ),
          ])
        ],
      ),
    );
  }
}

// -------- InlineComposer --------
// (unchanged except formatting) — inline behavior already deletes draft after send correctly
class InlineComposer extends StatefulWidget {
  final String threadId;
  final VoidCallback? onReplySent;
  final VoidCallback? onInlineDraftSaved;
  final Map<String, dynamic>? prefillRecipient; // single recipient map from _resolveEmployeeFromThread

  const InlineComposer({super.key, required this.threadId, this.onReplySent, this.onInlineDraftSaved, this.prefillRecipient});

  @override
  State<InlineComposer> createState() => _InlineComposerState();
}

class _InlineComposerState extends State<InlineComposer> {
  final TextEditingController _inlineBodyCtrl = TextEditingController();
  final List<PlatformFile> _inlineAttachments = [];
  final List<Map<String, dynamic>> _inlineRecipients = [];
  final List<Map<String, dynamic>> _inlineCcRecipients = [];
  final List<Map<String, dynamic>> _inlineBccRecipients = [];

  bool _inlineSending = false;
  Timer? _inlineDraftDebounce;
  bool _inlineShowCc = false;
  bool _inlineShowBcc = false;
  String? _editingInlineDraftId;

  @override
  void initState() {
    super.initState();
    if (widget.prefillRecipient != null) _inlineRecipients.add(widget.prefillRecipient!);
    _inlineBodyCtrl.addListener(_onInlineComposeChanged);
  }

  @override
  void dispose() {
    _inlineDraftDebounce?.cancel();
    _inlineBodyCtrl.removeListener(_onInlineComposeChanged);
    _inlineBodyCtrl.dispose();
    super.dispose();
  }

  void _onInlineComposeChanged() {
    _scheduleInlineDraftSave();
  }

  void _scheduleInlineDraftSave() {
    _inlineDraftDebounce?.cancel();
    _inlineDraftDebounce = Timer(const Duration(seconds: 2), () => _saveInlineDraft(showSnack: false));
  }

  Future<void> pickInlineFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (res != null) {
      setState(() {
        _inlineAttachments.addAll(res.files);
      });
      _scheduleInlineDraftSave();
    }
  }

  Future<void> _sendInlineReply() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final from = user.employeeId;
    if (from == null) return;

    final toList = _inlineRecipients.map((r) => r['employeeId'].toString()).toList();
    if (toList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Receiver required")));
      return;
    }

    setState(() => _inlineSending = true);
    var req = http.MultipartRequest("POST", Uri.parse("https://company-04bz.onrender.com/api/mail/send"));
    req.fields["from"] = from;
    req.fields["to"] = jsonEncode(toList);
    req.fields["cc"] = jsonEncode(_inlineCcRecipients.map((r) => r['employeeId']).toList());
    req.fields["bcc"] = jsonEncode(_inlineBccRecipients.map((r) => r['employeeId']).toList());
    req.fields["subject"] = ""; // inline uses thread subject on server side via threadId if needed
    req.fields["body"] = _inlineBodyCtrl.text;
    req.fields["threadId"] = widget.threadId;

    for (var f in _inlineAttachments) {
      if (f.bytes != null) {
        req.files.add(http.MultipartFile.fromBytes("attachments", f.bytes!, filename: f.name));
      } else if (f.path != null) {
        req.files.add(await http.MultipartFile.fromPath("attachments", f.path!, filename: f.name));
      }
    }

    try {
      var resp = await req.send();
      var finalRes = await http.Response.fromStream(resp);
      if (finalRes.statusCode == 200 || finalRes.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reply sent"), backgroundColor: Colors.green));
        // delete inline draft if present
        if (_editingInlineDraftId != null) {
          try {
            await http.delete(Uri.parse("https://company-04bz.onrender.com/api/mail/draft/$_editingInlineDraftId/$from"));
          } catch (e) {
            debugPrint("Failed to delete inline draft after send: $e");
          }
          setState(() {
            _editingInlineDraftId = null;
          });
          // signal parent to refresh drafts
          widget.onInlineDraftSaved?.call();
        }

        setState(() {
          _inlineBodyCtrl.clear();
          _inlineAttachments.clear();
          _inlineRecipients.clear();
          _inlineCcRecipients.clear();
          _inlineBccRecipients.clear();
        });
        widget.onReplySent?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${finalRes.body}")));
      }
    } catch (e) {
      debugPrint("Inline send error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send reply")));
    } finally {
      setState(() => _inlineSending = false);
    }
  }

  Future<void> _saveInlineDraft({bool showSnack = true}) async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final from = user.employeeId;
    if (from == null) return;
    final toList = _inlineRecipients.map((r) => r['employeeId'].toString()).toList();
    final hasContent = toList.isNotEmpty || _inlineBodyCtrl.text.trim().isNotEmpty || _inlineAttachments.isNotEmpty;
    if (!hasContent) {
      if (_editingInlineDraftId != null) {
        try {
          await http.delete(Uri.parse("https://company-04bz.onrender.com/api/mail/draft/$_editingInlineDraftId/$from"));
        } catch (e) {
          debugPrint("Delete empty inline draft error: $e");
        }
        setState(() => _editingInlineDraftId = null);
        widget.onInlineDraftSaved?.call();
      }
      return;
    }

    var uri = Uri.parse("https://company-04bz.onrender.com/api/mail/drafts/save");
    var req = http.MultipartRequest("POST", uri);
    if (_editingInlineDraftId != null) req.fields["draftId"] = _editingInlineDraftId!;
    req.fields["from"] = from;
    req.fields["to"] = jsonEncode(toList);
    req.fields["subject"] = "";
    req.fields["body"] = _inlineBodyCtrl.text;
    for (var f in _inlineAttachments) {
      if (f.bytes != null) {
        req.files.add(http.MultipartFile.fromBytes("attachments", f.bytes!, filename: f.name));
      } else if (f.path != null) req.files.add(await http.MultipartFile.fromPath("attachments", f.path!, filename: f.name));
    }

    try {
      var resp = await req.send();
      var finalRes = await http.Response.fromStream(resp);
      if (finalRes.statusCode == 200 || finalRes.statusCode == 201) {
        final body = json.decode(finalRes.body);
        final d = body['draft'] ?? body;
        setState(() {
          _editingInlineDraftId = d != null ? (d['_id'] ?? d['id'] ?? _editingInlineDraftId) : _editingInlineDraftId;
        });
        if (showSnack) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Draft saved"), backgroundColor: Colors.green));
        widget.onInlineDraftSaved?.call();
      }
    } catch (e) {
      debugPrint("Inline draft save error: $e");
    }
  }

  @override
Widget build(BuildContext context) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey.shade200),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [

        // Recipient chips
        if (_inlineRecipients.isNotEmpty)
          Wrap(
            children: _inlineRecipients
                .map((r) => Chip(
                      label: Text("${r['employeeName']} (${r['employeeId']})"),
                    ))
                .toList(),
          ),

        // CC / BCC buttons (attachment button removed)
        Row(
          children: [
            TextButton(
              onPressed: () =>
                  setState(() => _inlineShowCc = !_inlineShowCc),
              child: Text(_inlineShowCc ? "Hide CC" : "Add CC"),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () =>
                  setState(() => _inlineShowBcc = !_inlineShowBcc),
              child: Text(_inlineShowBcc ? "Hide BCC" : "Add BCC"),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ✅ Gmail Style Reply Box
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            children: [

  // ✍️ Text area (starts typing from top)
  Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 56),
    child: TextField(
      controller: _inlineBodyCtrl,
      maxLines: null,
      minLines: 3,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        hintText: "Write a reply...",
        border: InputBorder.none,
      ),
    ),
  ),

  // 📎 Attachment icon (bottom-left)
  Positioned(
    left: 6,
    bottom: 8,
    child: IconButton(
      icon: const Icon(Icons.attach_file, size: 20),
      onPressed: pickInlineFiles,
    ),
  ),

  // small attachment count
  if (_inlineAttachments.isNotEmpty)
    Positioned(
      left: 40,
      bottom: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "${_inlineAttachments.length}",
          style: const TextStyle(fontSize: 12, color: Colors.deepPurple, fontWeight: FontWeight.bold),
        ),
      ),
    ),

  // Inline attachment chips (horizontal)
  if (_inlineAttachments.isNotEmpty)
    Positioned(
      left: 12,
      right: 12,
      bottom: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _inlineAttachments.length; i++) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file, size: 16, color: Colors.deepPurple),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        _inlineAttachments[i].name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _inlineAttachments.removeAt(i);
                        });
                        _scheduleInlineDraftSave();
                      },
                      child: const Icon(Icons.close, size: 18, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
],

          ),
        ),

        const SizedBox(height: 10),

        // Send / Cancel buttons
        Row(
          children: [
            ElevatedButton.icon(
              onPressed:
                  _inlineSending ? null : _sendInlineReply,
              icon: const Icon(Icons.send),
              label: const Text("Send"),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                setState(() {
                  _inlineBodyCtrl.clear();
                  _inlineAttachments.clear();
                  _inlineRecipients.clear();
                });

                if (_editingInlineDraftId != null) {
                  final user =
                      Provider.of<UserProvider>(context,
                          listen: false);
                  final empId = user.employeeId;

                  try {
                    await http.delete(Uri.parse(
                        "https://company-04bz.onrender.com/api/mail/draft/$_editingInlineDraftId/$empId"));
                  } catch (e) {
                    debugPrint(
                        "Failed to delete inline draft: $e");
                  }

                  setState(() =>
                      _editingInlineDraftId = null);

                  widget.onInlineDraftSaved?.call();
                }
              },
              child: const Text("Cancel"),
            ),
          ],
        ),
      ],
    ),
  );
}

}