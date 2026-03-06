import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/gamification/gamification_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'cursos_ejercicios_model.dart';
export 'cursos_ejercicios_model.dart';

class CursosEjerciciosWidget extends StatefulWidget {
  const CursosEjerciciosWidget({super.key});

  static String routeName = 'cursos_ejercicios';
  static String routePath = '/cursosEjercicios';

  @override
  State<CursosEjerciciosWidget> createState() => _CursosEjerciciosWidgetState();
}

class _CursosEjerciciosWidgetState extends State<CursosEjerciciosWidget> {
  late CursosEjerciciosModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // State
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'Todos';
  int _currentPage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.92);

  // Data
  Map<String, dynamic>? _userProgress;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final Map<String, String> _userCourseStatus = {};
  final Map<String, String> _userExerciseStatus = {};
  final Map<String, _ChallengeAttempt> _attemptByItemKey = {};

  final List<String> _filters = [
    'Todos',
    'Cursos',
    'Ejercicios',
    'Completados'
  ];

  final List<String> _placeholderImages = [
    'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=800',
    'https://images.unsplash.com/photo-1553778263-73a83bab9b0c?w=800',
    'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800',
    'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?w=800',
    'https://images.unsplash.com/photo-1517466787929-bc90951d0974?w=800',
    'https://images.unsplash.com/photo-1560272564-c83b66b1ad12?w=800',
  ];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CursosEjerciciosModel());
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    _pageController.dispose();
    super.dispose();
  }

  double _responsive(BuildContext context,
      {required double mobile, double? tablet, double? desktop}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return desktop ?? tablet ?? mobile;
    if (width >= 600) return tablet ?? mobile;
    return mobile;
  }

  double _scaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 320) return 0.8;
    if (width < 360) return 0.9;
    if (width >= 1024) return 1.1;
    return 1.0;
  }

  bool _isLargeScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (currentUserUid.isNotEmpty) {
        await GamificationService.recalculateUserProgress(
          userId: currentUserUid,
        );
      }

      await Future.wait([
        _loadUserProgress(),
        _loadCourses(),
        _loadExercises(),
        _loadSavedAttempts(),
      ]);

      _combineAndFilterItems();
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _errorMessage = 'Error al cargar datos');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserProgress() async {
    try {
      final progressResponse = await SupaFlow.client
          .from('user_progress')
          .select()
          .eq('user_id', currentUserUid)
          .maybeSingle();

      if (progressResponse != null) {
        _userProgress = progressResponse;
      } else {
        await SupaFlow.client.from('user_progress').insert({
          'user_id': currentUserUid,
          'total_xp': 0,
          'current_level_id': GamificationService.levelIdFromPoints(0),
          'courses_completed': 0,
          'exercises_completed': 0
        });
        _userProgress = {
          'total_xp': 0,
          'current_level_id': GamificationService.levelIdFromPoints(0),
          'courses_completed': 0,
          'exercises_completed': 0
        };
      }
    } catch (e) {
      debugPrint('Error loading user progress: $e');
    }
  }

  Future<void> _loadCourses() async {
    try {
      final coursesResponse = await SupaFlow.client
          .from('courses')
          .select()
          .eq('is_active', true)
          .order('order_index');
      _courses = List<Map<String, dynamic>>.from(coursesResponse);
      final userCoursesResponse = await SupaFlow.client
          .from('user_courses')
          .select('course_id, status')
          .eq('user_id', currentUserUid);
      for (var uc in (userCoursesResponse)) {
        _userCourseStatus[uc['course_id'].toString()] = uc['status'];
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
  }

  Future<void> _loadExercises() async {
    try {
      final exercisesResponse = await SupaFlow.client
          .from('exercises')
          .select()
          .eq('is_active', true)
          .order('order_index');
      _exercises = List<Map<String, dynamic>>.from(exercisesResponse);
      final userExercisesResponse = await SupaFlow.client
          .from('user_exercises')
          .select('exercise_id, status')
          .eq('user_id', currentUserUid);
      for (var ue in (userExercisesResponse)) {
        _userExerciseStatus[ue['exercise_id'].toString()] = ue['status'];
      }
    } catch (e) {
      debugPrint('Error loading exercises: $e');
    }
  }

  String get _attemptsStorageKey => 'challenge_attempts_$currentUserUid';

  String _itemKey(Map<String, dynamic> item) => '${item['type']}:${item['id']}';

  bool _hasAttemptForItem(Map<String, dynamic> item) {
    return _attemptByItemKey.containsKey(_itemKey(item));
  }

  Future<void> _loadSavedAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_attemptsStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          for (final entry in parsed.entries) {
            if (entry.value is Map<String, dynamic>) {
              _attemptByItemKey[entry.key] = _ChallengeAttempt.fromJson(
                entry.value as Map<String, dynamic>,
              );
            } else if (entry.value is Map) {
              _attemptByItemKey[entry.key] = _ChallengeAttempt.fromJson(
                Map<String, dynamic>.from(entry.value as Map),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading saved attempts: $e');
    }

    try {
      final rows = await SupaFlow.client
          .from('user_challenge_attempts')
          .select('item_id, item_type, video_id, video_url, submitted_at')
          .eq('user_id', currentUserUid)
          .eq('status', 'submitted');
      for (final row in rows) {
        final itemId = (row['item_id'] ?? '').toString();
        final itemType = (row['item_type'] ?? '').toString();
        if (itemId.isEmpty || itemType.isEmpty) continue;
        final key = '$itemType:$itemId';
        _attemptByItemKey[key] = _ChallengeAttempt(
          itemId: itemId,
          itemType: itemType,
          profileVideoId: row['video_id']?.toString(),
          videoUrl: (row['video_url'] ?? '').toString(),
          localPath: null,
          submittedAt:
              DateTime.tryParse((row['submitted_at'] ?? '').toString()) ??
                  DateTime.now(),
        );
      }
      await _persistAttempts();
    } catch (e) {
      debugPrint('Server attempts fetch unavailable: $e');
    }

    // Fallback: rebuild attempts from user's videos tagged as challenge uploads.
    try {
      final videos = await SupaFlow.client
          .from('videos')
          .select('id, user_id, description, video_url, created_at')
          .eq('user_id', currentUserUid)
          .order('created_at', ascending: false)
          .limit(300);
      final tagExp = RegExp(r'\[challenge_ref:(course|exercise):([^\]]+)\]');
      for (final row in (videos as List)) {
        final description = row['description']?.toString() ?? '';
        final match = tagExp.firstMatch(description);
        if (match == null) continue;
        final itemType = match.group(1)?.trim() ?? '';
        final itemId = match.group(2)?.trim() ?? '';
        if (itemType.isEmpty || itemId.isEmpty) continue;
        final key = '$itemType:$itemId';
        _attemptByItemKey[key] ??= _ChallengeAttempt(
          itemId: itemId,
          itemType: itemType,
          profileVideoId: row['id']?.toString(),
          videoUrl: row['video_url']?.toString() ?? '',
          localPath: null,
          submittedAt:
              DateTime.tryParse((row['created_at'] ?? '').toString()) ??
                  DateTime.now(),
        );
      }
      await _persistAttempts();
    } catch (e) {
      debugPrint('Challenge-tagged videos fallback unavailable: $e');
    }
  }

  Future<void> _persistAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode({
        for (final entry in _attemptByItemKey.entries)
          entry.key: entry.value.toJson(),
      });
      await prefs.setString(_attemptsStorageKey, encoded);
    } catch (e) {
      debugPrint('Error saving attempts local cache: $e');
    }
  }

  Future<void> _syncAttemptForItem(Map<String, dynamic> item) async {
    final itemId = item['id']?.toString() ?? '';
    final itemType = item['type']?.toString() ?? '';
    if (itemId.isEmpty || itemType.isEmpty) return;
    final key = '$itemType:$itemId';

    try {
      final row = await SupaFlow.client
          .from('user_challenge_attempts')
          .select('video_id, video_url, submitted_at')
          .eq('user_id', currentUserUid)
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .eq('status', 'submitted')
          .maybeSingle();
      if (row != null) {
        _attemptByItemKey[key] = _ChallengeAttempt(
          itemId: itemId,
          itemType: itemType,
          profileVideoId: row['video_id']?.toString(),
          videoUrl: row['video_url']?.toString() ?? '',
          localPath: _attemptByItemKey[key]?.localPath,
          submittedAt:
              DateTime.tryParse((row['submitted_at'] ?? '').toString()) ??
                  DateTime.now(),
        );
        await _persistAttempts();
        return;
      }
    } catch (_) {}

    // Fallback by scanning tagged videos for this challenge key.
    try {
      final videos = await SupaFlow.client
          .from('videos')
          .select('id, description, video_url, created_at')
          .eq('user_id', currentUserUid)
          .order('created_at', ascending: false)
          .limit(200);
      final token = '[challenge_ref:$itemType:$itemId]';
      for (final row in (videos as List)) {
        final description = row['description']?.toString() ?? '';
        if (!description.contains(token)) continue;
        _attemptByItemKey[key] = _ChallengeAttempt(
          itemId: itemId,
          itemType: itemType,
          profileVideoId: row['id']?.toString(),
          videoUrl: row['video_url']?.toString() ?? '',
          localPath: _attemptByItemKey[key]?.localPath,
          submittedAt:
              DateTime.tryParse((row['created_at'] ?? '').toString()) ??
                  DateTime.now(),
        );
        await _persistAttempts();
        break;
      }
    } catch (_) {}
  }

  Future<_ChallengeAttempt?> _recordAttemptVideo(
    Map<String, dynamic> item,
  ) async {
    _showSnack(
      'Se abrirá la cámara para grabar tu intento.',
      background: const Color(0xFF0D3B66),
    );

    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 3),
      );

      if (video == null) {
        _showSnack(
          'No se grabó ningún video. El desafío sigue pendiente.',
          background: Colors.orange,
        );
        return null;
      }

      final itemId = item['id'].toString();
      final itemType = (item['type'] ?? 'exercise').toString();
      final challengeRef = '[challenge_ref:$itemType:$itemId]';
      var uploadExt = _fileExtension(video.name);
      Uint8List bytes;
      // Keep the original camera file for local preview.
      // Compressed files live in temporary cache and may be deleted later.
      String? localVideoPath = kIsWeb ? null : video.path;

      if (kIsWeb) {
        bytes = await video.readAsBytes();
      } else {
        try {
          final compressed = await VideoCompress.compressVideo(
            video.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
          );
          final compressedPath = compressed?.file?.path;
          if (compressedPath != null && compressedPath.isNotEmpty) {
            uploadExt = _fileExtension(compressedPath);
            bytes = await File(compressedPath).readAsBytes();
          } else {
            bytes = await File(video.path).readAsBytes();
          }
        } catch (e) {
          debugPrint('Challenge video compression failed, using original: $e');
          bytes = await File(video.path).readAsBytes();
        }
      }

      final fileName =
          'challenge_attempts/$currentUserUid/${itemType}_${itemId}_${DateTime.now().millisecondsSinceEpoch}.$uploadExt';

      await SupaFlow.client.storage.from('Videos').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: _videoContentTypeFromExtension(uploadExt),
              upsert: true,
            ),
          );

      final publicUrl = SupaFlow.client.storage.from('Videos').getPublicUrl(
            fileName,
          );

      String? profileVideoId;
      try {
        await SupaFlow.client.from('videos').insert({
          'user_id': currentUserUid,
          'video_url': publicUrl,
          'title': 'Desafío: ${item['title'] ?? itemType}',
          'description':
              'Video enviado al intentar un desafío de entrenamiento. $challengeRef',
          'is_public': true,
          'likes_count': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
        try {
          final lookup = await SupaFlow.client
              .from('videos')
              .select('id')
              .eq('user_id', currentUserUid)
              .eq('video_url', publicUrl)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          profileVideoId = lookup?['id']?.toString();
        } catch (_) {}
      } catch (e) {
        debugPrint('Error registering challenge video in videos table: $e');
        _showSnack(
          'No se pudo registrar el video en tu perfil. Intentá de nuevo.',
          background: Colors.red,
        );
        return null;
      }

      final attempt = _ChallengeAttempt(
        itemId: itemId,
        itemType: itemType,
        profileVideoId: profileVideoId,
        videoUrl: publicUrl,
        localPath: localVideoPath,
        submittedAt: DateTime.now(),
      );

      _attemptByItemKey[_itemKey(item)] = attempt;
      await _persistAttempts();

      try {
        await SupaFlow.client.from('user_challenge_attempts').upsert(
          {
            'user_id': currentUserUid,
            'item_id': itemId,
            'item_type': itemType,
            'video_id': profileVideoId,
            'video_url': publicUrl,
            'status': 'submitted',
            'submitted_at': attempt.submittedAt.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id,item_id,item_type',
        );
      } catch (e) {
        debugPrint('Optional server sync for attempts unavailable: $e');
      }

      await GamificationService.recalculateUserProgress(userId: currentUserUid);

      _showSnack(
        'Intento enviado. Ya aparece en tu perfil y en Explorer (si es público).',
        background: const Color(0xFF48BB78),
      );
      return attempt;
    } catch (e) {
      debugPrint('Error recording attempt video: $e');
      _showSnack(
        'No se pudo subir el video. Revisá permisos e intentá de nuevo.',
        background: Colors.red,
      );
      return null;
    } finally {
      if (!kIsWeb) {
        try {
          await VideoCompress.deleteAllCache();
        } catch (_) {}
      }
    }
  }

  void _showSnack(
    String message, {
    required Color background,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
      ),
    );
  }

  String _fileExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot >= fileName.length - 1) return 'mp4';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _videoContentTypeFromExtension(String ext) {
    switch (ext) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp4':
      default:
        return 'video/mp4';
    }
  }

  void _combineAndFilterItems() {
    _allItems = [];
    for (int i = 0; i < _courses.length; i++) {
      final course = _courses[i];
      _allItems.add({
        ...course,
        'type': 'course',
        'status': _userCourseStatus[course['id'].toString()] ?? 'not_started',
        'placeholder_image': _placeholderImages[i % _placeholderImages.length]
      });
    }
    for (int i = 0; i < _exercises.length; i++) {
      final exercise = _exercises[i];
      _allItems.add({
        ...exercise,
        'type': 'exercise',
        'status':
            _userExerciseStatus[exercise['id'].toString()] ?? 'not_started',
        'placeholder_image':
            _placeholderImages[(i + 3) % _placeholderImages.length]
      });
    }
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      switch (_selectedFilter) {
        case 'Cursos':
          _filteredItems =
              _allItems.where((item) => item['type'] == 'course').toList();
          break;
        case 'Ejercicios':
          _filteredItems =
              _allItems.where((item) => item['type'] == 'exercise').toList();
          break;
        case 'Completados':
          _filteredItems =
              _allItems.where((item) => item['status'] == 'completed').toList();
          break;
        default:
          _filteredItems = List.from(_allItems);
      }
      _currentPage = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    });
  }

  void _onFilterSelected(String filter) {
    setState(() => _selectedFilter = filter);
    _applyFilter();
  }

  Future<void> _onItemTap(Map<String, dynamic> item) async {
    final isCourse = item['type'] == 'course';
    final status = item['status'] ?? 'not_started';
    final itemId = item['id'].toString();
    var startedNow = false;

    if (status == 'not_started') {
      try {
        if (isCourse) {
          final existing = await SupaFlow.client
              .from('user_courses')
              .select('id')
              .eq('user_id', currentUserUid)
              .eq('course_id', itemId)
              .maybeSingle();
          if (existing != null) {
            await SupaFlow.client
                .from('user_courses')
                .update({
                  'status': 'in_progress',
                  'started_at': DateTime.now().toIso8601String()
                })
                .eq('user_id', currentUserUid)
                .eq('course_id', itemId);
          } else {
            await SupaFlow.client.from('user_courses').insert({
              'user_id': currentUserUid,
              'course_id': itemId,
              'status': 'in_progress',
              'started_at': DateTime.now().toIso8601String()
            });
          }
          _userCourseStatus[itemId] = 'in_progress';
          startedNow = true;
        } else {
          final existing = await SupaFlow.client
              .from('user_exercises')
              .select('id')
              .eq('user_id', currentUserUid)
              .eq('exercise_id', itemId)
              .maybeSingle();
          if (existing != null) {
            await SupaFlow.client
                .from('user_exercises')
                .update({'status': 'in_progress'})
                .eq('user_id', currentUserUid)
                .eq('exercise_id', itemId);
          } else {
            await SupaFlow.client.from('user_exercises').insert({
              'user_id': currentUserUid,
              'exercise_id': itemId,
              'status': 'in_progress'
            });
          }
          _userExerciseStatus[itemId] = 'in_progress';
          startedNow = true;
        }
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
    if (startedNow) {
      await GamificationService.recalculateUserProgress(userId: currentUserUid);
    }
    await _syncAttemptForItem(item);
    _showVideoModal(item);
  }

  void _showVideoModal(Map<String, dynamic> item) {
    final scale = _scaleFactor(context);
    final videoUrl = item['video_url']?.toString() ?? '';
    final title =
        item['title'] ?? (item['type'] == 'course' ? 'Curso' : 'Ejercicio');
    final pointsReward = GamificationService.challengeCompletedPoints;
    final isCourse = item['type'] == 'course';
    final itemId = item['id'].toString();
    final itemKey = _itemKey(item);
    final imageUrl = item['thumbnail_url'] ??
        item['image_url'] ??
        item['placeholder_image'] ??
        '';
    _ChallengeAttempt? modalAttempt = _attemptByItemKey[itemKey];
    bool isSendingAttempt = false;
    String uploadStateMessage = modalAttempt != null
        ? 'Video enviado para este desafío. Ya figura en tu perfil.'
        : 'Todavía no enviaste video.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12 * scale),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    if (imageUrl.isNotEmpty)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            color: Colors.black.withOpacity(0.45),
                            colorBlendMode: BlendMode.darken,
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(20 * scale),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(ctx),
                                child: Container(
                                  padding: EdgeInsets.all(8 * scale),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 24 * scale,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 10 * scale),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * scale,
                                vertical: 6 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: isCourse
                                    ? const Color(0xFF0D3B66)
                                    : const Color(0xFF48BB78),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isCourse ? 'CURSO' : 'EJERCICIO',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(height: 12 * scale),
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 28 * scale,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8 * scale),
                            Row(
                              children: [
                                Icon(
                                  Icons.bolt,
                                  color: const Color(0xFFFFD700),
                                  size: 20 * scale,
                                ),
                                SizedBox(width: 4 * scale),
                                Text(
                                  '+$pointsReward pts al completar',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 16 * scale,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 18 * scale),
                            Text(
                              'Tutorial dentro del app',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16 * scale,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8 * scale),
                            if (videoUrl.isNotEmpty)
                              _InlineVideoPlayer(
                                videoUrl: videoUrl,
                                localPath: null,
                                autoplay: false,
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(14 * scale),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Este desafío no tiene tutorial cargado.',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13 * scale,
                                  ),
                                ),
                              ),
                            SizedBox(height: 14 * scale),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * scale,
                                vertical: 10 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: isSendingAttempt
                                    ? const Color(0xFF1E40AF)
                                    : (modalAttempt != null
                                        ? const Color(0xFF0F9D58)
                                        : Colors.white12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSendingAttempt
                                      ? const Color(0xFF60A5FA)
                                      : (modalAttempt != null
                                          ? const Color(0xFF86EFAC)
                                          : Colors.white24),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (isSendingAttempt)
                                    SizedBox(
                                      width: 14 * scale,
                                      height: 14 * scale,
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Icon(
                                      modalAttempt != null
                                          ? Icons.check_circle
                                          : Icons.info_outline,
                                      color: Colors.white,
                                      size: 18 * scale,
                                    ),
                                  SizedBox(width: 8 * scale),
                                  Expanded(
                                    child: Text(
                                      uploadStateMessage,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 13 * scale,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10 * scale),
                            if (modalAttempt != null) ...[
                              Text(
                                'Tu intento enviado',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8 * scale),
                              _InlineVideoPlayer(
                                videoUrl: modalAttempt!.videoUrl,
                                localPath: modalAttempt!.localPath,
                                autoplay: false,
                              ),
                              SizedBox(height: 8 * scale),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isSendingAttempt
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          isSendingAttempt = true;
                                          uploadStateMessage =
                                              'Subiendo video... esto puede tardar unos segundos.';
                                        });
                                        safeSetState(() {});

                                        final attempt =
                                            await _recordAttemptVideo(item);
                                        setModalState(
                                          () {
                                            isSendingAttempt = false;
                                            if (attempt != null) {
                                              modalAttempt = attempt;
                                              uploadStateMessage =
                                                  'Video enviado correctamente. Ya puede verse en tu perfil y Explorer.';
                                            } else {
                                              uploadStateMessage =
                                                  'No se pudo enviar el video. Intentá nuevamente.';
                                            }
                                          },
                                        );
                                        safeSetState(() {});
                                      },
                                style: OutlinedButton.styleFrom(
                                  minimumSize:
                                      Size(double.infinity, 52 * scale),
                                  side: const BorderSide(color: Colors.white54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: isSendingAttempt
                                    ? SizedBox(
                                        width: 16 * scale,
                                        height: 16 * scale,
                                        child: const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        Icons.videocam_rounded,
                                        color: Colors.white,
                                        size: 20 * scale,
                                      ),
                                label: Text(
                                  'Tentar Desafío',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15 * scale,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12 * scale),
                            _CompletarButton(
                              itemId: itemId,
                              isCourse: isCourse,
                              userId: currentUserUid,
                              pointsReward: pointsReward,
                              canComplete: modalAttempt != null,
                              onComplete: () {
                                Navigator.pop(ctx);
                                _loadData();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    final scale = _scaleFactor(context);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D3B66)))
            : _errorMessage != null
                ? _buildErrorState(context)
                : Stack(
                    children: [
                      SafeArea(
                        child: Column(
                          children: [
                            _buildHeader(context),
                            SizedBox(height: 16 * scale),
                            _buildFilters(context),
                            SizedBox(height: 20 * scale),
                            Expanded(
                              child: _filteredItems.isEmpty
                                  ? _buildEmptyState(context)
                                  : _isLargeScreen(context)
                                      ? _buildGridView(context)
                                      : _buildCarousel(context),
                            ),
                            if (!_isLargeScreen(context) &&
                                _filteredItems.isNotEmpty)
                              _buildPageIndicators(context),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                      Align(
                        alignment: const AlignmentDirectional(0.0, 1.0),
                        child: userType == 'jugador'
                            ? wrapWithModel(
                                model: _model.navBarJudadorModel,
                                updateCallback: () => safeSetState(() {}),
                                child: const NavBarJudadorWidget(),
                              )
                            : (userType == 'profesional'
                                ? wrapWithModel(
                                    model: _model.navBarProfesionalModel,
                                    updateCallback: () => safeSetState(() {}),
                                    child: const NavBarProfesionalWidget(),
                                  )
                                : const SizedBox.shrink()),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final scale = _scaleFactor(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48 * scale),
          SizedBox(height: 16 * scale),
          Text(_errorMessage!,
              style:
                  GoogleFonts.inter(color: Colors.red, fontSize: 16 * scale)),
          SizedBox(height: 16 * scale),
          ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66)),
              child: Text('Reintentar',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 14 * scale))),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scale = _scaleFactor(context);
    final totalXpRaw = _userProgress?['total_xp'] ?? 0;
    final totalPoints = GamificationService.toInt(totalXpRaw);
    final levelName = GamificationService.levelNameFromPoints(totalPoints);
    final horizontalPadding =
        _responsive(context, mobile: 16, tablet: 24, desktop: 32);

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: 12 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mi Progreso',
                  style: GoogleFonts.inter(
                      fontSize: 14 * scale, color: Colors.grey[600])),
              SizedBox(height: 4 * scale),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale, vertical: 4 * scale),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF0D3B66), Color(0xFF1E5A8A)]),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Icon(Icons.bolt,
                          color: const Color(0xFFFFD700), size: 16 * scale),
                      SizedBox(width: 4 * scale),
                      Text('$totalPoints pts',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.bold))
                    ]),
                  ),
                  SizedBox(width: 8 * scale),
                  Text(levelName,
                      style: GoogleFonts.inter(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D3B66))),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => context.pushNamed('ranking'),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale, vertical: 10 * scale),
              decoration: BoxDecoration(
                  color: const Color(0xFF0D3B66),
                  borderRadius: BorderRadius.circular(25)),
              child: Row(children: [
                Icon(Icons.leaderboard, color: Colors.white, size: 18 * scale),
                SizedBox(width: 6 * scale),
                Text('Ranking',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w600))
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final scale = _scaleFactor(context);
    final horizontalPadding =
        _responsive(context, mobile: 16, tablet: 24, desktop: 32);

    return SizedBox(
      height: 40 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 10 * scale),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => _onFilterSelected(filter),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 20 * scale, vertical: 10 * scale),
              decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF0D3B66) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0D3B66)
                          : Colors.grey[300]!,
                      width: 1.5)),
              child: Text(filter,
                  style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontSize: 14 * scale,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scale = _scaleFactor(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined,
              size: 64 * scale, color: Colors.grey[400]),
          SizedBox(height: 16 * scale),
          Text(
              _selectedFilter == 'Completados'
                  ? 'No has completado ningún contenido aún'
                  : 'No hay contenido disponible',
              style: GoogleFonts.inter(
                  fontSize: 16 * scale, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCarousel(BuildContext context) {
    final scale = _scaleFactor(context);
    return PageView.builder(
      controller: _pageController,
      itemCount: _filteredItems.length,
      onPageChanged: (index) => setState(() => _currentPage = index),
      itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          child: _buildCard(context, _filteredItems[index])),
    );
  }

  Widget _buildGridView(BuildContext context) {
    final scale = _scaleFactor(context);
    final horizontalPadding =
        _responsive(context, mobile: 16, tablet: 24, desktop: 32);

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16 * scale,
          mainAxisSpacing: 16 * scale,
          childAspectRatio: 0.75),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) =>
          _buildCard(context, _filteredItems[index]),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> item) {
    final scale = _scaleFactor(context);
    final isCourse = item['type'] == 'course';
    final status = item['status'] ?? 'not_started';
    final isCompleted = status == 'completed';
    final hasAttempt = _hasAttemptForItem(item);
    final title = item['title'] ?? (isCourse ? 'Curso' : 'Ejercicio');
    final pointsReward = GamificationService.challengeCompletedPoints;
    final imageUrl = item['thumbnail_url'] ??
        item['image_url'] ??
        item['placeholder_image'] ??
        '';

    String statusText = isCompleted
        ? '✓ Completado'
        : (status == 'in_progress' ? 'Continuar' : 'Empezar ahora');

    return GestureDetector(
      onTap: () => _onItemTap(item),
      child: Container(
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey[300]),
                    errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF0D3B66),
                        child: const Icon(Icons.play_circle_outline,
                            color: Colors.white54, size: 80)))
              else
                Container(
                    color: const Color(0xFF0D3B66),
                    child: const Icon(Icons.play_circle_outline,
                        color: Colors.white54, size: 80)),
              Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8)
                  ],
                          stops: const [
                    0.3,
                    0.6,
                    1.0
                  ]))),
              if (isCompleted)
                Positioned(
                    top: 16 * scale,
                    right: 16 * scale,
                    child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12 * scale, vertical: 6 * scale),
                        decoration: BoxDecoration(
                            color: const Color(0xFF48BB78),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle,
                              color: Colors.white, size: 14 * scale),
                          SizedBox(width: 4 * scale),
                          Text('Completado',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w600))
                        ]))),
              Positioned(
                  top: 16 * scale,
                  left: 16 * scale,
                  child: Container(
                      width: 40 * scale,
                      height: 40 * scale,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8)
                          ]),
                      child: Icon(
                          isCourse ? Icons.school : Icons.fitness_center,
                          color: const Color(0xFF0D3B66),
                          size: 22 * scale))),
              Positioned(
                  bottom: 24 * scale,
                  left: 20 * scale,
                  right: 20 * scale,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: _responsive(context,
                                        mobile: 24, tablet: 26, desktop: 28) *
                                    scale,
                                fontWeight: FontWeight.bold,
                                height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        SizedBox(height: 8 * scale),
                        if (hasAttempt) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: const Color(0xFF86EFAC),
                                size: 14 * scale,
                              ),
                              SizedBox(width: 4 * scale),
                              Text(
                                'Video enviado',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFBBF7D0),
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6 * scale),
                        ],
                        Row(children: [
                          Text(statusText,
                              style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10 * scale, vertical: 4 * scale),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Icon(Icons.bolt,
                                    color: const Color(0xFFFFD700),
                                    size: 14 * scale),
                                SizedBox(width: 2 * scale),
                                Text('+$pointsReward pts',
                                    style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12 * scale,
                                        fontWeight: FontWeight.w600))
                              ]))
                        ])
                      ])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators(BuildContext context) {
    final scale = _scaleFactor(context);
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 16 * scale),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                _filteredItems.length,
                (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                    width: _currentPage == index ? 24 * scale : 8 * scale,
                    height: 8 * scale,
                    decoration: BoxDecoration(
                        color: _currentPage == index
                            ? const Color(0xFF0D3B66)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))))));
  }
}

