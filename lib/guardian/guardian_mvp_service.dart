import 'dart:math';

import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/video_visibility_utils.dart';
import '/fluxo_compartilhado/email_service.dart';

class GuardianMvpService {
  static const String pendingStatus = 'pending';
  static const String approvedStatus = 'approved';
  static const String rejectedStatus = 'rejected';
  static const String limitedVisibility = 'limited';
  static const String activeVisibility = 'active';

  static final List<RegExp> _blockedPublicPatterns = <RegExp>[
    RegExp(r'whats?\s*app', caseSensitive: false),
    RegExp(r'\binstagram\b|\binsta\b', caseSensitive: false),
    RegExp(r'\btelegram\b|\bt\.me\b', caseSensitive: false),
    RegExp(r'https?://|www\.', caseSensitive: false),
    RegExp(
      r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
      caseSensitive: false,
    ),
    RegExp(r'@[A-Za-z0-9_.]{2,}', caseSensitive: false),
    RegExp(r'\+?\d[\d\s().-]{7,}\d'),
    RegExp(r'\b\d{7,}\b'),
  ];

  static String generateApprovalCode() {
    final random = Random.secure();
    final buffer = StringBuffer('RESP-');
    for (var index = 0; index < 6; index++) {
      buffer.write(random.nextInt(10));
    }
    return buffer.toString();
  }

  static String _newApprovalExpiryIso() {
    return DateTime.now()
        .toUtc()
        .add(const Duration(days: 7))
        .toIso8601String();
  }

  static bool _isCodeExpired(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return true;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return true;
    return !parsed.toUtc().isAfter(DateTime.now().toUtc());
  }

  static String normalizedGuardianStatus(Map<String, dynamic>? userData) {
    final raw = userData?['guardian_status']?.toString().trim().toLowerCase();
    if (raw == pendingStatus ||
        raw == approvedStatus ||
        raw == rejectedStatus) {
      return raw!;
    }

    final isMinor = userData?['is_minor'] == true;
    if (!isMinor) return approvedStatus;

    final hasGuardian = userData?['has_guardian'] == true;
    return hasGuardian ? pendingStatus : 'missing';
  }

  static String normalizedVisibilityStatus(Map<String, dynamic>? userData) {
    final raw = userData?['visibility_status']?.toString().trim().toLowerCase();
    if (raw == limitedVisibility || raw == activeVisibility) {
      return raw!;
    }

    final isMinor = userData?['is_minor'] == true;
    if (!isMinor) return activeVisibility;

    if (!(userData?.containsKey('guardian_status') ?? false) &&
        !(userData?.containsKey('visibility_status') ?? false)) {
      return activeVisibility;
    }

    return normalizedGuardianStatus(userData) == approvedStatus
        ? activeVisibility
        : limitedVisibility;
  }

  static String normalizedVideoModerationStatus(
    Map<String, dynamic>? videoData,
  ) {
    final raw =
        videoData?['moderation_status']?.toString().trim().toLowerCase();
    if (raw == pendingStatus ||
        raw == approvedStatus ||
        raw == rejectedStatus) {
      return raw!;
    }
    return approvedStatus;
  }

  static bool isLimitedProfile(Map<String, dynamic>? userData) {
    return normalizedVisibilityStatus(userData) == limitedVisibility;
  }

  static bool isVideoVisibleToPublic(
    Map<String, dynamic> videoData, {
    Map<String, dynamic>? ownerData,
  }) {
    if (!isPublicVideoCandidate(videoData)) return false;
    if (isLimitedProfile(ownerData)) return false;
    return normalizedVideoModerationStatus(videoData) == approvedStatus;
  }

  static String moderationStatusForUser(Map<String, dynamic>? userData) {
    return isLimitedProfile(userData) ? pendingStatus : approvedStatus;
  }

  static String? validatePublicText(String? text) {
    final normalized = text?.trim() ?? '';
    if (normalized.isEmpty) return null;

    for (final pattern in _blockedPublicPatterns) {
      if (pattern.hasMatch(normalized)) {
        return 'No podés publicar datos de contacto directos en texto público. Quitá WhatsApp, Instagram, arrobas, links o teléfonos.';
      }
    }
    return null;
  }

  static String? validatePublicFields(Iterable<String?> values) {
    for (final value in values) {
      final error = validatePublicText(value);
      if (error != null) return error;
    }
    return null;
  }

