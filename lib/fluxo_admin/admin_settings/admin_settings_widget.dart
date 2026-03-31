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

    await _loadOverrides();
    if (mounted) setState(() => _isLoading = false);
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
        return 'Desafios';
      case 'convocatorias':
        return 'Convocatorias';
      case 'convocatoria_send':
        return 'Envio de convocatórias';
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
        return 'Incluído no plano Free.';
      case 'desafios':
        return 'Conteúdo do plano Pro com paywall.';
      case 'convocatorias':
        return 'Acesso aos resultados e detalhes da convocatória no Pro.';
      case 'convocatoria_send':
        return 'Paywall para enviar ou convidar jogadores a convocatórias.';
      case 'cursos':
        return 'Conteúdo exclusivo do plano Pro com paywall.';
      default:
        return 'Controle global da funcionalidade.';
    }
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
    final userIdCtrl =
        TextEditingController(text: existing?['user_id']?.toString() ?? '');
    final featureCtrl =
        TextEditingController(text: existing?['feature_key']?.toString() ?? '');
    final notesCtrl =
        TextEditingController(text: existing?['notes']?.toString() ?? '');
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
                TextField(
                  controller: userIdCtrl,
                  decoration:
                      const InputDecoration(labelText: 'User ID (auth uid)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: featureCtrl,
                  decoration: const InputDecoration(labelText: 'Feature key'),
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

    final userId = userIdCtrl.text.trim();
    final featureKey = featureCtrl.text.trim().toLowerCase();
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
      userIdCtrl.dispose();
      featureCtrl.dispose();
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
          'Configurações',
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
                        'Plano Free: subir videos, Explorer e Feed. '
                        'Plano Pro: desafios, convocatórias e cursos. '
                        'Quando o modo piloto está ON, todos os paywalls ficam desativados.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _pilotEnabled,
                      onChanged: (value) async {
                        setState(() => _pilotEnabled = value);
                        await _persistPilot();
                      },
                      title: const Text('ON = sem restrições / sem paywalls'),
                      subtitle: const Text(
                        'Libera funcionalidades Pro e envio de convocatórias para todos os usuários.',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    Text('Feature flags',
                        style: FlutterFlowTheme.of(context).headlineSmall),
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
                          const InputDecoration(labelText: 'Mensagem bloqueio'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _uploadMessageCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Mensagem upload desafio'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _uploadSuccessCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Mensagem sucesso upload'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _feedEmptyCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Feed vazio'),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Overrides por usuário',
                            style: FlutterFlowTheme.of(context).headlineSmall),
                        TextButton.icon(
                          onPressed: () => _openOverrideDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Nuevo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_overrides.isEmpty)
                      const Text('Nenhum override cadastrado.')
                    else
                      Column(
                        children: _overrides.map((row) {
                          final feature = row['feature_key'] ?? '';
                          final userId = row['user_id'] ?? '';
                          final enabled = row['is_enabled'] == true;
                          return Card(
                            child: ListTile(
                              title:
                                  Text('$feature · ${enabled ? "ON" : "OFF"}'),
                              subtitle: Text('User: $userId'),
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
