import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/fluxo_compartilhado/account_deletion_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

enum _ProfileSupportAction { editProfile, feedback, signOut, deleteAccount }

Future<void> showProfileSupportSheet({
  required BuildContext context,
  required String userId,
  required String screenName,
  required VoidCallback onEditProfile,
}) async {
  final action = await showModalBottomSheet<_ProfileSupportAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final mediaQuery = MediaQuery.of(sheetContext);

      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Perfil y soporte',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Administrá tu perfil, sesión y datos de la cuenta.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                _SupportActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Editar perfil',
                  subtitle: 'Actualizá tus datos visibles en la app.',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(_ProfileSupportAction.editProfile),
                ),
                const SizedBox(height: 10),
                _SupportActionTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Reportar error o sugerencia',
                  subtitle: 'Mandanos feedback desde esta pantalla.',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(_ProfileSupportAction.feedback),
                ),
                const SizedBox(height: 10),
                _SupportActionTile(
                  icon: Icons.logout_rounded,
                  title: 'Cerrar sesión',
                  subtitle: 'Salí de tu cuenta en este dispositivo.',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(_ProfileSupportAction.signOut),
                ),
                const SizedBox(height: 10),
                _SupportActionTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Eliminar mi cuenta',
                  subtitle: 'Borrá tu cuenta y todos tus datos de la app.',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(_ProfileSupportAction.deleteAccount),
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (!context.mounted || action == null) {
    return;
  }

  if (action == _ProfileSupportAction.editProfile) {
    onEditProfile();
    return;
  }

  if (action == _ProfileSupportAction.feedback) {
    await _showFeedbackDialog(
      context: context,
      userId: userId,
      screenName: screenName,
    );
    return;
  }

  if (action == _ProfileSupportAction.signOut) {
    try {
      await authManager.signOut();
    } catch (_) {}
    if (context.mounted) {
      context.goNamed('login');
    }
    return;
  }

  if (action == _ProfileSupportAction.deleteAccount) {
    await AccountDeletionService.showDeleteAccountDialog(context: context);
  }
}

Future<void> _showFeedbackDialog({
  required BuildContext context,
  required String userId,
  required String screenName,
}) async {
  final controller = TextEditingController();
  var selectedType = 'error';
  var isSaving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submitFeedback() async {
            final message = controller.text.trim();
            if (message.isEmpty || isSaving) {
              return;
            }

            setDialogState(() => isSaving = true);
            try {
              await SupaFlow.client.from('feedback').insert({
                'user_id': userId,
                'mensaje': message,
                'pantalla': screenName,
                'tipo': selectedType,
                'created_at': DateTime.now().toIso8601String(),
              });

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gracias. Tu feedback fue enviado.'),
                    backgroundColor: Color(0xFF0F9D58),
                  ),
                );
              }
            } catch (_) {
              setDialogState(() => isSaving = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo enviar el feedback.'),
                  ),
                );
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              'Reportar error o sugerencia',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contanos qué pasó o qué te gustaría mejorar.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tipo',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Error'),
                        selected: selectedType == 'error',
                        onSelected: isSaving
                            ? null
                            : (_) {
                                setDialogState(() => selectedType = 'error');
                              },
                      ),
                      ChoiceChip(
                        label: const Text('Sugerencia'),
                        selected: selectedType == 'sugerencia',
                        onSelected: isSaving
                            ? null
                            : (_) {
                                setDialogState(
                                  () => selectedType = 'sugerencia',
                                );
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    minLines: 4,
                    maxLines: 6,
                    enabled: !isSaving,
                    onChanged: (_) {
                      setDialogState(() {});
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Ej.: al abrir esta pantalla no carga mi perfil, o me gustaría ver otra opción acá.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF0D3B66)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                      },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isSaving || controller.text.trim().isEmpty
                    ? null
                    : submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enviar'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
}

class _SupportActionTile extends StatelessWidget {
  const _SupportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isDestructive ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDestructive
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDestructive
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon,
                  color: isDestructive
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF0D3B66)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
