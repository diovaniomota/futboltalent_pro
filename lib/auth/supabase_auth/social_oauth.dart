import '/auth/supabase_auth/apple_auth.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart' show kIsWeb;

export 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

String get socialOAuthRedirectTo {
  if (kIsWeb) {
    return '${Uri.base.origin}/auth/callback';
  }
  return 'futboltalent://login-callback';
}

String socialProviderLabel(OAuthProvider provider) {
  if (provider == OAuthProvider.google) return 'Google';
  if (provider == OAuthProvider.apple) return 'Apple';
  return 'este proveedor';
}

Future<bool> signInWithSocialProvider(OAuthProvider provider) {
  const launchMode =
      kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;

  if (provider == OAuthProvider.apple) {
    return appleSignIn(
      redirectTo: socialOAuthRedirectTo,
      authScreenLaunchMode: launchMode,
    );
  }

  return SupaFlow.client.auth.signInWithOAuth(
    provider,
    redirectTo: socialOAuthRedirectTo,
    scopes: _scopesForProvider(provider),
    authScreenLaunchMode: launchMode,
    queryParams: _queryParamsForProvider(provider),
  );
}

String socialAuthLaunchErrorMessage(OAuthProvider provider) {
  final label = socialProviderLabel(provider);
  return 'No pudimos abrir el acceso con $label. Verifica tu conexión e intenta de nuevo.';
}

String socialAuthFriendlyErrorMessage(Object error, OAuthProvider provider) {
  final label = socialProviderLabel(provider);
  final text = error.toString().toLowerCase();

  if (_looksLikeProviderConfigurationError(text)) {
    return 'El acceso con $label no está disponible en este momento. Intenta de nuevo más tarde.';
  }

  return 'No pudimos conectarnos con $label. Verifica tu conexión e intenta de nuevo.';
}

bool isSocialAuthCanceled(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('canceled') ||
      text.contains('cancelled') ||
      text.contains('user_cancelled') ||
      text.contains('user cancelled') ||
      text.contains('authorizationerrorcode.canceled') ||
      text.contains('sign_in_with_apple_authorization_exception') &&
          text.contains('1001');
}

String? _scopesForProvider(OAuthProvider provider) {
  if (provider == OAuthProvider.google) return 'email profile';
  return null;
}

Map<String, String>? _queryParamsForProvider(OAuthProvider provider) {
  if (provider == OAuthProvider.google) {
    return const {'prompt': 'select_account'};
  }
  return null;
}

bool _looksLikeProviderConfigurationError(String text) {
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
      text.contains('missing') && text.contains('provider');
}
