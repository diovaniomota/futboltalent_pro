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
  }

  return SupaFlow.client.auth.signInWithOAuth(
    OAuthProvider.apple,
    redirectTo: redirectTo,
    scopes: 'email name',
    authScreenLaunchMode: authScreenLaunchMode,
  );
}
