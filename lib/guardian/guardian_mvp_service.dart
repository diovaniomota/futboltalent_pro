import 'dart:math';

import '/backend/supabase/supabase.dart';

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

  static Future<Map<String, dynamic>> approveGuardianCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw Exception('Ingresá el código del responsable.');
    }

    // Try RPC first
    try {
      final response = await SupaFlow.client.rpc(
        'approve_guardian_by_code',
        params: <String, dynamic>{'p_approval_code': normalized},
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
      // If the error is 'code not found', re-throw as-is
      if (rpcMessage.contains('approval_code_not_found')) {
        rethrow;
      }
      // If the RPC function simply doesn't exist, fall through to manual logic
      if (!rpcMessage.contains('approve_guardian_by_code') &&
          !rpcMessage.contains('could not find the function') &&
          !rpcMessage.contains('42883') &&
          !rpcMessage.contains('does not exist')) {
        rethrow;
      }
    }

    // Fallback: manual approval when RPC is not deployed
    final guardianRow = await SupaFlow.client
        .from('guardians')
        .select()
        .eq('approval_code', normalized)
        .maybeSingle();

    if (guardianRow == null) {
      // Try case-insensitive search
      final allGuardians = await SupaFlow.client
          .from('guardians')
          .select()
          .not('approval_code', 'is', null);
      final match = (allGuardians as List).cast<Map<String, dynamic>>().where(
        (g) =>
            (g['approval_code']?.toString().trim().toUpperCase() ?? '') ==
            normalized,
      );
      if (match.isEmpty) {
        throw Exception('approval_code_not_found');
      }
      return _manualApprove(Map<String, dynamic>.from(match.first));
    }

    return _manualApprove(Map<String, dynamic>.from(guardianRow));
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
    try {
      await SupaFlow.client.from('guardians').update({
        'status': approvedStatus,
        'approved_at': DateTime.now().toIso8601String(),
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
        'status': pendingStatus,
      }).eq('player_id', uid);
    } catch (e) {
      // Fallback: tenta sem campo status
      await SupaFlow.client.from('guardians').update({
        'approval_code': newCode,
      }).eq('player_id', uid);
    }
    return newCode;
  }

  /// 1.3 — Atualiza o e-mail do responsável para um jogador menor.
  static Future<void> updateGuardianEmail(
    String playerId,
    String newEmail,
  ) async {
    final uid = playerId.trim();
    final email = newEmail.trim();
    if (uid.isEmpty) {
      throw Exception('ID del jugador no proporcionado.');
    }
    if (email.isEmpty || !email.contains('@')) {
      throw Exception('Ingresá un email válido del responsable.');
    }

    await SupaFlow.client.from('guardians').update({
      'email': email,
    }).eq('player_id', uid);
  }

  /// 1.3 — Recupera dados do guardian de um jogador.
  static Future<Map<String, dynamic>?> fetchGuardianInfo(
    String playerId,
  ) async {
    final uid = playerId.trim();
    if (uid.isEmpty) return null;

    try {
      final row = await SupaFlow.client
          .from('guardians')
          .select()
          .eq('player_id', uid)
          .maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }
}

