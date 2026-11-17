import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  // Professional AM5 ROYAL palette.
  static const Color navy = Color(0xFF243451);
  static const Color royalBlue = Color(0xFF4568A8);
  static const Color electricBlue = Color(0xFF5278C7);
  static const Color purple = Color(0xFF8064B5);
  static const Color teal = Color(0xFF3F9293);
  static const Color green = Color(0xFF438B6B);
  static const Color orange = Color(0xFFC98543);
  static const Color gold = Color(0xFFE4BD68);

  static const Color muted = Color(0xFF778397);
  static const Color borderColor = Color(0xFFE0E6EF);
  static const Color background = Color(0xFFF5F7FB);
  static const Color fieldBackground = Color(0xFFFAFBFE);
  static const Color errorColor = Color(0xFFD85C5C);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _holder = TextEditingController();
  final TextEditingController _account = TextEditingController();
  final TextEditingController _confirmAccount = TextEditingController();
  final TextEditingController _ifsc = TextEditingController();
  final TextEditingController _bank = TextEditingController();

  bool _obscureAccount = true;
  bool _obscureConfirmAccount = true;
  bool _isSaving = false;
  final FreelanceApi _api = FreelanceApi();

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    _confirmAccount.dispose();
    _ifsc.dispose();
    _bank.dispose();
    _api.dispose();
    super.dispose();
  }

  // ---------------- VALIDATION ----------------

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  String? _validateAccount(String? value) {
    final accountNumber = value?.trim() ?? '';

    if (accountNumber.isEmpty) {
      return 'Enter account number';
    }

    if (!RegExp(r'^\d{8,20}$').hasMatch(accountNumber)) {
      return 'Enter 8–20 digits';
    }

    return null;
  }

  String? _validateConfirmAccount(String? value) {
    final confirmation = value?.trim() ?? '';
    final accountNumber = _account.text.trim();

    if (confirmation.isEmpty) {
      return 'Please confirm your account number';
    }

    if (confirmation != accountNumber) {
      return 'Account numbers do not match';
    }

    return null;
  }

  String? _validateIfsc(String? value) {
    final ifsc = (value ?? '').trim().toUpperCase();

    if (ifsc.isEmpty) {
      return 'Enter IFSC code';
    }

    // Standard IFSC structure: 4 letters, zero, 6 alphanumeric.
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
      return 'Enter a valid IFSC code';
    }

    return null;
  }

  // ---------------- SAVE / CANCEL ----------------

  Future<void> _save() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final Map<String, String> details = <String, String>{
      'accountHolder': _holder.text.trim(),
      'accountNumber': _account.text.trim(),
      'ifsc': _ifsc.text.trim().toUpperCase(),
      'bankName': _bank.text.trim(),
    };

    try {
      final saved = await _api.updateBankDetails({
        'account_holder_name': details['accountHolder'],
        'account_number': details['accountNumber'],
        'ifsc_code': details['ifsc'],
        'bank_name': details['bankName'],
      });

      if (!mounted) return;

      details['accountNumber'] =
          saved['masked_account_number']?.toString() ?? '••••';
      details['verificationStatus'] =
          saved['verification_status']?.toString() ?? 'PENDING';
      Navigator.of(context).pop(details);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _cancel() {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  // ---------------- MAIN UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'Bank Details',
          style: TextStyle(
            color: navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: _cancel,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  _buildSecurityNotice(),
                  const SizedBox(height: 22),
                  _buildFormCard(),
                  const SizedBox(height: 18),
                  _buildBottomNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- HEADER ----------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF243451), Color(0xFF4568A8), Color(0xFF74649B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -18,
            child: Icon(
              Icons.account_balance_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.17),
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: gold,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'AM5 ROYAL',
                style: TextStyle(
                  color: gold,
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Your Payout Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Add your bank details to receive your earnings.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _headerTag(Icons.verified_user_outlined, 'Secure details'),
                  _headerTag(Icons.payments_outlined, 'Payout details'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: gold, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- SECURITY NOTICE ----------------

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF6F0),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: green.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: green, size: 23),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep your details accurate',
                  style: TextStyle(
                    color: Color(0xFF246344),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Double-check your account number and IFSC code '
                  'before saving.',
                  style: TextStyle(
                    color: Color(0xFF557765),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- FORM CARD ----------------

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: royalBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.wallet_rounded,
                    color: royalBlue,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Information',
                        style: TextStyle(
                          color: navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Enter the details below',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            _sectionLabel('ACCOUNT DETAILS', royalBlue),
            const SizedBox(height: 15),

            _buildField(
              controller: _holder,
              label: 'Account holder name',
              hint: 'Enter name as per bank account',
              icon: Icons.person_outline_rounded,
              color: royalBlue,
              validator: _required,
              textCapitalization: TextCapitalization.words,
            ),

            _buildField(
              controller: _account,
              label: 'Account number',
              hint: 'Enter your bank account number',
              icon: Icons.credit_card_rounded,
              color: purple,
              validator: _validateAccount,
              keyboardType: TextInputType.number,
              obscureText: _obscureAccount,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(20),
              ],
              suffix: IconButton(
                tooltip: _obscureAccount
                    ? 'Show account number'
                    : 'Hide account number',
                onPressed: () {
                  setState(() {
                    _obscureAccount = !_obscureAccount;
                  });
                },
                icon: Icon(
                  _obscureAccount
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: muted,
                ),
              ),
            ),

            _buildField(
              controller: _confirmAccount,
              label: 'Confirm account number',
              hint: 'Re-enter account number',
              icon: Icons.verified_outlined,
              color: teal,
              validator: _validateConfirmAccount,
              keyboardType: TextInputType.number,
              obscureText: _obscureConfirmAccount,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(20),
              ],
              suffix: IconButton(
                tooltip: _obscureConfirmAccount
                    ? 'Show confirmation'
                    : 'Hide confirmation',
                onPressed: () {
                  setState(() {
                    _obscureConfirmAccount = !_obscureConfirmAccount;
                  });
                },
                icon: Icon(
                  _obscureConfirmAccount
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: muted,
                ),
              ),
            ),

            const SizedBox(height: 7),
            _sectionLabel('BANK DETAILS', orange),
            const SizedBox(height: 15),

            _buildField(
              controller: _ifsc,
              label: 'IFSC code',
              hint: 'Example: SBIN0001234',
              icon: Icons.qr_code_rounded,
              color: orange,
              validator: _validateIfsc,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                UpperCaseTextFormatter(),
                LengthLimitingTextInputFormatter(11),
              ],
            ),

            _buildField(
              controller: _bank,
              label: 'Bank name',
              hint: 'Enter your bank name',
              icon: Icons.account_balance_rounded,
              color: electricBlue,
              validator: _required,
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 5),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ---------------- SECTION LABEL ----------------

  Widget _sectionLabel(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 17,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ---------------- REUSABLE INPUT FIELD ----------------

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 19),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(
          color: navy,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: muted, fontSize: 13),
          hintStyle: TextStyle(
            color: muted.withValues(alpha: 0.75),
            fontSize: 12,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(11),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 62,
            minHeight: 58,
          ),
          suffixIcon: suffix,
          filled: true,
          fillColor: fieldBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: color, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: errorColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ---------------- ACTION BUTTONS ----------------

  Widget _buildActionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 420;

        final Widget saveButton = SizedBox(
          height: 53,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: royalBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: royalBlue.withValues(alpha: 0.55),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, size: 19),
                      SizedBox(width: 9),
                      Text(
                        'Save Bank Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        );

        final Widget cancelButton = SizedBox(
          height: 50,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isSaving ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: navy,
              side: const BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [saveButton, const SizedBox(height: 10), cancelButton],
          );
        }

        return Row(
          children: [
            Expanded(child: cancelButton),
            const SizedBox(width: 12),
            Expanded(child: saveButton),
          ],
        );
      },
    );
  }

  // ---------------- BOTTOM NOTE ----------------

  Widget _buildBottomNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline_rounded, size: 17, color: muted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'After saving, the backend returns a masked account number and '
            'verification status for your profile.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted.withValues(alpha: 0.95),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- IFSC UPPERCASE FORMATTER ----------------

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
