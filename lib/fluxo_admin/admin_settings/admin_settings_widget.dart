import '/admin/admin_runtime_service.dart';
import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'admin_settings_model.dart';
export 'admin_settings_model.dart';

class AdminSettingsWidget extends StatefulWidget {
  const AdminSettingsWidget({super.key});

  static String routeName = 'admin_settings';
  static String routePath = '/adminSettings';

  @override
  State<AdminSettingsWidget> createState() => _AdminSettingsWidgetState();
}

class _AdminSettingsWidgetState extends State<AdminSettingsWidget> {
  static const List<String> _featureOrder = <String>[
    'feed',
    'explorer',
    'videos',
    'desafios',
    'convocatorias',
    'convocatoria_send',
    'cursos',
  ];

  late AdminSettingsModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _pilotEnabled = false;
  Map<String, bool> _featureFlags =
      Map<String, bool>.from(AdminRuntimeService.defaultFeatureFlags);

  final _blockedTitleCtrl = TextEditingController();
  final _blockedMessageCtrl = TextEditingController();
  final _uploadMessageCtrl = TextEditingController();
  final _uploadSuccessCtrl = TextEditingController();
  final _feedEmptyCtrl = TextEditingController();

  List<Map<String, dynamic>> _overrides = [];
  List<Map<String, dynamic>> _overrideUsers = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminSettingsModel());
    _loadSettings();
  }

  @override
  void dispose() {
    _model.dispose();
    _blockedTitleCtrl.dispose();
    _blockedMessageCtrl.dispose();
    _uploadMessageCtrl.dispose();
    _uploadSuccessCtrl.dispose();
    _feedEmptyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupaFlow.client
          .from('admin_settings')
          .select('setting_key, value_json');
      final map = <String, dynamic>{};
      for (final row in List<Map<String, dynamic>>.from(response as List)) {
        final key = row['setting_key']?.toString() ?? '';
        map[key] = row['value_json'];
      }

      final pilotJson = _jsonMap(map['pilot_mode']);
      final flagsJson = _jsonMap(map['feature_flags']);
      final uiJson = _jsonMap(map['ui_texts']);

      _pilotEnabled = _toBool(pilotJson['enabled'], fallback: false);
      _featureFlags = Map<String, bool>.from(
        AdminRuntimeService.defaultFeatureFlags,
      );
      for (final key in _featureOrder) {
        _featureFlags[key] = _toBool(
          flagsJson[key],
          fallback: _featureFlags[key] ?? true,
        );
      }

      _blockedTitleCtrl.text =
          uiJson['blocked_action_title']?.toString() ?? 'Acción bloqueada';
      _blockedMessageCtrl.text = uiJson['blocked_action_message']?.toString() ??
          'Para acciones sensibles necesitas cuenta verificada y plan activo.';
      _uploadMessageCtrl.text =
          uiJson['challenge_upload_message']?.toString() ??
              'Se abrirá la cámara para grabar tu intento.';
      _uploadSuccessCtrl.text =
          uiJson['challenge_upload_success']?.toString() ?? 'Intento enviado.';
      _feedEmptyCtrl.text = uiJson['feed_empty_label']?.toString() ??
          'No hay videos disponibles por ahora.';
    } catch (e) {
      debugPrint('AdminSettings load error: $e');
    }

    await Future.wait([
      _loadOverrides(),
      _loadOverrideUsers(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadOverrideUsers() async {
    try {
      final response = await SupaFlow.client
          .from('users')
          .select('user_id, name, lastname, username, userType')
          .order('name', ascending: true);
      _overrideUsers = List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      _overrideUsers = [];
    }
  }

  Future<void> _loadOverrides() async {
    try {
      final response = await SupaFlow.client
          .from('admin_user_feature_overrides')
          .select('id, user_id, feature_key, is_enabled, notes, updated_at')
          .order('updated_at', ascending: false);
      _overrides = List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      _overrides = [];
    }
  }

  Map<String, dynamic> _jsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  bool _toBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return fallback;
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'sim' ||
        normalized == 'on';
  }

  String _featureLabel(String key) {
    switch (key) {
      case 'feed':
        return 'Feed';
      case 'explorer':
        return 'Explorer';
      case 'videos':
        return 'Subir videos';
      case 'desafios':
        return 'Desafíos';
      case 'convocatorias':
        return 'Convocatorias';
      case 'convocatoria_send':
        return 'Envío de convocatorias';
      case 'cursos':
        return 'Cursos';
      default:
        return key;
    }
  }

  String _featureDescription(String key) {
    switch (key) {
      case 'feed':
      case 'explorer':
      case 'videos':
        return 'Disponible en el plan Free.';
      case 'desafios':
        return 'Contenido del plan Pro con paywall.';
      case 'convocatorias':
        return 'Acceso a resultados y detalle de convocatorias en Pro.';
      case 'convocatoria_send':
        return 'Controla quién puede postular o invitar jugadores a convocatorias.';
      case 'cursos':
        return 'Contenido exclusivo del plan Pro con paywall.';
      default:
        return 'Control global de esta funcionalidad.';
    }
  }

  String _normalizeOverrideRole(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    switch (normalized) {
      case 'admin':
        return 'admin';
      case 'club':
      case 'clube':
        return 'club';
      case 'profesional':
      case 'profissional':
      case 'professional':
      case 'scout':
        return 'profesional';
      case 'jugador':
      case 'player':
        return 'jugador';
      default:
        return 'otro';
    }
  }

  String _overrideRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'club':
        return 'Club';
      case 'profesional':
        return 'Profesional';
      case 'jugador':
        return 'Jugador';
      default:
        return 'Otro';
    }
  }

  Color _overrideRoleBackground(BuildContext context, String role) {
    final theme = FlutterFlowTheme.of(context);
    switch (role) {
      case 'admin':
        return theme.warningBg;
      case 'club':
        return const Color(0xFFEDE9FE);
      case 'profesional':
        return const Color(0xFFE6F4FF);
      case 'jugador':
        return theme.successBg;
      default:
        return theme.accent4;
    }
  }

  Color _overrideRoleForeground(BuildContext context, String role) {
    final theme = FlutterFlowTheme.of(context);
    switch (role) {
      case 'admin':
        return theme.warningMain;
      case 'club':
        return const Color(0xFF7C3AED);
      case 'profesional':
        return const Color(0xFF2563EB);
      case 'jugador':
        return theme.successMain;
      default:
        return theme.secondaryText;
    }
  }

  String _overrideUserName(Map<String, dynamic>? user) {
    if (user == null) return 'Seleccionar usuario';
    final fullName = '${user['name'] ?? ''} ${user['lastname'] ?? ''}'.trim();
    if (fullName.isNotEmpty) return fullName;
    final username = user['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    return 'Usuario';
  }

  String _overrideUserSecondary(Map<String, dynamic>? user) {
    if (user == null) return 'Elegí un usuario por perfil.';
    final username = user['username']?.toString().trim() ?? '';
    final userId = user['user_id']?.toString().trim() ?? '';
    final parts = <String>[
      if (username.isNotEmpty) '@$username',
      if (userId.isNotEmpty)
        userId.length > 12 ? '${userId.substring(0, 12)}…' : userId,
    ];
    return parts.isEmpty ? 'Sin identificador visible' : parts.join(' · ');
  }

  String _overrideUserAvatarLetter(Map<String, dynamic>? user) {
    final raw = _overrideUserName(user).trim();
    for (final rune in raw.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]').hasMatch(char)) {
        return char.toUpperCase();
      }
    }
    return 'U';
  }

  List<String> get _overrideRoleOrder => const [
        'admin',
        'club',
        'profesional',
        'jugador',
        'otro',
      ];

  Widget _buildOverrideRoleChip(BuildContext context, String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _overrideRoleBackground(context, role),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _overrideRoleLabel(role),
        style: FlutterFlowTheme.of(context).bodySmall.override(
              fontFamily: 'Inter',
              color: _overrideRoleForeground(context, role),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.0,
            ),
      ),
    );
  }

  Widget _buildOverrideUserSelectorTile(
    BuildContext context, {
    required Map<String, dynamic>? user,
    required VoidCallback onTap,
  }) {
    final role = _normalizeOverrideRole(user?['userType']);
    final hasUser = user != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUser
                ? FlutterFlowTheme.of(context).primary.withOpacity(0.18)
                : FlutterFlowTheme.of(context).alternate,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: hasUser
                    ? _overrideRoleBackground(context, role)
                    : FlutterFlowTheme.of(context).alternate,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                hasUser ? Icons.person_outline : Icons.search,
                color: hasUser
                    ? _overrideRoleForeground(context, role)
                    : FlutterFlowTheme.of(context).secondaryText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _overrideUserName(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodyLarge.override(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.0,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _overrideUserSecondary(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          fontFamily: 'Inter',
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (hasUser) _buildOverrideRoleChip(context, role),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickOverrideUser(String? currentUserId) async {
    final searchCtrl = TextEditingController();
    String query = '';

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = FlutterFlowTheme.of(ctx);
          final normalizedQuery = query.trim().toLowerCase();
          final filteredUsers = _overrideUsers.where((user) {
            if (normalizedQuery.isEmpty) return true;
            final haystack = [
              user['name'],
              user['lastname'],
              user['username'],
              user['user_id'],
              _overrideRoleLabel(_normalizeOverrideRole(user['userType'])),
            ].join(' ').toLowerCase();
            return haystack.contains(normalizedQuery);
          }).toList()
            ..sort((a, b) {
              final roleA = _overrideRoleOrder.indexOf(
                _normalizeOverrideRole(a['userType']),
              );
              final roleB = _overrideRoleOrder.indexOf(
                _normalizeOverrideRole(b['userType']),
              );
              if (roleA != roleB) return roleA.compareTo(roleB);
              return _overrideUserName(a)
                  .toLowerCase()
                  .compareTo(_overrideUserName(b).toLowerCase());
            });

          final groupedUsers = <String, List<Map<String, dynamic>>>{};
          for (final role in _overrideRoleOrder) {
            groupedUsers[role] = [];
          }
          for (final user in filteredUsers) {
            final role = _normalizeOverrideRole(user['userType']);
            groupedUsers.putIfAbsent(role, () => []);
            groupedUsers[role]!.add(user);
          }

          return Container(
            height: MediaQuery.sizeOf(ctx).height * 0.82,
            decoration: BoxDecoration(
              color: theme.primaryBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.alternate,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seleccionar usuario',
                                style:
                                    FlutterFlowTheme.of(ctx).headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Separados por perfil para encontrarlo más rápido.',
                                style: theme.bodySmall.override(
                                  fontFamily: 'Inter',
                                  color: theme.secondaryText,
                                  letterSpacing: 0.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (value) =>
                          setSheetState(() => query = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, usuario o ID',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: theme.secondaryBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: theme.alternate),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: theme.alternate),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: theme.primary),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: Text(
                              'No encontramos usuarios para esa búsqueda.',
                              style: theme.bodyMedium.override(
                                fontFamily: 'Inter',
                                color: theme.secondaryText,
                                letterSpacing: 0.0,
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            children: [
                              for (final role in _overrideRoleOrder)
                                if ((groupedUsers[role] ?? const []).isNotEmpty)
                                  ...[
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 8, bottom: 8),
                                      child: Row(
                                        children: [
                                          _buildOverrideRoleChip(ctx, role),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${groupedUsers[role]!.length}',
                                            style: theme.bodySmall.override(
                                              fontFamily: 'Inter',
                                              color: theme.secondaryText,
                                              letterSpacing: 0.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...groupedUsers[role]!.map(
                                      (user) {
                                        final isSelected =
                                            (user['user_id']?.toString() ?? '') ==
                                                currentUserId;
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          decoration: BoxDecoration(
                                            color: theme.secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: isSelected
                                                  ? theme.primary
                                                  : theme.alternate,
                                              width: isSelected ? 1.4 : 1,
                                            ),
                                          ),
                                          child: ListTile(
                                            onTap: () => Navigator.pop(
                                              ctx,
                                              user['user_id']?.toString(),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 4,
                                            ),
                                            leading: Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: _overrideRoleBackground(
                                                  ctx,
                                                  role,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                _overrideUserAvatarLetter(user),
                                                style: theme.bodyLarge.override(
                                                  fontFamily: 'Inter',
                                                  color:
                                                      _overrideRoleForeground(
                                                    ctx,
                                                    role,
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.0,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              _overrideUserName(user),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.bodyLarge.override(
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.0,
                                              ),
                                            ),
                                            subtitle: Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                _overrideUserSecondary(user),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.bodySmall.override(
                                                  fontFamily: 'Inter',
                                                  color: theme.secondaryText,
                                                  letterSpacing: 0.0,
                                                ),
                                              ),
                                            ),
                                            trailing: isSelected
                                                ? Icon(
                                                    Icons.check_circle,
                                                    color: theme.primary,
                                                  )
                                                : Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: theme.secondaryText,
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    searchCtrl.dispose();
    return result;
  }

  Map<String, dynamic>? _findOverrideUser(String userId) {
    for (final user in _overrideUsers) {
      if ((user['user_id']?.toString() ?? '') == userId) return user;
    }
    return null;
  }

  Future<void> _saveSetting(String key, Map<String, dynamic> value) async {
    try {
      await SupaFlow.client.from('admin_settings').upsert({
        'setting_key': key,
        'value_json': value,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserUid,
      });
    } catch (e) {
      debugPrint('AdminSettings save error: $e');
    }
  }

  Future<void> _persistFlags() async {
    await _saveSetting('feature_flags', _featureFlags);
    await FFAppState().refreshAdminRuntimeSettings();
  }

  Future<void> _persistPilot() async {
    await _saveSetting('pilot_mode', {'enabled': _pilotEnabled});
    await FFAppState().refreshAdminRuntimeSettings();
  }

  Future<void> _persistTexts() async {
    await _saveSetting('ui_texts', {
      'blocked_action_title': _blockedTitleCtrl.text.trim(),
      'blocked_action_message': _blockedMessageCtrl.text.trim(),
      'challenge_upload_message': _uploadMessageCtrl.text.trim(),
      'challenge_upload_success': _uploadSuccessCtrl.text.trim(),
      'feed_empty_label': _feedEmptyCtrl.text.trim(),
    });
    await FFAppState().refreshAdminRuntimeSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Textos actualizados')),
      );
    }
  }

  Future<void> _openOverrideDialog({Map<String, dynamic>? existing}) async {
    final notesCtrl =
        TextEditingController(text: existing?['notes']?.toString() ?? '');
    String? selectedUserId = existing?['user_id']?.toString();
    String? selectedFeatureKey = existing?['feature_key']?.toString();
    bool enabled = existing?['is_enabled'] == true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nuevo override' : 'Editar override'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Usuario',
                    style: FlutterFlowTheme.of(ctx).bodyMedium.override(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildOverrideUserSelectorTile(
                  ctx,
                  user: _findOverrideUser(selectedUserId ?? ''),
                  onTap: () async {
                    final pickedUserId =
                        await _pickOverrideUser(selectedUserId);
                    if (pickedUserId != null && pickedUserId.isNotEmpty) {
                      setDialogState(() => selectedUserId = pickedUserId);
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _featureOrder.contains(selectedFeatureKey)
                      ? selectedFeatureKey
                      : null,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Funcionalidad'),
                  items: _featureOrder
                      .map(
                        (featureKey) => DropdownMenuItem<String>(
                          value: featureKey,
                          child: Text(_featureLabel(featureKey)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedFeatureKey = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                  title: const Text('Habilitado'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final userId = selectedUserId?.trim() ?? '';
    final featureKey = selectedFeatureKey?.trim().toLowerCase() ?? '';
    if (userId.isEmpty || featureKey.isEmpty) return;

    try {
      await SupaFlow.client.from('admin_user_feature_overrides').upsert({
        if (existing != null) 'id': existing['id'],
        'user_id': userId,
        'feature_key': featureKey,
        'is_enabled': enabled,
        'notes': notesCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserUid,
      });
      await _loadOverrides();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Admin override save error: $e');
    } finally {
      notesCtrl.dispose();
    }
  }

  Future<void> _deleteOverride(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await SupaFlow.client
          .from('admin_user_feature_overrides')
          .delete()
          .eq('id', id);
      await _loadOverrides();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Admin override delete error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        title: Text(
          'Configuración',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                fontFamily: 'Poppins',
                color: Colors.white,
                letterSpacing: 0.0,
              ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modo piloto global',
                        style: FlutterFlowTheme.of(context).headlineSmall),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Plan Free: subir videos, Explorer y Feed. '
                        'Plan Pro: desafíos, convocatorias y cursos. '
                        'Cuando el modo piloto está activado, todos los paywalls quedan deshabilitados.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _pilotEnabled,
                      onChanged: (value) async {
                        setState(() => _pilotEnabled = value);
                        await _persistPilot();
                      },
                      title:
                          const Text('ON = sin restricciones / sin paywalls'),
                      subtitle: const Text(
                        'Libera funciones Pro y envío de convocatorias para todos los usuarios.',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    Text('Feature flags',
                        style: FlutterFlowTheme.of(context).headlineSmall),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Cada switch controla la disponibilidad global de una sección. Si está apagado, la función se oculta o queda bloqueada incluso para usuarios con plan. Usá overrides solo para excepciones puntuales por usuario.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._featureOrder.map(
                      (key) => SwitchListTile(
                        value: _featureFlags[key] ?? true,
                        onChanged: (value) async {
                          setState(() => _featureFlags[key] = value);
                          await _persistFlags();
                        },
                        title: Text(_featureLabel(key)),
                        subtitle: Text(_featureDescription(key)),
                        isThreeLine: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Textos de UI',
                        style: FlutterFlowTheme.of(context).headlineSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _blockedTitleCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Título bloqueado'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _blockedMessageCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Mensaje de bloqueo'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _uploadMessageCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Mensaje al subir intento'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _uploadSuccessCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Mensaje de éxito'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _feedEmptyCtrl,
                      decoration:
                        const InputDecoration(labelText: 'Feed vacío'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _persistTexts,
                        child: const Text('Guardar textos'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text('Overrides por usuario',
                            style: FlutterFlowTheme.of(context).headlineSmall),
                        TextButton.icon(
                          onPressed: () => _openOverrideDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('+ Nuevo override'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_overrides.isEmpty)
                      const Text('No hay overrides cargados.')
                    else
                      Column(
                        children: _overrides.map((row) {
                          final feature = row['feature_key'] ?? '';
                          final userId = row['user_id'] ?? '';
                          final user = _findOverrideUser(userId.toString());
                          final enabled = row['is_enabled'] == true;
                          final role =
                              _normalizeOverrideRole(user?['userType']);
                          return Card(
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _featureLabel(feature.toString()),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: enabled
                                          ? FlutterFlowTheme.of(context)
                                              .successBg
                                          : FlutterFlowTheme.of(context)
                                              .warningBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      enabled ? 'ON' : 'OFF',
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            fontFamily: 'Inter',
                                            color: enabled
                                                ? FlutterFlowTheme.of(context)
                                                    .successMain
                                                : FlutterFlowTheme.of(context)
                                                    .warningMain,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _buildOverrideRoleChip(context, role),
                                      Text(
                                        _overrideUserName(user),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _overrideUserSecondary(user),
                                    style: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .override(
                                          fontFamily: 'Inter',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                  if ((row['notes']?.toString().trim() ?? '')
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        row['notes'].toString().trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openOverrideDialog(existing: row);
                                  } else if (value == 'delete') {
                                    _deleteOverride(row);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
