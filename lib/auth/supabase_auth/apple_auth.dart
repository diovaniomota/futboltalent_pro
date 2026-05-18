import 'dart:convert';

import '/backend/supabase/supabase.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

bool get _canUseNativeAppleSignIn {
  return !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
}

Future<bool> appleSignIn({
  String? redirectTo,
  LaunchMode authScreenLaunchMode = LaunchMode.platformDefault,
}) async {
  if (_canUseNativeAppleSignIn && await SignInWithApple.isAvailable()) {
    try {
      final rawNonce = SupaFlow.client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('No pudimos obtener la credencial de Apple.');
      }

      // ignore: experimental_member_use
      await SupaFlow.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      return SupaFlow.client.auth.currentSession != null;
    } catch (error) {
      if (!_shouldFallbackToAppleOAuth(error)) {
        rethrow;
      }
    }
  }

  return _appleOAuthSignIn(
    redirectTo: redirectTo,
    authScreenLaunchMode: authScreenLaunchMode,
  );
}

Future<bool> _appleOAuthSignIn({
  required String? redirectTo,
  required LaunchMode authScreenLaunchMode,
}) {
  return SupaFlow.client.auth.signInWithOAuth(
    OAuthProvider.apple,
    redirectTo: redirectTo,
    scopes: 'email name',
    authScreenLaunchMode: authScreenLaunchMode,
  );
}

bool _shouldFallbackToAppleOAuth(Object error) {
  final text = error.toString().toLowerCase();
  if (_isCanceledAppleSignIn(text)) {
    return false;
  }

  return _looksLikeAppleProviderConfigurationError(text) ||
      text.contains('identity token') ||
      text.contains('id token') ||
      text.contains('token audience') ||
      text.contains('unacceptable audience') ||
      text.contains('audience') ||
      text.contains('client_id') ||
      text.contains('bundle id') ||
      text.contains('not available') ||
      text.contains('failed') ||
      text.contains('unknown');
}

bool _looksLikeAppleProviderConfigurationError(String text) {
  return text.contains('not enabled') ||
      text.contains('not configured') ||
      text.contains('provider is disabled') ||
      text.contains('provider not enabled') ||
      text.contains('oauth provider') ||
      text.contains('unauthorized_client') ||
      text.contains('invalid_client') ||
      text.contains('invalid redirect') ||
      text.contains('redirect_uri') ||
      text.contains('client_id') ||
      text.contains('bundle id') ||
      text.contains('unacceptable audience') ||
      text.contains('missing') && text.contains('provider');
}

bool _isCanceledAppleSignIn(String text) {
  return text.contains('canceled') ||
      text.contains('cancelled') ||
      text.contains('user_cancelled') ||
      text.contains('user cancelled') ||
      text.contains('authorizationerrorcode.canceled') ||
      text.contains('sign_in_with_apple_authorization_exception') &&
          text.contains('1001');
}
