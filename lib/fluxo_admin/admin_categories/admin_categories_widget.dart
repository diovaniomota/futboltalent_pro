import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'admin_categories_model.dart';
export 'admin_categories_model.dart';

class AdminCategoriesWidget extends StatefulWidget {
  const AdminCategoriesWidget({super.key});

  static String routeName = 'admin_categories';
  static String routePath = '/adminCategories';

  @override
  State<AdminCategoriesWidget> createState() => _AdminCategoriesWidgetState();
}

class _AdminCategoriesWidgetState extends State<AdminCategoriesWidget> {
  late AdminCategoriesModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminCategoriesModel());
    _loadCategories();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupaFlow.client
          .from('challenge_categories')
          .select()
          .order('name');
      _categories = List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('AdminCategories load error: $e');
      _categories = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<void> _openEditor({Map<String, dynamic>? category}) async {
    final nameCtrl =
        TextEditingController(text: category?['name']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: category?['description']?.toString() ?? '');
    bool isActive = category?['is_active'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Nueva categoría' : 'Editar categoría'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isActive,
                  onChanged: (value) =>
                      setDialogState(() => isActive = value),
                  title: const Text('Activa'),
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

    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final payload = {
      if (category != null) 'id': category['id'],
      'name': name,
      'slug': _slugify(name),
      'description': descCtrl.text.trim(),
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await SupaFlow.client.from('challenge_categories').upsert(payload);
      await _loadCategories();
    } catch (e) {
      debugPrint('AdminCategories save error: $e');
    } finally {
      nameCtrl.dispose();
      descCtrl.dispose();
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final id = category['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('Eliminar ${category['name'] ?? ''}?'),
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
      await SupaFlow.client
          .from('challenge_categories')
          .delete()
          .eq('id', id);
      await _loadCategories();
    } catch (e) {
      debugPrint('AdminCategories delete error: $e');
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
          'Categorías',
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
            tooltip: 'Nueva categoría',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final active = category['is_active'] != false;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(category['name']?.toString() ?? ''),
                      subtitle: Text(category['description']?.toString() ?? ''),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditor(category: category);
                          } else if (value == 'delete') {
                            _deleteCategory(category);
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
                      leading: Icon(
                        active ? Icons.check_circle : Icons.pause_circle,
                        color: active ? Colors.green : Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
