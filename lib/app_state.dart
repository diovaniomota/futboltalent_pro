import 'package:flutter/material.dart';
import '/backend/api_requests/api_manager.dart';
import 'backend/supabase/supabase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'auth/supabase_auth/auth_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

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

  void _setupAuthListener() {
    jwtTokenStream.listen((token) {
      if (token != null) {
        debugPrint(
            '🔔 FFAppState: Token atualizado, sincronizando userType...');
        syncUserType();
      }
    });
  }

  static void reset() {
    _instance = FFAppState._internal();
  }

  // Retorna o UID do usuário autenticado, usando o SDK do Supabase diretamente
  // (não depende do stream customizado que só fica pronto após runApp)
  String get _currentUid =>
      SupaFlow.client.auth.currentUser?.id ?? currentUserUid;

  Future initializePersistedState() async {
    try {
      prefs = await SharedPreferences.getInstance();
      _userType = normalizeUserType(
        prefs.getString('ff_userType') ?? _userType,
      );
      debugPrint('📦 FFAppState: Cache carregado: "$_userType"');

      _setupAuthListener();

      final uid = _currentUid;
      debugPrint('👤 FFAppState: UID atual: "$uid"');

      if (uid.isNotEmpty) {
        // Sempre sincroniza do banco para garantir valor atualizado
        await syncUserType();
      }
    } catch (e) {
      debugPrint('❌ FFAppState: Erro no initializePersistedState: $e');
    }
  }

  Future syncUserType() async {
    final uid = _currentUid;
    if (uid.isEmpty) {
      debugPrint('⚠️ FFAppState: Sem usuário logado para sync.');
      return;
    }

    try {
      final response = await SupaFlow.client
          .from('users')
          .select('userType')
          .eq('user_id', uid)
          .maybeSingle();

      debugPrint('🔍 FFAppState: sync resposta = $response');

      if (response != null && response['userType'] != null) {
        final String sanitizedType = normalizeUserType(response['userType']);
        if (sanitizedType.isNotEmpty) {
          debugPrint('✅ FFAppState: userType = "$sanitizedType"');
          userType = sanitizedType;
          return;
        }
      }

      // Fallback: se não encontrou userType válido e o atual está vazio
      if (_userType.isEmpty) {
        debugPrint('🔄 FFAppState: Usando fallback "jugador"');
        userType = 'jugador';
      }
    } catch (e) {
      debugPrint('❌ FFAppState: Erro no sync: $e');
      if (_userType.isEmpty) userType = 'jugador';
    }
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  String _userType = '';
  String get userType => _userType;
  set userType(String value) {
    final sanitizedValue = normalizeUserType(value);
    _userType = sanitizedValue;

    try {
      prefs.setString('ff_userType', sanitizedValue);
    } catch (e) {
      // prefs pode não estar pronto ainda
    }

    debugPrint('📝 FFAppState: userType -> "$sanitizedValue"');
    notifyListeners();
  }

  String _authBlockMessage = '';
  String get authBlockMessage => _authBlockMessage;
  set authBlockMessage(String value) {
    _authBlockMessage = value;
    notifyListeners();
  }

  late SharedPreferences prefs;
}
