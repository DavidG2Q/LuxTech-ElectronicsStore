class Validators {
  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    if (value.length < 3) {
      return 'Password length should be at least 3 characters';
    }
    return null;
  }

  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }
    
    // Email format validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    
    // Check for lowercase letter
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    
    // Check for uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    
    // Check for number
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    
    // Check for special character
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    
    return null;
  }

  // Password validation for login (less strict)
  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the password';
    }
    
    if (value.length < 6) {
      return 'Invalid Password';
    }
    
    return null;
  }

  // Password match validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please Confirm your password';
    }
    
    if (value != password) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  // Validate building number
  static String? validateBuilding(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your building info';
    }
    return null;
  }

  // Validate phone number format
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    // Format phone number to ensure 01xxxxxxxxx format
    final cleanNumber = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length != 11) {
      return 'Phone number must be exactly 11 digits';
    }
    if (!cleanNumber.startsWith('01')) {
      return 'Phone number must start with 01';
    }
    // Check for valid Egyptian mobile prefixes
    final validPrefixes = ['010', '011', '012', '015'];
    final prefix = cleanNumber.substring(0, 3);
    if (!validPrefixes.contains(prefix)) {
      return 'Phone number must start with 010, 011, 012, or 015';
    }
    return null;
  }
}

