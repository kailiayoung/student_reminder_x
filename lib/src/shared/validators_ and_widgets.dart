String? emailValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email';
  }

  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  if (!emailRegex.hasMatch(value)) {
    return 'Please enter a valid email';
  }

  return null;
}

String? dueDateValidator(DateTime? selectedDate) {
  if (selectedDate == null) {
    return 'Please select a due date'; // Make due date required
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final selectedDay = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );

  // Check if date is in the past
  if (selectedDay.isBefore(today)) {
    return 'Due date cannot be in the past';
  }

  // Check if date is too far in the future (e.g., more than 5 years)
  final maxDate = today.add(Duration(days: 365 * 5));
  if (selectedDay.isAfter(maxDate)) {
    return 'Due date cannot be more than 5 years from now';
  }

  return null;
}

String? dateValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a date';
  }

  final RegExp regex = RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$');
  if (!regex.hasMatch(value)) {
    return 'Date must be in MM/YY format';
  }

  final parts = value.split('/');
  final int month = int.parse(parts[0]);
  final int year = int.parse('20${parts[1]}');

  final now = DateTime.now();
  final lastDayOfMonth = DateTime(year, month + 1, 0);

  if (lastDayOfMonth.isBefore(now)) {
    return 'Card is expired';
  }

  return null;
}

String? passwordValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a password';
  }

  if (value.length < 8) {
    return 'Password must be at least 8 characters long';
  }

  final hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
  final hasLowercase = RegExp(r'[a-z]').hasMatch(value);
  final hasSymbol = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value);

  if (!hasUppercase) {
    return 'Password must contain at least one uppercase letter';
  }
  if (!hasLowercase) {
    return 'Password must contain at least one lowercase letter';
  }
  if (!hasSymbol) {
    return 'Password must contain at least one special character';
  }

  return null;
}

String? validateNotEmpty(String? val) {
  return (val == null || val.trim().isEmpty)
      ? 'This field cannot be empty'
      : null;
}

String? phoneNumberValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a phone number';
  }

  final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
  if (!phoneRegex.hasMatch(value)) {
    return 'Please enter a valid phone number';
  }
  if (value.length < 10) {
    return 'Please enter a valid phone number';
  }

  return null;
}

String? confirmPasswordValidator(String? value, String? password) {
  if (value == null || value.isEmpty) {
    return 'Please confirm your password';
  }
  if (value != password) {
    return 'Passwords do not match';
  }
  return null;
}

// file picker
