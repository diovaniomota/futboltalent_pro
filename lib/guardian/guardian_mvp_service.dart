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
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw Exception('Ingresá el código del responsable.');
    }

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
  }
}
