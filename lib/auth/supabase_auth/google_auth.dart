import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '/backend/supabase/supabase.dart';

const String _googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue:
      '624671008647-a9htsutbbfd0mfc4qp4bsv3rpekbbarn.apps.googleusercontent.com',
);
const String _googleIosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
);

bool get _isApplePlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

Future<bool> nativeGoogleSignIn() async {
  if (kIsWeb) return false;

  if (_googleWebClientId.trim().isEmpty) {
    throw const AuthException('missing_google_web_client_id');
  }

  if (_isApplePlatform && _googleIosClientId.trim().isEmpty) {
    throw const AuthException('missing_google_ios_client_id');
  }

  final googleSignIn = GoogleSignIn(
    clientId: _isApplePlatform ? _googleIosClientId : null,
    serverClientId: _googleWebClientId,
    scopes: const ['email', 'profile'],
  );

  // Forces the native account picker instead of silently reusing a prior
  // Google account.
  await googleSignIn.signOut();

  final googleUser = await googleSignIn.signIn();
  if (googleUser == null) return false;

  final googleAuth = await googleUser.authentication;
  final idToken = googleAuth.idToken;
  final accessToken = googleAuth.accessToken;

  if (idToken == null || idToken.isEmpty) {
    throw const AuthException('missing_google_id_token');
  }

  // ignore: experimental_member_use
  final response = await SupaFlow.client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: accessToken,
  );

  return response.session != null;
}
