import 'package:uuid/uuid.dart';

import '/app_state.dart';
import '/backend/supabase/supabase.dart';

class AdminUserManagementCapabilities {
  const AdminUserManagementCapabilities({
    required this.isAdmin,
    required this.canCreateUsers,
    required this.canEditUsers,
    required this.canDeleteUsers,
    required this.canCreateAuthUsers,
    required this.canDeleteAuthUsers,
    required this.canManageAdminSettings,
    required this.mode,
    required this.source,
  });

  final bool isAdmin;
  final bool canCreateUsers;
  final bool canEditUsers;
  final bool canDeleteUsers;
  final bool canCreateAuthUsers;
  final bool canDeleteAuthUsers;
  final bool canManageAdminSettings;
  final String mode;
  final String source;

  bool get hasFullLifecycle => canCreateAuthUsers && canDeleteAuthUsers;

  factory AdminUserManagementCapabilities.fromMap(
    Map<String, dynamic> data, {
    String source = 'rpc',
  }) {
    return AdminUserManagementCapabilities(
      isAdmin: _readBool(data['is_admin']),
      canCreateUsers: _readBool(
        data['can_create_users'] ?? data['can_manage_user_profiles'],
      ),
      canEditUsers: _readBool(
        data['can_edit_users'] ?? data['can_manage_user_profiles'],
      ),
      canDeleteUsers: _readBool(
        data['can_delete_users'] ?? data['can_manage_user_profiles'],
      ),
      canCreateAuthUsers: _readBool(data['can_create_auth_users']),
      canDeleteAuthUsers: _readBool(data['can_delete_auth_users']),
      canManageAdminSettings: _readBool(data['can_manage_admin_settings']),
      mode: data['mode']?.toString().trim().toLowerCase() ?? 'unknown',
      source: source,
    );
  }

  factory AdminUserManagementCapabilities.fallback({
    required bool isAdmin,
  }) {
    return AdminUserManagementCapabilities(
      isAdmin: isAdmin,
      canCreateUsers: isAdmin,
      canEditUsers: isAdmin,
      canDeleteUsers: isAdmin,
      canCreateAuthUsers: false,
      canDeleteAuthUsers: false,
      canManageAdminSettings: isAdmin,
      mode: isAdmin ? 'profile_only' : 'restricted',
      source: 'fallback',
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'sim' ||
        normalized == 'on';
  }
}

class AdminCreateManagedUserInput {
  const AdminCreateManagedUserInput({
    required this.name,
    required this.lastname,
    required this.userType,
    required this.planId,
    required this.city,
    required this.country,
    required this.position,
    required this.category,
    required this.isVerified,
    required this.createAuthAccount,
    this.email = '',
    this.password = '',
    this.birthday,
  });

  final String name;
  final String lastname;
  final String userType;
  final int planId;
  final String city;
  final String country;
  final String position;
  final String category;
  final bool isVerified;
  final bool createAuthAccount;
  final String email;
  final String password;
  final DateTime? birthday;

  String get normalizedUserType => FFAppState.normalizeUserType(userType);

  String get displayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Usuario' : trimmed;
  }

  String get username {
    final emailValue = email.trim().toLowerCase();
    if (emailValue.contains('@')) {
      return emailValue.split('@').first;
    }
    final base =
        displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return base.isEmpty ? 'usuario' : base;
  }
}

class AdminUserOperationResult {
  const AdminUserOperationResult({
    required this.userId,
    required this.message,
    this.createdAuthAccount = false,
    this.deletedAuthAccount = false,
  });

  final String userId;
  final String message;
  final bool createdAuthAccount;
  final bool deletedAuthAccount;
}

class AdminUserManagementService {
  AdminUserManagementService._();

  static const String _fullUserCatalogSelect =
      'user_id, name, lastname, username, photo_url, city, country, pais, userType, is_admin, plan_id, banned_until, verification_status, is_verified, full_profile, is_test_account';
  static const String _fullUserCatalogSelectLegacy =
      'user_id, name, lastname, username, photo_url, city, country, pais, userType, plan_id, banned_until, verification_status, is_verified, full_profile, is_test_account';
  static const String _compactUserCatalogSelect =
      'user_id, name, lastname, username, userType, is_admin';
  static const String _compactUserCatalogSelectLegacy =
      'user_id, name, lastname, username, userType';

