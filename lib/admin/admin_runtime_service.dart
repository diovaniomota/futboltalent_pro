import '/backend/supabase/supabase.dart';

class AdminRuntimeSnapshot {
  const AdminRuntimeSnapshot({
    required this.pilotModeEnabled,
    required this.featureFlags,
    required this.uiTexts,
    required this.userOverrides,
  });

  final bool pilotModeEnabled;
  final Map<String, bool> featureFlags;
  final Map<String, String> uiTexts;
  final Map<String, bool> userOverrides;
}

class AdminRuntimeService {
  AdminRuntimeService._();

  static const Map<String, bool> defaultFeatureFlags = <String, bool>{
    'feed': true,
    'explorer': true,
    'videos': true,
    'desafios': true,
    'cursos': true,
    'convocatorias': true,
    'convocatoria_send': true,
  };

  static const Map<String, String> defaultUiTexts = <String, String>{
    'blocked_action_title': 'Acción bloqueada',
    'blocked_action_message':
        'Para acciones sensibles necesitas cuenta verificada y plan activo.',
    'challenge_upload_message': 'Se abrirá la cámara para grabar tu intento.',
    'challenge_upload_success': 'Intento enviado.',
    'feed_empty_label': 'No hay videos disponibles por ahora.',
  };

  static Future<AdminRuntimeSnapshot> load({
    required String userId,
  }) async {
    final settingsRows = await _loadSettings();
    final pilotJson = _jsonMap(settingsRows['pilot_mode']);
    final featureJson = _jsonMap(settingsRows['feature_flags']);
    final uiTextsJson = _jsonMap(settingsRows['ui_texts']);

    final featureFlags = <String, bool>{...defaultFeatureFlags};
    for (final entry in featureJson.entries) {
      featureFlags[entry.key] = _toBool(entry.value, fallback: true);
    }

    final uiTexts = <String, String>{...defaultUiTexts};
    for (final entry in uiTextsJson.entries) {
      final value = entry.value?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        uiTexts[entry.key] = value;
      }
    }

    final userOverrides = <String, bool>{};
    if (userId.trim().isNotEmpty) {
      try {
        final response = await SupaFlow.client
            .from('admin_user_feature_overrides')
            .select('feature_key, is_enabled')
            .eq('user_id', userId.trim());
        for (final row in List<Map<String, dynamic>>.from(response as List)) {
          final key = row['feature_key']?.toString().trim().toLowerCase() ?? '';
          if (key.isEmpty) continue;
          userOverrides[key] = _toBool(row['is_enabled'], fallback: true);
        }
      } catch (_) {}
    }

    return AdminRuntimeSnapshot(
      pilotModeEnabled: _toBool(pilotJson['enabled'], fallback: false),
      featureFlags: featureFlags,
      uiTexts: uiTexts,
      userOverrides: userOverrides,
    );
  }

  static Future<Map<String, dynamic>> _loadSettings() async {
    try {
      final response = await SupaFlow.client
          .from('admin_settings')
          .select('setting_key, value_json');
      final settings = <String, dynamic>{};
      for (final row in List<Map<String, dynamic>>.from(response as List)) {
        final key = row['setting_key']?.toString().trim() ?? '';
        if (key.isEmpty) continue;
        settings[key] = row['value_json'];
      }
      return settings;
    } catch (_) {
      return const {};
    }
  }

  static Map<String, dynamic> _jsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return fallback;
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'sim' ||
        normalized == 'on') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'nao' ||
        normalized == 'não' ||
        normalized == 'off') {
      return false;
    }
    return fallback;
  }
}