  static Future<Map<String, dynamic>> approveGuardianCode(
    String code, {
    String? playerId,
    String? guardianEmail,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw Exception('Ingresá el código del responsable.');
    }

    final currentUid = SupaFlow.client.auth.currentUser?.id ?? '';
    var uid = (playerId ?? '').trim();
    if (uid.isEmpty && currentUid.isNotEmpty) {
      uid = currentUid.trim();
    }
    var guardianEmailNormalized = (guardianEmail ?? '').trim().toLowerCase();
    Map<String, dynamic>? guardianInfo;

    if (guardianEmailNormalized.isEmpty && uid.isNotEmpty) {
      guardianInfo = await fetchGuardianInfo(uid);
      guardianEmailNormalized =
          guardianInfo?['email']?.toString().trim().toLowerCase() ?? '';
    }

    if (guardianEmailNormalized.isEmpty) {
      throw Exception('guardian_email_required');
    }

    // Try RPC first
    try {
      final response = await SupaFlow.client.rpc(
        'approve_guardian_by_code',
        params: <String, dynamic>{
          'p_approval_code': normalized,
          'p_player_id': uid,
          'p_guardian_email': guardianEmailNormalized,
        },
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      if (response is List && response.isNotEmpty && response.first is Map) {
        return Map<String, dynamic>.from(response.first as Map);
      }
      return <String, dynamic>{};
    } catch (rpcError) {
      final rpcMessage = rpcError.toString().toLowerCase();
      if (rpcMessage.contains('approval_code_not_found') ||
          rpcMessage.contains('approval_context_required') ||
          rpcMessage.contains('approval_code_expired') ||
          rpcMessage.contains('approval_code_used') ||
          rpcMessage.contains('guardian_email_required') ||
          rpcMessage.contains('approval_not_pending') ||
          rpcMessage.contains('approval_player_not_pending')) {
        rethrow;
      }
      if (!rpcMessage.contains('approve_guardian_by_code') &&
          !rpcMessage.contains('could not find the function') &&
          !rpcMessage.contains('42883') &&
          !rpcMessage.contains('does not exist')) {
        rethrow;
      }
    }

    if (guardianInfo == null && uid.isNotEmpty) {
      guardianInfo = await fetchGuardianInfo(uid);
    }
    if (guardianInfo == null) {
      throw Exception('approval_context_required');
    }

    final storedGuardianEmail =
        guardianInfo['email']?.toString().trim().toLowerCase() ?? '';
    if (storedGuardianEmail != guardianEmailNormalized) {
      throw Exception('approval_code_not_found');
    }

    final status = guardianInfo['status']?.toString().trim().toLowerCase() ??
        pendingStatus;
    final storedCode =
        guardianInfo['approval_code']?.toString().trim().toUpperCase() ?? '';
    final usedAt = guardianInfo['approval_code_used_at']?.toString().trim();

    if (status != pendingStatus) {
      throw Exception('approval_not_pending');
    }
    if (usedAt != null && usedAt.isNotEmpty) {
      throw Exception('approval_code_used');
    }
    if (_isCodeExpired(guardianInfo['approval_code_expires_at'])) {
      throw Exception('approval_code_expired');
    }
    if (storedCode != normalized) {
      throw Exception('approval_code_not_found');
    }

    return _manualApprove(Map<String, dynamic>.from(guardianInfo));
  }

  static Future<Map<String, dynamic>> _manualApprove(
    Map<String, dynamic> guardianRow,
  ) async {
    final guardianId = guardianRow['id']?.toString() ?? '';
    final playerId = guardianRow['player_id']?.toString() ?? '';

    if (guardianId.isEmpty || playerId.isEmpty) {
      throw Exception('approval_code_not_found');
    }

    // Update guardian status
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await SupaFlow.client.from('guardians').update({
        'status': approvedStatus,
        'approved_at': nowIso,
        'approval_code_used_at': nowIso,
        'approval_code': null,
      }).eq('id', guardianId);
    } catch (_) {
      // Fallback without approved_at
      await SupaFlow.client.from('guardians').update({
        'status': approvedStatus,
      }).eq('id', guardianId);
    }

    // Update user status
    try {
      await SupaFlow.client.from('users').update({
        'guardian_status': approvedStatus,
        'visibility_status': activeVisibility,
        'has_guardian': true,
      }).eq('user_id', playerId);
    } catch (_) {
      try {
        await SupaFlow.client.from('users').update({
          'guardian_status': approvedStatus,
          'has_guardian': true,
        }).eq('user_id', playerId);
      } catch (_) {
        await SupaFlow.client
            .from('users')
            .update({'has_guardian': true}).eq('user_id', playerId);
      }
    }

    // Approve pending videos
    try {
      await SupaFlow.client
          .from('videos')
          .update({'moderation_status': approvedStatus})
          .eq('user_id', playerId)
          .eq('moderation_status', pendingStatus);
    } catch (_) {}

    return <String, dynamic>{
      'player_id': playerId,
      'guardian_id': guardianId,
      'status': approvedStatus,
    };
  }