  static Future<AdminUserManagementCapabilities> loadCapabilities() async {
    final fallback = AdminUserManagementCapabilities.fallback(
      isAdmin: FFAppState().isAdminSession,
    );

    try {
      final response = await SupaFlow.client.rpc('admin_get_capabilities');
      final payload = _responseMap(response);
      if (payload != null && payload.isNotEmpty) {
        return AdminUserManagementCapabilities.fromMap(payload);
      }
    } catch (_) {}

    return fallback;
  }

  static Future<List<Map<String, dynamic>>> loadUsersCatalog({
    bool includeOperationalFields = true,
    bool includeAdminUsers = true,
  }) async {
    final attempts = <String>[
      if (includeOperationalFields) _fullUserCatalogSelect,
      if (includeOperationalFields) _fullUserCatalogSelectLegacy,
      _compactUserCatalogSelect,
      _compactUserCatalogSelectLegacy,
    ];

    for (final fields in attempts) {
      try {
        final orderedResponse = await SupaFlow.client
            .from('users')
            .select(fields)
            .order('name', ascending: true);
        final orderedRows = _filterCatalogRows(
          _normalizeUserCatalogResponse(orderedResponse),
          includeAdminUsers: includeAdminUsers,
        );
        if (orderedRows.isNotEmpty) return orderedRows;
      } catch (_) {}

      try {
        final response = await SupaFlow.client.from('users').select(fields);
        final rows = _filterCatalogRows(
          _normalizeUserCatalogResponse(response),
          includeAdminUsers: includeAdminUsers,
        );
        if (rows.isNotEmpty) return rows;
      } catch (_) {}
    }

    return const [];
  }

  static Future<AdminUserOperationResult> createUser(
    AdminCreateManagedUserInput input,
  ) async {
    if (input.createAuthAccount) {
      return _createUserWithAuth(input);
    }
    return _createOperationalProfile(input);
  }

  static Future<AdminUserOperationResult> deleteUser({
    required String userId,
    required bool deleteAuthAccount,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw Exception('Usuario invalido para eliminar.');
    }
    final currentUid = SupaFlow.client.auth.currentUser?.id.trim() ?? '';
    if (currentUid.isNotEmpty && trimmedUserId == currentUid) {
      throw Exception('No puedes eliminar tu propio usuario admin.');
    }
    if (await _isAdminUserProfile(trimmedUserId)) {
      throw Exception(
        'Los usuarios admin no pueden eliminarse desde esta pantalla.',
      );
    }

    try {
      return await _deleteUserWithRpc(
        userId: trimmedUserId,
        deleteAuthAccount: deleteAuthAccount,
      );
    } catch (e) {
      if (_isFeedbackForeignKeyError(e)) {
        try {
          await _detachFeedbackFromUser(trimmedUserId);
          return await _deleteUserWithRpc(
            userId: trimmedUserId,
            deleteAuthAccount: deleteAuthAccount,
          );
        } catch (_) {}
      }

      if (deleteAuthAccount) {
        throw Exception(
          _humanizeError(
            e,
            fallback:
                'No fue posible eliminar la cuenta completa. Aplica la migracion de ciclo de vida admin y reintenta.',
          ),
        );
      }

      try {
        await _deleteOperationalProfileFallback(trimmedUserId);
        return AdminUserOperationResult(
          userId: trimmedUserId,
          message: 'Perfil operativo eliminado.',
        );
      } catch (fallbackError) {
        throw Exception(
          _humanizeError(
            fallbackError,
            fallback: 'No fue posible eliminar el perfil operativo.',
          ),
        );
      }
    }
  }

