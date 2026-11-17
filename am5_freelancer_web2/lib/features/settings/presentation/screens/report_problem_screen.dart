import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _category = 'App issue';
  final FreelanceApi _api = FreelanceApi();
  bool _sending = false;

  static const Color navy = Color(0xFF101D45);
  static const Color blue = Color(0xFF2449A5);

  @override
  void dispose() {
    _descriptionController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final result = await _api.reportProblem({
        'problem_category': _category,
        'problem_description': _descriptionController.text.trim(),
        'page_url': Uri.base.toString(),
      });
      if (!mounted) return;
      _descriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report submitted${result['report_id'] == null ? '.' : ' (${result['report_id']}).'}',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FD),
      appBar: AppBar(
        title: const Text('Report a Problem'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE5EAF5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.report_problem_outlined,
                        color: blue,
                        size: 42,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Tell us what went wrong',
                        style: TextStyle(
                          color: navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 22),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Problem category',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'App issue',
                            child: Text('App issue'),
                          ),
                          DropdownMenuItem(
                            value: 'Login issue',
                            child: Text('Login issue'),
                          ),
                          DropdownMenuItem(
                            value: 'Referral issue',
                            child: Text('Referral issue'),
                          ),
                          DropdownMenuItem(
                            value: 'Wallet issue',
                            child: Text('Wallet issue'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 5,
                        maxLines: 8,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Describe the problem',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 10) {
                            return 'Please enter at least 10 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: blue),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Screenshot attachments can be added after '
                                'the upload flow is implemented.',
                                style: TextStyle(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sending ? null : _submit,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Submit Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your report is sent to the AM5 ROYAL support team.',
                        style: TextStyle(
                          color: Color(0xFF778198),
                          fontSize: 12,
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
