import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'sidebar.dart';
import 'offer_letter_pdf_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pdf_content_model.dart';
import 'edit_pdf_content_page.dart';

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

  // State to hold the editable PDF content
  var _pdfContent = PdfContentModel();

  // State for loading indicator
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchNextEmployeeId();
    // The page will now always start with the default template.
  }

  // ---------------------------------------------------------------------------
  // FETCH NEXT AUTO-GENERATED EMPLOYEE ID FROM BACKEND
  // ---------------------------------------------------------------------------
  Future<void> _fetchNextEmployeeId() async {
    final url = Uri.parse("http://localhost:5000/api/offerletter/next-id");

    try {
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          _employeeIdController.text = data["nextId"]; // ZeAI153
        });
      } else {
        debugPrint("Failed to fetch next employee ID");
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _employeeIdController.dispose();
    _positionController.dispose();
    _stipendController.dispose();
    _dojController.dispose();
    _ctcController.dispose();
    _signdateController.dispose();
    super.dispose();
  }

  Future<void> _generateAndShowPdf() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

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
          content: _pdfContent,
        );

        final pdfBase64 = base64Encode(pdfBytes);
        final url = Uri.parse("http://localhost:5000/api/offerletter");
        final body = {
          "fullName": _fullNameController.text,
         // "employeeId": _employeeIdController.text,
          "position": _positionController.text,
          "stipend": _stipendController.text,
          "doj": _dojController.text,
          "ctc": _ctcController.text,
          "signdate": _signdateController.text,
          "pdfFile": pdfBase64,
        };

        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );

        if (!mounted) return;

        if (response.statusCode != 200 && response.statusCode != 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to save offer letter")),
          );
          return;
        }

        setState(() {
          _pdfContent = PdfContentModel();
        });

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Offer Letter Preview'),
            contentPadding: const EdgeInsets.all(16),
            insetPadding: const EdgeInsets.all(20),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
              child: PdfPreview(
                build: (format) => pdfBytes,
                canChangeOrientation: false,
                canDebug: false,
                useActions: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Failed to generate PDF: $e")));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _editTemplate() async {
    final newContent = await Navigator.of(context).push<PdfContentModel>(
      MaterialPageRoute(
        builder: (context) => EditPdfContentPage(initialContent: _pdfContent),
      ),
    );

    if (newContent != null) {
      setState(() {
        _pdfContent = newContent;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Template updated!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Generate Offer Letter',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Offer Letter Details',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          TextButton.icon(
                            onPressed: _editTemplate,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Edit Template'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _employeeIdController,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Employee ID',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _positionController,
                        decoration: const InputDecoration(
                          labelText: 'Position',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a position' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _stipendController,
                        decoration: const InputDecoration(
                          labelText: 'Stipend (INR)',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a stipend' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _ctcController,
                        decoration: const InputDecoration(
                          labelText: 'CTC (e.g., 3 CTC - 5 CTC)',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a CTC' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _dojController,
                        decoration: const InputDecoration(
                          labelText: 'Date of Joining (DD/MM/YYYY)',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a date' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _signdateController,
                        decoration: const InputDecoration(
                          labelText: 'Signed Date (DD/MM/YYYY)',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a date' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateAndShowPdf,
                        icon: _isLoading
                            ? Container(
                                width: 24,
                                height: 24,
                                padding: const EdgeInsets.all(2.0),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _isLoading ? 'Generating...' : 'Generate & Preview',
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
    );
  }
}