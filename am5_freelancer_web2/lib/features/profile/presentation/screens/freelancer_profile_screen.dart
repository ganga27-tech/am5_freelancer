import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

import 'bank_details_screen.dart';
import 'documents_kyc_screen.dart';
import 'face_verification_screen.dart';
import 'personal_details_screen.dart';

class FreelancerProfileScreen extends StatefulWidget {
  const FreelancerProfileScreen({super.key});

  static const navy = Color(0xFF142B6F);
  static const blue = Color(0xFF1E3A8A);
  static const gold = Color(0xFFD4AF37);
  static const cream = Color(0xFFFFF8E7);
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE8E0CE);

  @override
  State<FreelancerProfileScreen> createState() =>
      _FreelancerProfileScreenState();
}

class _FreelancerProfileScreenState extends State<FreelancerProfileScreen> {
  static const navy = FreelancerProfileScreen.navy;
  static const blue = FreelancerProfileScreen.blue;
  static const gold = FreelancerProfileScreen.gold;
  static const cream = FreelancerProfileScreen.cream;
  static const ink = FreelancerProfileScreen.ink;
  static const muted = FreelancerProfileScreen.muted;
  static const line = FreelancerProfileScreen.line;

  final ImagePicker _picker = ImagePicker();
  final FreelanceApi _api = FreelanceApi();
  String? _photoUrl;
  int _profileCompletionPercentage = 0;
  bool _completionLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _api.profile();
      if (!mounted) return;
      setState(() {
        fullName = data['full_name']?.toString() ?? fullName;
        mobileNumber = data['mobile']?.toString() ?? mobileNumber;
        emailAddress = data['email']?.toString() ?? emailAddress;
        address = data['address']?.toString() ?? address;
        stateName = data['state']?.toString() ?? stateName;
        city = data['city']?.toString() ?? city;
        pincode = data['pincode']?.toString() ?? pincode;
        _photoUrl = data['photo_url']?.toString();
        _profileCompletionPercentage =
            int.tryParse(data['completion_percentage']?.toString() ?? '') ?? 0;
        _completionLoaded = true;
      });
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
      return;
    }
    try {
      final bank = await _api.bankDetails();
      final kyc = await _api.kycStatus();
      if (!mounted) return;
      setState(() {
        bankAccountHolder = bank['account_holder']?.toString() ?? '';
        bankAccountNumber = bank['masked_account_number']?.toString() ?? '';
        bankIfsc = bank['ifsc']?.toString() ?? '';
        bankName = bank['bank_name']?.toString() ?? '';
        _kycStatus = kyc['overall_status']?.toString() ?? _kycStatus;
      });
    } on ApiException {
      // Keep the profile screen usable when a secondary section is unavailable.
    }
  }

  Uint8List? _photo;

  // Personal details
  String fullName = '';
  String mobileNumber = '';
  String emailAddress = '';
  String dateOfBirth = '';
  String gender = '';
  String address = '';
  String stateName = '';
  String district = '';
  String city = '';
  String pincode = '';

  // Bank details
  String bankAccountHolder = '';
  String bankAccountNumber = '';
  String bankIfsc = '';
  String bankName = '';

  // KYC details
  String aadhaarNumber = '';
  String panNumber = '';
  String gstNumber = '';
  String _kycStatus = 'NOT_STARTED';

  Map<String, String?> documents = {
    'Aadhaar document': null,
    'PAN document': null,
    'GST certificate': null,
    'Address proof': null,
  };

  bool faceVerificationComplete = false;

  // The backend owns the profile completion calculation.
  double get _completion {
    if (_completionLoaded) {
      return _profileCompletionPercentage.clamp(0, 100) / 100;
    }
    final basic = fullName.trim().isNotEmpty &&
        mobileNumber.trim().isNotEmpty && emailAddress.trim().isNotEmpty;
    final addressComplete = address.trim().isNotEmpty &&
        city.trim().isNotEmpty && pincode.trim().isNotEmpty;
    final bankComplete = bankAccountNumber.trim().isNotEmpty &&
        bankIfsc.trim().isNotEmpty;
    final kycComplete = _kycStatus.toUpperCase() == 'VERIFIED';
    return ([basic, addressComplete, bankComplete, kycComplete]
            .where((complete) => complete)
            .length) /
        4;
  }

  String _maskedNumber(String value) {
    if (value.trim().isEmpty) return 'Not added';

    final lastDigits = value.length > 4
        ? value.substring(value.length - 4)
        : value;

    return '••••$lastDigits';
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Update profile photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: blue),
                title: const Text('Choose from gallery'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: blue),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final uploaded = await _api.uploadProfilePhoto(bytes, file.name);

      if (!mounted) return;

      setState(() {
        _photo = bytes;
        _photoUrl = uploaded['photo_url']?.toString();
      });
      _showMessage('Profile photo updated.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to select photo. Please check permissions and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        surfaceTintColor: cream,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: navy,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [navy, gold, Color(0xFFFFE9A8), gold],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final columns = width >= 1150
                ? 3
                : width >= 720
                ? 2
                : 1;

            final padding = width >= 1000 ? 28.0 : 16.0;
            const gap = 18.0;

            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1450),
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final availableWidth = innerConstraints.maxWidth;

                      final cardWidth =
                          (availableWidth - gap * (columns - 1)) / columns;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _profileHeader(width),
                          const SizedBox(height: 30),
                          const Text(
                            'ACCOUNT DETAILS',
                            style: TextStyle(
                              color: navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Manage your personal information and account settings.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Profile cards without Profile Visibility.
                          Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              _sizedCard(
                                cardWidth,
                                _accountCard(
                                  title: 'Personal Details',
                                  subtitle:
                                      'Your contact and personal information',
                                  icon: Icons.person_outline_rounded,
                                  iconColor: blue,
                                  actionText: 'Edit details',
                                  onEdit: _editPersonalDetails,
                                  rows: [
                                    _InfoRow('Full name', fullName),
                                    _InfoRow('Mobile number', mobileNumber),
                                    _InfoRow('Email address', emailAddress),
                                    _InfoRow('Date of birth', dateOfBirth),
                                  ],
                                ),
                              ),
                              _sizedCard(
                                cardWidth,
                                _accountCard(
                                  title: 'Bank Details',
                                  subtitle: 'Your payout account information',
                                  icon: Icons.account_balance_outlined,
                                  iconColor: const Color(0xFF7655B7),
                                  actionText: 'Edit bank details',
                                  onEdit: _openBankDetails,
                                  rows: [
                                    _InfoRow(
                                      'Account holder',
                                      bankAccountHolder,
                                    ),
                                    _InfoRow(
                                      'Account number',
                                      _maskedNumber(bankAccountNumber),
                                    ),
                                    _InfoRow('IFSC code', bankIfsc),
                                    _InfoRow('Bank name', bankName),
                                  ],
                                ),
                              ),
                              _sizedCard(
                                cardWidth,
                                _accountCard(
                                  title: 'Identity Verification',
                                  subtitle: 'Verify your identity',
                                  icon: Icons.verified_user_outlined,
                                  iconColor: const Color(0xFF16856B),
                                  actionText: 'Verify identity',
                                  onEdit: _openIdentityVerification,
                                  rows: [
                                    _InfoRow(
                                      'Face verification',
                                      faceVerificationComplete
                                          ? 'Completed'
                                          : 'Pending',
                                    ),
                                    _InfoRow(
                                      'Identity check',
                                      aadhaarNumber.isNotEmpty &&
                                              panNumber.isNotEmpty
                                          ? 'Details added'
                                          : 'Pending',
                                    ),
                                    _InfoRow('Verification status', _kycStatus),
                                  ],
                                ),
                              ),
                              _sizedCard(
                                cardWidth,
                                _accountCard(
                                  title: 'Documents & KYC',
                                  subtitle: 'Manage required documents',
                                  icon: Icons.folder_open_outlined,
                                  iconColor: const Color(0xFFB7791F),
                                  actionText: 'Manage documents',
                                  onEdit: _openDocuments,
                                  rows: [
                                    _InfoRow(
                                      'Aadhaar',
                                      _maskedNumber(aadhaarNumber),
                                    ),
                                    _InfoRow(
                                      'PAN card',
                                      panNumber.isEmpty
                                          ? 'Not added'
                                          : panNumber,
                                    ),
                                    _InfoRow(
                                      'GST certificate',
                                      documents['GST certificate'] ??
                                          (gstNumber.isEmpty
                                              ? 'Not added'
                                              : 'Details added'),
                                    ),
                                    _InfoRow(
                                      'Address proof',
                                      documents['Address proof'] ??
                                          'Not uploaded',
                                    ),
                                  ],
                                ),
                              ),
                              _sizedCard(cardWidth, _statusCard()),
                            ],
                          ),

                          const SizedBox(height: 30),

                          const Center(
                            child: Text(
                              'AM5 ROYAL  •  Work. Refer. Grow.',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _profileHeader(double width) {
    final compact = width < 560;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [navy, Color(0xFF254586)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gold.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _photoWidget(78),
                    const SizedBox(width: 16),
                    Expanded(child: _profileInfo(true)),
                  ],
                ),
                const SizedBox(height: 20),
                _editProfileButton(),
              ],
            )
          : Row(
              children: [
                _photoWidget(104),
                const SizedBox(width: 25),
                Expanded(child: _profileInfo(false)),
                const SizedBox(width: 16),
                _editProfileButton(),
              ],
            ),
    );
  }

  Widget _photoWidget(double size) {
    final uri = Uri.tryParse(_photoUrl ?? '');
    final ImageProvider? image = _photo != null
        ? MemoryImage(_photo!)
        : (uri != null &&
                  (uri.scheme == 'https' || uri.scheme == 'http') &&
                  uri.host.isNotEmpty
              ? NetworkImage(uri.toString())
              : null);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: gold, shape: BoxShape.circle),
          child: CircleAvatar(
            backgroundColor: const Color(0xFF344B7B),
            backgroundImage: image,
            child: image == null
                ? Icon(
                    Icons.person_rounded,
                    size: size * 0.55,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
        Positioned(
          right: -2,
          bottom: 0,
          child: Material(
            color: gold,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _choosePhoto,
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(Icons.camera_alt_rounded, size: 17, color: navy),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileInfo(bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fullName.trim().isEmpty ? 'Your Name' : fullName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 20 : 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _headerInfo(Icons.email_outlined, emailAddress),
        const SizedBox(height: 8),
        _headerInfo(Icons.phone_outlined, mobileNumber),
        if (city.trim().isNotEmpty || stateName.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _headerInfo(
            Icons.location_on_outlined,
            [
              city,
              stateName,
            ].where((value) => value.trim().isNotEmpty).join(', '),
          ),
        ],
      ],
    );
  }

  Widget _headerInfo(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: gold, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value.trim().isEmpty ? 'Not added' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE5EBF8),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _editProfileButton() {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: _editPersonalDetails,
        icon: const Icon(Icons.edit_outlined, size: 17),
        label: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: navy,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _sizedCard(double width, Widget child) {
    return SizedBox(width: width, height: 300, child: child);
  }

  Widget _accountCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String actionText,
    required VoidCallback onEdit,
    required List<_InfoRow> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon, iconColor),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Divider(height: 1, color: line),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              children: rows.map((row) {
                return _info(row.label, row.value);
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                side: const BorderSide(color: gold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                actionText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 11, height: 1.35),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value.trim().isEmpty ? 'Not added' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final percentage = (_completion * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.insights_outlined, blue),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Profile Status',
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$percentage% complete',
            style: const TextStyle(
              color: navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _completion,
              minHeight: 9,
              backgroundColor: const Color(0xFFECE5D6),
              valueColor: const AlwaysStoppedAnimation<Color>(gold),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Completion reflects the backend requirements for your account.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.6),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2D6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF8A5A00),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    percentage == 100
                        ? 'All personal details are filled.'
                        : 'Some profile details are still missing.',
                    style: const TextStyle(
                      color: Color(0xFF8A5A00),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: line),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: 0.045),
          blurRadius: 17,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Future<void> _editPersonalDetails() async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => PersonalDetailsScreen(
          initialFullName: fullName,
          initialMobileNumber: mobileNumber,
          initialEmail: emailAddress,
          initialDateOfBirth: dateOfBirth,
          initialGender: gender,
          initialAddress: address,
          initialState: stateName,
          initialDistrict: district,
          initialCity: city,
          initialPincode: pincode,
        ),
      ),
    );

    if (!mounted || result == null) return;

    late final Map<String, dynamic> saved;
    try {
      saved = await _api.updateProfile({
        'full_name': result['fullName']?.trim(),
        'city': result['city']?.trim(),
        'state': result['state']?.trim(),
        'address': result['address']?.trim(),
        'pincode': result['pincode']?.trim(),
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
      return;
    }

    final confirmedFullName = saved['full_name'];
    if (confirmedFullName is! String || confirmedFullName.trim().isEmpty) {
      _showMessage('The server did not confirm the updated profile.');
      return;
    }

    setState(() {
      // The PATCH response is built from the committed, refreshed database
      // row. Render that canonical response instead of the form's optimistic
      // values or stale local values.
      fullName = confirmedFullName;
      address = saved['address']?.toString() ?? '';
      stateName = saved['state']?.toString() ?? '';
      city = saved['city']?.toString() ?? '';
      pincode = saved['pincode']?.toString() ?? '';
      _profileCompletionPercentage = int.tryParse(
            saved['completion_percentage']?.toString() ?? '',
          ) ??
          0;
      _completionLoaded = true;
    });

    _showMessage('Profile updated.');
  }

  Future<void> _openBankDetails() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const BankDetailsScreen()),
    );

    if (!mounted || result == null) return;

    await _loadProfile();
    _showMessage('Bank details updated.');
  }

  Future<void> _openDocuments() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const DocumentsKycScreen()),
    );

    if (!mounted || result == null) return;

    setState(() {
      aadhaarNumber = result['aadhaarNumber']?.toString() ?? aadhaarNumber;
      panNumber = result['panNumber']?.toString() ?? panNumber;
      gstNumber = result['gstNumber']?.toString() ?? gstNumber;
      _kycStatus = result['kycStatus']?.toString() ?? _kycStatus;

      final returnedDocuments = result['documents'];

      if (returnedDocuments is Map) {
        documents = returnedDocuments.map(
          (key, value) => MapEntry(key.toString(), value?.toString()),
        );
      }
    });

    _showMessage('KYC details updated.');
  }

  Future<void> _openIdentityVerification() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FaceVerificationScreen()),
    );

    if (!mounted || result == null) return;

    setState(() {
      faceVerificationComplete = result;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);
}
