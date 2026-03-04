// lib/drive_bulk_offerletter_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for formatters
// import 'package:printing/printing.dart';
import 'sidebar.dart';
import 'offer_letter_pdf_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pdf_content_model.dart';
import 'edit_pdf_content_page.dart';
import 'view_offer_letter_page.dart';

class DriveOfferLetterPage extends StatefulWidget {
  final List<dynamic>? students;
  final String? position; // ✅ optional position override

  const DriveOfferLetterPage({super.key, this.students, this.position});

  @override
  State<DriveOfferLetterPage> createState() => _DriveOfferLetterPageState();
}

class _DriveOfferLetterPageState extends State<DriveOfferLetterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _positionController = TextEditingController();
  final _stipendController = TextEditingController();
  final _dojController = TextEditingController();
  final _ctcController = TextEditingController();
  final _signdateController = TextEditingController();
  final _salaryMonthController = TextEditingController();

  // NEW: email controller (optional)
  final _emailController = TextEditingController();

  // State to hold the editable PDF content
  var _pdfContent = PdfContentModel();

  // State for loading indicator
  bool _isLoading = false;
  bool _isGenerated = false; // 🔒 NEW: Add this line
  int _successCount = 0;
  int _failedCount = 0;

  // ---------------- INPUT FORMATTERS ----------------
  final _alphaSpaceFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z ]'),
  );
  final _numbersOnlyFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9]'),
  );
  final _dateFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'));
  // final _alphaNumericFormatter = FilteringTextInputFormatter.allow(
  //   RegExp(r'[a-zA-Z0-9 ]'),
  // );
  final _alphaNumericSpaceFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z0-9 ]'),
  );
  final _ctcFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z0-9₹.,\- /()]'),
  );
  // --------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchNextEmployeeId();

    // Prefill position if passed from parent
    if (widget.position != null && widget.position!.isNotEmpty) {
      _positionController.text = widget.position!;
    }
  }

  Future<void> _showBulkResultDialog({
    required int selected,
    required int generated,
    required int failed,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Bulk Offer Letters Generated"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Selected Students : $selected"),
            const SizedBox(height: 6),
            Text(
              "Generated Successfully : $generated",
              style: const TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 6),
            if (failed > 0)
              Text(
                "Failed : $failed",
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text("View Offer Letters"),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewOfferLetterPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _generateBulkOfferLetters() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all mandatory fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (widget.students == null || widget.students!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No students found")));
      return;
    }

    setState(() {
      _isLoading = true;
      _successCount = 0;
      _failedCount = 0;
    });

    final pdfService = OfferLetterPdfService();

    try {
      for (final student in widget.students!) {
        try {
          // Prefill per-student fields (name & email from student details page)
          _fullNameController.text =
              (student['name'] ?? student['fullName'] ?? '').toString();
          _emailController.text = (student['email'] ?? student['mail'] ?? '')
              .toString();

          // If parent didn't provide a position, prefer student position if available
          if ((widget.position == null || widget.position!.isEmpty)) {
            final studentPos = (student['position'] ?? student['role'] ?? '')
                .toString();
            if (studentPos.isNotEmpty) _positionController.text = studentPos;
          }

          await _fetchNextEmployeeId();

          // Generate PDF (do not pass email to PDF generator unless you want email printed)
          final pdfBytes = await pdfService.generateOfferLetter(
            fullName: _fullNameController.text,
            employeeId: _employeeIdController.text,
            position: _positionController.text,
            stipend: _stipendController.text,
            doj: _dojController.text,
            ctc: _ctcController.text,
            signdate: _signdateController.text,
            salaryFrom: _salaryMonthController.text,
            content: _pdfContent,
          );

          final pdfBase64 = base64Encode(pdfBytes);

          final res = await http.post(
            Uri.parse("https://company-04bz.onrender.com/api/offerletter"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "fullName": _fullNameController.text,
              "position": _positionController.text,
              "stipend": _stipendController.text,
              "doj": _dojController.text,
              "ctc": _ctcController.text,
              "signdate": _signdateController.text,
              // include both key names for compatibility
              "salaryMonth": _salaryMonthController.text,
              "salaryFrom": _salaryMonthController.text,
              "email": _emailController.text, // <-- email included
              "pdfFile": pdfBase64,
            }),
          );

          if (res.statusCode == 200 || res.statusCode == 201) {
            _successCount++;
          } else {
            _failedCount++;
          }
        } catch (e) {
          debugPrint("Bulk generation error for student: $e");
          _failedCount++;
        }
      }

      if (!mounted) return;

      if (_successCount > 0) {
        setState(() => _isGenerated = true);
      }

      await _showBulkResultDialog(
        selected: widget.students!.length,
        generated: _successCount,
        failed: _failedCount,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FETCH NEXT AUTO-GENERATED EMPLOYEE ID FROM BACKEND
  // ---------------------------------------------------------------------------
  Future<void> _fetchNextEmployeeId() async {
    final url = Uri.parse("https://company-04bz.onrender.com/api/offerletter/next-id");

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
    _salaryMonthController.dispose();
    _emailController.dispose(); // dispose new controller
    super.dispose();
  }

  // Future<void> _generateAndShowPdf() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() {
  //       _isLoading = true;
  //     });

  //     try {
  //       final pdfService = OfferLetterPdfService();
  //       final pdfBytes = await pdfService.generateOfferLetter(
  //         fullName: _fullNameController.text,
  //         employeeId: _employeeIdController.text,
  //         position: _positionController.text,
  //         stipend: _stipendController.text,
  //         doj: _dojController.text,
  //         ctc: _ctcController.text,
  //         signdate: _signdateController.text,
  //         salaryFrom: _salaryMonthController.text,
  //         content: _pdfContent,
  //       );

  //       final pdfBase64 = base64Encode(pdfBytes);
  //       final url = Uri.parse("https://company-04bz.onrender.com/api/offerletter");
  //       final body = {
  //         "fullName": _fullNameController.text,
  //         //"employeeId": _employeeIdController.text,
  //         "position": _positionController.text,
  //         "stipend": _stipendController.text,
  //         "doj": _dojController.text,
  //         "ctc": _ctcController.text,
  //         "signdate": _signdateController.text,
  //         "salaryFrom": _salaryMonthController.text,
  //         "email": _emailController.text, // <-- include email for single save
  //         "pdfFile": pdfBase64,
  //       };

  //       final response = await http.post(
  //         url,
  //         headers: {"Content-Type": "application/json"},
  //         body: jsonEncode(body),
  //       );

  //       if (!mounted) return;

  //       if (response.statusCode != 200 && response.statusCode != 201) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text("Failed to save offer letter")),
  //         );
  //         return;
  //       }

  //       await showDialog(
  //         context: context,
  //         builder: (context) => AlertDialog(
  //           title: const Text('Offer Letter Preview'),
  //           contentPadding: const EdgeInsets.all(16),
  //           insetPadding: const EdgeInsets.all(20),
  //           content: SizedBox(
  //             width: MediaQuery.of(context).size.width * 0.8,
  //             height: MediaQuery.of(context).size.height * 0.8,
  //             child: PdfPreview(
  //               build: (format) => pdfBytes,
  //               canChangeOrientation: false,
  //               canDebug: false,
  //               useActions: true,
  //             ),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(context).pop(),
  //               child: const Text('Close'),
  //             ),
  //           ],
  //         ),
  //       );
  //     } catch (e) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(
  //           context,
  //         ).showSnackBar(SnackBar(content: Text("Failed to generate PDF: $e")));
  //       }
  //     } finally {
  //       if (mounted) {
  //         setState(() {
  //           _isLoading = false;
  //         });
  //       }
  //     }
  //   }
  // }

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
                            onPressed: _isGenerated
                                ? null
                                : _editTemplate, // Disable if generated
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Edit Template'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _fullNameController,
                        enabled: false,
                        inputFormatters: [_alphaSpaceFormatter], // Add this
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                        ),
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
                      // 2. Form Fields (Repeat this for all TextFormFields)
                      TextFormField(
                        controller: _positionController,
                        enabled:
                            !_isGenerated, // 🔒 Add this line to ALL TextFormFields
                        inputFormatters: [_alphaSpaceFormatter],
                        decoration: const InputDecoration(
                          labelText: 'Position',
                        ),
                      ),
                      const SizedBox(height: 10),
                      // NEW: Email input (optional)
                      TextFormField(
                        controller: _emailController,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return null; // optional
                          }
                          final emailReg = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailReg.hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _stipendController,
                        enabled: !_isGenerated,
                        inputFormatters: [_numbersOnlyFormatter], // Add this
                        decoration: const InputDecoration(
                          labelText: 'Stipend (INR)',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a stipend' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _ctcController,
                        enabled: !_isGenerated,
                        inputFormatters: [_ctcFormatter], // Add this
                        decoration: const InputDecoration(labelText: 'CTC (e.g., 3 CTC - 5 CTC)'),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a CTC' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _dojController,
                        enabled: !_isGenerated,
                        inputFormatters: [_dateFormatter], // Add this
                        decoration: const InputDecoration(
                          labelText: 'Date of Joining (DD/MM/YYYY)',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a date' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _signdateController,
                        enabled: !_isGenerated,
                        inputFormatters: [_dateFormatter], // Add this
                        decoration: const InputDecoration(
                          labelText: 'Signed Date (DD/MM/YYYY)',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a date' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _salaryMonthController,
                        enabled: !_isGenerated,
                        inputFormatters: [_alphaNumericSpaceFormatter],
                        decoration: const InputDecoration(
                          labelText: 'Salary Month (e.g., March 2026)',
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter salary month'
                            : null,
                      ),

                      // 👇 VERY IMPORTANT: add bottom spacing
                      const SizedBox(height: 40),

                      ElevatedButton.icon(
                        onPressed: (_isLoading || _isGenerated)
                            ? null
                            : _generateBulkOfferLetters,
                        icon: _isLoading
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _isGenerated
                              ? 'Offer Letters Generated'
                              : _isLoading
                              ? 'Generating...'
                              : 'Generate Bulk Offer Letters',
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