  /// 1.3 — Regenera o código de aprovação e atualiza no banco.
  /// Retorna o novo código gerado.
  static Future<String> resendGuardianCode(String playerId) async {
    final uid = playerId.trim();
    if (uid.isEmpty) {
      throw Exception('ID del jugador no proporcionado.');
    }

    final newCode = generateApprovalCode();
    try {
      await SupaFlow.client.from('guardians').update({
        'approval_code': newCode,
        'approval_code_expires_at': _newApprovalExpiryIso(),
        'approval_code_used_at': null,
        'approved_at': null,
        'status': pendingStatus,
      }).eq('player_id', uid);
    } catch (e) {
      // Fallback: tenta sem campo status
      await SupaFlow.client.from('guardians').update({
        'approval_code': newCode,
      }).eq('player_id', uid);
    }

    String guardianEmail = '';
    try {
      final gRow = await SupaFlow.client
          .from('guardians')
          .select('email')
          .eq('player_id', uid)
          .maybeSingle();
      if (gRow != null) guardianEmail = gRow['email']?.toString() ?? '';
    } catch (_) {}

    if (guardianEmail.isNotEmpty) {
      String playerName = 'Jugador';
      try {
        final uRow = await SupaFlow.client
            .from('users')
            .select('display_name, name')
            .eq('user_id', uid)
            .maybeSingle();
        if (uRow != null) {
          playerName = (uRow['display_name'] ?? uRow['name'])?.toString() ??
              playerName;
        }
      } catch (_) {}

      await EmailService.sendGuardianValidationEmail(
        playerId: uid,
        guardianEmail: guardianEmail,
        playerName: playerName,
        approvalCode: newCode,
      );
    }

    return newCode;
  }

  /// 1.3 — Atualiza o e-mail do responsável para um jogador menor.
  /// Regenerates the approval code so the new email receives a fresh code.
  /// Returns a user-friendly success message.
  static Future<String?> updateGuardianEmail({
    String? playerId,
    required String newEmail,
  }) async {
    final email = newEmail.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      throw Exception('Ingresá un email válido del responsable.');
    }

    // Resolve player ID: if not provided, look up from current user
    var uid = (playerId ?? '').trim();
    if (uid.isEmpty) {
      // Try to find a guardian entry where the current session user is the player
      try {
        final currentUid = SupaFlow.client.auth.currentUser?.id ?? '';
        if (currentUid.isNotEmpty) {
          uid = currentUid;
        }
      } catch (_) {}
    }
    if (uid.isEmpty) {
      throw Exception('No se pudo identificar al jugador.');
    }

    final newCode = generateApprovalCode();
    try {
      await SupaFlow.client.from('guardians').update({
        'email': email,
        'approval_code': newCode,
        'approval_code_expires_at': _newApprovalExpiryIso(),
        'approval_code_used_at': null,
        'approved_at': null,
        'status': pendingStatus,
      }).eq('player_id', uid);
    } catch (_) {
      // Fallback without status field
      await SupaFlow.client.from('guardians').update({
        'email': email,
        'approval_code': newCode,
      }).eq('player_id', uid);
    }

    String playerName = 'Jugador';
    try {
      final uRow = await SupaFlow.client
          .from('users')
          .select('display_name, name')
          .eq('user_id', uid)
          .maybeSingle();
      if (uRow != null) {
        playerName =
            (uRow['display_name'] ?? uRow['name'])?.toString() ?? playerName;
      }
    } catch (_) {}

    final sent = await EmailService.sendGuardianValidationEmail(
      playerId: uid,
      guardianEmail: email,
      playerName: playerName,
      approvalCode: newCode,
    );

    if (!sent) {
      throw Exception('guardian_email_send_failed');
    }

    return 'Correo actualizado. Enviamos un nuevo código de aprobación a $email.';
  }

  /// 1.3 — Recupera dados do guardian de um jogador.
  static Future<Map<String, dynamic>?> fetchGuardianInfo(
    String playerId,
  ) async {
    final uid = playerId.trim();
    if (uid.isEmpty) return null;

    try {
      final rows = await SupaFlow.client
          .from('guardians')
          .select()
          .eq('player_id', uid)
          .order('created_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      try {
        final rows = await SupaFlow.client
            .from('guardians')
            .select()
            .eq('player_id', uid)
            .limit(1);
        final list = List<Map<String, dynamic>>.from(rows as List);
        return list.isEmpty ? null : list.first;
      } catch (_) {
        return null;
      }
    }
  }
}
