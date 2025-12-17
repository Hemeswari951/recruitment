import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'sidebar.dart';
import 'revised_offer_letter_pdf_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'revised_pdf_content_model.dart';
import 'edit_revised_pdf_content_page.dart';

class GenerateRevisedOfferPage extends StatefulWidget {
  const GenerateRevisedOfferPage({super.key});

  @override
  State<GenerateRevisedOfferPage> createState() =>
      _GenerateRevisedOfferPageState();
}

class _GenerateRevisedOfferPageState extends State<GenerateRevisedOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _fromPositionController = TextEditingController(); // New controller
  final _positionController = TextEditingController();
  final _stipendController = TextEditingController();
  final _dojController = TextEditingController();
  final _ctcController = TextEditingController();
  final _signdateController = TextEditingController();

  var _pdfContent = RevisedPdfContentModel();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _employeeIdController.dispose();
    _fromPositionController.dispose(); // Dispose new controller
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
        final pdfService = RevisedOfferLetterPdfService();
        final pdfBytes = await pdfService.generateRevisedOfferLetter(
          fullName: _fullNameController.text,
          employeeId: _employeeIdController.text,
          fromposition: _fromPositionController.text, // Pass new field
          position: _positionController.text,
          stipend: _stipendController.text,
          doj: _dojController.text,
          ctc: _ctcController.text,
          signdate: _signdateController.text,
          content: _pdfContent,
        );

        final pdfBase64 = base64Encode(pdfBytes);
        final url = Uri.parse("http://localhost:5000/api/revisedofferletter");
        final body = {
          "fullName": _fullNameController.text,
          "employeeId": _employeeIdController.text,
          "fromposition": _fromPositionController.text, // Include in API body
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
            const SnackBar(content: Text("Failed to save revised offer")),
          );
          return;
        }

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Revised Offer Letter Preview'),
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
    final newContent = await Navigator.of(context).push<RevisedPdfContentModel>(
      MaterialPageRoute(
        builder: (context) =>
            EditRevisedPdfContentPage(initialContent: _pdfContent),
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
      title: 'Generate Revised Offer Letter',
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
                            'Revised Offer Details',
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
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _employeeIdController,
                        decoration: const InputDecoration(
                          labelText: 'Employee ID',
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter an ID' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _fromPositionController,
                        decoration: const InputDecoration(
                          labelText: 'Previous Position', // New input field
                        ),
                        validator: (v) => v!.isEmpty
                            ? 'Please enter previous position'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _positionController,
                        decoration: const InputDecoration(
                          labelText: 'Position',
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a position' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _stipendController,
                        decoration: const InputDecoration(
                          labelText: 'Salary (INR)',
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a salary' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _ctcController,
                        decoration: const InputDecoration(
                          labelText: 'CTC (e.g., 3 CTC - 5 CTC)',
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a CTC' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _dojController,
                        decoration: const InputDecoration(
                          labelText: 'Date of Joining (DD/MM/YYYY)',
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a date' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _signdateController,
                        decoration: const InputDecoration(
                          labelText: 'Signed Date (DD/MM/YYYY)',
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a date' : null,
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