import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';

import '/backend/supabase/supabase.dart';
import '../base_auth_user_provider.dart';

export '../base_auth_user_provider.dart';

class FutboltalentProSupabaseUser extends BaseAuthUser {
  FutboltalentProSupabaseUser(this.user);
  User? user;
  @override
  bool get loggedIn => user != null;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(
        uid: user?.id,
        email: user?.email,
        phoneNumber: user?.phone,
      );

  @override
  Future? delete() =>
      throw UnsupportedError('The delete user operation is not yet supported.');

  @override
  Future? updateEmail(String email) async {
    final response =
        await SupaFlow.client.auth.updateUser(UserAttributes(email: email));
    if (response.user != null) {
      user = response.user;
    }
  }

  @override
  Future? updatePassword(String newPassword) async {
    final response = await SupaFlow.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    if (response.user != null) {
      user = response.user;
    }
  }

  @override
  Future? sendEmailVerification() => throw UnsupportedError(
      'The send email verification operation is not yet supported.');

  @override
  bool get emailVerified {
    // Reloads the user when checking in order to get the most up to date
    // email verified status.
    if (loggedIn && user!.emailConfirmedAt == null) {
      refreshUser();
    }
    return user?.emailConfirmedAt != null;
  }

  @override
  Future refreshUser() async {
    await SupaFlow.client.auth
        .refreshSession()
        .then((_) => user = SupaFlow.client.auth.currentUser);
  }
}

/// Generates a stream of the authenticated user.
/// Seeds the stream with Supabase's current user so an already restored session
/// is available before the next auth event arrives.
Stream<BaseAuthUser> futboltalentProSupabaseUserStream() {
  final restoredUser =
      FutboltalentProSupabaseUser(SupaFlow.client.auth.currentUser);
  currentUser = restoredUser;

  final supabaseAuthStream = SupaFlow.client.auth.onAuthStateChange.debounce(
      (authState) => authState.event == AuthChangeEvent.tokenRefreshed
          ? TimerStream(authState, const Duration(seconds: 1))
          : Stream.value(authState));
  return Stream<BaseAuthUser>.value(restoredUser).concatWith([
    supabaseAuthStream.map<BaseAuthUser>(
      (authState) {
        currentUser = FutboltalentProSupabaseUser(authState.session?.user);
        return currentUser!;
      },
    ).handleError((error, stackTrace) {
      debugPrint('Supabase auth stream error: $error');
    }),
  ]);
}
