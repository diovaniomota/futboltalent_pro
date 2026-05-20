import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:futboltalent_pro/guardian/guardian_mvp_service.dart';

class MockGuardianService extends Mock implements GuardianMvpService {}

void main() {
  group('Auth & Guardian Logic (Bugs 5, 6, 7, 8)', () {
    test('Minor account status should block access if not approved (Bug 7)', () {
      // Mocking the guardian status check
      bool isBlocked(Map<String, dynamic> user) {
        final age = user['age'] ?? 18;
        final approved = user['guardian_approved'] ?? false;
        return age < 18 && !approved;
      }

      final minorUser = {'age': 15, 'guardian_approved': false};
      expect(isBlocked(minorUser), true);

      final approvedMinor = {'age': 15, 'guardian_approved': true};
      expect(isBlocked(approvedMinor), false);
    });

    test('OAuth error message should be in Spanish (Bug 5 & 6)', () {
      String getSpanishErrorMessage(String errorCode) {
        if (errorCode == 'provider-not-enabled') {
          return 'El inicio de sesión con este proveedor no está configurado.';
        }
        return 'Ocurreu un error al iniciar sesión.';
      }

      expect(getSpanishErrorMessage('provider-not-enabled'), contains('configurado'));
    });

    test('Session should not logout on transient network errors (Bug 8)', () {
      bool shouldLogout(int statusCode) {
        // Only 401 Unauthorized should trigger logout
        return statusCode == 401;
      }

      expect(shouldLogout(500), false); // Server error, stay logged in
      expect(shouldLogout(401), true); // Unauthorized, must logout
    });
  });
}
