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

  FFAppState._internal() {
    // O listener será ativado após o initializePersistedState para evitar LateInitializationError
  }

  void _setupAuthListener() {
    jwtTokenStream.listen((token) {
      if (token != null) {
        debugPrint(
            '🔔 FFAppState: Sessão ativa/revalidada, sincronizando userType...');
        syncUserType();
      }
    });
  }

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    try {
      prefs = await SharedPreferences.getInstance();
      _userType =
          (prefs.getString('ff_userType') ?? _userType).trim().toLowerCase();
      debugPrint('📦 FFAppState: Estado carregado: "$_userType"');

      // Inicia listener de auth agora que prefs está pronto
      _setupAuthListener();

      // Sincronização automática para garantir consistência com o DB
      if (currentUserUid.isNotEmpty) {
        if (_userType.isEmpty) {
          // Se não tem cache, aguarda o sync para não mostrar UI errada
          await syncUserType();
        } else {
          // Se tem cache, mostra o cache mas sincroniza em background para atualizar se mudou no DB
          syncUserType();
        }
      }
    } catch (e) {
      // Falha silenciosa ou log de erro mínimo em produção
    }
  }

  Future syncUserType() async {
    if (currentUserUid.isEmpty) {
      debugPrint('⚠️ FFAppState: Tentativa de sync sem usuário logado.');
      return;
    }
    try {
      final response = await SupaFlow.client
          .from('users')
          .select('userType')
          .eq('user_id', currentUserUid)
          .maybeSingle();

      if (response != null && response['userType'] != null) {
        final String rawType = response['userType'].toString();
        final String sanitizedType = rawType.trim().toLowerCase();
        debugPrint(
            '✅ FFAppState: Sucesso no sync! Bruto: "$rawType" -> Sanitizado: "$sanitizedType"');
        userType = sanitizedType;
      } else {
        debugPrint(
            '⚠️ FFAppState: Resposta do banco vazia para userType. Mantendo atual: "$_userType"');
      }
    } catch (e) {
      debugPrint('❌ FFAppState: Erro no sync do userType: $e');
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
    final sanitizedValue = value.trim().toLowerCase();
    _userType = sanitizedValue;

    // Tenta persistir apenas se prefs estiver inicializado
    try {
      prefs.setString('ff_userType', sanitizedValue);
    } catch (e) {
      // Ignora erro de persistência se ocorrer
    }

    notifyListeners();
  }

  late SharedPreferences prefs;
}
