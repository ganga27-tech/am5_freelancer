import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const Color navy = Color(0xFF101D45);
  static const Color blue = Color(0xFF2449A5);
  static const Color background = Color(0xFFF5F7FC);
  static const Color mutedText = Color(0xFF727D92);
  static const Color borderColor = Color(0xFFE2E7F0);

  final FreelanceApi _api = FreelanceApi();

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedCategory = 'General Inquiry';
  bool _isOpeningEmail = false;

  static const List<String> _categories = [
    'General Inquiry',
    'Account & Profile',
    'App Installation & Activation',
    'Referral & Rewards',
    'Earnings & Wallet',
    'Payment Issue',
    'Technical Issue',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _api.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address.';
    }

    final pattern = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

    if (!pattern.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: blue, size: 21),
      filled: true,
      fillColor: const Color(0xFFFAFBFE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  Future<void> _openEmailApp() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isOpeningEmail = true);
    try {
      final result = await _api.submitSupportTicket({
        'full_name': _nameController.text.trim(),
        'email_address': _emailController.text.trim(),
        'query_category': _selectedCategory,
        'subject': _subjectController.text.trim(),
        'query_description': _messageController.text.trim(),
      });

      if (!mounted) return;
      _showMessage(
        'Support request submitted${result['ticket_number'] == null ? '.' : ' (${result['ticket_number']}).'}',
      );
      _formKey.currentState?.reset();
      _subjectController.clear();
      _messageController.clear();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;

      _showMessage('Unable to open the email app. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isOpeningEmail = false);
      }
    }
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF2FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.support_agent_rounded, color: blue, size: 31),
        ),
        const SizedBox(height: 20),
        const Text(
          'How can we help you?',
          style: TextStyle(
            color: navy,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Have a question or facing an issue? Tell us about it. '
          'Our support team can assist you.',
          style: TextStyle(color: mutedText, fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Contact Support',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 56).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: borderColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 28),

                              // Full name
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  label: 'Full name',
                                  icon: Icons.person_outline_rounded,
                                  hint: 'Enter your name',
                                ),
                                validator: _validateRequired,
                              ),

                              const SizedBox(height: 18),

                              // Email address
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: _inputDecoration(
                                  label: 'Your email address',
                                  icon: Icons.email_outlined,
                                  hint: 'you@example.com',
                                ),
                                validator: _validateEmail,
                              ),

                              const SizedBox(height: 18),

                              // Query category
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                isExpanded: true,
                                decoration: _inputDecoration(
                                  label: 'Query category',
                                  icon: Icons.category_outlined,
                                ),
                                items: _categories.map((category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(
                                      category,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCategory = value;
                                    });
                                  }
                                },
                              ),

                              const SizedBox(height: 18),

                              // Subject
                              TextFormField(
                                controller: _subjectController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  label: 'Subject',
                                  icon: Icons.subject_rounded,
                                  hint: 'Briefly describe your issue',
                                ),
                                validator: _validateRequired,
                              ),

                              const SizedBox(height: 18),

                              // Query message
                              TextFormField(
                                controller: _messageController,
                                minLines: 4,
                                maxLines: 7,
                                maxLength: 3000,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: _inputDecoration(
                                  label: 'Describe your query',
                                  icon: Icons.chat_bubble_outline_rounded,
                                  hint: 'Please explain how we can help...',
                                ).copyWith(alignLabelWithHint: true),
                                validator: (value) {
                                  final error = _validateRequired(value);

                                  if (error != null) return error;

                                  if (value!.trim().length < 10) {
                                    return 'Please provide at least 10 characters.';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              // Contact Support button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isOpeningEmail
                                      ? null
                                      : _openEmailApp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: blue,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(
                                      0xFF9BAAD0,
                                    ),
                                    elevation: 0,
                                    minimumSize: const Size(
                                      double.infinity,
                                      52,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isOpeningEmail
                                      ? const SizedBox(
                                          width: 21,
                                          height: 21,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.support_agent_rounded,
                                              size: 20,
                                            ),
                                            SizedBox(width: 9),
                                            Text(
                                              'Contact Support',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              const Center(
                                child: Text(
                                  'AM5 ROYAL • Freelancer Support',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: mutedText,
                                    fontSize: 12,
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
          },
        ),
      ),
    );
  }
}
