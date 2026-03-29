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
    final base = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
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

    if (deleteAuthAccount) {
      try {
        final response = await SupaFlow.client.rpc(
          'admin_delete_managed_user',
          params: <String, dynamic>{
            'p_user_id': trimmedUserId,
            'p_delete_auth_user': true,
          },
        );
        final payload = _responseMap(response);
        return AdminUserOperationResult(
          userId: payload?['user_id']?.toString() ?? trimmedUserId,
          message: payload?['message']?.toString() ??
              'Usuario y acceso eliminados correctamente.',
          deletedAuthAccount: payload?['deleted_auth_account'] != false,
        );
      } catch (e) {
        throw Exception(
          _humanizeError(
            e,
            fallback:
                'No fue posible eliminar la cuenta completa. Aplicá la migracion de ciclo de vida admin y reintentá.',
          ),
        );
      }
    }

    await SupaFlow.client.from('users').delete().eq('user_id', trimmedUserId);
    return AdminUserOperationResult(
      userId: trimmedUserId,
      message: 'Perfil operativo eliminado.',
    );
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
      'userType':
          input.normalizedUserType.isEmpty ? 'jugador' : input.normalizedUserType,
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
    return fallback;
  }
}
