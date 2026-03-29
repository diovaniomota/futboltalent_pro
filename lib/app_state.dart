import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/admin/admin_runtime_service.dart';
import 'auth/supabase_auth/auth_util.dart';
import 'backend/supabase/supabase.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  static String normalizeUserType(dynamic rawValue, {String fallback = ''}) {
    final value = rawValue?.toString().trim().toLowerCase() ?? '';
    if (value.isEmpty) return fallback;

    switch (value) {
      case 'jugador':
      case 'jogador':
      case 'player':
      case 'athlete':
      case 'atleta':
        return 'jugador';
      case 'profesional':
      case 'profissional':
      case 'professional':
      case 'scout':
      case 'scouter':
      case 'scouting':
      case 'oleador':
      case 'ojeador':
        return 'profesional';
      case 'club':
      case 'clube':
      case 'club_staff':
      case 'club-staff':
      case 'staff':
        return 'club';
      case 'admin':
      case 'administrador':
      case 'administrator':
        return 'admin';
      default:
        return value;
    }
  }

  String get _currentUid =>
      SupaFlow.client.auth.currentUser?.id ?? currentUserUid;

  void _setupAuthListener() {
    jwtTokenStream.listen((token) {
      if (token != null) {
        debugPrint(
          'FFAppState: token atualizado, sincronizando contexto do usuario.',
        );
        syncUserType();
        refreshAdminRuntimeSettings();
      } else {
        _resetViewerAccessState();
        refreshAdminRuntimeSettings();
      }
    });
  }

  int? _readPlanId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString().trim() ?? '');
  }

  bool _resolveVerification(Map<String, dynamic>? user,
      {required bool defaultIfMissing}) {
    if (user == null) return defaultIfMissing;
    final hasInfo = user.containsKey('is_verified') ||
        user.containsKey('verification_status');
    if (!hasInfo) return defaultIfMissing;

    final direct = user['is_verified'];
    if (direct is bool) return direct;

    final status = user['verification_status']?.toString().toLowerCase() ?? '';
    return status == 'verified' ||
        status == 'verificado' ||
        status == 'approved' ||
        status == 'aprobado' ||
        status == 'aprovado' ||
        status == 'active' ||
        status == 'ativo';
  }

  void _hydrateViewerAccessFromUser(Map<String, dynamic> user) {
    _currentUserIsAdmin = user['is_admin'] == true ||
        normalizeUserType(user['userType']) == 'admin';
    _currentPlanId = _readPlanId(user['plan_id']);
    _currentUserVerified = _resolveVerification(user, defaultIfMissing: true);
    _currentUserFullAccess = user['full_profile'] == true ||
        user['is_test_account'] == true ||
        _currentUserIsAdmin;
  }

  void _resetViewerAccessState() {
    _currentUserIsAdmin = false;
    _currentPlanId = null;
    _currentUserVerified = true;
    _currentUserFullAccess = false;
  }

  Future initializePersistedState() async {
    try {
      prefs = await SharedPreferences.getInstance();
      _userType = normalizeUserType(
        prefs.getString('ff_userType') ?? _userType,
      );
      debugPrint('FFAppState: cache carregado: "$_userType"');

      _setupAuthListener();

      final uid = _currentUid;
      debugPrint('FFAppState: UID atual: "$uid"');

      if (uid.isNotEmpty) {
        await syncUserType();
      } else {
        _resetViewerAccessState();
      }
      await refreshAdminRuntimeSettings();
    } catch (e) {
      debugPrint('FFAppState: erro no initializePersistedState: $e');
    }
  }

  Future syncUserType() async {
    final uid = _currentUid;
    if (uid.isEmpty) {
      debugPrint('FFAppState: sem usuario logado para sync.');
      _resetViewerAccessState();
      return;
    }

    try {
      final response = await SupaFlow.client
          .from('users')
          .select(
            'userType, plan_id, full_profile, is_test_account, is_admin, is_verified, verification_status',
          )
          .eq('user_id', uid)
          .maybeSingle();

      debugPrint('FFAppState: sync resposta = $response');

      if (response != null) {
        _hydrateViewerAccessFromUser(response);
      } else {
        _resetViewerAccessState();
      }

      final sanitizedType = normalizeUserType(response?['userType']);
      if (sanitizedType.isNotEmpty) {
        debugPrint('FFAppState: userType = "$sanitizedType"');
        userType = sanitizedType;
        return;
      }

      if (_userType.isEmpty) {
        debugPrint('FFAppState: usando fallback "jugador"');
        userType = 'jugador';
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FFAppState: erro no sync: $e');
      _resetViewerAccessState();
      if (_userType.isEmpty) {
        userType = 'jugador';
      } else {
        notifyListeners();
      }
    }
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  Future<void> refreshAdminRuntimeSettings() async {
    final uid = _currentUid;

    try {
      final snapshot = await AdminRuntimeService.load(userId: uid);
      _pilotModeEnabled = snapshot.pilotModeEnabled;
      _featureFlags = snapshot.featureFlags;
      _uiTexts = snapshot.uiTexts;
      _userFeatureOverrides = snapshot.userOverrides;
      notifyListeners();
    } catch (e) {
      debugPrint('FFAppState: erro ao carregar admin runtime: $e');
      _pilotModeEnabled = false;
      _featureFlags = Map<String, bool>.from(
        AdminRuntimeService.defaultFeatureFlags,
      );
      _uiTexts = Map<String, String>.from(AdminRuntimeService.defaultUiTexts);
      _userFeatureOverrides = <String, bool>{};
      notifyListeners();
    }
  }

  String _userType = '';
  String get userType => _userType;
  set userType(String value) {
    final sanitizedValue = normalizeUserType(value);
    _userType = sanitizedValue;

    try {
      prefs.setString('ff_userType', sanitizedValue);
    } catch (_) {}

    debugPrint('FFAppState: userType -> "$sanitizedValue"');
    notifyListeners();
  }

  String _authBlockMessage = '';
  String get authBlockMessage => _authBlockMessage;
  set authBlockMessage(String value) {
    _authBlockMessage = value;
    notifyListeners();
  }

  bool _pilotModeEnabled = false;
  bool get pilotModeEnabled => _pilotModeEnabled;

  int? _currentPlanId;
  int? get currentPlanId => _currentPlanId;

  bool _currentUserVerified = true;
  bool get currentUserVerified => _currentUserVerified;

  bool _currentUserIsAdmin = false;
  bool get currentUserIsAdmin => _currentUserIsAdmin;

  bool _currentUserFullAccess = false;
  bool get currentUserFullAccess => _currentUserFullAccess;

  bool get isAdminSession =>
      _currentUserIsAdmin || normalizeUserType(_userType) == 'admin';

  Map<String, bool> _featureFlags =
      Map<String, bool>.from(AdminRuntimeService.defaultFeatureFlags);
  Map<String, bool> get featureFlags => Map<String, bool>.from(_featureFlags);

  Map<String, String> _uiTexts =
      Map<String, String>.from(AdminRuntimeService.defaultUiTexts);
  Map<String, String> get uiTexts => Map<String, String>.from(_uiTexts);

  Map<String, bool> _userFeatureOverrides = <String, bool>{};
  Map<String, bool> get userFeatureOverrides =>
      Map<String, bool>.from(_userFeatureOverrides);

  bool get hasProPlan => _currentUserFullAccess || ((_currentPlanId ?? 0) >= 2);

  bool isFeatureEnabled(
    String featureKey, {
    bool defaultValue = true,
  }) {
    final normalized = featureKey.trim().toLowerCase();
    if (normalized.isEmpty) return defaultValue;
    if (_userFeatureOverrides.containsKey(normalized)) {
      return _userFeatureOverrides[normalized] ?? defaultValue;
    }
    return _featureFlags[normalized] ?? defaultValue;
  }

  bool get disablePaywalls =>
      _pilotModeEnabled || (_userFeatureOverrides['disable_paywalls'] ?? false);

  bool get unlockSensitiveActions =>
      disablePaywalls ||
      (_userFeatureOverrides['unlock_sensitive_actions'] ?? false);

  bool get unlockVideoExplorer =>
      disablePaywalls ||
      (_userFeatureOverrides['unlock_video_explorer'] ?? false);

  bool _isPlanIncludedFeature(String featureKey) {
    switch (featureKey) {
      case 'feed':
      case 'explorer':
      case 'videos':
        return true;
      case 'desafios':
      case 'cursos':
      case 'convocatorias':
      case 'convocatoria_send':
        return hasProPlan;
      default:
        return true;
    }
  }

  bool canAccessFeature(
    String featureKey, {
    bool defaultValue = true,
  }) {
    final normalized = featureKey.trim().toLowerCase();
    if (normalized.isEmpty) return defaultValue;
    if (!isFeatureEnabled(normalized, defaultValue: defaultValue)) {
      return false;
    }
    if (disablePaywalls) return true;
    return _isPlanIncludedFeature(normalized);
  }

  bool get canSendConvocatoria => canAccessFeature('convocatoria_send');

  String uiText(String key, {String fallback = ''}) {
    final normalized = key.trim();
    if (normalized.isEmpty) return fallback;
    return _uiTexts[normalized] ?? fallback;
  }

  late SharedPreferences prefs;
}