class _CompletarButton extends StatefulWidget {
  final String itemId;
  final bool isCourse;
  final String userId;
  final int pointsReward;
  final bool canComplete;
  final VoidCallback onComplete;
  const _CompletarButton(
      {required this.itemId,
      required this.isCourse,
      required this.userId,
      required this.pointsReward,
      required this.canComplete,
      required this.onComplete});
  @override
  State<_CompletarButton> createState() => _CompletarButtonState();
}

class _CompletarButtonState extends State<_CompletarButton> {
  bool _isLoading = false;
  Future<void> _markAsCompleted() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isCourse) {
        final existing = await SupaFlow.client
            .from('user_courses')
            .select('id, status')
            .eq('user_id', widget.userId)
            .eq('course_id', widget.itemId)
            .maybeSingle();
        if (existing != null && existing['status'] == 'completed') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Este curso ya fue completado'),
              backgroundColor: Colors.orange));
          widget.onComplete();
          return;
        }
        if (existing != null) {
          await SupaFlow.client
              .from('user_courses')
              .update({
                'status': 'completed',
                'completed_at': DateTime.now().toIso8601String(),
                'progress_percent': 100,
                'xp_earned': widget.pointsReward
              })
              .eq('user_id', widget.userId)
              .eq('course_id', widget.itemId);
        } else {
          await SupaFlow.client.from('user_courses').insert({
            'user_id': widget.userId,
            'course_id': widget.itemId,
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'progress_percent': 100,
            'xp_earned': widget.pointsReward
          });
        }
        await _updateUserProgress();
      } else {
        final existing = await SupaFlow.client
            .from('user_exercises')
            .select('id, status')
            .eq('user_id', widget.userId)
            .eq('exercise_id', widget.itemId)
            .maybeSingle();
        if (existing != null && existing['status'] == 'completed') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Este ejercicio ya fue completado'),
              backgroundColor: Colors.orange));
          widget.onComplete();
          return;
        }
        if (existing != null) {
          await SupaFlow.client
              .from('user_exercises')
              .update({
                'status': 'completed',
                'last_completed_at': DateTime.now().toIso8601String(),
                'total_xp_earned': widget.pointsReward
              })
              .eq('user_id', widget.userId)
              .eq('exercise_id', widget.itemId);
        } else {
          await SupaFlow.client.from('user_exercises').insert({
            'user_id': widget.userId,
            'exercise_id': widget.itemId,
            'status': 'completed',
            'last_completed_at': DateTime.now().toIso8601String(),
            'total_xp_earned': widget.pointsReward
          });
        }
        await _updateUserProgress();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isCourse
              ? '¡Curso completado! +${widget.pointsReward} pts'
              : '¡Ejercicio completado! +${widget.pointsReward} pts'),
          backgroundColor: const Color(0xFF48BB78)));
      widget.onComplete();
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserProgress() async {
    try {
      await GamificationService.recalculateUserProgress(userId: widget.userId);
    } catch (e) {
      debugPrint('Error updating user progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        onPressed:
            (_isLoading || !widget.canComplete) ? null : _markAsCompleted,
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF48BB78),
            disabledBackgroundColor: Colors.grey,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(
                widget.canComplete
                    ? 'Marcar como Completado'
                    : 'Subí un video para completar',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)));
  }
}

