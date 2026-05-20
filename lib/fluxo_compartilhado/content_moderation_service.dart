import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';

/// Centralised content-moderation service.
///
/// Provides "Report video", "Report user" and "Block user" flows, storing
/// results in the `reported_content` and `blocked_users` Supabase tables.
/// This satisfies Apple Guideline 1.2 (User Generated Content).
class ContentModerationService {
  ContentModerationService._();

  // ── Cache ────────────────────────────────────────────────────────────
  static final Set<String> _blockedUserIds = {};

  /// Pre-load blocked user list (call once after login).
  static Future<void> loadBlockedUsers() async {
    final uid = currentUserUid;
    if (uid.isEmpty) return;
    try {
      final rows = await SupaFlow.client
          .from('blocked_users')
          .select('blocked_user_id')
          .eq('user_id', uid);
      _blockedUserIds.clear();
      for (final row in (rows as List)) {
        final blockedId = row['blocked_user_id']?.toString() ?? '';
        if (blockedId.isNotEmpty) _blockedUserIds.add(blockedId);
      }
    } catch (e) {
      debugPrint('ContentModeration: loadBlockedUsers failed: $e');
    }
  }

  /// Returns true if [userId] is blocked by the current user.
  static bool isBlocked(String userId) => _blockedUserIds.contains(userId);

  /// Clears cache (call on logout).
  static void clearCache() {
    _blockedUserIds.clear();
  }

  // ── Report video ─────────────────────────────────────────────────────

  static Future<void> _reportContent({
    required BuildContext context,
    required String contentId,
    required String contentType,
    required String? contentOwnerId,
  }) async {
    final uid = currentUserUid;
    if (uid.isEmpty) return;

    String? selectedReason;
    final reasons = contentType == 'video'
        ? [
            'Contenido inapropiado o violento',
            'Spam o publicidad no deseada',
            'Acoso o bullying',
            'Información falsa o engañosa',
            'Contenido sexual',
            'Violación de derechos de autor',
            'Otro',
          ]
        : [
            'Comportamiento abusivo o acoso',
            'Perfil falso o suplantación',
            'Spam o publicidad no deseada',
            'Contenido inapropiado',
            'Otro',
          ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              const Icon(Icons.flag_outlined,
                  color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  contentType == 'video'
                      ? 'Reportar video'
                      : 'Reportar usuario',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
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
                Text(
                  '¿Por qué querés reportar este ${contentType == 'video' ? 'video' : 'usuario'}?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 12),
                ...reasons.map((reason) => RadioListTile<String>(
                      title: Text(
                        reason,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      value: reason,
                      groupValue: selectedReason,
                      activeColor: const Color(0xFF0D3B66),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onChanged: (value) =>
                          setDialogState(() => selectedReason = value),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Enviar reporte',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedReason == null) return;

    try {
      await SupaFlow.client.from('reported_content').upsert(
        {
          'reporter_user_id': uid,
          'content_id': contentId,
          'content_type': contentType,
          'content_owner_id': contentOwnerId,
          'reason': selectedReason,
          'created_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'reporter_user_id,content_id,content_type',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              contentType == 'video'
                  ? 'Video reportado. Revisaremos tu reporte.'
                  : 'Usuario reportado. Revisaremos tu reporte.',
            ),
            backgroundColor: const Color(0xFF0F9D58),
          ),
        );
      }
    } catch (e) {
      debugPrint('ContentModeration: report failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo enviar el reporte. Intenta de nuevo.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Block user ───────────────────────────────────────────────────────

  static Future<bool> _blockUser({
    required BuildContext context,
    required String targetUserId,
    required String? targetUserName,
  }) async {
    final uid = currentUserUid;
    if (uid.isEmpty || uid == targetUserId) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            const Icon(Icons.block, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bloquear usuario',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que querés bloquear a ${targetUserName ?? 'este usuario'}?\n\n'
          'No verás más su contenido en tu feed.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF374151),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Bloquear',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await SupaFlow.client.from('blocked_users').upsert(
        {
          'user_id': uid,
          'blocked_user_id': targetUserId,
          'created_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,blocked_user_id',
      );
      _blockedUserIds.add(targetUserId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario bloqueado. No verás más su contenido.'),
            backgroundColor: Color(0xFF0F9D58),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('ContentModeration: block failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo bloquear al usuario. Intenta de nuevo.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // ── Bottom sheet (entry-point) ────────────────────────────────────────

  /// Shows a moderation bottom sheet for a video in the feed.
  /// Returns true if the user blocked the content owner (caller should
  /// refresh the feed to hide that user's videos).
  static Future<bool> showVideoModerationSheet({
    required BuildContext context,
    required String videoId,
    required String? videoOwnerId,
    required String? videoOwnerName,
  }) async {
    final uid = currentUserUid;
    if (uid.isEmpty) return false;
    // Don't show moderation options for own content
    if (uid == videoOwnerId) return false;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
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
                'Opciones',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              _ModerationOptionTile(
                icon: Icons.flag_outlined,
                title: 'Reportar video',
                subtitle: 'Este video viola las normas de la comunidad.',
                onTap: () =>
                    Navigator.of(sheetContext).pop('report_video'),
              ),
              const SizedBox(height: 8),
              if (videoOwnerId != null && videoOwnerId != uid) ...[
                _ModerationOptionTile(
                  icon: Icons.person_off_outlined,
                  title: 'Reportar usuario',
                  subtitle:
                      'Reportar a ${videoOwnerName ?? 'este usuario'} por comportamiento inadecuado.',
                  onTap: () =>
                      Navigator.of(sheetContext).pop('report_user'),
                ),
                const SizedBox(height: 8),
                _ModerationOptionTile(
                  icon: Icons.block,
                  title: 'Bloquear usuario',
                  subtitle:
                      'Dejar de ver el contenido de ${videoOwnerName ?? 'este usuario'}.',
                  onTap: () =>
                      Navigator.of(sheetContext).pop('block_user'),
                  isDestructive: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (action == null || !context.mounted) return false;

    switch (action) {
      case 'report_video':
        await _reportContent(
          context: context,
          contentId: videoId,
          contentType: 'video',
          contentOwnerId: videoOwnerId,
        );
        return false;

      case 'report_user':
        if (videoOwnerId != null) {
          await _reportContent(
            context: context,
            contentId: videoOwnerId,
            contentType: 'user',
            contentOwnerId: videoOwnerId,
          );
        }
        return false;

      case 'block_user':
        if (videoOwnerId != null) {
          return await _blockUser(
            context: context,
            targetUserId: videoOwnerId,
            targetUserName: videoOwnerName,
          );
        }
        return false;

      default:
        return false;
    }
  }
}

// ── Private widget ──────────────────────────────────────────────────────

class _ModerationOptionTile extends StatelessWidget {
  const _ModerationOptionTile({
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
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDestructive
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF0D3B66),
              ),
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
                      color: isDestructive
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
