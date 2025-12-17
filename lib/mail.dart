import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zeai_project/user_provider.dart';

// Assume these are imported from your project
// import 'sidebar.dart';
// import 'user_provider.dart';

class MailDashboard extends StatefulWidget {
  const MailDashboard({super.key});

  @override
  State<MailDashboard> createState() => _MailDashboardState();
}

class _MailDashboardState extends State<MailDashboard> {
  int selectedMenu = 0; // 0 = Inbox, 1 = Sent, 2 = Compose, 3 = View Mail, 4 = Trash
  Map<String, dynamic>? selectedMail;

  List inbox = [];
  List sent = [];
  List trash = [];
  bool loadingInbox = true;
  bool loadingSent = true;
  bool loadingTrash = true;
  bool isReplyOrForward = false;

  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _subCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  List<PlatformFile> attachments = [];
  bool sending = false;

  @override
  void initState() {
    super.initState();
    loadInbox();
    loadSent();
    loadTrash();
  }

  Future<void> loadInbox() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final empId = user.employeeId;
    try {
      final res = await http.get(Uri.parse("http://localhost:5000/api/mail/inbox/$empId"));
      if (res.statusCode == 200) {
        setState(() {
          inbox = json.decode(res.body);
          loadingInbox = false;
        });
      }
    } catch (e) {
      debugPrint("Inbox error: $e");
      setState(() => loadingInbox = false);
    }
  }

  Future<void> loadSent() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final empId = user.employeeId;
    try {
      final res = await http.get(Uri.parse("http://localhost:5000/api/mail/sent/$empId"));
      if (res.statusCode == 200) {
        setState(() {
          sent = json.decode(res.body);
          loadingSent = false;
        });
      }
    } catch (e) {
      debugPrint("Sent error: $e");
      setState(() => loadingSent = false);
    }
  }

  Future<void> loadTrash() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final empId = user.employeeId;
    try {
      final res = await http.get(Uri.parse("http://localhost:5000/api/mail/trash/$empId"));
      if (res.statusCode == 200) {
        setState(() {
          trash = json.decode(res.body);
          loadingTrash = false;
        });
      }
    } catch (e) {
      debugPrint("Trash load error: $e");
      setState(() => loadingTrash = false);
    }
  }

  Future<void> openMail(String id) async {
    setState(() {
      selectedMenu = 3;
      selectedMail = null;
    });
    try {
      final res = await http.get(Uri.parse("http://localhost:5000/api/mail/view/$id"));
      if (res.statusCode == 200) {
        setState(() {
          selectedMail = json.decode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Mail view error: $e");
    }
  }

  Future<void> pickFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (res != null) {
      setState(() {
        attachments.addAll(res.files);
      });
    }
  }

  Future<void> sendMail() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final from = user.employeeId;
    if (_toCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Receiver required")));
      return;
    }
    setState(() => sending = true);
    var req = http.MultipartRequest("POST", Uri.parse("http://localhost:5000/api/mail/send"));
    req.fields["from"] = from!;
    req.fields["to"] = _toCtrl.text;
    req.fields["subject"] = _subCtrl.text;
    req.fields["body"] = _bodyCtrl.text;
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
      if (finalRes.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mail Sent"), backgroundColor: Colors.green),
        );
        setState(() {
          attachments.clear();
          isReplyOrForward = false;
          selectedMenu = 0;
        });
        loadInbox();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${finalRes.body}")));
      }
    } catch (e) {
      debugPrint("Send error: $e");
    }
    setState(() => sending = false);
  }

  Future<void> _moveToTrash(String id) async {
    await http.put(Uri.parse("http://localhost:5000/api/mail/trash/$id"));
    loadInbox();
    loadTrash();
    setState(() => selectedMenu = 4);
  }

  Future<void> _restoreMail(String id) async {
    await http.put(Uri.parse("http://localhost:5000/api/mail/restore/$id"));
    loadTrash();
    loadInbox();
    setState(() => selectedMenu = 0);
  }

  Future<void> _deleteForever(String id) async {
    await http.delete(Uri.parse("http://localhost:5000/api/mail/delete-permanent/$id"));
    loadTrash();
    setState(() => selectedMenu = 4);
  }

  void _prepareReplyMail(Map mail) {
    setState(() {
      isReplyOrForward = true;
      selectedMenu = 2;
      attachments.clear();
      _toCtrl.text = mail["from"];
      _subCtrl.text = "Re: ${mail['subject']}";
      _bodyCtrl.text = "\n\n----- Reply Below -----\n${mail['body']}";
    });
  }

  void _prepareForwardMail(Map mail) {
    setState(() {
      isReplyOrForward = true;
      selectedMenu = 2;
      attachments.clear();
      _toCtrl.clear();
      _subCtrl.text = "Fwd: ${mail['subject']}";
      _bodyCtrl.text = "----- Forwarded Message -----\nFrom: ${mail['from']}\nTo: ${mail['to']}\n\n${mail['body']}";
    });
  }

  Widget _menuButton(icon, text, index) {
    final selected = selectedMenu == index;
    return InkWell(
      onTap: () => setState(() => selectedMenu = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple.shade100 : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.deepPurple : Colors.black87, size: 22),
            const SizedBox(width: 12),
            Text(text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.deepPurple : Colors.black87,
                )),
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
        return _buildCompose();
      case 3:
        return _buildViewMail();
      case 4:
        return _buildTrash();
      default:
        return const SizedBox();
    }
  }

  Widget _buildInbox() {
    if (loadingInbox) return const Center(child: CircularProgressIndicator());
    if (inbox.isEmpty) return const Center(child: Text("No inbox mails"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inbox.length,
      itemBuilder: (context, i) {
        final mail = inbox[i];
        return _mailCard(
          subject: mail["subject"],
          subtitle: "From: ${mail['from']}",
          onTap: () => openMail(mail["_id"]),
        );
      },
    );
  }

  Widget _buildSent() {
    if (loadingSent) return const Center(child: CircularProgressIndicator());
    if (sent.isEmpty) return const Center(child: Text("No sent mails"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sent.length,
      itemBuilder: (context, i) {
        final mail = sent[i];
        return _mailCard(
          subject: mail["subject"],
          subtitle: "To: ${mail['to']}",
          onTap: () => openMail(mail["_id"]),
        );
      },
    );
  }

  Widget _buildTrash() {
    if (loadingTrash) return const Center(child: CircularProgressIndicator());
    if (trash.isEmpty) return const Center(child: Text("Trash is empty"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trash.length,
      itemBuilder: (context, i) {
        final mail = trash[i];
        return _mailCard(
          subject: mail["subject"],
          subtitle: "From: ${mail['from']}",
          onTap: () => openMail(mail["_id"]),
        );
      },
    );
  }

  Widget _mailCard({required String subject, required String subtitle, required VoidCallback onTap}) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(subject,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            )),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRecipientAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue value) async {
        final query = value.text.split(",").last.trim();
        if (query.isEmpty) return const Iterable.empty();
        final res = await http.get(Uri.parse("http://localhost:5000/api/employees/search/$query"));
        if (res.statusCode != 200) return const Iterable.empty();
        List list = json.decode(res.body);
        return list.cast<Map<String, dynamic>>();
      },
      displayStringForOption: (option) => "${option['employeeName']} (${option['employeeId']})",
      onSelected: (option) {
        final empId = option["employeeId"];
        List existing = _toCtrl.text.split(",").map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (!existing.contains(empId)) {
          existing.add(empId);
        }
        _toCtrl.text = existing.join(", ");
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        controller.value = _toCtrl.value;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: _purpleBox("To (Type employee name...)"),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 350,
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opt = options.elementAt(index);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: opt["employeeImage"] != null
                          ? NetworkImage("http://localhost:5000${opt['employeeImage']}")
                          : const AssetImage("assets/profile.png") as ImageProvider,
                    ),
                    title: Text(
                      opt["employeeName"],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    subtitle: Text(
                      "${opt['employeeId']} • ${opt['position'] ?? ''}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    onTap: () => onSelected(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompose() {
    if (!isReplyOrForward &&
        selectedMenu == 2 &&
        attachments.isEmpty &&
        _bodyCtrl.text.isEmpty &&
        _subCtrl.text.isEmpty &&
        _toCtrl.text.isEmpty) {
      _toCtrl.clear();
      _subCtrl.clear();
      _bodyCtrl.clear();
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildRecipientAutocomplete(),
          const SizedBox(height: 12),
          _composeField(_subCtrl, "Subject"),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _bodyCtrl,
              expands: true,
              maxLines: null,
              decoration: _purpleBox("Type your message..."),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: pickFiles,
            icon: const Icon(Icons.attach_file),
            label: Text("Attachments (${attachments.length})"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: sending ? null : sendMail,
                icon: const Icon(Icons.send),
                label: const Text("Send"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: () {
                  isReplyOrForward = false;
                  setState(() => selectedMenu = 0);
                },
                icon: const Icon(Icons.cancel),
                label: const Text("Cancel"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAttachmentPreview(),
        ],
      ),
    );
  }

  Widget _composeField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: _purpleBox(hint),
    );
  }

  InputDecoration _purpleBox(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.deepPurple.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    if (attachments.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Attachments:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          ...attachments.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            final isImage = ["png", "jpg", "jpeg"].contains(file.extension?.toLowerCase());
            return Card(
              child: ListTile(
                leading: isImage && file.bytes != null
                    ? Image.memory(
                        file.bytes!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.file_present, color: Colors.deepPurple),
                title: Text(file.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => attachments.removeAt(index)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildViewMail() {
    if (selectedMail == null) return const Center(child: CircularProgressIndicator());
    final mail = selectedMail!;
    final bool isTrash = selectedMenu == 4;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _prepareReplyMail(mail),
                icon: const Icon(Icons.reply),
                label: const Text("Reply"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _prepareForwardMail(mail),
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
                  onPressed: () => _moveToTrash(mail["_id"]),
                  icon: const Icon(Icons.delete),
                  label: const Text("Trash"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (isTrash) ...[
                ElevatedButton.icon(
                  onPressed: () => _restoreMail(mail["_id"]),
                  icon: const Icon(Icons.restore),
                  label: const Text("Restore"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _deleteForever(mail["_id"]),
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
            "From: ${mail['from']}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            "To: ${mail['to']}",
            style: const TextStyle(color: Colors.black54),
          ),
          const Divider(height: 30),
          Text(
            mail["subject"] ?? "",
            style: const TextStyle(
              color: Colors.deepPurple,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                mail["body"] ?? "",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (mail["attachments"] != null && mail["attachments"].isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Attachments:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ...mail["attachments"].map<Widget>((file) {
                  return InkWell(
                    onTap: () => launchUrl(Uri.parse("http://localhost:5000$file")),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.attach_file, color: Colors.deepPurple),
                        title: Text(file.toString().split("/").last),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mail Portal"), backgroundColor: Colors.deepPurple),
      body: Row(
        children: [
          Container(
            width: 230,
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _menuButton(Icons.inbox, "Inbox", 0),
                _menuButton(Icons.send, "Sent", 1),
                _menuButton(Icons.delete, "Trash", 4),
                _menuButton(Icons.edit, "Compose", 2),
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