class _ChallengeAttempt {
  const _ChallengeAttempt({
    required this.itemId,
    required this.itemType,
    required this.profileVideoId,
    required this.videoUrl,
    required this.localPath,
    required this.submittedAt,
  });

  final String itemId;
  final String itemType;
  final String? profileVideoId;
  final String videoUrl;
  final String? localPath;
  final DateTime submittedAt;

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_type': itemType,
        'profile_video_id': profileVideoId,
        'video_url': videoUrl,
        'local_path': localPath,
        'submitted_at': submittedAt.toIso8601String(),
      };

  factory _ChallengeAttempt.fromJson(Map<String, dynamic> json) {
    return _ChallengeAttempt(
      itemId: (json['item_id'] ?? '').toString(),
      itemType: (json['item_type'] ?? '').toString(),
      profileVideoId: json['profile_video_id']?.toString(),
      videoUrl: (json['video_url'] ?? '').toString(),
      localPath: json['local_path']?.toString(),
      submittedAt: DateTime.tryParse((json['submitted_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({
    required this.videoUrl,
    required this.localPath,
    this.autoplay = false,
  });

  final String? videoUrl;
  final String? localPath;
  final bool autoplay;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;
  String? _fallbackUrl;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _InlineVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.localPath != widget.localPath) {
      _disposeController();
      _initialize();
    }
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _fallbackUrl = null;
      });
    } else {
      _loading = true;
      _error = null;
      _fallbackUrl = null;
    }

    try {
      final localPath = (widget.localPath ?? '').trim();
      final url = (widget.videoUrl ?? '').trim();

      bool initialized = false;

      if (!kIsWeb && localPath.isNotEmpty) {
        final file = File(localPath);
        if (await file.exists()) {
          initialized = await _tryInitializeController(
            VideoPlayerController.file(file),
          );
        }
      }

      if (!initialized && url.isNotEmpty) {
        final candidates = _buildVideoCandidates(url);
        for (final candidate in candidates) {
          final uri = Uri.tryParse(candidate);
          if (uri == null || uri.toString().isEmpty) continue;
          initialized = await _tryInitializeController(
            VideoPlayerController.networkUrl(
              uri,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
              httpHeaders: const {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              },
            ),
          );
          if (initialized) break;
        }
        if (!initialized && candidates.isNotEmpty) {
          _fallbackUrl = candidates.first;
        }
      }

      if (!initialized) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'No se pudo reproducir este video.';
          });
        }
        return;
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error loading inline video: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo reproducir este video.';
        });
      }
    }
  }

  Future<bool> _tryInitializeController(
      VideoPlayerController controller) async {
    try {
      _disposeController();
      _controller = controller;
      await _controller!.initialize();
      await _controller!.setLooping(true);
      if (widget.autoplay) {
        await _controller!.play();
      }
      return true;
    } catch (e) {
      debugPrint('Error initializing inline video source: $e');
      try {
        await controller.dispose();
      } catch (_) {}
      if (identical(_controller, controller)) {
        _controller = null;
      }
      return false;
    }
  }

  List<String> _buildVideoCandidates(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return const [];

    final seen = <String>{};
    final result = <String>[];
    void add(String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty || seen.contains(v)) return;
      seen.add(v);
      result.add(v);
    }

    add(input);
    final uri = Uri.tryParse(input);
    if (uri == null) return result;

    final host = uri.host.toLowerCase();

    if (host.contains('drive.google.com')) {
      String? id;
      final segments = uri.pathSegments;
      final fileIndex = segments.indexOf('d');
      if (fileIndex >= 0 && fileIndex + 1 < segments.length) {
        id = segments[fileIndex + 1];
      }
      id ??= uri.queryParameters['id'];
      if ((id ?? '').isNotEmpty) {
        add('https://drive.google.com/uc?export=download&id=$id');
        add('https://drive.google.com/uc?export=view&id=$id');
      }
    }

    if (host.contains('dropbox.com')) {
      final swappedHost = uri.replace(host: 'dl.dropboxusercontent.com');
      add(swappedHost.toString());
      final forcedRaw = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'raw': '1',
          'dl': '1',
        },
      );
      add(forcedRaw.toString());
    }

    if (host.contains('onedrive.live.com') || host.contains('1drv.ms')) {
      add(uri.replace(queryParameters: {
        ...uri.queryParameters,
        'download': '1',
      }).toString());
    }

    return result;
  }

  Future<void> _openInAppWebView() async {
    final url = (_fallbackUrl ?? widget.videoUrl ?? '').trim();
    if (url.isEmpty) return;
    if (kIsWeb) {
      try {
        await launchURL(url);
      } catch (_) {}
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _VideoFallbackWebViewDialog(url: url),
    );
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.of(context).size.width < 360 ? 0.9 : 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: (_controller != null && _controller!.value.isInitialized)
              ? _controller!.value.aspectRatio
              : 16 / 9,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : (_error != null || _controller == null)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error ?? 'No disponible.',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 13 * scale,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if ((_fallbackUrl ?? '').isNotEmpty) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _openInAppWebView,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white54),
                                ),
                                icon: const Icon(
                                  Icons.open_in_new,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                label: Text(
                                  'Abrir reproductor interno',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(_controller!),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                _controller!.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _VideoFallbackWebViewDialog extends StatefulWidget {
  const _VideoFallbackWebViewDialog({required this.url});

  final String url;

  @override
  State<_VideoFallbackWebViewDialog> createState() =>
      _VideoFallbackWebViewDialogState();
}

class _VideoFallbackWebViewDialogState
    extends State<_VideoFallbackWebViewDialog> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null || uri.toString().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'URL de video inválida.';
      });
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = err.description.isNotEmpty
                  ? err.description
                  : 'No se pudo abrir este video.';
            });
          },
        ),
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.74,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reproductor interno',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_error == null) WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
