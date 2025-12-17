import 'package:flutter/material.dart';
import 'revised_pdf_content_model.dart';

class EditRevisedPdfContentPage extends StatefulWidget {
  final RevisedPdfContentModel initialContent;

  const EditRevisedPdfContentPage({super.key, required this.initialContent});

  @override
  State<EditRevisedPdfContentPage> createState() =>
      _EditRevisedPdfContentPageState();
}

class _EditRevisedPdfContentPageState extends State<EditRevisedPdfContentPage> {
  late RevisedPdfContentModel _content;
  final _formKey = GlobalKey<FormState>();

  // One controller for each field
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _content = widget.initialContent;
    // Initialize controllers
    _content.toJson().forEach((key, value) {
      _controllers[key] = TextEditingController(text: value.toString());
    });
  }

  // Safely get or create a controller for a key
  TextEditingController _ctrl(String key) {
    if (!_controllers.containsKey(key)) {
      final initial = _content.toJson()[key];
      _controllers[key] = TextEditingController(
        text: initial?.toString() ?? '',
      );
    }
    return _controllers[key]!;
  }

  @override
  void dispose() {
    // Dispose all controllers
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _saveContent() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedContent = RevisedPdfContentModel.fromJson(
        _controllers.map((key, controller) => MapEntry(key, controller.text)),
      );

      Navigator.of(context).pop(updatedContent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Revised Offer Content'),
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
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildFormFields(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    final List<Widget> fields = [];

    // Helper to create a styled text field
    Widget buildEditorField(String label, TextEditingController controller) {
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

    // Helper to create a section header
    Widget buildSectionHeader(String title) {
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

    fields.add(buildSectionHeader("Page 1"));
    fields.add(buildEditorField('Greeting', _ctrl('dearName')));
    fields.add(buildEditorField('Introduction', _ctrl('intro')));
    fields.add(
      buildEditorField(
        'Position Details (use {fromposition}, {position}, {doj})',
        _ctrl('positionBody'),
      ),
    );
    fields.add(
      buildEditorField('Compensation Details', _ctrl('compensationBody')),
    );
    fields.add(
      buildEditorField('Confidentiality', _ctrl('confidentialityBody')),
    );

    fields.add(buildSectionHeader("Page 2"));
    fields.add(buildEditorField('Working Hours', _ctrl('workingHoursBody')));
    fields.add(
      buildEditorField(
        'Leave Eligibility Intro',
        _ctrl('leaveEligibilityBody'),
      ),
    );
    fields.add(buildEditorField('Leave Accrual', _ctrl('leaveAccrual')));
    fields.add(buildEditorField('Public Holidays', _ctrl('publicHolidays')));
    fields.add(buildEditorField('Special Leave', _ctrl('specialLeave')));
    fields.add(buildEditorField('Add Ons For Men', _ctrl('addOnsForMen')));
    fields.add(buildEditorField('Add Ons For Women', _ctrl('addOnsForWomen')));
    fields.add(buildEditorField('Leave Requests', _ctrl('leaveRequests')));
    fields.add(
      buildEditorField('Leave Responsibility', _ctrl('leaveResponsibly')),
    );
    fields.add(buildEditorField('Leave Note', _ctrl('leaveNote')));
    fields.add(buildEditorField('Notice Period', _ctrl('noticePeriodBody')));

    fields.add(buildSectionHeader("Page 3"));
    fields.add(
      buildEditorField(
        'Professional Conduct (Part 1)',
        _ctrl('professionalConductBody1'),
      ),
    );
    fields.add(
      buildEditorField(
        'Professional Conduct (Part 2)',
        _ctrl('professionalConductBody2'),
      ),
    );
    fields.add(
      buildEditorField('Termination - Point 1', _ctrl('terminationPoint1')),
    );
    fields.add(
      buildEditorField('Termination - Point 2', _ctrl('terminationPoint2')),
    );
    fields.add(
      buildEditorField('Termination - Point 3', _ctrl('terminationPoint3')),
    );
    fields.add(
      buildEditorField('Termination - Point 4', _ctrl('terminationPoint4')),
    );
    fields.add(
      buildEditorField('Termination - Point 5', _ctrl('terminationPoint5')),
    );
    fields.add(
      buildEditorField('Termination - Point 6', _ctrl('terminationPoint6')),
    );
    fields.add(
      buildEditorField('Termination - Point 7', _ctrl('terminationPoint7')),
    );

    fields.add(buildSectionHeader("Page 4"));
    fields.add(
      buildEditorField(
        'Pre-Employment Screening',
        _ctrl('preEmploymentScreeningBody'),
      ),
    );
    fields.add(buildEditorField('Dispute', _ctrl('disputeBody')));
    fields.add(buildEditorField('Declaration', _ctrl('declarationBody')));
    fields.add(
      buildEditorField(
        'Acceptance Confirmation',
        _ctrl('acceptanceConfirmation'),
      ),
    );

    return fields;
  }
}