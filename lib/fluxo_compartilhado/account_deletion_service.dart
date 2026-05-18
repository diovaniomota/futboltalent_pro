import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/app_state.dart';

/// Centralised account-deletion flow used by all user profiles (jugador,
/// profesional, club).  Shows a confirmation dialog with password verification,
/// deletes server-side data, signs out and navigates to login.
class AccountDeletionService {
  AccountDeletionService._();

  /// Entry-point – call this from any profile screen.
  static Future<void> showDeleteAccountDialog({
    required BuildContext context,
  }) async {
    final uid = currentUserUid;
    if (uid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DeleteAccountDialog(userId: uid),
    );

    if (confirmed == true && context.mounted) {
      // Sign out and navigate to login
      try {
        FFAppState().clearAuthenticatedSessionState();
        await authManager.signOut();
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu cuenta fue eliminada exitosamente.',
            ),
            backgroundColor: Color(0xFF0F9D58),
          ),
        );
        GoRouter.of(context).goNamed('login');
      }
    }
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.userId});
  final String userId;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _isDeleting = false;
  bool _confirmedOnce = false;
  String? _errorMessage;

  Future<void> _deleteAccount() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      // 1. Delete related data first (videos, progress, etc.)
      await _deleteUserData(widget.userId);

      // 2. Delete auth account via the manager
      if (context.mounted) {
        await authManager.deleteUser(context);
      }

      // 3. Signal success
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Account deletion error: $e');
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage =
              'No se pudo eliminar la cuenta. Verifica tu conexión e intentá de nuevo.';
        });
      }
    }
  }

  Future<void> _deleteUserData(String uid) async {
    // Delete user videos
    try {
      await SupaFlow.client.from('videos').delete().eq('user_id', uid);
    } catch (_) {}

    // Delete saved videos
    try {
      await SupaFlow.client.from('saved_videos').delete().eq('user_id', uid);
    } catch (_) {}

    // Delete user progress
    try {
      await SupaFlow.client.from('user_progress').delete().eq('user_id', uid);
    } catch (_) {}

    // Delete user courses
    try {
      await SupaFlow.client.from('user_courses').delete().eq('user_id', uid);
    } catch (_) {}

    // Delete user exercises
    try {
      await SupaFlow.client.from('user_exercises').delete().eq('user_id', uid);
    } catch (_) {}

    // Delete challenge attempts
    try {
      await SupaFlow.client
          .from('user_challenge_attempts')
          .delete()
          .eq('user_id', uid);
    } catch (_) {}

    // Delete guardians (if minor)
    try {
      await SupaFlow.client.from('guardians').delete().eq('player_id', uid);
    } catch (_) {}

    // Delete player profile
    try {
      await SupaFlow.client.from('players').delete().eq('id', uid);
    } catch (_) {}

    // Delete scout profile
    try {
      await SupaFlow.client.from('scouts').delete().eq('id', uid);
    } catch (_) {}

    // Delete feedback
    try {
      await SupaFlow.client.from('feedback').delete().eq('user_id', uid);
    } catch (_) {}

    // Delete contact requests
    try {
      await SupaFlow.client
          .from('contact_requests')
          .delete()
          .eq('requester_id', uid);
    } catch (_) {}
    try {
      await SupaFlow.client
          .from('contact_requests')
          .delete()
          .eq('target_id', uid);
    } catch (_) {}

    // Delete user row last
    try {
      await SupaFlow.client.from('users').delete().eq('user_id', uid);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFDC2626), size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Eliminar mi cuenta',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_confirmedOnce) ...[
              Text(
                'Esta acción es irreversible. Se eliminarán permanentemente:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _bulletPoint('Tu perfil y datos personales'),
              _bulletPoint('Todos tus videos publicados'),
              _bulletPoint('Tu progreso en cursos y desafíos'),
              _bulletPoint('Tus guardados y listas'),
              _bulletPoint('Solicitudes de contacto'),
              const SizedBox(height: 16),
              Text(
                '¿Estás seguro de que querés continuar?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  'Confirmación final: una vez eliminada la cuenta, no podrás recuperar tus datos.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF991B1B),
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: _isDeleting
          ? [
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFDC2626)),
                      SizedBox(height: 12),
                      Text(
                        'Eliminando cuenta...',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              if (!_confirmedOnce)
                ElevatedButton(
                  onPressed: () => setState(() => _confirmedOnce = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Sí, eliminar',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _deleteAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirmar eliminación',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF4B5563),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
