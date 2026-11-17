import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PersonalDetailsScreen extends StatefulWidget {
  final String initialFullName;
  final String initialMobileNumber;
  final String initialEmail;
  final String initialDateOfBirth;
  final String initialGender;
  final String initialAddress;
  final String initialState;
  final String initialDistrict;
  final String initialCity;
  final String initialPincode;

  final Future<void> Function(Map<String, String> details)? onSave;

  const PersonalDetailsScreen({
    super.key,
    this.initialFullName = '',
    this.initialMobileNumber = '',
    this.initialEmail = '',
    this.initialDateOfBirth = '',
    this.initialGender = '',
    this.initialAddress = '',
    this.initialState = '',
    this.initialDistrict = '',
    this.initialCity = '',
    this.initialPincode = '',
    this.onSave,
  });

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _dobController;
  late final TextEditingController _addressController;
  late final TextEditingController _stateController;
  late final TextEditingController _districtController;
  late final TextEditingController _cityController;
  late final TextEditingController _pincodeController;

  String? _gender;
  bool _isSaving = false;

  // Brand colors
  static const Color navy = Color(0xFF101D45);
  static const Color blue = Color(0xFF2449A5);
  static const Color royalBlue = Color(0xFF3158B8);
  static const Color gold = Color(0xFFE7BD65);

  // Background and borders
  static const Color pageColor = Color(0xFFF4F7FC);
  static const Color borderColor = Color(0xFFE2E8F2);
  static const Color mutedColor = Color(0xFF77839A);
  static const Color fieldColor = Color(0xFFFBFCFF);

  // Colorful icon palette
  static const Color purple = Color(0xFF805AD5);
  static const Color green = Color(0xFF229A72);
  static const Color teal = Color(0xFF159A9C);
  static const Color orange = Color(0xFFE99535);
  static const Color pink = Color(0xFFD9578B);
  static const Color skyBlue = Color(0xFF3986D7);
  static const Color indigo = Color(0xFF5967D8);
  static const Color red = Color(0xFFD95757);

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.initialFullName);
    _mobileController = TextEditingController(text: widget.initialMobileNumber);
    _emailController = TextEditingController(text: widget.initialEmail);
    _dobController = TextEditingController(text: widget.initialDateOfBirth);
    _addressController = TextEditingController(text: widget.initialAddress);
    _stateController = TextEditingController(text: widget.initialState);
    _districtController = TextEditingController(text: widget.initialDistrict);
    _cityController = TextEditingController(text: widget.initialCity);
    _pincodeController = TextEditingController(text: widget.initialPincode);

    const validGenders = ['Female', 'Male', 'Other', 'Prefer not to say'];

    _gender = validGenders.contains(widget.initialGender)
        ? widget.initialGender
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // COLORFUL ICON
  // ------------------------------------------------------------

  Widget _buildColorfulIcon({
    required IconData icon,
    required Color color,
    double size = 20,
  }) {
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  Color _fieldIconColor(String label) {
    switch (label) {
      case 'Full Name':
        return purple;
      case 'Mobile Number':
        return green;
      case 'Email Address':
        return skyBlue;
      case 'Full Address':
        return teal;
      case 'State':
        return indigo;
      case 'District':
        return purple;
      case 'City / Town':
        return blue;
      case 'PIN Code':
        return orange;
      default:
        return royalBlue;
    }
  }

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();

    DateTime initialDate = DateTime(now.year - 18, now.month, now.day);

    final currentText = _dobController.text.trim();

    if (currentText.isNotEmpty) {
      DateTime? parsedDate;

      // Supports both yyyy-MM-dd and dd/MM/yyyy.
      if (currentText.contains('/')) {
        final parts = currentText.split('/');

        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);

          if (day != null && month != null && year != null) {
            try {
              final candidate = DateTime(year, month, day);

              if (candidate.year == year &&
                  candidate.month == month &&
                  candidate.day == day) {
                parsedDate = candidate;
              }
            } catch (_) {
              parsedDate = null;
            }
          }
        }
      } else {
        parsedDate = DateTime.tryParse(currentText);
      }

      if (parsedDate != null &&
          !parsedDate.isBefore(DateTime(1940)) &&
          !parsedDate.isAfter(now)) {
        initialDate = parsedDate;
      }
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Select date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: navy,
              secondary: gold,
              surface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final formattedDate =
        '${pickedDate.day.toString().padLeft(2, '0')}/'
        '${pickedDate.month.toString().padLeft(2, '0')}/'
        '${pickedDate.year}';

    setState(() {
      _dobController.text = formattedDate;
    });
  }

  // ------------------------------------------------------------
  // VALIDATION
  // ------------------------------------------------------------

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Please enter your full name';
    }

    if (name.length < 3) {
      return 'Name must contain at least 3 characters';
    }

    if (!RegExp(r"^[A-Za-z .'-]+$").hasMatch(name)) {
      return 'Use letters, spaces, hyphens or apostrophes';
    }

    return null;
  }

  String? _validatePincode(String? value) {
    final pincode = value?.trim() ?? '';

    if (pincode.isNotEmpty && !RegExp(r'^[1-9][0-9]{5}$').hasMatch(pincode)) {
      return 'Enter a valid 6-digit PIN code';
    }

    return null;
  }

  // ------------------------------------------------------------
  // SAVE DETAILS
  // ------------------------------------------------------------

  Future<void> _saveDetails() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final details = <String, String>{
      'fullName': _nameController.text.trim(),
      'mobileNumber': _mobileController.text.trim(),
      'email': _emailController.text.trim(),
      'dateOfBirth': _dobController.text.trim(),
      'gender': ?_gender,
      'address': _addressController.text.trim(),
      'state': _stateController.text.trim(),
      'district': _districtController.text.trim(),
      'city': _cityController.text.trim(),
      'pincode': _pincodeController.text.trim(),
    };

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.onSave != null) {
        await widget.onSave!(details);
      }

      if (!mounted) return;

      Navigator.of(context).pop(details);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to save details: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // MAIN SCREEN
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Personal Details',
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),

                  _buildSection(
                    title: 'Basic Information',
                    subtitle:
                        'Name is editable. Mobile and email changes require a verified contact-update flow.',
                    icon: Icons.person_outline_rounded,
                    accentColor: blue,
                    secondaryColor: purple,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        icon: Icons.badge_rounded,
                        validator: _validateName,
                        required: true,
                      ),
                      _buildTextField(
                        controller: _mobileController,
                        label: 'Mobile Number',
                        hint: '10-digit mobile number',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        enabled: false,
                        readOnlyReason: 'Contact updates require verification.',
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'example@email.com',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        enabled: false,
                        readOnlyReason: 'Contact updates require verification.',
                      ),
                      _buildDateField(),
                      _buildGenderField(),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildSection(
                    title: 'Address Information',
                    subtitle:
                        'Address fields save to your profile. Date of birth, gender, and district are not supported by the current API.',
                    icon: Icons.location_on_rounded,
                    accentColor: teal,
                    secondaryColor: green,
                    children: [
                      _buildTextField(
                        controller: _addressController,
                        label: 'Full Address',
                        hint: 'House number, street, area',
                        icon: Icons.home_rounded,
                        maxLines: 2,
                      ),
                      _buildTextField(
                        controller: _stateController,
                        label: 'State',
                        hint: 'Enter your state',
                        icon: Icons.map_rounded,
                      ),
                      _buildTextField(
                        controller: _districtController,
                        label: 'District',
                        hint: 'Enter your district',
                        icon: Icons.location_city_rounded,
                        enabled: false,
                        readOnlyReason: 'This field is not saved by the current API.',
                      ),
                      _buildTextField(
                        controller: _cityController,
                        label: 'City / Town',
                        hint: 'Enter your city or town',
                        icon: Icons.apartment_rounded,
                      ),
                      _buildTextField(
                        controller: _pincodeController,
                        label: 'PIN Code',
                        hint: '6-digit PIN code',
                        icon: Icons.markunread_mailbox_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: _validatePincode,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101D45), Color(0xFF2449A5), Color(0xFF4568C4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE6A6), Color(0xFFE7BD65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: gold.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.person_rounded, color: navy, size: 33),
          ),
          const SizedBox(width: 17),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Keep your information accurate and up to date.',
                  style: TextStyle(
                    color: Color(0xFFDCE5FF),
                    fontSize: 13,
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

  // ------------------------------------------------------------
  // SECTION CARD
  // ------------------------------------------------------------

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color secondaryColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.17),
                      secondaryColor.withValues(alpha: 0.09),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.10),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        color: navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: mutedColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 2 : 1;
              const spacing = 16.0;

              final fieldWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: 19,
                children: children.map((child) {
                  return SizedBox(width: fieldWidth, child: child);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TEXT FIELD
  // ------------------------------------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool required = false,
    bool enabled = true,
    String? readOnlyReason,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              color: navy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(
            color: navy,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textCapitalization:
              label == 'Full Name' ||
                  label == 'State' ||
                  label == 'District' ||
                  label == 'City / Town'
              ? TextCapitalization.words
              : TextCapitalization.none,
          decoration: InputDecoration(
            hintText: hint,
            helperText: readOnlyReason,
            hintStyle: const TextStyle(
              color: Color(0xFFA0A8B8),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: _buildColorfulIcon(
              icon: icon,
              color: _fieldIconColor(label),
            ),
            filled: true,
            fillColor: fieldColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: royalBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: red, width: 1.5),
            ),
            errorStyle: const TextStyle(fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // DATE OF BIRTH
  // ------------------------------------------------------------

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',
          style: TextStyle(
            color: navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: _dobController,
          enabled: false,
          readOnly: true,
          onTap: _selectDateOfBirth,
          style: const TextStyle(
            color: navy,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Select date of birth',
            hintStyle: const TextStyle(color: Color(0xFFA0A8B8), fontSize: 13),
            prefixIcon: _buildColorfulIcon(
              icon: Icons.calendar_month_rounded,
              color: orange,
            ),
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: mutedColor,
              size: 22,
            ),
            filled: true,
            fillColor: fieldColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: royalBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // GENDER
  // ------------------------------------------------------------

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            color: navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          onChanged: null,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: mutedColor,
          ),
          style: const TextStyle(
            color: navy,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Not provided by profile API',
            helperText: 'Gender cannot be updated through the current API.',
            hintStyle: const TextStyle(color: Color(0xFFA0A8B8), fontSize: 13),
            prefixIcon: _buildColorfulIcon(icon: Icons.wc_rounded, color: pink),
            filled: true,
            fillColor: fieldColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: royalBlue, width: 1.5),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
            DropdownMenuItem(
              value: 'Prefer not to say',
              child: Text('Prefer not to say'),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // BUTTONS
  // ------------------------------------------------------------

  Widget _buildButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(125, 50),
            foregroundColor: navy,
            backgroundColor: Colors.white,
            side: const BorderSide(color: borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveDetails,
          style: ElevatedButton.styleFrom(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            disabledBackgroundColor: navy.withValues(alpha: 0.55),
            minimumSize: const Size(170, 50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 19),
          label: Text(
            _isSaving ? 'Saving...' : 'Save Details',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
