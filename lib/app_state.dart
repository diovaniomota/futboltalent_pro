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
        _resetViewerAccessState(clearCachedUserType: true);
        notifyListeners();
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

  void _resetViewerAccessState({bool clearCachedUserType = false}) {
    _currentUserIsAdmin = false;
    _currentPlanId = null;
    _currentUserVerified = true;
    _currentUserFullAccess = false;
    _registrationComplete = false;
    if (clearCachedUserType) {
      _userType = '';
      try {
        prefs.remove('ff_userType');
      } catch (_) {}
    }
  }

  void clearAuthenticatedSessionState() {
    _registrationFlowActive = false;
    _resetViewerAccessState(clearCachedUserType: true);
    _pilotModeEnabled = false;
    _featureFlags = Map<String, bool>.from(
      AdminRuntimeService.defaultFeatureFlags,
    );
    _uiTexts = Map<String, String>.from(AdminRuntimeService.defaultUiTexts);
    _userFeatureOverrides = <String, bool>{};
    notifyListeners();
  }

  Future initializePersistedState() async {
    try {
      prefs = await SharedPreferences.getInstance();
      _userType = normalizeUserType(
        prefs.getString('ff_userType') ?? _userType,
      );
      _registrationComplete = prefs.getBool('ff_registrationComplete') ?? false;
      _registrationFlowActive = prefs.getBool('ff_registrationFlowActive') ?? false;
      debugPrint('FFAppState: cache carregado: "$_userType", complete: $_registrationComplete, flow: $_registrationFlowActive');

      _setupAuthListener();

      final uid = _currentUid;
      debugPrint('FFAppState: UID atual: "$uid"');

      if (uid.isNotEmpty) {
        await syncUserType();
      } else {
        _resetViewerAccessState(clearCachedUserType: true);
      }
      await refreshAdminRuntimeSettings();
    } catch (e) {
      debugPrint('FFAppState: erro no initializePersistedState: $e');
    }
  }

  Future syncUserType({String? expectedUid}) async {
    final explicitUid = expectedUid?.trim() ?? '';
    final uid = explicitUid.isNotEmpty ? explicitUid : _currentUid;
    if (uid.isEmpty) {
      debugPrint('FFAppState: sem usuario logado para sync.');
      _resetViewerAccessState(clearCachedUserType: true);
      notifyListeners();
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
        _registrationComplete =
            await _hasCompletedOperationalProfile(uid, response);
        if (_registrationComplete) {
          _registrationFlowActive = false;
        }
        await prefs.setBool('ff_registrationComplete', _registrationComplete);
        _hydrateViewerAccessFromUser(response);
      } else {
        _resetViewerAccessState(
          clearCachedUserType: !_registrationFlowActive,
        );
        _registrationComplete = false;
        debugPrint('FFAppState: cadastro incompleto - sem row na tabela users');
        notifyListeners();
        return;
      }

      final sanitizedType = normalizeUserType(response['userType']);
      if (sanitizedType.isNotEmpty) {
        debugPrint('FFAppState: userType = "$sanitizedType"');
        _userType = sanitizedType;
        await prefs.setString('ff_userType', sanitizedType);
        notifyListeners();
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
      // Do NOT reset viewer access state on error to avoid kicking the user out
      // during temporary network issues.
      notifyListeners();
    }
  }

  Future<bool> _rowExists(
    String table,
    String column,
    String value,
  ) async {
    try {
      final row = await SupaFlow.client
          .from(table)
          .select(column)
          .eq(column, value)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint(
        'FFAppState: nao foi possivel validar $table.$column: $e',
      );
      return false;
    }
  }

  Future<bool> _hasCompletedOperationalProfile(
    String uid,
    Map<String, dynamic> user,
  ) async {
    final normalizedType = normalizeUserType(user['userType']);
    if (normalizedType == 'admin') return true;

    if (normalizedType == 'jugador') {
      return _rowExists('players', 'id', uid);
    }

    if (normalizedType == 'profesional') {
      return _rowExists('scouts', 'id', uid);
    }

    if (normalizedType == 'club') {
      final hasCurrentClub = await _rowExists('clubs', 'owner_id', uid) ||
          await _rowExists('clubs', 'id', uid);
      if (hasCurrentClub) return true;
      return _rowExists('clubes', 'id', uid);
    }

    return false;
  }

  Future<void> refreshCurrentUserAccess() async {
    await syncUserType();
    await refreshAdminRuntimeSettings();
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

  /// True apenas quando o usuário tem um row completo na tabela `users`.
  /// False enquanto o cadastro não foi finalizado (auth criado mas perfil não salvo).
  bool _registrationComplete = false;
  bool get registrationComplete => _registrationComplete;

  bool _registrationFlowActive = false;
  bool get registrationFlowActive => _registrationFlowActive;
  set registrationFlowActive(bool value) {
    if (_registrationFlowActive == value) return;
    _registrationFlowActive = value;
    prefs.setBool('ff_registrationFlowActive', value);
    if (value) {
      _registrationComplete = false;
      prefs.setBool('ff_registrationComplete', false);
    }
    notifyListeners();
  }

  bool get isAdminSession => _currentUserIsAdmin;

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

  bool get canUseSensitiveActions =>
      unlockSensitiveActions ||
      _currentUserFullAccess ||
      (hasProPlan && _currentUserVerified);

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
