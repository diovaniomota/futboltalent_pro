import 'dart:io';

import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'admin_desafios_model.dart';
export 'admin_desafios_model.dart';

class AdminDesafiosWidget extends StatefulWidget {
  const AdminDesafiosWidget({super.key});

  static String routeName = 'admin_desafios';
  static String routePath = '/adminDesafios';

  @override
  State<AdminDesafiosWidget> createState() => _AdminDesafiosWidgetState();
}

class _AdminDesafiosWidgetState extends State<AdminDesafiosWidget> {
  late AdminDesafiosModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _hasAttemptTable = true;
  String _typeFilter = 'todos';
  bool _onlyActive = false;

  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _filteredChallenges = [];
  List<Map<String, dynamic>> _attempts = [];
  List<Map<String, dynamic>> _categories = [];

  final Map<String, int> _attemptCountByChallengeKey = {};
  final Map<String, String> _userNameById = {};
  final Map<String, String> _categoryNameById = {};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminDesafiosModel());
    _loadData();
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _challengeKey(String type, String id) => '$type:$id';

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _displayNameForUser(String userId) {
    final known = _userNameById[userId];
    if (known != null && known.trim().isNotEmpty) return known.trim();
    if (userId.isEmpty) return 'Usuario desconocido';
    if (userId.length <= 8) return userId;
    return '${userId.substring(0, 8)}...';
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

  String _assetDisplayName(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(uri.pathSegments.last);
      }
    } catch (_) {}
    if (url.length <= 42) return url;
    return '${url.substring(0, 39)}...';
  }

  Widget _buildPersistedAssetCard({
    required String title,
    required String url,
    required IconData icon,
    bool isImage = false,
  }) {
    final hasAsset = url.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF0D3B66)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasAsset
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasAsset ? 'Cargado' : 'Sin cargar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: hasAsset
                        ? const Color(0xFF166534)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasAsset)
            const Text(
              'Todavía no hay un archivo guardado.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            )
          else ...[
            if (isImage)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      height: 84,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 84,
                        width: double.infinity,
                        color: const Color(0xFFE2E8F0),
                        alignment: Alignment.center,
                        child: const Text(
                          'No se pudo cargar la portada',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _assetDisplayName(url),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 18,
                    color: Color(0xFF0D3B66),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _assetDisplayName(url),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  String _resolvedChallengeVideoUrl(Map<String, dynamic> challenge) {
    final candidates = [
      challenge['video_url'],
      challenge['tutorial_video_url'],
      challenge['tutorial_url'],
    ];
    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _resolvedChallengeCoverUrl(Map<String, dynamic> challenge) {
    final candidates = [
      challenge['thumbnail_url'],
      challenge['image_url'],
      challenge['cover_url'],
    ];
    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _cacheBustedAssetUrl(String rawUrl, dynamic versionSeed) {
    final url = rawUrl.trim();
    if (url.isEmpty) return '';
    final seed = versionSeed?.toString().trim() ?? '';
    if (seed.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=${Uri.encodeQueryComponent(seed)}';
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        SupaFlow.client
            .from('courses')
            .select(
              'id, title, description, thumbnail_url, video_url, difficulty, duration_minutes, xp_reward, reward_type, reward_name, order_index, is_active, is_premium, created_at, updated_at, category_id, validity_days',
            )
            .order('order_index', ascending: true),
        SupaFlow.client
            .from('exercises')
            .select(
              'id, title, description, thumbnail_url, video_url, difficulty, duration_minutes, xp_reward, repetitions, sets, instructions, order_index, is_active, is_premium, created_at, updated_at, category_id, validity_days',
            )
            .order('order_index', ascending: true),
        SupaFlow.client
            .from('users')
            .select('user_id, name, lastname')
            .order('name', ascending: true),
      ]);

      final courses = List<Map<String, dynamic>>.from(results[0] as List);
      final exercises = List<Map<String, dynamic>>.from(results[1] as List);
      final users = List<Map<String, dynamic>>.from(results[2] as List);

      _categories = [];
      _categoryNameById.clear();
      try {
        final categoriesResponse = await SupaFlow.client
            .from('challenge_categories')
            .select('id, name')
            .order('name', ascending: true);
        final categories =
            List<Map<String, dynamic>>.from(categoriesResponse as List);
        _categories = categories;
        for (final row in categories) {
          final id = row['id']?.toString() ?? '';
          final name = row['name']?.toString() ?? '';
          if (id.isNotEmpty) {
            _categoryNameById[id] = name.isEmpty ? id : name;
          }
        }
      } catch (_) {
        _categories = [];
      }

      for (final row in users) {
        final userId = (row['user_id'] ?? '').toString();
        final fullName = '${row['name'] ?? ''} ${row['lastname'] ?? ''}'.trim();
        if (userId.isNotEmpty) {
          _userNameById[userId] =
              fullName.isEmpty ? 'Usuario sin nombre' : fullName;
        }
      }

      _attempts = [];
      _hasAttemptTable = true;
      _attemptCountByChallengeKey.clear();
      try {
        final attemptsResponse = await SupaFlow.client
            .from('user_challenge_attempts')
            .select(
              'id, user_id, item_id, item_type, video_url, status, submitted_at, video_id, updated_at',
            )
            .order('submitted_at', ascending: false);
        _attempts = List<Map<String, dynamic>>.from(attemptsResponse as List);
      } catch (e) {
        debugPrint('AdminDesafios: attempts table unavailable: $e');
        _hasAttemptTable = false;
      }

      for (final attempt in _attempts) {
        final key = _challengeKey(
          (attempt['item_type'] ?? '').toString(),
          (attempt['item_id'] ?? '').toString(),
        );
        _attemptCountByChallengeKey[key] =
            (_attemptCountByChallengeKey[key] ?? 0) + 1;
      }

      final combined = <Map<String, dynamic>>[];
      combined.addAll(
        courses.map(
          (item) => {
            ...item,
            'type': 'course',
          },
        ),
      );
      combined.addAll(
        exercises.map(
          (item) => {
            ...item,
            'type': 'exercise',
          },
        ),
      );
      combined.sort((a, b) {
        final cmp =
            _toInt(a['order_index']).compareTo(_toInt(b['order_index']));
        if (cmp != 0) return cmp;
        final aDate = _toDate(a['created_at']) ?? DateTime(1970);
        final bDate = _toDate(b['created_at']) ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _challenges = combined;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AdminDesafios load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showSnack('Error al cargar desafíos: $e', color: Colors.red);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    _filteredChallenges = _challenges.where((item) {
      final type = (item['type'] ?? '').toString();
      final isActive = item['is_active'] == true;
      final title = (item['title'] ?? '').toString().toLowerCase();
      final description = (item['description'] ?? '').toString().toLowerCase();
      final matchesType = _typeFilter == 'todos' || _typeFilter == type;
      final matchesActive = !_onlyActive || isActive;
      final matchesQuery =
          query.isEmpty || title.contains(query) || description.contains(query);
      return matchesType && matchesActive && matchesQuery;
    }).toList();
  }

  Future<int> _nextOrderIndex(String tableName) async {
    try {
      final response = await SupaFlow.client
          .from(tableName)
          .select('order_index')
          .order('order_index', ascending: false)
          .limit(1)
          .maybeSingle();
      return _toInt(response?['order_index']) + 1;
    } catch (_) {
      return 1;
    }
  }

  String _extensionFromName(String fileName, String fallback) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return fallback;
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _contentTypeForExtension(String ext) {
    switch (ext) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
      default:
        return 'video/mp4';
    }
  }

  Future<String> _uploadChallengeAsset({
    required XFile file,
    required String folder,
    required String fallbackExt,
  }) async {
    final fileName = file.name.isNotEmpty ? file.name : file.path;
    final ext = _extensionFromName(fileName, fallbackExt);
    Uint8List bytes;
    if (kIsWeb) {
      bytes = await file.readAsBytes();
    } else {
      bytes = await File(file.path).readAsBytes();
    }
    final path =
        'challenge_assets/admin/$folder/${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';
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

  Future<void> _toggleActive(Map<String, dynamic> challenge) async {
    final type = challenge['type']?.toString() ?? 'exercise';
    final table = type == 'course' ? 'courses' : 'exercises';
    final id = (challenge['id'] ?? '').toString();
    final isActive = challenge['is_active'] == true;
    try {
      await SupaFlow.client.from(table).update({
        'is_active': !isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      _showSnack(
        !isActive ? 'Desafío activado' : 'Desafío inactivado',
        color: const Color(0xFF0D3B66),
      );
      await _loadData();
    } catch (e) {
      debugPrint('Toggle challenge active failed: $e');
      _showSnack('No se pudo actualizar el desafío.', color: Colors.red);
    }
  }

  Future<void> _openCreateChallengeDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final videoUrlController = TextEditingController();
    final thumbnailController = TextEditingController();
    final difficultyController = TextEditingController(text: 'beginner');
    final durationController = TextEditingController(text: '15');
    final xpController = TextEditingController(text: '120');
    final rewardTypeController = TextEditingController(text: 'xp');
    final rewardNameController = TextEditingController();
    final repetitionsController = TextEditingController(text: '10');
    final setsController = TextEditingController(text: '3');
    final instructionsController = TextEditingController();
    final validityController = TextEditingController(text: '60');

    final formKey = GlobalKey<FormState>();
    String selectedType = 'exercise';
    String? selectedCategoryId;
    bool isPremium = false;
    bool isActive = true;
    bool isSaving = false;
    XFile? selectedVideoFile;
    XFile? selectedCoverFile;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (isSaving) return;
            if (!(formKey.currentState?.validate() ?? false)) return;

            setDialogState(() => isSaving = true);
            final table = selectedType == 'course' ? 'courses' : 'exercises';
            final nextOrder = await _nextOrderIndex(table);
            final now = DateTime.now().toIso8601String();
            int? maybeInt(String raw) {
              final text = raw.trim();
              if (text.isEmpty) return null;
              return int.tryParse(text);
            }

            try {
              var finalVideoUrl = videoUrlController.text.trim();
              if (selectedVideoFile != null) {
                finalVideoUrl = await _uploadChallengeAsset(
                  file: selectedVideoFile!,
                  folder: 'tutorials',
                  fallbackExt: 'mp4',
                );
              }
              if (finalVideoUrl.isEmpty) {
                _showSnack(
                  'Seleccioná un video tutorial desde el dispositivo.',
                  color: Colors.red,
                );
                setDialogState(() => isSaving = false);
                return;
              }

              var finalThumbnailUrl = thumbnailController.text.trim();
              if (selectedCoverFile != null) {
                finalThumbnailUrl = await _uploadChallengeAsset(
                  file: selectedCoverFile!,
                  folder: 'covers',
                  fallbackExt: 'jpg',
                );
              }
              if (finalThumbnailUrl.isEmpty) {
                _showSnack(
                  'Seleccioná la portada del desafío desde el dispositivo.',
                  color: Colors.red,
                );
                setDialogState(() => isSaving = false);
                return;
              }

              final payload = <String, dynamic>{
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
                'video_url': finalVideoUrl,
                'thumbnail_url': finalThumbnailUrl,
                'category_id': selectedCategoryId,
                'difficulty': difficultyController.text.trim().isEmpty
                    ? null
                    : difficultyController.text.trim(),
                'duration_minutes': maybeInt(durationController.text),
                'xp_reward': maybeInt(xpController.text) ?? 100,
                'validity_days': maybeInt(validityController.text) ?? 60,
                'order_index': nextOrder,
                'is_active': isActive,
                'is_premium': isPremium,
                'created_at': now,
                'updated_at': now,
              };

              if (selectedType == 'course') {
                payload['reward_type'] =
                    rewardTypeController.text.trim().isEmpty
                        ? null
                        : rewardTypeController.text.trim();
                payload['reward_name'] =
                    rewardNameController.text.trim().isEmpty
                        ? null
                        : rewardNameController.text.trim();
              } else {
                payload['repetitions'] = maybeInt(repetitionsController.text);
                payload['sets'] = maybeInt(setsController.text);
                payload['instructions'] =
                    instructionsController.text.trim().isEmpty
                        ? null
                        : instructionsController.text.trim();
              }

              await SupaFlow.client.from(table).insert(payload);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              debugPrint('Create challenge failed: $e');
              if (mounted) {
                _showSnack('No se pudo crear el desafío: $e',
                    color: Colors.red);
              }
              setDialogState(() => isSaving = false);
            }
          }

          return AlertDialog(
            title: const Text('Nuevo desafío'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: const [
                          DropdownMenuItem(
                              value: 'exercise', child: Text('Ejercicio')),
                          DropdownMenuItem(
                              value: 'course', child: Text('Curso')),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() => selectedType = value);
                              },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: titleController,
                        enabled: !isSaving,
                        decoration:
                            const InputDecoration(labelText: 'Título *'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresá un título.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: descriptionController,
                        enabled: !isSaving,
                        minLines: 2,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Descripción'),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Seleccioná el video tutorial desde tu dispositivo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  try {
                                    final picker = ImagePicker();
                                    final picked = await picker.pickVideo(
                                      source: ImageSource.gallery,
                                      maxDuration: const Duration(minutes: 10),
                                    );
                                    if (picked == null) return;
                                    setDialogState(() {
                                      selectedVideoFile = picked;
                                    });
                                  } catch (e) {
                                    _showSnack(
                                      'No se pudo seleccionar el video.',
                                      color: Colors.red,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            selectedVideoFile == null
                                ? 'Subir video desde dispositivo'
                                : 'Video seleccionado: ${selectedVideoFile!.name}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Seleccioná la portada del desafío desde tu dispositivo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
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
                                  } catch (e) {
                                    _showSnack(
                                      'No se pudo seleccionar la capa.',
                                      color: Colors.red,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.image_outlined),
                          label: Text(
                            selectedCoverFile == null
                                ? 'Subir portada desde dispositivo'
                                : 'Portada seleccionada: ${selectedCoverFile!.name}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        value: selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin categoría'),
                          ),
                          ..._categories.map(
                            (cat) => DropdownMenuItem<String?>(
                              value: cat['id']?.toString(),
                              child: Text(cat['name']?.toString() ?? ''),
                            ),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedCategoryId = value;
                                });
                              },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: validityController,
                        enabled: !isSaving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Vigencia (días)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: difficultyController,
                              enabled: !isSaving,
                              decoration: const InputDecoration(
                                  labelText: 'Dificultad'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: durationController,
                              enabled: !isSaving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duración (min)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: xpController,
                        enabled: !isSaving,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Recompensa XP'),
                      ),
                      const SizedBox(height: 10),
                      if (selectedType == 'course') ...[
                        TextFormField(
                          controller: rewardTypeController,
                          enabled: !isSaving,
                          decoration:
                              const InputDecoration(
                                labelText: 'Tipo de recompensa',
                              ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: rewardNameController,
                          enabled: !isSaving,
                          decoration:
                              const InputDecoration(
                                labelText: 'Nombre de recompensa',
                              ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: repetitionsController,
                                enabled: !isSaving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Repeticiones',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: setsController,
                                enabled: !isSaving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Series',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: instructionsController,
                          enabled: !isSaving,
                          minLines: 2,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(labelText: 'Instrucciones'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(() => isActive = value),
                        title: const Text('Activo'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isPremium,
                        onChanged: isSaving
                            ? null
                            : (value) =>
                                setDialogState(() => isPremium = value),
                        title: const Text('Premium'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: isSaving ? null : submit,
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    videoUrlController.dispose();
    thumbnailController.dispose();
    difficultyController.dispose();
    durationController.dispose();
    xpController.dispose();
    validityController.dispose();
    rewardTypeController.dispose();
    rewardNameController.dispose();
    repetitionsController.dispose();
    setsController.dispose();
    instructionsController.dispose();

    if (created == true) {
      _showSnack('Desafío creado correctamente.',
          color: const Color(0xFF0D3B66));
      await _loadData();
    }
  }

  Future<void> _openEditChallengeDialog(Map<String, dynamic> challenge) async {
    final titleController =
        TextEditingController(text: challenge['title'] ?? '');
    final descriptionController =
        TextEditingController(text: challenge['description'] ?? '');
    final difficultyController =
        TextEditingController(text: challenge['difficulty'] ?? '');
    final durationController = TextEditingController(
        text: challenge['duration_minutes']?.toString() ?? '');
    final xpController =
        TextEditingController(text: challenge['xp_reward']?.toString() ?? '');
    final validityController = TextEditingController(
        text: challenge['validity_days']?.toString() ?? '60');
    final rewardTypeController =
        TextEditingController(text: challenge['reward_type'] ?? '');
    final rewardNameController =
        TextEditingController(text: challenge['reward_name'] ?? '');
    final repetitionsController =
        TextEditingController(text: challenge['repetitions']?.toString() ?? '');
    final setsController =
        TextEditingController(text: challenge['sets']?.toString() ?? '');
    final instructionsController =
        TextEditingController(text: challenge['instructions'] ?? '');
    String? selectedCategoryId = challenge['category_id']?.toString();
    bool isActive = challenge['is_active'] == true;
    bool isPremium = challenge['is_premium'] == true;
    final type = challenge['type']?.toString() ?? 'exercise';
    final currentVideoUrl = _resolvedChallengeVideoUrl(challenge);
    final currentCoverUrl = _resolvedChallengeCoverUrl(challenge);
    final currentCoverPreviewUrl = _cacheBustedAssetUrl(
      currentCoverUrl,
      challenge['updated_at'],
    );
    XFile? selectedVideoFile;
    XFile? selectedCoverFile;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar desafío'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      selectedVideoFile == null
                          ? currentVideoUrl.isNotEmpty
                              ? 'Video tutorial guardado. Podés reemplazarlo desde tu dispositivo.'
                              : 'Todavía no cargaste un video tutorial para este desafío.'
                          : 'Nuevo video seleccionado: ${selectedVideoFile!.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPersistedAssetCard(
                    title: 'Video tutorial actual',
                    url: currentVideoUrl,
                    icon: Icons.smart_display_outlined,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                              try {
                                final picker = ImagePicker();
                                final picked = await picker.pickVideo(
                                  source: ImageSource.gallery,
                                  maxDuration: const Duration(minutes: 10),
                                );
                                if (picked == null) return;
                                setDialogState(() => selectedVideoFile = picked);
                              } catch (_) {
                                _showSnack(
                                  'No se pudo seleccionar el video.',
                                  color: Colors.red,
                                );
                              }
                            },
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        selectedVideoFile == null
                            ? currentVideoUrl.isNotEmpty
                                ? 'Reemplazar video del dispositivo'
                                : 'Seleccionar video del dispositivo'
                            : 'Cambiar video seleccionado',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      selectedCoverFile == null
                          ? currentCoverUrl.isNotEmpty
                              ? 'Portada guardada. Podés reemplazarla desde tu dispositivo.'
                              : 'Todavía no cargaste una portada para este desafío.'
                          : 'Nueva portada seleccionada: ${selectedCoverFile!.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPersistedAssetCard(
                    title: 'Portada actual',
                    url: currentCoverPreviewUrl,
                    icon: Icons.image_outlined,
                    isImage: true,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                              try {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 90,
                                );
                                if (picked == null) return;
                                setDialogState(() => selectedCoverFile = picked);
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
                            ? currentCoverUrl.isNotEmpty
                                ? 'Reemplazar portada del dispositivo'
                                : 'Seleccionar portada del dispositivo'
                            : 'Cambiar portada seleccionada',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin categoría'),
                      ),
                      ..._categories.map(
                        (cat) => DropdownMenuItem<String?>(
                          value: cat['id']?.toString(),
                          child: Text(cat['name']?.toString() ?? ''),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                            setDialogState(() => selectedCategoryId = value),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: validityController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Vigencia (días)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: difficultyController,
                          decoration:
                              const InputDecoration(labelText: 'Dificultad'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duración (min)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: xpController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Recompensa XP'),
                  ),
                  const SizedBox(height: 10),
                  if (type == 'course') ...[
                    TextFormField(
                      controller: rewardTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de recompensa',
                        ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: rewardNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de recompensa',
                        ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: repetitionsController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Repeticiones'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: setsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Series'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: instructionsController,
                      decoration:
                          const InputDecoration(labelText: 'Instrucciones'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                    title: const Text('Activo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: isPremium,
                    onChanged: (value) =>
                        setDialogState(() => isPremium = value),
                    title: const Text('Premium'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (result != true) return;

    int? maybeInt(String raw) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      return int.tryParse(text);
    }

    final table = type == 'course' ? 'courses' : 'exercises';
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      var finalVideoUrl = _resolvedChallengeVideoUrl(challenge);
      if (selectedVideoFile != null) {
        finalVideoUrl = await _uploadChallengeAsset(
          file: selectedVideoFile!,
          folder: 'tutorials',
          fallbackExt: 'mp4',
        );
      }

      var finalThumbnailUrl = _resolvedChallengeCoverUrl(challenge);
      if (selectedCoverFile != null) {
        finalThumbnailUrl = await _uploadChallengeAsset(
          file: selectedCoverFile!,
          folder: 'covers',
          fallbackExt: 'jpg',
        );
      }

      final payload = <String, dynamic>{
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        'video_url': finalVideoUrl.isEmpty ? null : finalVideoUrl,
        'thumbnail_url': finalThumbnailUrl.isEmpty ? null : finalThumbnailUrl,
        'category_id': selectedCategoryId,
        'validity_days': maybeInt(validityController.text) ?? 60,
        'difficulty': difficultyController.text.trim().isEmpty
            ? null
            : difficultyController.text.trim(),
        'duration_minutes': maybeInt(durationController.text),
        'xp_reward': maybeInt(xpController.text) ?? 100,
        'is_active': isActive,
        'is_premium': isPremium,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (type == 'course') {
        payload['reward_type'] =
            rewardTypeController.text.trim().isEmpty
                ? null
                : rewardTypeController.text.trim();
        payload['reward_name'] =
            rewardNameController.text.trim().isEmpty
                ? null
                : rewardNameController.text.trim();
      } else {
        payload['repetitions'] = maybeInt(repetitionsController.text);
        payload['sets'] = maybeInt(setsController.text);
        payload['instructions'] = instructionsController.text.trim().isEmpty
            ? null
            : instructionsController.text.trim();
      }

      await SupaFlow.client.from(table).update(payload).eq(
            'id',
            challenge['id'],
          );
      final updatedAt = payload['updated_at']?.toString();
      challenge['video_url'] = finalVideoUrl.isEmpty ? null : finalVideoUrl;
      challenge['thumbnail_url'] =
          finalThumbnailUrl.isEmpty ? null : finalThumbnailUrl;
      if (finalThumbnailUrl.isNotEmpty) {
        challenge['image_url'] = finalThumbnailUrl;
      }
      if (updatedAt != null && updatedAt.isNotEmpty) {
        challenge['updated_at'] = updatedAt;
      }
      if (mounted) {
        setState(() {
          _challenges = _challenges.map((row) {
            final sameId =
                (row['id'] ?? '').toString() == (challenge['id'] ?? '').toString();
            final sameType =
                (row['type'] ?? '').toString() ==
                (challenge['type'] ?? '').toString();
            if (!sameId || !sameType) return row;
            return {
              ...row,
              'video_url': finalVideoUrl.isEmpty ? null : finalVideoUrl,
              'thumbnail_url':
                  finalThumbnailUrl.isEmpty ? null : finalThumbnailUrl,
              if (finalThumbnailUrl.isNotEmpty) 'image_url': finalThumbnailUrl,
              if (updatedAt != null && updatedAt.isNotEmpty)
                'updated_at': updatedAt,
            };
          }).toList();
          _applyFilters();
        });
      }
      await _loadData();
      _showSnack(
        'Desafío actualizado correctamente.',
        color: const Color(0xFF0D3B66),
      );
    } catch (e) {
      debugPrint('Edit challenge failed: $e');
      _showSnack('No se pudo actualizar el desafío.', color: Colors.red);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      difficultyController.dispose();
      durationController.dispose();
      xpController.dispose();
      validityController.dispose();
      rewardTypeController.dispose();
      rewardNameController.dispose();
      repetitionsController.dispose();
      setsController.dispose();
      instructionsController.dispose();
    }
  }

  Future<void> _deleteChallenge(Map<String, dynamic> challenge) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar desafío'),
        content: Text('Eliminar ${challenge['title'] ?? ''}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final type = challenge['type']?.toString() ?? 'exercise';
    final table = type == 'course' ? 'courses' : 'exercises';
    try {
      await SupaFlow.client.from(table).delete().eq('id', challenge['id']);
      await _loadData();
    } catch (e) {
      debugPrint('Delete challenge failed: $e');
    }
  }

  void _showAttemptsForChallenge(Map<String, dynamic> challenge) {
    final itemId = (challenge['id'] ?? '').toString();
    final itemType = (challenge['type'] ?? '').toString();
    final title = (challenge['title'] ?? 'Desafío').toString();
    final list = _attempts.where((attempt) {
      final sameType = (attempt['item_type'] ?? '').toString() == itemType;
      final sameId = (attempt['item_id'] ?? '').toString() == itemId;
      return sameType && sameId;
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Envíos de $title',
                              style: FlutterFlowTheme.of(context).titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${list.length} envío(s)',
                              style: FlutterFlowTheme.of(context).bodySmall,
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
                const Divider(height: 1),
                if (list.isEmpty)
                  const Expanded(
                    child: Center(
                      child:
                          Text('Aún no hay videos enviados para este desafío.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final attempt = list[index];
                        final userId = (attempt['user_id'] ?? '').toString();
                        final status =
                            (attempt['status'] ?? 'submitted').toString();
                        final date = _toDate(attempt['submitted_at']);
                        final dateLabel = date != null
                            ? dateTimeFormat('d/M/y H:mm', date)
                            : 'Sin fecha';
                        final videoUrl =
                            (attempt['video_url'] ?? '').toString().trim();
                        final hasVideo = videoUrl.isNotEmpty;

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _displayNameForUser(userId),
                                        style: FlutterFlowTheme.of(context)
                                            .titleSmall,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F0FF),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        status,
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              fontFamily: 'Poppins',
                                              color: const Color(0xFF0D3B66),
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateLabel,
                                  style: FlutterFlowTheme.of(context).bodySmall,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: hasVideo
                                          ? () async {
                                              _showVideoPreviewModal(videoUrl);
                                            }
                                          : null,
                                      icon:
                                          const Icon(Icons.play_circle_outline),
                                      label: const Text('Abrir video'),
                                    ),
                                    if (userId.isNotEmpty)
                                      OutlinedButton.icon(
                                        onPressed: () => context.pushNamed(
                                          PerfilProfesionalSolicitarContatoWidget
                                              .routeName,
                                          queryParameters: {
                                            'userId': userId,
                                          }.withoutNulls,
                                        ),
                                        icon: const Icon(Icons.person_outline),
                                        label: const Text('Ver perfil'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVideoPreviewModal(String videoUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Video del envío',
                          style: FlutterFlowTheme.of(context).titleMedium,
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
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: _AdminInlineVideoPlayer(videoUrl: videoUrl),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        title: Text(
          'Desafíos',
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
            tooltip: 'Actualizar',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateChallengeDialog,
        backgroundColor: FlutterFlowTheme.of(context).primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nuevo desafío',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_hasAttemptTable)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text(
                      'La tabla user_challenge_attempts no está disponible en este entorno.',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily: 'Poppins',
                            color: const Color(0xFF92400E),
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(_applyFilters),
                        decoration: InputDecoration(
                          hintText: 'Buscar desafío...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'todos',
                                  label: Text('Todos'),
                                  icon: Icon(Icons.apps),
                                ),
                                ButtonSegment(
                                  value: 'course',
                                  label: Text('Cursos'),
                                  icon: Icon(Icons.school),
                                ),
                                ButtonSegment(
                                  value: 'exercise',
                                  label: Text('Ejercicios'),
                                  icon: Icon(Icons.fitness_center),
                                ),
                              ],
                              selected: {_typeFilter},
                              onSelectionChanged: (selection) {
                                setState(() {
                                  _typeFilter = selection.first;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        value: _onlyActive,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mostrar solo activos'),
                        onChanged: (value) {
                          setState(() {
                            _onlyActive = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredChallenges.isEmpty
                      ? const Center(
                          child: Text('No hay desafíos para mostrar'))
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _filteredChallenges.length,
                            itemBuilder: (context, index) {
                              final challenge = _filteredChallenges[index];
                              return _buildChallengeCard(challenge);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final id = (challenge['id'] ?? '').toString();
    final type = (challenge['type'] ?? '').toString();
    final key = _challengeKey(type, id);
    final title = (challenge['title'] ?? 'Sin título').toString();
    final description = (challenge['description'] ?? '').toString();
    final isActive = challenge['is_active'] == true;
    final orderIndex = _toInt(challenge['order_index']);
    final xpReward = _toInt(challenge['xp_reward']);
    final difficulty = (challenge['difficulty'] ?? '').toString();
    final attempts = _attemptCountByChallengeKey[key] ?? 0;
    final typeLabel = type == 'course' ? 'Curso' : 'Ejercicio';
    final typeIcon = type == 'course' ? Icons.school : Icons.fitness_center;
    final categoryId = (challenge['category_id'] ?? '').toString();
    final categoryLabel = _categoryNameById[categoryId] ?? '';
    final validityDays = _toInt(challenge['validity_days']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F0FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 14, color: const Color(0xFF0D3B66)),
                      const SizedBox(width: 4),
                      Text(
                        typeLabel,
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              fontFamily: 'Poppins',
                              color: const Color(0xFF0D3B66),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isActive ? 'Activo' : 'Inactivo',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          fontFamily: 'Poppins',
                          color: isActive
                              ? const Color(0xFF166534)
                              : const Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: FlutterFlowTheme.of(context).titleMedium,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: FlutterFlowTheme.of(context).bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoTag('Orden $orderIndex'),
                _infoTag('+$xpReward XP'),
                if (categoryLabel.isNotEmpty) _infoTag(categoryLabel),
                if (difficulty.isNotEmpty) _infoTag(difficulty),
                if (validityDays > 0) _infoTag('$validityDays días'),
                _infoTag('$attempts envío(s)'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAttemptsForChallenge(challenge),
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Ver envíos'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openEditChallengeDialog(challenge),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _toggleActive(challenge),
                  icon: Icon(isActive ? Icons.pause_circle : Icons.play_arrow),
                  label: Text(isActive ? 'Inactivar' : 'Activar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteChallenge(challenge),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: FlutterFlowTheme.of(context).bodySmall,
      ),
    );
  }
}

class _AdminInlineVideoPlayer extends StatefulWidget {
  const _AdminInlineVideoPlayer({required this.videoUrl});

  final String videoUrl;

  @override
  State<_AdminInlineVideoPlayer> createState() =>
      _AdminInlineVideoPlayerState();
}

class _AdminInlineVideoPlayerState extends State<_AdminInlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final uri = Uri.tryParse(widget.videoUrl.trim());
      if (uri == null || widget.videoUrl.trim().isEmpty) {
        throw Exception('URL inválida');
      }

      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      await controller.setLooping(false);

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo reproducir este video.';
      });
      debugPrint('Admin inline video init failed: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_loading) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          _error ?? 'No se pudo reproducir este video.',
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'Poppins',
                color: Colors.white70,
                letterSpacing: 0.0,
              ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio <= 0
              ? 16 / 9
              : controller.value.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: VideoPlayer(controller),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                });
              },
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
            Expanded(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF0D3B66),
                  bufferedColor: Color(0xFFBFD4EA),
                  backgroundColor: Color(0xFFE5E7EB),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
