import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/password_policy.dart';

void main() {
  group('PasswordPolicy', () {
    test('accepts passwords that meet every account creation rule', () {
      expect(PasswordPolicy.isValid('Futbol#2026'), isTrue);
      expect(PasswordPolicy.firstError('Futbol#2026'), isNull);
    });

    test('rejects common weak password compositions from the start', () {
      expect(PasswordPolicy.isValid('Sho1A!'), isFalse);
      expect(PasswordPolicy.isValid('futbol#2026'), isFalse);
      expect(PasswordPolicy.isValid('FUTBOL#2026'), isFalse);
      expect(PasswordPolicy.isValid('FutbolTalent!'), isFalse);
      expect(PasswordPolicy.isValid('Futbol2026'), isFalse);
      expect(PasswordPolicy.isValid('FutbolTalent#2026'), isFalse);
    });

    test('exposes all visible checklist rules', () {
      final labels = PasswordPolicy.rules('').map((rule) => rule.label);

      expect(labels, contains('8 a 16 caracteres'));
      expect(labels, contains('Al menos una letra mayúscula'));
      expect(labels, contains('Al menos una letra minúscula'));
      expect(labels, contains('Al menos un número'));
      expect(labels, contains('Al menos un carácter especial'));
    });
  });
}
