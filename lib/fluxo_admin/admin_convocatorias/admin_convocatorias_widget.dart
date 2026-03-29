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
    final clubCtrl =
        TextEditingController(text: convocatoria?['club_id']?.toString() ?? '');
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
                TextField(
                  controller: clubCtrl,
                  decoration: const InputDecoration(labelText: 'Club ID'),
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
      'club_id': clubCtrl.text.trim().isEmpty
          ? (convocatoria == null ? '' : (convocatoria['club_id'] ?? ''))
          : clubCtrl.text.trim(),
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
      clubCtrl.dispose();
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
