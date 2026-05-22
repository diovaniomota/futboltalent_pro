import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:go_router/go_router.dart';
import '/backend/supabase/supabase.dart';
import '/app_state.dart';
import '/auth/supabase_auth/auth_util.dart';

/// Centralised account-deletion flow used by all user profiles (jugador,
/// profesional, club). Shows a confirmation dialog, deletes server-side data,
/// signs out and navigates to login.
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
  final TextEditingController _confirmationController = TextEditingController();
  bool _isDeleting = false;
  bool _confirmedOnce = false;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await SupaFlow.client.rpc('delete_own_account');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Account deletion error: $e');
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = _deleteAccountErrorMessage(e);
        });
      }
    }
  }

  String _deleteAccountErrorMessage(Object error) {
    final rawError = error.toString().toLowerCase();

    if (rawError.contains('delete_own_account') &&
        (rawError.contains('schema cache') ||
            rawError.contains('could not find') ||
            rawError.contains('pgrst202'))) {
      return 'La eliminación todavía no está configurada en el servidor. Aplicá la migración de eliminación e intentá de nuevo.';
    }

    if (rawError.contains('admin_delete_rows_by_text_values')) {
      return 'La migración de eliminación quedó incompleta en el servidor. Aplicá la versión actualizada e intentá de nuevo.';
    }

    if (rawError.contains('permission denied') ||
        rawError.contains('42501') ||
        rawError.contains('insufficient_privilege')) {
      return 'No tenés permiso para completar la eliminación. Revisá la migración y los permisos de la función.';
    }

    if (rawError.contains('auth_required') ||
        rawError.contains('jwt') ||
        rawError.contains('not authenticated') ||
        rawError.contains('401')) {
      return 'Tu sesión expiró. Iniciá sesión de nuevo y repetí la eliminación.';
    }

    return 'No se pudo eliminar la cuenta. Verifica tu conexión e intentá de nuevo.';
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
              const SizedBox(height: 14),
              Text(
                'Escribí ELIMINAR para confirmar.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmationController,
                enabled: !_isDeleting,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ELIMINAR',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFDC2626),
                      width: 2,
                    ),
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
                  onPressed:
                      _confirmationController.text.trim().toUpperCase() ==
                              'ELIMINAR'
                          ? _deleteAccount
                          : null,
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
