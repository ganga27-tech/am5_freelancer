abstract final class Validators {
  Validators._();

  static String? mobileNumber(String? value) {
    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return 'Mobile number is required';
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(input)) {
      return 'Enter a valid 10-digit mobile number';
    }

    return null;
  }

  static String? email(String? value) {
    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return 'Email address is required';
    }

    if (!RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@'
      r'[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
    ).hasMatch(input)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  static String? password(String? value) {
    final input = value ?? '';

    if (input.trim().isEmpty) {
      return 'Password is required';
    }

    if (input.length < 8) {
      return 'Password must contain at least 8 characters';
    }

    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    return null;
  }
}
