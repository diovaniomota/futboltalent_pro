import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'admin_convocatorias_model.dart';
export 'admin_convocatorias_model.dart';

class AdminConvocatoriasWidget extends StatefulWidget {
  const AdminConvocatoriasWidget({super.key});

  static String routeName = 'admin_convocatorias';
  static String routePath = '/adminConvocatorias';

  @override
  State<AdminConvocatoriasWidget> createState() =>
      _AdminConvocatoriasWidgetState();
}

class _AdminConvocatoriasWidgetState extends State<AdminConvocatoriasWidget> {
  late AdminConvocatoriasModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _convocatorias = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _clubs = [];

  String _firstNonEmptyValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final text = data[key]?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  String _normalizedUserType(Map<String, dynamic> user) {
    return (user['userType'] ?? user['usertype'] ?? user['user_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  String _clubBaseName(Map<String, dynamic> club) {
    return _firstNonEmptyValue(club, [
      'nombre',
      'name',
      'club_name',
      'display_name',
      'username',
      'user_name',
    ]);
  }

  List<String> _clubRefs(Map<String, dynamic> club) {
    final refs = <String>{};
    for (final key in ['value', 'id', 'owner_id', 'user_id', 'club_id']) {
      final ref = club[key]?.toString().trim() ?? '';
      if (ref.isNotEmpty && ref.toLowerCase() != 'null') {
        refs.add(ref);
      }
    }
    final extraRefs = club['refs'];
    if (extraRefs is List) {
      for (final value in extraRefs) {
        final ref = value?.toString().trim() ?? '';
        if (ref.isNotEmpty && ref.toLowerCase() != 'null') {
          refs.add(ref);
        }
      }
    }
    return refs.toList();
  }

  bool _clubMatchesRef(Map<String, dynamic> club, String? ref) {
    final normalizedRef = ref?.trim() ?? '';
    if (normalizedRef.isEmpty) return false;
    return _clubRefs(club).contains(normalizedRef);
  }

  String _clubValue(Map<String, dynamic> club) {
    return _firstNonEmptyValue(club, ['value', 'id', 'owner_id', 'user_id', 'club_id']);
  }

  Map<String, dynamic>? _findClubByValue(String? value) {
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) return null;
    for (final club in _clubs) {
      if (_clubValue(club) == normalizedValue || _clubMatchesRef(club, normalizedValue)) {
        return club;
      }
    }
    return null;
  }

  String? _selectedClubValueForDialog(String? currentRef) {
    final normalizedRef = currentRef?.trim() ?? '';
    if (normalizedRef.isEmpty) return null;
    for (final club in _clubs) {
      if (_clubMatchesRef(club, normalizedRef)) {
        return _clubValue(club);
      }
    }
    return null;
  }

  void _mergeClubOption(
    List<Map<String, dynamic>> clubs,
    Map<String, dynamic> candidate,
  ) {
    final candidateValue = _clubValue(candidate);
    if (candidateValue.isEmpty) return;

    final candidateRefs = _clubRefs(candidate).toSet();
    if (candidateRefs.isEmpty) return;

    for (final existing in clubs) {
      final existingRefs = _clubRefs(existing).toSet();
      if (existingRefs.intersection(candidateRefs).isEmpty) {
        continue;
      }

      if (_clubBaseName(existing).isEmpty && _clubBaseName(candidate).isNotEmpty) {
        existing['nombre'] = candidate['nombre'];
        existing['name'] = candidate['name'];
        existing['club_name'] = candidate['club_name'];
        existing['display_name'] = candidate['display_name'];
      }

      if ((existing['nombre_corto']?.toString().trim().isEmpty ?? true) &&
          (candidate['nombre_corto']?.toString().trim().isNotEmpty ?? false)) {
        existing['nombre_corto'] = candidate['nombre_corto'];
      }

      for (final key in ['id', 'owner_id', 'user_id', 'club_id']) {
        if ((existing[key]?.toString().trim().isEmpty ?? true) &&
            (candidate[key]?.toString().trim().isNotEmpty ?? false)) {
          existing[key] = candidate[key];
        }
      }

      existing['refs'] = {...existingRefs, ...candidateRefs}.toList();
      existing['value'] = _clubValue(existing);
      if ((existing['value']?.toString().trim().isEmpty ?? true) &&
          candidateValue.isNotEmpty) {
        existing['value'] = candidateValue;
      }
      return;
    }

    clubs.add({
      ...candidate,
      'value': candidateValue,
      'refs': candidateRefs.toList(),
    });
  }

  Future<List<Map<String, dynamic>>> _loadClubOptions() async {
    final clubs = <Map<String, dynamic>>[];

    try {
      final clubsResponse = await SupaFlow.client.from('clubs').select();
      for (final row in List<Map<String, dynamic>>.from(clubsResponse as List)) {
        final normalized = Map<String, dynamic>.from(row);
        normalized['value'] = _firstNonEmptyValue(normalized, [
          'id',
          'owner_id',
          'user_id',
          'club_id',
        ]);
        _mergeClubOption(clubs, normalized);
      }
    } catch (error) {
      debugPrint('AdminConvocatorias clubs table load error: $error');
    }

    try {
      final usersResponse = await SupaFlow.client.from('users').select();
      for (final row in List<Map<String, dynamic>>.from(usersResponse as List)) {
        final normalized = Map<String, dynamic>.from(row);
        if (_normalizedUserType(normalized) != 'club') continue;

        final userId = _firstNonEmptyValue(normalized, ['user_id', 'id']);
        if (userId.isEmpty) continue;

        _mergeClubOption(clubs, {
          'value': userId,
          'user_id': userId,
          'id': normalized['id'],
          'display_name': _firstNonEmptyValue(normalized, [
            'club_name',
            'name',
            'username',
          ]),
          'nombre': _firstNonEmptyValue(normalized, [
            'club_name',
            'name',
            'username',
          ]),
          'club_name': normalized['club_name'],
          'username': normalized['username'],
          'refs': [userId],
        });
      }
    } catch (error) {
      debugPrint('AdminConvocatorias club users load error: $error');
    }

    clubs.sort((a, b) => _clubLabel(a).toLowerCase().compareTo(
          _clubLabel(b).toLowerCase(),
        ));
    return clubs;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminConvocatoriasModel());
    _loadConvocatorias();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConvocatorias() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupaFlow.client
          .from('convocatorias')
          .select()
          .order('created_at', ascending: false);
      final convocatorias = List<Map<String, dynamic>>.from(response as List);

      try {
        _clubs = await _loadClubOptions();
      } catch (clubError) {
        debugPrint('AdminConvocatorias clubs load error: $clubError');
        _clubs = [];
      }

      final ids = convocatorias
          .map((c) => c['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final counts = <String, int>{};

      if (ids.isNotEmpty) {
        try {
          final postResponse = await SupaFlow.client
              .from('aplicaciones_convocatoria')
              .select('convocatoria_id')
              .inFilter('convocatoria_id', ids);
          for (final row in List<Map<String, dynamic>>.from(postResponse as List)) {
            final id = row['convocatoria_id']?.toString() ?? '';
            if (id.isEmpty) continue;
            counts[id] = (counts[id] ?? 0) + 1;
          }
        } catch (_) {}

        try {
          final postResponse = await SupaFlow.client
              .from('postulaciones')
              .select('convocatoria_id')
              .inFilter('convocatoria_id', ids);
          for (final row in List<Map<String, dynamic>>.from(postResponse as List)) {
            final id = row['convocatoria_id']?.toString() ?? '';
            if (id.isEmpty) continue;
            counts[id] = (counts[id] ?? 0) + 1;
          }
        } catch (_) {}
      }

      for (final conv in convocatorias) {
        final id = conv['id']?.toString() ?? '';
        conv['postulaciones_count'] = counts[id] ?? 0;
      }

      _convocatorias = convocatorias;
      _applyFilters();
    } catch (e) {
      debugPrint('AdminConvocatorias load error: $e');
      _convocatorias = [];
      _filtered = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    _filtered = _convocatorias.where((conv) {
      if (query.isEmpty) return true;
      final title = (conv['titulo'] ?? conv['title'] ?? '').toString().toLowerCase();
      final category =
          (conv['categoria'] ?? conv['category'] ?? '').toString().toLowerCase();
      final position =
          (conv['posicion'] ?? conv['position'] ?? '').toString().toLowerCase();
      return title.contains(query) ||
          category.contains(query) ||
          position.contains(query);
    }).toList();
    if (mounted) setState(() {});
  }

  String _clubLabel(Map<String, dynamic> club) {
    final name = _clubBaseName(club).isNotEmpty ? _clubBaseName(club) : 'Club';
    final short = (club['nombre_corto'] ?? '').toString().trim();
    if (short.isNotEmpty && short.toLowerCase() != name.toLowerCase()) {
      return '$name · $short';
    }
    return name;
  }

  Future<void> _openEditor({Map<String, dynamic>? convocatoria}) async {
    final titleCtrl =
        TextEditingController(text: convocatoria?['titulo']?.toString() ?? '');
    final categoryCtrl = TextEditingController(
        text: convocatoria?['categoria']?.toString() ?? '');
    final positionCtrl = TextEditingController(
        text: convocatoria?['posicion']?.toString() ?? '');
    final countryCtrl = TextEditingController(
        text: convocatoria?['pais']?.toString() ?? '');
    final cityCtrl = TextEditingController(
        text: convocatoria?['ciudad']?.toString() ??
            convocatoria?['ubicacion']?.toString() ??
            '');
    final originalClubRef = convocatoria?['club_id']?.toString().trim();
    String? selectedClubId = _selectedClubValueForDialog(originalClubRef);
    DateTime? startDate = _parseDate(convocatoria?['fecha_inicio']);
    DateTime? endDate = _parseDate(convocatoria?['fecha_fin']) ??
        _parseDate(convocatoria?['fecha_cierre']);
    bool isActive = convocatoria?['is_active'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(convocatoria == null
              ? 'Nueva convocatoria'
              : 'Editar convocatoria'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: positionCtrl,
                  decoration: const InputDecoration(labelText: 'Posición'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: countryCtrl,
                  decoration: const InputDecoration(labelText: 'País'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cityCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Ciudad / Ubicación'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _clubs.any((club) => _clubValue(club) == selectedClubId)
                      ? selectedClubId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Club'),
                  items: _clubs
                      .map(
                        (club) => DropdownMenuItem<String>(
                          value: _clubValue(club),
                          child: Text(
                            _clubLabel(club),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedClubId = value),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isActive,
                  onChanged: (value) =>
                      setDialogState(() => isActive = value),
                  title: const Text('Activa'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 3650)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setDialogState(() => startDate = picked);
                          }
                        },
                        child: Text(startDate == null
                            ? 'Fecha inicio'
                            : '${startDate!.day}/${startDate!.month}/${startDate!.year}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 3650)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setDialogState(() => endDate = picked);
                          }
                        },
                        child: Text(endDate == null
                            ? 'Fecha fin'
                            : '${endDate!.day}/${endDate!.month}/${endDate!.year}'),
                      ),
                    ),
                  ],
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

    final selectedClub = _findClubByValue(selectedClubId);
    final selectedClubRefs = selectedClub == null ? const <String>[] : _clubRefs(selectedClub);
    final clubIdForSave = (originalClubRef?.isNotEmpty ?? false) &&
            selectedClubRefs.contains(originalClubRef)
        ? originalClubRef
        : (selectedClubId?.trim().isNotEmpty ?? false)
            ? selectedClubId!.trim()
            : (convocatoria?['club_id']?.toString().trim() ?? '');
    final selectedClubName = selectedClub == null
        ? ''
        : (_clubBaseName(selectedClub).isNotEmpty
            ? _clubBaseName(selectedClub)
            : _clubLabel(selectedClub));

    final payload = <String, dynamic>{
      if (convocatoria != null) 'id': convocatoria['id'],
      'titulo': titleCtrl.text.trim().isEmpty
          ? 'Convocatoria'
          : titleCtrl.text.trim(),
      'categoria': categoryCtrl.text.trim(),
      'posicion': positionCtrl.text.trim(),
      'pais': countryCtrl.text.trim(),
      'ciudad': cityCtrl.text.trim(),
      'ubicacion': cityCtrl.text.trim(),
      'club_id': clubIdForSave,
      if (selectedClubName.isNotEmpty) 'club_name': selectedClubName,
      if (selectedClubName.isNotEmpty) 'club_nombre': selectedClubName,
      'is_active': isActive,
      'estado': isActive ? 'activa' : 'cerrada',
      'updated_at': DateTime.now().toIso8601String(),
      if (startDate != null) 'fecha_inicio': startDate!.toIso8601String(),
      if (endDate != null) 'fecha_fin': endDate!.toIso8601String(),
      if (convocatoria == null)
        'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await SupaFlow.client.from('convocatorias').upsert(payload);
      await _loadConvocatorias();
    } catch (e) {
      debugPrint('AdminConvocatorias save error: $e');
    } finally {
      titleCtrl.dispose();
      categoryCtrl.dispose();
      positionCtrl.dispose();
      countryCtrl.dispose();
      cityCtrl.dispose();
    }
  }

  Future<void> _deleteConvocatoria(Map<String, dynamic> conv) async {
    final id = conv['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar convocatoria'),
        content: Text('Eliminar ${conv['titulo'] ?? ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await SupaFlow.client.from('convocatorias').delete().eq('id', id);
      await _loadConvocatorias();
    } catch (e) {
      debugPrint('AdminConvocatorias delete error: $e');
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        title: Text(
          'Convocatorias',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                fontFamily: 'Poppins',
                color: Colors.white,
                letterSpacing: 0.0,
              ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Nueva convocatoria',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar convocatoria...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadConvocatorias,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final conv = _filtered[index];
                        final isActive = conv['is_active'] != false;
                        final postulaciones =
                            conv['postulaciones_count'] ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(conv['titulo']?.toString() ?? ''),
                            subtitle: Text(
                              '${conv['categoria'] ?? ''} · ${conv['posicion'] ?? ''} · $postulaciones postulaciones',
                            ),
                            leading: Icon(
                              isActive ? Icons.check_circle : Icons.pause_circle,
                              color: isActive ? Colors.green : Colors.grey,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openEditor(convocatoria: conv);
                                } else if (value == 'delete') {
                                  _deleteConvocatoria(conv);
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
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