  static Future<AdminUserOperationResult> _deleteUserWithRpc({
    required String userId,
    required bool deleteAuthAccount,
  }) async {
    final response = await SupaFlow.client.rpc(
      'admin_delete_managed_user',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_delete_auth_user': deleteAuthAccount,
      },
    );
    final payload = _responseMap(response);
    return AdminUserOperationResult(
      userId: payload?['user_id']?.toString() ?? userId,
      message: payload?['message']?.toString() ??
          (deleteAuthAccount
              ? 'Usuario y acceso eliminados correctamente.'
              : 'Perfil operativo eliminado.'),
      deletedAuthAccount:
          deleteAuthAccount && payload?['deleted_auth_account'] != false,
    );
  }

  static Future<void> _deleteOperationalProfileFallback(String userId) async {
    await _deleteRelatedRowsFallback(userId);
    await _safeDeleteByColumnValues('videos', 'user_id', {userId});
    await _safeDeleteByColumnValues('players', 'id', {userId});
    await _safeDeleteByColumnValues('scouts', 'id', {userId});
    await _safeDeleteByColumnValues('clubs', 'owner_id', {userId});
    await _safeDeleteByColumnValues('users', 'user_id', {userId});
  }

  static Future<void> _detachFeedbackFromUser(String userId) async {
    await SupaFlow.client
        .from('feedback')
        .update({'user_id': null}).eq('user_id', userId);
  }

  static Future<void> _deleteRelatedRowsFallback(String userId) async {
    final compactUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final legacyClubId = compactUserId.length <= 10
        ? compactUserId
        : compactUserId.substring(0, 10);
    final identityIds = <String>{
      userId,
      if (legacyClubId.isNotEmpty) legacyClubId
    };
    final clubIds = <String>{
      ...identityIds,
      ...await _selectTextIds('clubs', 'id', 'owner_id', userId),
      ...await _selectTextIds('clubs', 'id', 'id', userId),
    };
    final videoIds = <String>{
      ...await _selectTextIds('videos', 'id', 'user_id', userId),
    };
    final commentIds = <String>{
      ...await _selectTextIds('comments', 'id', 'user_id', userId),
      ...await _selectTextIdsIn('comments', 'id', 'video_id', videoIds),
    };
    final convocatoriaIds = <String>{
      ...await _selectTextIdsIn('convocatorias', 'id', 'club_id', clubIds),
    };
    final listaIds = <String>{
      ...await _selectTextIds('listas', 'id', 'profesional_id', userId),
      ...await _selectTextIdsIn(
        'listas',
        'id',
        'convocatoria_id',
        convocatoriaIds,
      ),
    };
    final listaClubIds = <String>{
      ...await _selectTextIdsIn('listas_club', 'id', 'club_id', clubIds),
    };

    await _safeDeleteByColumnValues(
        'comment_reports', 'comment_id', commentIds);
    await _safeDeleteByColumnValues(
      'comment_reports',
      'reporter_user_id',
      {userId},
    );
    await _safeDeleteByColumnValues('comments', 'video_id', videoIds);
    await _safeDeleteByColumnValues('comments', 'user_id', {userId});
    await _safeDeleteByColumnValues('likes', 'video_id', videoIds);
    await _safeDeleteByColumnValues('likes', 'user_id', {userId});
    await _safeDeleteByColumnValues('user_videos_saved', 'video_id', videoIds);
    await _safeDeleteByColumnValues('user_videos_saved', 'user_id', {userId});
    await _safeDeleteByColumnValues(
      'user_challenge_attempts',
      'video_id',
      videoIds,
    );
    await _safeDeleteByColumnValues(
      'user_challenge_attempts',
      'user_id',
      {userId},
    );
    await _safeDeleteByColumnValues(
        'activity_notifications', 'user_id', {userId});
    await _safeDeleteByColumnValues('activity_notifications', 'entity_id', {
      userId,
      ...clubIds,
      ...videoIds,
      ...commentIds,
      ...convocatoriaIds,
      ...listaIds,
      ...listaClubIds,
    });
    await _safeDeleteByColumnValues('feedback', 'user_id', {userId});
    await _safeDeleteByColumnValues(
      'admin_user_feature_overrides',
      'user_id',
      {userId},
    );
    await _safeDeleteByColumnValues('user_badges', 'user_id', {userId});
    await _safeDeleteByColumnValues('user_stats', 'user_id', {userId});
    await _safeDeleteByColumnValues(
        'user_challenge_goals', 'user_id', {userId});
    await _safeDeleteByColumnValues('followers', 'follower_id', {userId});
    await _safeDeleteByColumnValues('followers', 'following_id', {userId});
    await _safeDeleteByColumnValues('follows', 'follower_id', {userId});
    await _safeDeleteByColumnValues('follows', 'following_id', {userId});
    await _safeDeleteByColumnValues(
        'contact_requests', 'from_user_id', {userId});
    await _safeDeleteByColumnValues('contact_requests', 'to_user_id', {userId});
    await _safeDeleteByColumnValues(
      'player_profile_views',
      'player_user_id',
      {userId},
    );
    await _safeDeleteByColumnValues(
      'player_profile_views',
      'viewer_user_id',
      {userId},
    );
    await _safeDeleteByColumnValues('guardians', 'player_id', {userId});
    await _safeDeleteByColumnValues(
        'jugadores_guardados', 'scout_id', {userId});
    await _safeDeleteByColumnValues(
        'jugadores_guardados', 'jugador_id', {userId});
    await _safeDeleteByColumnValues('listas_jugadores', 'jugador_id', {userId});
    await _safeDeleteByColumnValues('listas_jugadores', 'lista_id', listaIds);
    await _safeDeleteByColumnValues(
      'listas_jugadores',
      'lista_id',
      listaClubIds,
    );
    await _safeDeleteByColumnValues(
      'aplicaciones_convocatoria',
      'jugador_id',
      {userId},
    );
    await _safeDeleteByColumnValues(
      'aplicaciones_convocatoria',
      'convocatoria_id',
      convocatoriaIds,
    );
    await _safeDeleteByColumnValues('postulaciones', 'player_id', {userId});
    await _safeDeleteByColumnValues(
      'postulaciones',
      'convocatoria_id',
      convocatoriaIds,
    );
    await _safeDeleteByColumnValues('listas', 'profesional_id', {userId});
    await _safeDeleteByColumnValues(
        'listas', 'convocatoria_id', convocatoriaIds);
    await _safeDeleteByColumnValues('listas_club', 'club_id', clubIds);
    await _safeDeleteByColumnValues('convocatorias', 'club_id', clubIds);
    await _safeDeleteByColumnValues('club_staff', 'user_id', {userId});
    await _safeDeleteByColumnValues('club_staff', 'club_id', clubIds);
    await _safeDeleteByColumnValues('clubs', 'id', clubIds);
    await _safeDeleteByColumnValues('clubes', 'id', identityIds);
  }

  static Future<List<String>> _selectTextIds(
    String table,
    String idColumn,
    String matchColumn,
    String matchValue,
  ) async {
    try {
      final response = await SupaFlow.client
          .from(table)
          .select(idColumn)
          .eq(matchColumn, matchValue);
      return _readTextColumnValues(response, idColumn);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<String>> _selectTextIdsIn(
    String table,
    String idColumn,
    String matchColumn,
    Set<String> matchValues,
  ) async {
    final values =
        matchValues.where((value) => value.trim().isNotEmpty).toList();
    if (values.isEmpty) return const [];
    try {
      final response = await SupaFlow.client
          .from(table)
          .select(idColumn)
          .inFilter(matchColumn, values);
      return _readTextColumnValues(response, idColumn);
    } catch (_) {
      return const [];
    }
  }

  static List<String> _readTextColumnValues(dynamic response, String column) {
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((row) => row[column]?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  static Future<void> _safeDeleteByColumnValues(
    String table,
    String column,
    Set<String> values,
  ) async {
    final cleanValues =
        values.where((value) => value.trim().isNotEmpty).toList();
    if (cleanValues.isEmpty) return;
    try {
      await SupaFlow.client.from(table).delete().inFilter(column, cleanValues);
    } catch (_) {
      for (final value in cleanValues) {
        try {
          await SupaFlow.client.from(table).delete().eq(column, value);
        } catch (_) {}
      }
    }
  }

  static Future<AdminUserOperationResult> _createUserWithAuth(
    AdminCreateManagedUserInput input,
  ) async {
    final email = input.email.trim().toLowerCase();
    final password = input.password.trim();

    if (email.isEmpty) {
      throw Exception('Informá un email para crear acceso.');
    }
    if (password.length < 8) {
      throw Exception('La contraseña debe tener al menos 8 caracteres.');
    }

    try {
      final response = await SupaFlow.client.rpc(
        'admin_create_managed_user',
        params: <String, dynamic>{
          'p_email': email,
          'p_password': password,
          'p_name': input.displayName,
          'p_lastname': input.lastname.trim(),
          'p_username': input.username,
          'p_user_type': input.normalizedUserType.isEmpty
              ? 'jugador'
              : input.normalizedUserType,
          'p_plan_id': input.planId,
          'p_city': _nullable(input.city),
          'p_country': _nullable(input.country),
          'p_position': _nullable(input.position),
          'p_category': _nullable(input.category),
          'p_birthday': input.birthday?.toIso8601String(),
          'p_is_verified': input.isVerified,
          'p_create_auth_user': true,
        },
      );
      final payload = _responseMap(response);
      return AdminUserOperationResult(
        userId: payload?['user_id']?.toString() ?? '',
        message: payload?['message']?.toString() ??
            'Usuario creado con acceso al app.',
        createdAuthAccount: true,
      );
    } catch (e) {
      throw Exception(
        _humanizeError(
          e,
          fallback:
              'No fue posible crear la cuenta con acceso. Aplicá la migracion de ciclo de vida admin y reintentá.',
        ),
      );
    }
  }

  static Future<AdminUserOperationResult> _createOperationalProfile(
    AdminCreateManagedUserInput input,
  ) async {
    final userId = const Uuid().v4();
    final payload = _buildProfilePayload(userId: userId, input: input);
    final fallbackPayload = Map<String, dynamic>.from(payload)
      ..remove('posicion')
      ..remove('categoria')
      ..remove('country')
      ..remove('pais')
      ..remove('city');

    try {
      await SupaFlow.client.from('users').insert(payload);
    } catch (_) {
      await SupaFlow.client.from('users').insert(fallbackPayload);
    }

    await _ensureRelatedProfile(userId: userId, input: input);

    return AdminUserOperationResult(
      userId: userId,
      message: 'Perfil operativo creado sin credenciales.',
    );
  }

  static Map<String, dynamic> _buildProfilePayload({
    required String userId,
    required AdminCreateManagedUserInput input,
  }) {
    return <String, dynamic>{
      'user_id': userId,
      'name': input.displayName,
      'lastname': input.lastname.trim(),
      'username': input.username,
      'userType': input.normalizedUserType.isEmpty
          ? 'jugador'
          : input.normalizedUserType,
      'plan_id': input.planId,
      'role_id': 1,
      'country_id': 1,
      'created_at': DateTime.now().toIso8601String(),
      'posicion': _nullable(input.position),
      'categoria': _nullable(input.category),
      'country': _nullable(input.country),
      'pais': _nullable(input.country),
      'city': _nullable(input.city),
      'verification_status': input.isVerified ? 'verified' : 'pending',
      'is_verified': input.isVerified,
      'is_test_account': true,
      if (input.birthday != null) 'birthday': input.birthday!.toIso8601String(),
    };
  }

  static Future<void> _ensureRelatedProfile({
    required String userId,
    required AdminCreateManagedUserInput input,
  }) async {
    try {
      switch (input.normalizedUserType) {
        case 'jugador':
          await SupaFlow.client.from('players').insert({
            'id': userId,
            'created_at': DateTime.now().toIso8601String(),
            'position_id': null,
          });
          break;
        case 'profesional':
          await SupaFlow.client.from('scouts').insert({
            'id': userId,
            'created_at': DateTime.now().toIso8601String(),
            'telephone': '',
            'club': '',
          });
          break;
        case 'club':
          await SupaFlow.client.from('clubs').insert({
            'owner_id': userId,
            'nombre': input.displayName,
            'created_at': DateTime.now().toIso8601String(),
          });
          break;
      }
    } catch (_) {}
  }

  static String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, dynamic>? _responseMap(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  static List<Map<String, dynamic>> _normalizeUserCatalogResponse(
    dynamic response,
  ) {
    if (response is! List) return const [];

    final rows = <Map<String, dynamic>>[];
    for (final row in response) {
      final map = row is Map<String, dynamic>
          ? Map<String, dynamic>.from(row)
          : row is Map
              ? Map<String, dynamic>.from(row)
              : null;
      if (map == null) continue;

      final userId = map['user_id']?.toString().trim() ?? '';
      if (userId.isEmpty) continue;

      map['userType'] = FFAppState.normalizeUserType(
        map['userType'] ?? map['user_type'] ?? map['usertype'],
      );
      rows.add(map);
    }

    rows.sort((a, b) {
      final aName = [
        a['name'],
        a['lastname'],
        a['username'],
      ].map((value) => value?.toString().trim() ?? '').join(' ').toLowerCase();
      final bName = [
        b['name'],
        b['lastname'],
        b['username'],
      ].map((value) => value?.toString().trim() ?? '').join(' ').toLowerCase();
      return aName.compareTo(bName);
    });

    return rows;
  }

  static List<Map<String, dynamic>> _filterCatalogRows(
    List<Map<String, dynamic>> rows, {
    required bool includeAdminUsers,
  }) {
    if (includeAdminUsers) return rows;

    final currentUid = SupaFlow.client.auth.currentUser?.id.trim() ?? '';
    return rows.where((row) {
      final userId = row['user_id']?.toString().trim() ?? '';
      if (currentUid.isNotEmpty && userId == currentUid) return false;
      return !_isAdminCatalogUser(row);
    }).toList();
  }

  static bool _isAdminCatalogUser(Map<String, dynamic> user) {
    final type = FFAppState.normalizeUserType(
      user['userType'] ?? user['user_type'] ?? user['usertype'],
    );
    return type == 'admin' ||
        AdminUserManagementCapabilities._readBool(user['is_admin']);
  }

  static Future<bool> _isAdminUserProfile(String userId) async {
    try {
      final row = await SupaFlow.client
          .from('users')
          .select('userType, is_admin')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return false;
      return _isAdminCatalogUser(Map<String, dynamic>.from(row));
    } catch (_) {
      try {
        final row = await SupaFlow.client
            .from('users')
            .select('userType')
            .eq('user_id', userId)
            .maybeSingle();
        if (row == null) return false;
        return _isAdminCatalogUser(Map<String, dynamic>.from(row));
      } catch (_) {
        return false;
      }
    }
  }

  static String _humanizeError(
    Object error, {
    required String fallback,
  }) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('email_exists') ||
        normalized.contains('already registered') ||
        normalized.contains('duplicate')) {
      return 'Ya existe una cuenta con ese email.';
    }
    if (normalized.contains('password_too_short')) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (normalized.contains('admin_only')) {
      return 'Tu usuario no tiene permisos de administrador para esta accion.';
    }
    if (normalized.contains('cannot_delete_self')) {
      return 'No puedes eliminar tu propio usuario admin.';
    }
    if (normalized.contains('cannot_delete_admin_user')) {
      return 'Los usuarios admin no pueden eliminarse desde esta pantalla.';
    }
    if (_isFeedbackForeignKeyError(error)) {
      return 'Este usuario tiene feedback asociado. Aplica la migracion de baja de usuarios para anonimizar el feedback antes de eliminar.';
    }
    return fallback;
  }

  static bool _isFeedbackForeignKeyError(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('feedback_user_id_fkey') ||
        (normalized.contains('foreign key') &&
            normalized.contains('feedback') &&
            normalized.contains('users'));
  }
}
