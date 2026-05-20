import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/auth/supabase_auth/social_oauth.dart';

void main() {
  group('social oauth error handling', () {
    test('detects Apple provider configuration errors', () {
      expect(
        looksLikeSocialProviderConfigurationError(
          'invalid_client: unacceptable audience for bundle id pro.futboltalent.app',
        ),
        isTrue,
      );
    });

    test('returns generic unavailable message for provider setup issues', () {
      final message = socialAuthFriendlyErrorMessage(
        'invalid_client: unacceptable audience for bundle id pro.futboltalent.app',
        OAuthProvider.apple,
      );

      expect(message, contains('no está disponible'));
      expect(message, isNot(contains('detalles:')));
    });

    test('keeps details for unexpected social auth failures', () {
      final message = socialAuthFriendlyErrorMessage(
        Exception('timeout while connecting'),
        OAuthProvider.apple,
      );

      expect(message, contains('Detalles:'));
      expect(message, contains('timeout while connecting'));
    });
  });
}
