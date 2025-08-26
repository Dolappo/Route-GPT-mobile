String? validateEmail(value) {
  if (value == null || value.isEmpty) {
    return 'Please enter an email';
  }

  // Regular expression for validating an email
  final RegExp emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  if (!emailRegExp.hasMatch(value)) {
    return 'Please enter a valid email';
  }

  return null;
}

String? validateLastName(val) {
  final digitRegex = RegExp(r'\d');
  if (val.isEmpty || val.length < 2) {
    return "Last Name is required";
  } else if (digitRegex.hasMatch(val)) {
    return 'Please enter a valid name';
  } else {
    return null;
  }
}

String? validateFirstName(val) {
  if (val.isEmpty || val.length < 2) {
    return "This field is required";
  } else {
    return null;
  }
}

String? validatePhoneNumber(value) {
  if (value == null || value.isEmpty || value.length < 10) {
    return 'Please enter a phone number';
  }

  return null;
}

String? validatePassword(password) {
  if (password == null || password.isEmpty) {
    return 'Password is required';
  }

  if (password.length < 8) {
    return 'Password must be at least 8 characters long';
  }

  if (!password.contains(RegExp(r'[A-Z]'))) {
    return 'Password must contain at least one uppercase letter';
  }

  if (!password.contains(RegExp(r'[a-z]'))) {
    return 'Password must contain at least one lowercase letter';
  }

  if (!password.contains(RegExp(r'\d'))) {
    return 'Password must contain at least one digit';
  }

  if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
    return 'Password must contain at least one special character';
  }

  return null;
}

String? validateDropdown(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please select a country';
  }
  return null;
}
