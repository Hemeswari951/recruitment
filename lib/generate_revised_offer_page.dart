// generate_revised_offer_page.dart
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'sidebar.dart';
import 'revised_offer_letter_pdf_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'revised_pdf_content_model.dart';
import 'edit_revised_pdf_content_page.dart';
import 'view_revised_offer_page.dart'; // re-add navigation target for preview dialog
import 'package:flutter/services.dart'; // input formatters

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
  final _fromPositionController = TextEditingController();
  final _positionController = TextEditingController();
  final _stipendController = TextEditingController();
  final _dojController = TextEditingController();
  final _ctcController = TextEditingController();
  final _signdateController = TextEditingController();

  // salaryFrom controller
  final _salaryFromController = TextEditingController();

  var _pdfContent = RevisedPdfContentModel();
  bool _isLoading = false;

  // when true the form fields become non-editable after generate
  bool _fieldsReadOnly = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _employeeIdController.dispose();
    _fromPositionController.dispose();
    _positionController.dispose();
    _stipendController.dispose();
    _dojController.dispose();
    _ctcController.dispose();
    _signdateController.dispose();
    _salaryFromController.dispose();
    super.dispose();
  }

  // basic date validator for DD/MM/YYYY
  bool _isValidDateDDMMYYYY(String v) {
    final reg = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!reg.hasMatch(v)) return false;
    try {
      final parts = v.split('/');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final d = DateTime(year, month, day);
      return d.day == day && d.month == month && d.year == year;
    } catch (_) {
      return false;
    }
  }

  // accepts either DD/MM/YYYY OR Month YYYY (e.g., February 2026)
  bool _isValidSalaryFrom(String v) {
    if (v.trim().isEmpty) return false;
    final monthYearReg = RegExp(
        r'^(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}$',
        caseSensitive: false);
    if (_isValidDateDDMMYYYY(v)) return true;
    if (monthYearReg.hasMatch(v.trim())) return true;
    return false;
  }

  Future<void> _generateAndShowPdf() async {
    // validate form
    if (!_formKey.currentState!.validate()) {
      // show a clear warning if validation fails
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // immediately make fields non-editable when generation starts
    setState(() {
      _fieldsReadOnly = true;
      _isLoading = true;
    });

    try {
      final pdfService = RevisedOfferLetterPdfService();
      final pdfBytes = await pdfService.generateRevisedOfferLetter(
        fullName: _fullNameController.text,
        employeeId: _employeeIdController.text,
        fromposition: _fromPositionController.text,
        position: _positionController.text,
        stipend: _stipendController.text,
        doj: _dojController.text,
        ctc: _ctcController.text,
        signdate: _signdateController.text,
        salaryFrom: _salaryFromController.text,
        content: _pdfContent,
      );

      final pdfBase64 = base64Encode(pdfBytes);
      final url = Uri.parse("https://company-04bz.onrender.com/api/revisedofferletter");
      final body = {
        "fullName": _fullNameController.text,
        "employeeId": _employeeIdController.text,
        "fromposition": _fromPositionController.text,
        "position": _positionController.text,
        "stipend": _stipendController.text,
        "doj": _dojController.text,
        "ctc": _ctcController.text,
        "signdate": _signdateController.text,
        "pdfFile": pdfBase64,
        "salaryFrom": _salaryFromController.text,
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
        // Allow re-editing if backend failed
        setState(() {
          _fieldsReadOnly = false;
        });
        return;
      }

      // Capture parent context so we can close dialog then navigate
      final parentContext = context;

      await showDialog(
        context: parentContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Revised Offer Letter Preview'),
          contentPadding: const EdgeInsets.all(16),
          insetPadding: const EdgeInsets.all(20),
          content: SizedBox(
            width: MediaQuery.of(parentContext).size.width * 0.8,
            height: MediaQuery.of(parentContext).size.height * 0.8,
            child: PdfPreview(
              build: (format) => pdfBytes,
              canChangeOrientation: false,
              canDebug: false,
              useActions: true,
            ),
          ),
          actions: [
            // View button placed to the left of Close
            TextButton.icon(
              onPressed: () {
                // close the dialog then navigate to the view page
                Navigator.of(dialogContext).pop();
                // ensure dialog closed before pushing
                Future.microtask(() {
                  Navigator.of(parentContext).push(
                    MaterialPageRoute(
                      builder: (_) => const ViewRevisedOfferPage(),
                    ),
                  );
                });
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View Offers'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );

      // NOTE: _fieldsReadOnly remains true as requested (fields stay non-editable after successful save)
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to generate PDF: $e")));
        // allow re-editing on exception
        setState(() {
          _fieldsReadOnly = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                          // *** CHANGED: disable Edit Template button when fields are read-only
                          TextButton.icon(
                            onPressed:
                                _fieldsReadOnly ? null : _editTemplate, // disabled when true
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
                        enabled: !_fieldsReadOnly,
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _employeeIdController,
                        decoration: const InputDecoration(
                          labelText: 'Employee ID',
                        ),
                        enabled: !_fieldsReadOnly,
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter an ID' : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _fromPositionController,
                        decoration: const InputDecoration(
                          labelText: 'Previous Position',
                        ),
                        enabled: !_fieldsReadOnly,
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
                        enabled: !_fieldsReadOnly,
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a position' : null,
                      ),
                      const SizedBox(height: 10),

                      // Salary numeric-only field
                      TextFormField(
                        controller: _stipendController,
                        decoration: const InputDecoration(
                          labelText: 'Salary (INR)',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        enabled: !_fieldsReadOnly,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a salary';
                          }
                          final numReg = RegExp(r'^\d+$');
                          if (!numReg.hasMatch(v.trim())) {
                            return 'Salary must be numeric';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _ctcController,
                        decoration: const InputDecoration(
                          labelText: 'CTC (e.g., 3 CTC - 5 CTC)',
                        ),
                        enabled: !_fieldsReadOnly,
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a CTC' : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _dojController,
                        decoration: const InputDecoration(
                          labelText: 'Date of Joining (DD/MM/YYYY)',
                        ),
                        keyboardType: TextInputType.datetime,
                        enabled: !_fieldsReadOnly,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a date of joining';
                          }
                          if (!_isValidDateDDMMYYYY(v.trim())) {
                            return 'Date must be in DD/MM/YYYY';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _signdateController,
                        decoration: const InputDecoration(
                          labelText: 'Signed Date (DD/MM/YYYY)',
                        ),
                        keyboardType: TextInputType.datetime,
                        enabled: !_fieldsReadOnly,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a signed date';
                          }
                          if (!_isValidDateDDMMYYYY(v.trim())) {
                            return 'Date must be in DD/MM/YYYY';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 10),

                      // SalaryFrom
                      TextFormField(
                        controller: _salaryFromController,
                        decoration: const InputDecoration(
                          labelText:
                              'Salary Effective From (e.g., February 2026)',
                          hintText: 'Month Year or DD/MM/YYYY',
                        ),
                        keyboardType: TextInputType.text,
                        enabled: !_fieldsReadOnly,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter Salary Effective From';
                          }
                          if (!_isValidSalaryFrom(v.trim())) {
                            return 'Enter valid date (DD/MM/YYYY) or Month YYYY';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        // *** CHANGED: button disabled when generating or when fields set to read-only
                        child: ElevatedButton.icon(
                          onPressed:
                              (_isLoading || _fieldsReadOnly) ? null : _generateAndShowPdf,
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
                            _isLoading
                                ? 'Generating...'
                                : (_fieldsReadOnly ? 'Generated' : 'Generate & Preview'),
                          ),
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