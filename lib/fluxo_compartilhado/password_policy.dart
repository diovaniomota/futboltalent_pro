class PasswordRule {
  const PasswordRule({
    required this.label,
    required this.isMet,
  });

  final String label;
  final bool isMet;
}

class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 8;
  static const int maxLength = 16;

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _number = RegExp(r'[0-9]');
  static final RegExp _special =
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/~]');

  static List<PasswordRule> rules(String password) {
    return [
      PasswordRule(
        label: '8 a 16 caracteres',
        isMet: password.length >= minLength && password.length <= maxLength,
      ),
      PasswordRule(
        label: 'Al menos una letra mayúscula',
        isMet: _uppercase.hasMatch(password),
      ),
      PasswordRule(
        label: 'Al menos una letra minúscula',
        isMet: _lowercase.hasMatch(password),
      ),
      PasswordRule(
        label: 'Al menos un número',
        isMet: _number.hasMatch(password),
      ),
      PasswordRule(
        label: 'Al menos un carácter especial',
        isMet: _special.hasMatch(password),
      ),
    ];
  }

  static bool isValid(String password) {
    return rules(password).every((rule) => rule.isMet);
  }

  static String? firstError(String password) {
    if (password.isEmpty) {
      return 'Por favor ingresa una contraseña';
    }
    if (password.length < minLength || password.length > maxLength) {
      return 'La contraseña debe tener entre 8 y 16 caracteres';
    }
    if (!_uppercase.hasMatch(password)) {
      return 'La contraseña debe contener al menos una letra mayúscula';
    }
    if (!_lowercase.hasMatch(password)) {
      return 'La contraseña debe contener al menos una letra minúscula';
    }
    if (!_number.hasMatch(password)) {
      return 'La contraseña debe contener al menos un número';
    }
    if (!_special.hasMatch(password)) {
      return 'La contraseña debe contener al menos un carácter especial';
    }
    return null;
  }
}
