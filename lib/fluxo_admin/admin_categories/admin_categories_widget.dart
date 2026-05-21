import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final Map<String, int> _linkedChallengesByCategoryId = {};

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
      final results = await Future.wait([
        SupaFlow.client.from('challenge_categories').select().order('name'),
        SupaFlow.client.from('courses').select('category_id'),
        SupaFlow.client.from('exercises').select('category_id'),
      ]);
      _categories = List<Map<String, dynamic>>.from(results[0] as List);
      _linkedChallengesByCategoryId.clear();
      final courseRows = List<Map<String, dynamic>>.from(results[1] as List);
      final exerciseRows = List<Map<String, dynamic>>.from(results[2] as List);
      for (final row in [...courseRows, ...exerciseRows]) {
        final categoryId = row['category_id']?.toString().trim() ?? '';
        if (categoryId.isEmpty) continue;
        _linkedChallengesByCategoryId[categoryId] =
            (_linkedChallengesByCategoryId[categoryId] ?? 0) + 1;
      }
    } catch (e) {
      debugPrint('AdminCategories load error: $e');
      _categories = [];
      _linkedChallengesByCategoryId.clear();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  String _resolveCategoryCoverUrl(Map<String, dynamic>? category) {
    if (category == null) return '';
    final candidates = [
      category['cover_url'],
      category['image_url'],
      category['thumbnail_url'],
      category['banner_url'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _extensionFromName(String fileName, String fallback) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return fallback;
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _contentTypeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<String> _uploadCategoryCover({required XFile file}) async {
    final ext = _extensionFromName(file.name, 'jpg');
    final fileName =
        'category_cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
    late final Uint8List bytes;
    if (kIsWeb) {
      bytes = await file.readAsBytes();
    } else {
      bytes = await File(file.path).readAsBytes();
    }
    final path = 'challenge_categories/covers/$fileName';
    await SupaFlow.client.storage.from('Videos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeForExtension(ext),
            upsert: true,
          ),
        );
    return SupaFlow.client.storage.from('Videos').getPublicUrl(path);
  }

  Widget _buildSelectedCoverPreview(XFile file) {
    if (kIsWeb) {
      return Image.network(
        file.path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildCategoryCoverPlaceholder(),
      );
    }
    return Image.file(
      File(file.path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildCategoryCoverPlaceholder(),
    );
  }

  Widget _buildCategoryCoverPlaceholder({String? label}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D3B66), Color(0xFF123D74), Color(0xFF1E5A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.category_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            if (label != null && label.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                label.trim(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor({Map<String, dynamic>? category}) async {
    final nameCtrl =
        TextEditingController(text: category?['name']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: category?['description']?.toString() ?? '');
    bool isActive = category?['is_active'] != false;
    bool isSaving = false;
    XFile? selectedCoverFile;
    String existingCoverUrl = _resolveCategoryCoverUrl(category);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (isSaving) return;
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              _showSnack('Ingresá un nombre para la categoría.',
                  color: Colors.red);
              return;
            }
            setDialogState(() => isSaving = true);

            try {
              var finalCoverUrl = existingCoverUrl;
              if (selectedCoverFile != null) {
                finalCoverUrl =
                    await _uploadCategoryCover(file: selectedCoverFile!);
              }

              final payload = {
                if (category != null) 'id': category['id'],
                'name': name,
                'slug': _slugify(name),
                'description': descCtrl.text.trim(),
                'is_active': isActive,
                'cover_url': finalCoverUrl.isEmpty ? null : finalCoverUrl,
                'image_url': finalCoverUrl.isEmpty ? null : finalCoverUrl,
                'updated_at': DateTime.now().toIso8601String(),
              };

              await SupaFlow.client
                  .from('challenge_categories')
                  .upsert(payload);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              debugPrint('AdminCategories save error: $e');
              _showSnack(
                  'No se pudo guardar la categoría. Verifica los datos e intenta de nuevo.',
                  color: Colors.red);
              setDialogState(() => isSaving = false);
            }
          }

          final hasPreview =
              selectedCoverFile != null || existingCoverUrl.isNotEmpty;

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category == null
                                      ? 'Nueva categoría'
                                      : 'Editar categoría',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Definí el nombre, descripción y la portada que verá el jugador.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(ctx, false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        height: 168,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F0F172A),
                              blurRadius: 20,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (selectedCoverFile != null)
                                _buildSelectedCoverPreview(selectedCoverFile!)
                              else if (existingCoverUrl.isNotEmpty)
                                Image.network(
                                  existingCoverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildCategoryCoverPlaceholder(
                                    label: nameCtrl.text.trim().isEmpty
                                        ? null
                                        : nameCtrl.text.trim(),
                                  ),
                                )
                              else
                                _buildCategoryCoverPlaceholder(
                                  label: nameCtrl.text.trim().isEmpty
                                      ? null
                                      : nameCtrl.text.trim(),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.16),
                                      Colors.black.withValues(alpha: 0.58),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isActive ? 'Activa' : 'Inactiva',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 18,
                                right: 18,
                                bottom: 18,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nameCtrl.text.trim().isEmpty
                                          ? 'Vista previa'
                                          : nameCtrl.text.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        height: 1.05,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      hasPreview
                                          ? 'Esta portada se mostrará en el catálogo del jugador.'
                                          : 'Sumá una portada para que la categoría se vea mucho mejor.',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.86),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    try {
                                      final picker = ImagePicker();
                                      final picked = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 90,
                                      );
                                      if (picked == null) return;
                                      setDialogState(() {
                                        selectedCoverFile = picked;
                                      });
                                    } catch (_) {
                                      _showSnack(
                                        'No se pudo seleccionar la portada.',
                                        color: Colors.red,
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              selectedCoverFile == null
                                  ? (existingCoverUrl.isEmpty
                                      ? 'Subir portada'
                                      : 'Cambiar portada')
                                  : 'Portada lista: ${selectedCoverFile!.name}',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D3B66),
                              foregroundColor: Colors.white,
                            ),
                          ),
                          if (existingCoverUrl.isNotEmpty ||
                              selectedCoverFile != null)
                            OutlinedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () => setDialogState(() {
                                        selectedCoverFile = null;
                                        existingCoverUrl = '';
                                      }),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Quitar portada'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: nameCtrl,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Ej: Velocidad explosiva',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        minLines: 2,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Descripción',
                          hintText:
                              'Contá qué tipo de cursos o desafíos entran en esta categoría.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: isActive,
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(() => isActive = value),
                        title: const Text('Categoría activa'),
                        subtitle: const Text(
                          'Las categorías inactivas quedan ocultas para nuevas asignaciones.',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: isSaving ? null : submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0D3B66),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Guardar categoría'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    nameCtrl.dispose();
    descCtrl.dispose();
    if (result == true) {
      await _loadCategories();
      _showSnack(
        category == null
            ? 'Categoría creada correctamente.'
            : 'Categoría actualizada correctamente.',
        color: const Color(0xFF0D3B66),
      );
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
      await SupaFlow.client.from('challenge_categories').delete().eq('id', id);
      await _loadCategories();
      _showSnack('Categoría eliminada.', color: const Color(0xFF0D3B66));
    } catch (e) {
      debugPrint('AdminCategories delete error: $e');
      _showSnack(
          'No se pudo eliminar la categoría. Verifica tu conexión e intenta de nuevo.',
          color: Colors.red);
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D3B66), Color(0xFF1E5A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x220D3B66),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Organizá el catálogo',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Creá categorías con portada para que cursos y desafíos se vean mucho mejor en el catálogo del jugador.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildHeroStatChip(
                              icon: Icons.category_rounded,
                              label: '${_categories.length} categorías',
                            ),
                            _buildHeroStatChip(
                              icon: Icons.link_rounded,
                              label:
                                  '${_linkedChallengesByCategoryId.values.fold<int>(0, (sum, value) => sum + value)} vínculos',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nueva categoría'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0D3B66),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Crea las categorías primero y luego vincula cada curso o ejercicio desde la pantalla de Desafíos.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (_categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('Todavía no hay categorías creadas.'),
                      ),
                    )
                  else
                    ..._categories.map(_buildCategoryCard),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final active = category['is_active'] != false;
    final categoryId = category['id']?.toString() ?? '';
    final linkedCount = _linkedChallengesByCategoryId[categoryId] ?? 0;
    final description = category['description']?.toString().trim() ?? '';
    final coverUrl = _resolveCategoryCoverUrl(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              height: 132,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildCategoryCoverPlaceholder(
                        label: category['name']?.toString(),
                      ),
                    )
                  else
                    _buildCategoryCoverPlaceholder(
                      label: category['name']?.toString(),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        coverUrl.isEmpty ? 'Sin portada' : 'Con portada',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFDCFCE7)
                            : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        active ? 'Activa' : 'Inactiva',
                        style: TextStyle(
                          color: active
                              ? const Color(0xFF166534)
                              : const Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category['name']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description.isNotEmpty
                      ? description
                      : 'Sin descripción cargada todavía.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryMetaChip(
                      icon: Icons.link_rounded,
                      label: '$linkedCount contenido(s) vinculado(s)',
                    ),
                    _buildCategoryMetaChip(
                      icon: Icons.photo_outlined,
                      label: coverUrl.isEmpty ? 'Sin portada' : 'Portada lista',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditor(category: category),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D3B66),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteCategory(category),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryMetaChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0D3B66)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF355070),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
