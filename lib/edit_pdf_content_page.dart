// lib/edit_pdf_content_page.dart
import 'package:flutter/material.dart';
import 'pdf_content_model.dart';

class EditPdfContentPage extends StatefulWidget {
  final PdfContentModel initialContent;

  const EditPdfContentPage({super.key, required this.initialContent});

  @override
  State<EditPdfContentPage> createState() => _EditPdfContentPageState();
}

class _EditPdfContentPageState extends State<EditPdfContentPage> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'dearName': TextEditingController(text: widget.initialContent.dearName),
      'intro': TextEditingController(text: widget.initialContent.intro),
      'positionBody': TextEditingController(
        text: widget.initialContent.positionBody,
      ),
      'compensationBody': TextEditingController(
        text: widget.initialContent.compensationBody,
      ),
      'confidentialityBody': TextEditingController(
        text: widget.initialContent.confidentialityBody,
      ),
      'workingHoursBody': TextEditingController(
        text: widget.initialContent.workingHoursBody,
      ),
      'leaveEligibilityBody': TextEditingController(
        text: widget.initialContent.leaveEligibilityBody,
      ),
      'leaveAccrual': TextEditingController(
        text: widget.initialContent.leaveAccrual,
      ),
      'publicHolidays': TextEditingController(
        text: widget.initialContent.publicHolidays,
      ),
      'specialLeave': TextEditingController(
        text: widget.initialContent.specialLeave,
      ),
      'addOnsForMen': TextEditingController(
        text: widget.initialContent.addOnsForMen,
      ),
      'addOnsForWomen': TextEditingController(
        text: widget.initialContent.addOnsForWomen,
      ),
      'leaveRequests': TextEditingController(
        text: widget.initialContent.leaveRequests,
      ),
      'leaveResponsibly': TextEditingController(
        text: widget.initialContent.leaveResponsibly,
      ),
      'leaveNote': TextEditingController(text: widget.initialContent.leaveNote),
      'noticePeriodBody': TextEditingController(
        text: widget.initialContent.noticePeriodBody,
      ),
      'professionalConductBody1': TextEditingController(
        text: widget.initialContent.professionalConductBody1,
      ),
      'professionalConductBody2': TextEditingController(
        text: widget.initialContent.professionalConductBody2,
      ),
      'terminationPoint1': TextEditingController(
        text: widget.initialContent.terminationPoint1,
      ),
      'terminationPoint2': TextEditingController(
        text: widget.initialContent.terminationPoint2,
      ),
      'terminationPoint3': TextEditingController(
        text: widget.initialContent.terminationPoint3,
      ),
      'terminationPoint4': TextEditingController(
        text: widget.initialContent.terminationPoint4,
      ),
      'preEmploymentScreeningBody': TextEditingController(
        text: widget.initialContent.preEmploymentScreeningBody,
      ),
      'disputeBody': TextEditingController(
        text: widget.initialContent.disputeBody,
      ),
      'declarationBody': TextEditingController(
        text: widget.initialContent.declarationBody,
      ),
      'acceptanceConfirmation': TextEditingController(
        text: widget.initialContent.acceptanceConfirmation,
      ),
    };
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _saveContent() async {
    final newContent = PdfContentModel(
      dearName: _controllers['dearName']!.text,
      intro: _controllers['intro']!.text,
      positionBody: _controllers['positionBody']!.text,
      compensationBody: _controllers['compensationBody']!.text,
      confidentialityBody: _controllers['confidentialityBody']!.text,
      workingHoursBody: _controllers['workingHoursBody']!.text,
      leaveEligibilityBody: _controllers['leaveEligibilityBody']!.text,
      leaveAccrual: _controllers['leaveAccrual']!.text,
      publicHolidays: _controllers['publicHolidays']!.text,
      specialLeave: _controllers['specialLeave']!.text,
      addOnsForMen: _controllers['addOnsForMen']!.text,
      addOnsForWomen: _controllers['addOnsForWomen']!.text,
      leaveRequests: _controllers['leaveRequests']!.text,
      leaveResponsibly: _controllers['leaveResponsibly']!.text,
      leaveNote: _controllers['leaveNote']!.text,
      noticePeriodBody: _controllers['noticePeriodBody']!.text,
      professionalConductBody1: _controllers['professionalConductBody1']!.text,
      professionalConductBody2: _controllers['professionalConductBody2']!.text,
      terminationPoint1: _controllers['terminationPoint1']!.text,
      terminationPoint2: _controllers['terminationPoint2']!.text,
      terminationPoint3: _controllers['terminationPoint3']!.text,
      terminationPoint4: _controllers['terminationPoint4']!.text,
      preEmploymentScreeningBody:
          _controllers['preEmploymentScreeningBody']!.text,
      disputeBody: _controllers['disputeBody']!.text,
      declarationBody: _controllers['declarationBody']!.text,
      acceptanceConfirmation: _controllers['acceptanceConfirmation']!.text,
    );

    if (!mounted) return;
    // Simply return the updated content to the previous page.
    Navigator.of(context).pop(newContent);
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Template?'),
        content: const Text(
          'Are you sure you want to reset all fields to their default content? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final defaultContent = PdfContentModel();
      final defaultJson = defaultContent.toJson();

      setState(() {
        _controllers.forEach((key, controller) {
          controller.text = defaultJson[key] ?? '';
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Offer Letter Content'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveContent,
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Page 1'),
              _buildEditorField('Greeting', _controllers['dearName']!),
              _buildEditorField('Introduction', _controllers['intro']!),
              _buildEditorField(
                'Position Details',
                _controllers['positionBody']!,
              ),
              _buildEditorField(
                'Compensation Details',
                _controllers['compensationBody']!,
              ),

              // Helper hint for compensation placeholders
              Padding(
                padding: const EdgeInsets.only(top: 6.0, bottom: 12.0),
                child: Text(
                  'Placeholders you can use in Compensation: {stipend}, {ctc}, {salaryFrom}\nExample: "You will receive your salary payment from {salaryFrom}."',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),

              _buildEditorField(
                'Confidentiality',
                _controllers['confidentialityBody']!,
              ),
              _buildSectionHeader('Page 2'),
              _buildEditorField(
                'Working Hours',
                _controllers['workingHoursBody']!,
              ),
              _buildEditorField(
                'Leave Eligibility Intro',
                _controllers['leaveEligibilityBody']!,
              ),
              _buildEditorField('Leave Accrual', _controllers['leaveAccrual']!),
              _buildEditorField(
                'Public Holidays',
                _controllers['publicHolidays']!,
              ),
              _buildEditorField('Special Leave', _controllers['specialLeave']!),
              _buildEditorField(
                'Add Ons For Men',
                _controllers['addOnsForMen']!,
              ),
              _buildEditorField(
                'Add Ons For Women',
                _controllers['addOnsForWomen']!,
              ),
              _buildEditorField(
                'Leave Requests',
                _controllers['leaveRequests']!,
              ),
              _buildEditorField(
                'Leave Responsibility',
                _controllers['leaveResponsibly']!,
              ),
              _buildEditorField('Leave Note', _controllers['leaveNote']!),
              _buildEditorField(
                'Notice Period',
                _controllers['noticePeriodBody']!,
              ),
              _buildSectionHeader('Page 3'),
              _buildEditorField(
                'Professional Conduct (Part 1)',
                _controllers['professionalConductBody1']!,
              ),
              _buildEditorField(
                'Professional Conduct (Part 2)',
                _controllers['professionalConductBody2']!,
              ),
              _buildEditorField(
                'Termination - Point 1',
                _controllers['terminationPoint1']!,
              ),
              _buildEditorField(
                'Termination - Point 2',
                _controllers['terminationPoint2']!,
              ),
              _buildEditorField(
                'Termination - Point 3',
                _controllers['terminationPoint3']!,
              ),
              _buildEditorField(
                'Termination - Point 4',
                _controllers['terminationPoint4']!,
              ),
              _buildEditorField(
                'Pre-Employment Screening',
                _controllers['preEmploymentScreeningBody']!,
              ),
              _buildSectionHeader('Page 4'),
              _buildEditorField('Dispute', _controllers['disputeBody']!),
              _buildEditorField(
                'Declaration',
                _controllers['declarationBody']!,
              ),
              _buildEditorField(
                'Acceptance Confirmation',
                _controllers['acceptanceConfirmation']!,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEditorField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: null, // Allows for multiline input
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}