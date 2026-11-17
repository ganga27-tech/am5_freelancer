import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'document_file_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class DocumentsKycScreen extends StatefulWidget {
  const DocumentsKycScreen({super.key});

  @override
  State<DocumentsKycScreen> createState() => _DocumentsKycScreenState();
}

class _DocumentsKycScreenState extends State<DocumentsKycScreen> {
  static const navy = Color(0xFF142B6F);
  static const cream = Color(0xFFFFF8E7);
  static const borderColor = Color(0xFFE8E0CE);

  final _formKey = GlobalKey<FormState>();

  final _aadhaar = TextEditingController();
  final _pan = TextEditingController();
  final _gst = TextEditingController();
  final _api = FreelanceApi();

  final Map<String, String?> _files = {
    'Aadhaar document': null,
    'PAN document': null,
    'GST certificate': null,
    'Address proof': null,
  };

  bool _isSaving = false;
  final Map<String, PlatformFile> _pickedFiles = {};

  @override
  void dispose() {
    _aadhaar.dispose();
    _pan.dispose();
    _gst.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String document) async {
    final file = await pickDocumentFile();

    if (!mounted || file == null) return;
    final name = file.name;

    final extension = name.split('.').last.toLowerCase();

    if (!['pdf', 'jpg', 'jpeg', 'png'].contains(extension)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF, JPG, JPEG or PNG file.'),
        ),
      );
      return;
    }

    setState(() {
      _files[document] = name;
      _pickedFiles[document] = file;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name selected'),
        backgroundColor: navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one KYC document to upload.'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final ids = <int>[];
      for (final entry in _pickedFiles.entries) {
        final file = entry.value;
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw const ApiException(
            'Could not read a selected document. Please choose it again.',
          );
        }
        if (bytes.length > 10 * 1024 * 1024) {
          throw ApiException('${file.name} exceeds the 10 MB upload limit.');
        }
        final type = switch (entry.key) {
          'Aadhaar document' => 'aadhaar',
          'PAN document' => 'pan',
          'GST certificate' => 'gst_certificate',
          _ => 'address_proof',
        };
        final ext = file.extension?.toLowerCase();
        final mime = ext == 'pdf'
            ? 'application/pdf'
            : 'image/${ext == 'jpg' ? 'jpeg' : ext}';
        final uploaded = await _api.uploadKycDocument(
          bytes,
          file.name,
          type,
          contentType: mime,
        );
        final id = uploaded['file_id'];
        if (id is num) ids.add(id.toInt());
      }
      final submitted = await _api.submitKyc(
        aadhaar: _aadhaar.text.trim(),
        pan: _pan.text.trim().toUpperCase(),
        gst: _gst.text.trim().toUpperCase(),
        documentIds: ids,
      );
      if (!mounted) return;
      Navigator.pop(context, {
        'aadhaarNumber': _aadhaar.text.trim(),
        'panNumber': _pan.text.trim().toUpperCase(),
        'gstNumber': _gst.text.trim().toUpperCase(),
        'documents': Map<String, String?>.from(_files),
        'kycStatus': submitted['kyc_status']?.toString() ?? 'PENDING',
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        foregroundColor: navy,
        elevation: 0,
        title: const Text(
          'Documents & KYC',
          style: TextStyle(color: navy, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Card(
                color: Colors.white,
                elevation: 3,
                shadowColor: navy.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: navy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.verified_user_outlined,
                                color: navy,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Identity Documents',
                                    style: TextStyle(
                                      color: navy,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Manage your KYC information',
                                    style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter your details and select the documents '
                          'required for your account.',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        _sectionTitle(
                          Icons.badge_outlined,
                          'Identity Information',
                        ),
                        const SizedBox(height: 16),

                        _textField(
                          controller: _aadhaar,
                          label: 'Aadhaar number',
                          hint: 'Enter 12-digit Aadhaar number',
                          icon: Icons.credit_card_outlined,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final input = value?.trim() ?? '';

                            if (input.isEmpty) {
                              return 'Enter Aadhaar number';
                            }

                            if (!RegExp(r'^\d{12}$').hasMatch(input)) {
                              return 'Enter a valid 12-digit number';
                            }

                            return null;
                          },
                        ),

                        _textField(
                          controller: _pan,
                          label: 'PAN number',
                          hint: 'Enter PAN number',
                          icon: Icons.assignment_ind_outlined,
                          capitalization: TextCapitalization.characters,
                          validator: (value) {
                            final input = value?.trim() ?? '';

                            if (input.isEmpty) {
                              return 'Enter PAN number';
                            }

                            if (!RegExp(r'^[A-Za-z]{5}[0-9]{4}[A-Za-z]$')
                                .hasMatch(input)) {
                              return 'Enter a valid PAN format';
                            }

                            return null;
                          },
                        ),

                        _textField(
                          controller: _gst,
                          label: 'GSTIN (optional)',
                          hint: 'Enter GSTIN if applicable',
                          icon: Icons.business_outlined,
                          capitalization: TextCapitalization.characters,
                          validator: (value) {
                            final input = value?.trim() ?? '';

                            if (input.isEmpty) return null;

                            if (!RegExp(r'^\d{2}[A-Za-z0-9]{13}$')
                                .hasMatch(input)) {
                              return 'Check GSTIN format';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 8),

                        _sectionTitle(
                          Icons.cloud_upload_outlined,
                          'Upload Documents',
                        ),
                        const SizedBox(height: 6),

                        const Text(
                          'Supported formats: PDF, JPG, JPEG and PNG',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),

                        ..._files.keys.map(_documentTile),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text(
                              'Save KYC Details',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.blueGrey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: cream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: navy, size: 19),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'Selected files are securely uploaded for review. '
                                  'KYC remains pending until AM5 ROYAL verifies it.',
                                  style: TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 11,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
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

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: navy, size: 20),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: navy, size: 21),
          filled: true,
          fillColor: const Color(0xFFFFFEFA),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 16,
          ),
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
            borderSide: const BorderSide(color: navy, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _documentTile(String title) {
    final file = _files[title];
    final hasFile = file != null && file.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        border: Border.all(
          color: hasFile ? const Color(0xFFB7DCC4) : borderColor,
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: hasFile
                ? const Color(0xFFE8F5EC)
                : navy.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            hasFile ? Icons.task_alt_outlined : Icons.description_outlined,
            color: hasFile ? Colors.green.shade700 : navy,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: navy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            file ?? 'No file selected',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasFile ? Colors.green.shade700 : Colors.blueGrey,
              fontSize: 11,
            ),
          ),
        ),
        trailing: IconButton(
          tooltip: 'Choose document',
          onPressed: () => _pickFile(title),
          icon: const Icon(Icons.upload_file_outlined, color: navy),
        ),
      ),
    );
  }
}
