//offer_letter_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

import 'sidebar.dart';
import 'offer_letter_pdf_service.dart';
import 'pdf_content_model.dart';
import 'edit_pdf_content_page.dart';
import 'view_offer_letter_page.dart';

class OfferLetterPage extends StatefulWidget {
  const OfferLetterPage({super.key});

  @override
  State<OfferLetterPage> createState() => _OfferLetterPageState();
}

class _OfferLetterPageState extends State<OfferLetterPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _positionController = TextEditingController();
  final _stipendController = TextEditingController();
  final _dojController = TextEditingController();
  final _ctcController = TextEditingController();
  final _signdateController = TextEditingController();
  final _salaryFromController = TextEditingController();
  final _emailController = TextEditingController();

  PdfContentModel _pdfContent = PdfContentModel();

  bool _isLoading = false;
  bool _isGenerated = false; // 🔒 MASTER LOCK

  // ---------------- INPUT FORMATTERS ----------------
  final _alphaSpaceFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'));

  final _numbersOnlyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  final _dateFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'));

  final _alphaNumericFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'));

  final _ctcFormatter =
      FilteringTextInputFormatter.allow(
          RegExp(r'[a-zA-Z0-9₹.,\- /()]'));
  // --------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchNextEmployeeId();
  }

  Future<void> _fetchNextEmployeeId() async {
    final url = Uri.parse("https://company-04bz.onrender.com/api/offerletter/next-id");
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _employeeIdController.text = data["nextId"];
      }
    } catch (_) {}
  }

  Future<void> _generateAndShowPdf() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final pdfService = OfferLetterPdfService();
      final pdfBytes = await pdfService.generateOfferLetter(
        fullName: _fullNameController.text,
        employeeId: _employeeIdController.text,
        position: _positionController.text,
        stipend: _stipendController.text,
        doj: _dojController.text,
        ctc: _ctcController.text,
        signdate: _signdateController.text,
        salaryFrom: _salaryFromController.text,
        content: _pdfContent,
      );

      final response = await http.post(
        Uri.parse("https://company-04bz.onrender.com/api/offerletter"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "fullName": _fullNameController.text,
          "position": _positionController.text,
          "stipend": _stipendController.text,
          "doj": _dojController.text,
          "ctc": _ctcController.text,
          "signdate": _signdateController.text,
          "salaryFrom": _salaryFromController.text,
          "email": _emailController.text,
          "pdfFile": base64Encode(pdfBytes),
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw "Failed to save offer letter";
      }

      // 🔒 LOCK ALL FIELDS AFTER GENERATE
      setState(() => _isGenerated = true);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Offer Letter Preview'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            child: PdfPreview(
              build: (format) => pdfBytes,
              canChangeOrientation: false,
              canDebug: false,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text('View Offer Letters'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ViewOfferLetterPage(),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editTemplate() async {
    final updated = await Navigator.push<PdfContentModel>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPdfContentPage(initialContent: _pdfContent),
      ),
    );

    if (updated != null) {
      setState(() => _pdfContent = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isGenerated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Editing is locked after generating the offer letter'),
            ),
          );
          return false;
        }
        return true;
      },
      child: Sidebar(
        title: 'Generate Offer Letter',
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Offer Letter Details',
                                style: Theme.of(context).textTheme.headlineSmall),
                            TextButton.icon(
                              onPressed: _isGenerated ? null : _editTemplate,
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Edit Template'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _fullNameController,
                          enabled: !_isGenerated,
                          inputFormatters: [_alphaSpaceFormatter],
                          decoration: const InputDecoration(labelText: 'Full Name'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),

                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _employeeIdController,
                          enabled: false,
                          decoration: const InputDecoration(labelText: 'Employee ID'),
                        ),

                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _positionController,
                          enabled: !_isGenerated,
                          inputFormatters: [_alphaSpaceFormatter],
                          decoration: const InputDecoration(labelText: 'Position'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),

                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isGenerated,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _stipendController,
                          enabled: !_isGenerated,
                          inputFormatters: [_numbersOnlyFormatter],
                          decoration: const InputDecoration(labelText: 'Stipend (INR)'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),

                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _ctcController,
                          enabled: !_isGenerated,
                          inputFormatters: [_ctcFormatter],
                          decoration: const InputDecoration(labelText: 'CTC (e.g., 3 CTC - 5 CTC)'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),

                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _dojController,
                          enabled: !_isGenerated,
                          inputFormatters: [_dateFormatter],
                          decoration:
                              const InputDecoration(labelText: 'Date of Joining (DD/MM/YYYY)'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),

                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _signdateController,
                          enabled: !_isGenerated,
                          inputFormatters: [_dateFormatter],
                          decoration:
                              const InputDecoration(labelText: 'Signed Date (DD/MM/YYYY)'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),

                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _salaryFromController,
                          enabled: !_isGenerated,
                          inputFormatters: [_alphaNumericFormatter],
                          decoration:
                              const InputDecoration(labelText: 'Salary From (e.g., March 2026)'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),

                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed:
                              (_isLoading || _isGenerated) ? null : _generateAndShowPdf,
                          icon: _isLoading
                              ? const CircularProgressIndicator()
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(
                            _isGenerated
                                ? 'Offer Letter Generated'
                                : _isLoading
                                    ? 'Generating...'
                                    : 'Generate & Preview',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}