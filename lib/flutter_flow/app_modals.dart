import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/app_state.dart';

Future<void> showBlockedActionDialog(
  BuildContext context, {
  required String message,
  String title = _defaultBlockedActionTitle,
  String confirmLabel = 'Entendido',
  String? secondaryLabel,
  VoidCallback? onConfirm,
  VoidCallback? onSecondary,
}) {
  final resolvedTitle = title == _defaultBlockedActionTitle
      ? FFAppState().uiText(
          'blocked_action_title',
          fallback: _defaultBlockedActionTitle,
        )
      : title;
  final resolvedMessage = message == _defaultBlockedActionMessage
      ? FFAppState().uiText(
          'blocked_action_message',
          fallback: _defaultBlockedActionMessage,
        )
      : message;

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 26,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF0D3B66),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    resolvedTitle,
                    style: GoogleFonts.inter(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              resolvedMessage,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF4B5563),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _requirementRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Cuenta verificada',
                  ),
                  const SizedBox(height: 8),
                  _requirementRow(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Plan activo',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (secondaryLabel == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    onConfirm?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFF0D3B66),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    confirmLabel,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        onSecondary?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        secondaryLabel,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        onConfirm?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: const Color(0xFF0D3B66),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showPlanRequiredDialog(
  BuildContext context, {
  required String featureName,
  String title = 'Plano Pro necessário',
  String? message,
  String confirmLabel = 'Entendi',
}) {
  final resolvedMessage = message ??
      '$featureName faz parte do Plano Pro. Se o modo piloto estiver ON, o bloqueio some automaticamente.';

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: PlanPaywallCard(
        title: title,
        message: resolvedMessage,
        actionLabel: confirmLabel,
        onAction: () => Navigator.pop(dialogContext),
      ),
    ),
  );
}

const String _defaultBlockedActionTitle = 'Accion bloqueada';
const String _defaultBlockedActionMessage =
    'Para acciones sensibles necesitas cuenta verificada y plan activo.';

class PlanPaywallCard extends StatelessWidget {
  const PlanPaywallCard({
    super.key,
    required this.title,
    required this.message,
    this.badge = 'PLANO PRO',
    this.actionLabel = 'Entendi',
    this.onAction,
  });

  final String title;
  final String message;
  final String badge;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFB7791F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB7791F),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF4B5563),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _requirementRow(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Feed, vídeos e Explorer ficam liberados no Free',
                ),
                const SizedBox(height: 8),
                _requirementRow(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Desafios, cursos e convocatórias ficam no Pro',
                ),
              ],
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: const Color(0xFF0D3B66),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _requirementRow({required IconData icon, required String label}) {
  return Row(
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FC),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF0D3B66),
          size: 15,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
      ),
    ],
  );
}
