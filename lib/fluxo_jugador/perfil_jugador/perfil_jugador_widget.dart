import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/location_data.dart' as location_data;
import '/fluxo_compartilhado/profile_history_utils.dart';
import '/fluxo_compartilhado/profile_support_sheet.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/fluxo_compartilhado/video_like_utils.dart';
import '/fluxo_compartilhado/video_visibility_utils.dart';
import '/gamification/gamification_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/guardian/guardian_mvp_service.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'perfil_jugador_model.dart';
export 'perfil_jugador_model.dart';

class PerfilJugadorWidget extends StatefulWidget {
  const PerfilJugadorWidget({super.key});

  static String routeName = 'perfil_jugador';
  static String routePath = '/perfilJugador';

  @override
  State<PerfilJugadorWidget> createState() => _PerfilJugadorWidgetState();
}

class _PerfilJugadorWidgetState extends State<PerfilJugadorWidget>
    with SingleTickerProviderStateMixin {
  String? _extractVideoStoragePath(String? rawUrl) {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final publicIndex = segments.indexOf('public');
    if (publicIndex == -1) return null;

    final bucketIndex = publicIndex + 1;
    if (bucketIndex >= segments.length || segments[bucketIndex] != 'Videos') {
      return null;
    }

    final objectSegments = segments.skip(bucketIndex + 1).toList();
    if (objectSegments.isEmpty) return null;

    return objectSegments.map(Uri.decodeComponent).join('/');
  }

  Future<void> _deleteVideoStorageAsset(String? rawUrl) async {
    final storagePath = _extractVideoStoragePath(rawUrl);
    if (storagePath == null || storagePath.isEmpty) return;

    try {
      await SupaFlow.client.storage.from('Videos').remove([storagePath]);
    } catch (e) {
      debugPrint('Storage delete failed for $storagePath: $e');
    }
  }

  String _profileLocationText() {
    final country = normalizeCountryName(
      _userData?['country'] ?? _userData?['pais'] ?? '',
    );
    var state = normalizeStateName(
      _userData?['state'] ??
          _userData?['estado'] ??
          _userData?['province'] ??
          _userData?['provincia'] ??
          _userData?['region'] ??
          '',
    );
    var city = normalizeCityName(
      _userData?['city'] ??
          _userData?['ciudad'] ??
          _userData?['location'] ??
          _userData?['ubicacion'] ??
          '',
    );

    if (country.isNotEmpty) {
      if (state.isNotEmpty) {
        final knownState = location_data.findHardcodedState(country, state);
        if (knownState != null) {
          state = knownState;
        } else if (location_data.hasHardcodedStatesForCountry(country)) {
          state = '';
        }
      }

      if (city.isNotEmpty) {
        final hasKnownCountryCities =
            location_data.hasHardcodedCitiesForCountry(country);
        final hasKnownStateCities = state.isNotEmpty &&
            location_data.getHardcodedCities(country, state).isNotEmpty;
        final knownCity = hasKnownStateCities
            ? location_data.findHardcodedCityForState(country, state, city)
            : location_data.findHardcodedCityForCountry(country, city);

        if (knownCity != null) {
          city = knownCity;
        } else if (hasKnownCountryCities) {
          city = '';
        }
      }
    }

    final parts = <String>[];
    for (final value in [city, state, country]) {
      if (value.isEmpty) continue;
      if (parts.any((part) => part.toLowerCase() == value.toLowerCase())) {
        continue;
      }
      parts.add(value);
    }
    return parts.join(' · ');
  }

  String _profileNationalityText() {
    final country = normalizeCountryName(
      _userData?['nationality'] ??
          _userData?['nacionalidad'] ??
          _userData?['country'] ??
          _userData?['pais'] ??
          '',
    );
    return country.isEmpty ? 'No definido' : country;
  }

  Future<void> _cleanupVideoRelations(
    String videoId, {
    Iterable<String> videoUrls = const [],
  }) async {
    final normalizedVideoUrls = videoUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    final cleanupOperations = <Future<void> Function()>[
      () async {
        await SupaFlow.client.from('comments').delete().eq('video_id', videoId);
      },
      () async {
        await SupaFlow.client.from('likes').delete().eq('video_id', videoId);
      },
      () async {
        await SupaFlow.client
            .from('saved_videos')
            .delete()
            .eq('video_id', videoId);
      },
      () async {
        await SupaFlow.client
            .from('user_challenge_attempts')
            .delete()
            .eq('video_id', videoId);
      },
      for (final videoUrl in normalizedVideoUrls)
        () async {
          await SupaFlow.client
              .from('user_challenge_attempts')
              .delete()
              .eq('user_id', currentUserUid)
              .eq('video_url', videoUrl);
        },
    ];

    for (final operation in cleanupOperations) {
      try {
        await operation();
      } catch (e) {
        debugPrint('Related cleanup failed for video $videoId: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _challengeAttemptsForVideo(
    String videoId, {
    Iterable<String> videoUrls = const [],
  }) async {
    final attemptsByKey = <String, Map<String, dynamic>>{};

    void addAttempts(List<Map<String, dynamic>> attempts) {
      for (final attempt in attempts) {
        final id = attempt['id']?.toString().trim() ?? '';
        final itemType =
            attempt['item_type']?.toString().trim().toLowerCase() ?? '';
        final itemId = attempt['item_id']?.toString().trim() ?? '';
        final attemptVideoId = attempt['video_id']?.toString().trim() ?? '';
        final attemptVideoUrl = attempt['video_url']?.toString().trim() ?? '';
        final key = id.isNotEmpty
            ? id
            : '$itemType:$itemId:$attemptVideoId:$attemptVideoUrl';
        if (key.trim().isNotEmpty) attemptsByKey[key] = attempt;
      }
    }

    try {
      final rows = await SupaFlow.client
          .from('user_challenge_attempts')
          .select('id, item_id, item_type, video_id, video_url')
          .eq('user_id', currentUserUid)
          .eq('video_id', videoId);
      addAttempts(List<Map<String, dynamic>>.from(rows as List));
    } catch (e) {
      debugPrint('Challenge attempt lookup failed for video $videoId: $e');
    }

    final normalizedVideoUrls = videoUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedVideoUrls.isNotEmpty) {
      try {
        final rows = await SupaFlow.client
            .from('user_challenge_attempts')
            .select('id, item_id, item_type, video_id, video_url')
            .eq('user_id', currentUserUid)
            .inFilter('video_url', normalizedVideoUrls);
        addAttempts(List<Map<String, dynamic>>.from(rows as List));
      } catch (e) {
        debugPrint('Challenge attempt URL lookup failed for $videoId: $e');
      }
    }

    if (attemptsByKey.isNotEmpty) return attemptsByKey.values.toList();

    try {
      final videoRow = await SupaFlow.client
          .from('videos')
          .select('id, description')
          .eq('user_id', currentUserUid)
          .eq('id', videoId)
          .maybeSingle();
      final description = videoRow?['description']?.toString() ?? '';
      final match = RegExp(r'\[challenge_ref:(course|exercise):([^\]]+)\]')
          .firstMatch(description);
      final itemType = match?.group(1)?.trim() ?? '';
      final itemId = match?.group(2)?.trim() ?? '';
      if (itemType.isNotEmpty && itemId.isNotEmpty) {
        return [
          {
            'item_type': itemType,
            'item_id': itemId,
            'video_id': videoId,
          }
        ];
      }
    } catch (fallbackError) {
      debugPrint(
          'Challenge tag fallback failed for video $videoId: $fallbackError');
    }

    return const [];
  }

  Future<void> _clearLocalChallengeAttemptsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('challenge_attempts_$currentUserUid');
    } catch (e) {
      debugPrint('Challenge attempt cache cleanup failed: $e');
    }
  }

  Future<bool> _hasOtherChallengeAttempt({
    required String videoId,
    required Set<String> videoUrls,
    required String itemType,
    required String itemId,
  }) async {
    try {
      final rows = await SupaFlow.client
          .from('user_challenge_attempts')
          .select('id, video_id, video_url, status')
          .eq('user_id', currentUserUid)
          .eq('item_type', itemType)
          .eq('item_id', itemId)
          .limit(20);
      for (final row in rows as List) {
        final attempt = Map<String, dynamic>.from(row as Map);
        final attemptVideoId = attempt['video_id']?.toString().trim() ?? '';
        final attemptVideoUrl = attempt['video_url']?.toString().trim() ?? '';
        if (attemptVideoId == videoId || videoUrls.contains(attemptVideoUrl)) {
          continue;
        }
        final status = attempt['status']?.toString().trim().toLowerCase() ?? '';
        if (status != 'submitted' &&
            status != 'completed' &&
            status != 'in_progress') {
          continue;
        }
        if (await _challengeAttemptStillHasVideo(attempt)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _challengeAttemptStillHasVideo(
    Map<String, dynamic> attempt,
  ) async {
    final attemptVideoId = attempt['video_id']?.toString().trim() ?? '';
    final attemptVideoUrl = attempt['video_url']?.toString().trim() ?? '';

    try {
      Map<String, dynamic>? videoRow;
      if (attemptVideoId.isNotEmpty) {
        final row = await SupaFlow.client
            .from('videos')
            .select()
            .eq('user_id', currentUserUid)
            .eq('id', attemptVideoId)
            .maybeSingle();
        if (row == null) return false;
        videoRow = Map<String, dynamic>.from(row);
      } else if (attemptVideoUrl.isNotEmpty) {
        final rows = await SupaFlow.client
            .from('videos')
            .select()
            .eq('user_id', currentUserUid)
            .eq('video_url', attemptVideoUrl)
            .limit(1);
        final list = rows as List;
        if (list.isEmpty) return false;
        videoRow = Map<String, dynamic>.from(list.first as Map);
      } else {
        return false;
      }

      return isPublicVideoCandidate(videoRow);
    } catch (e) {
      debugPrint('Other challenge attempt validation failed: $e');
      return false;
    }
  }

  Future<void> _revertChallengeCompletionForDeletedAttempts({
    required String videoId,
    required Set<String> videoUrls,
    required List<Map<String, dynamic>> attempts,
  }) async {
    for (final attempt in attempts) {
      final itemType =
          attempt['item_type']?.toString().trim().toLowerCase() ?? '';
      final itemId = attempt['item_id']?.toString().trim() ?? '';
      if (itemType.isEmpty || itemId.isEmpty) continue;
      if (await _hasOtherChallengeAttempt(
        videoId: videoId,
        videoUrls: videoUrls,
        itemType: itemType,
        itemId: itemId,
      )) {
        continue;
      }

      try {
        if (itemType == 'course') {
          try {
            await SupaFlow.client
                .from('user_courses')
                .update({
                  'status': 'not_started',
                  'progress_percent': 0,
                  'xp_earned': 0,
                })
                .eq('user_id', currentUserUid)
                .eq('course_id', itemId)
                .eq('status', 'completed');
          } catch (_) {
            await SupaFlow.client
                .from('user_courses')
                .update({'status': 'not_started'})
                .eq('user_id', currentUserUid)
                .eq('course_id', itemId)
                .eq('status', 'completed');
          }
        } else if (itemType == 'exercise') {
          try {
            await SupaFlow.client
                .from('user_exercises')
                .update({
                  'status': 'not_started',
                  'total_xp_earned': 0,
                })
                .eq('user_id', currentUserUid)
                .eq('exercise_id', itemId)
                .eq('status', 'completed');
          } catch (_) {
            await SupaFlow.client
                .from('user_exercises')
                .update({'status': 'not_started'})
                .eq('user_id', currentUserUid)
                .eq('exercise_id', itemId)
                .eq('status', 'completed');
          }
        }
      } catch (e) {
        debugPrint(
            'Challenge completion revert failed for $itemType/$itemId: $e');
      }
    }

    await _clearLocalChallengeAttemptsCache();
  }

  Future<void> _deleteOwnVideo(Map<String, dynamic> video) async {
    final videoId = (video['id'] ?? '').toString().trim();
    final ownerId = (video['user_id'] ?? '').toString().trim();

    if (videoId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar el video.')),
      );
      return;
    }

    if (ownerId.isNotEmpty && ownerId != currentUserUid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo podés eliminar videos publicados por tu cuenta.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar video'),
        content: Text(
          '¿Querés eliminar "${video['title'] ?? 'este video'}" desde tu perfil? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      bool removed = false;
      bool hardDeleted = false;
      setState(() => _deletingVideoId = videoId);
      final videoUrls = <String>{
        (video['video_url'] ?? '').toString().trim(),
        (video['url'] ?? '').toString().trim(),
      }..removeWhere((url) => url.isEmpty);
      final challengeAttempts = await _challengeAttemptsForVideo(
        videoId,
        videoUrls: videoUrls,
      );

      // Try direct delete first in case the DB already cascades related rows.
      try {
        final deleteResponse = await SupaFlow.client
            .from('videos')
            .delete()
            .eq('user_id', currentUserUid)
            .eq('id', videoId)
            .select('id');
        removed = (deleteResponse as List).isNotEmpty;
        hardDeleted = removed;
      } catch (e) {
        debugPrint('Direct delete failed for video $videoId: $e');
      }

      if (!removed) {
        await _cleanupVideoRelations(videoId, videoUrls: videoUrls);

        try {
          final deleteResponse = await SupaFlow.client
              .from('videos')
              .delete()
              .eq('user_id', currentUserUid)
              .eq('id', videoId)
              .select('id');
          removed = (deleteResponse as List).isNotEmpty;
          hardDeleted = removed;
        } catch (e) {
          debugPrint('Delete after cleanup failed for video $videoId: $e');
        }
      }

      // Last fallback: hide the video from the profile/feed if SQL policies
      // don't allow a hard delete in production yet.
      if (!removed) {
        try {
          final deletedAt = DateTime.now().toIso8601String();
          final updateResponse = await SupaFlow.client
              .from('videos')
              .update({
                'is_public': false,
                'is_deleted': true,
                'deleted_at': deletedAt,
              })
              .eq('user_id', currentUserUid)
              .eq('id', videoId)
              .select('id, is_public, is_deleted, deleted_at');
          removed = (updateResponse as List).isNotEmpty;
        } catch (e) {
          debugPrint('Soft delete marker failed for video $videoId: $e');
          try {
            final updateResponse = await SupaFlow.client
                .from('videos')
                .update({
                  'is_public': false,
                })
                .eq('user_id', currentUserUid)
                .eq('id', videoId)
                .select('id, is_public');
            removed = (updateResponse as List).isNotEmpty;
          } catch (fallbackError) {
            debugPrint('Soft hide failed for video $videoId: $fallbackError');
          }
        }
      }

      if (removed) {
        await _revertChallengeCompletionForDeletedAttempts(
          videoId: videoId,
          videoUrls: videoUrls,
          attempts: challengeAttempts,
        );
        await _cleanupVideoRelations(videoId, videoUrls: videoUrls);

        if (hardDeleted) {
          final storageUrls = <String>{
            (video['video_url'] ?? '').toString().trim(),
            (video['thumbnail_url'] ?? '').toString().trim(),
            (video['thumbnail'] ?? '').toString().trim(),
            (video['cover_url'] ?? '').toString().trim(),
          }..removeWhere((url) => url.isEmpty);

          for (final url in storageUrls) {
            await _deleteVideoStorageAsset(url);
          }
        }

        await GamificationService.recalculateUserProgress(
            userId: currentUserUid);
        if (!mounted) return;
        setState(() {
          _videos.removeWhere((item) => item['id']?.toString() == videoId);
          _savedVideos.removeWhere((item) => item['id']?.toString() == videoId);
          if (_updatingFeaturedVideoId == videoId) {
            _updatingFeaturedVideoId = null;
          }
          _deletingVideoId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hardDeleted
                  ? 'El video se eliminó de tu perfil.'
                  : 'El video se quitó de tu perfil.',
            ),
          ),
        );
      } else {
        if (!mounted) return;
        setState(() => _deletingVideoId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar el video desde tu perfil.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting video: $e');
      if (!mounted) return;
      setState(() => _deletingVideoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No pudimos eliminar este video. Verifica tu conexión e intenta de nuevo.'),
            backgroundColor: Colors.red),
      );
    }
  }

  late PerfilJugadorModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _savedVideos = [];
  List<Map<String, dynamic>> _contactRequests = [];
  bool _isLoadingSavedVideos = false;
  String? _deletingVideoId;
  String? _removingSavedVideoId;
  String? _updatingFeaturedVideoId;
  int _userRanking = 0;
  int _pendingContactRequests = 0;
  int _profileViewsCount = 0;
  String _videoFilterType = 'todos'; // 4.1 — filtro por content_type

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PerfilJugadorModel());
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (mounted) setState(() {});
    if (_tabController.index == 2 && currentUserUid.isNotEmpty) {
      _loadSavedVideos(currentUserUid, refreshUi: true);
    }
  }

  Future<void> _loadData() async {
    try {
      final uid = currentUserUid;
      if (uid.isEmpty) return;

      // Carregar dados do usuário
      final userResponse = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      Map<String, dynamic>? playerResponse;
      try {
        playerResponse = await SupaFlow.client
            .from('players')
            .select()
            .eq('id', uid)
            .maybeSingle();
      } catch (_) {}

      await GamificationService.recalculateUserProgress(userId: uid);

      Map<String, dynamic>? progressResponse;
      try {
        progressResponse = await SupaFlow.client
            .from('user_progress')
            .select('total_xp, courses_completed, exercises_completed')
            .eq('user_id', uid)
            .maybeSingle();
      } catch (_) {}

      final mergedUserData = <String, dynamic>{
        ...(userResponse ?? <String, dynamic>{}),
        ...(playerResponse ?? <String, dynamic>{}),
        ...(progressResponse ?? <String, dynamic>{}),
      };

      // Carregar vídeos do usuário (meus vídeos publicados)
      final videosResponse = await SupaFlow.client
          .from('videos')
          .select()
          .eq('user_id', uid)
          .eq('is_public', true)
          .order('created_at', ascending: false);
      final videos = _sortVideosForProfile(
          List<Map<String, dynamic>>.from(videosResponse)
              .where(isPublicVideoCandidate)
              .toList());
      final savedVideos = await _loadSavedVideos(uid);

      // Calcular ranking do usuário (com tratamento de erro)
      int ranking = await _loadCategoryRanking(uid, mergedUserData);

      final requests = await _loadContactRequests(uid);
      int profileViewsCount = 0;
      try {
        final profileViewsResponse = await SupaFlow.client
            .from('player_profile_views')
            .select('id')
            .eq('player_user_id', uid);
        profileViewsCount = (profileViewsResponse as List).length;
      } catch (e) {
        debugPrint('Erro ao carregar visualizações do perfil: $e');
      }

      if (mounted) {
        setState(() {
          _userData = mergedUserData;
          _videos = videos;
          _savedVideos = savedVideos;
          _contactRequests = requests;
          _pendingContactRequests = _countUnreadContactRequests(requests);
          _userRanking = ranking;
          _profileViewsCount = profileViewsCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadSavedVideos(
    String uid, {
    bool refreshUi = false,
  }) async {
    if (mounted && refreshUi) {
      setState(() => _isLoadingSavedVideos = true);
    }

    try {
      final savedRowsResponse = await SupaFlow.client
          .from('saved_videos')
          .select('video_id, created_at')
          .eq('user_id', uid);

      final savedRows = List<Map<String, dynamic>>.from(savedRowsResponse);
      savedRows.sort((a, b) {
        final aDate = a['created_at']?.toString() ?? '';
        final bDate = b['created_at']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

      final videoIds = savedRows
          .map((row) => row['video_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (videoIds.isEmpty) {
        if (mounted && refreshUi) {
          setState(() {
            _savedVideos = [];
            _isLoadingSavedVideos = false;
          });
        }
        return [];
      }

      final videosResponse = await SupaFlow.client
          .from('videos')
          .select()
          .inFilter('id', videoIds);

      final videos = List<Map<String, dynamic>>.from(videosResponse)
          .where(isPublicVideoCandidate)
          .toList();
      final videosById = <String, Map<String, dynamic>>{
        for (final video in videos)
          (video['id']?.toString() ?? ''): Map<String, dynamic>.from(video),
      };

      final ownerIds = videos
          .map((video) => video['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      final ownersById = <String, Map<String, dynamic>>{};
      if (ownerIds.isNotEmpty) {
        try {
          final ownersResponse = await SupaFlow.client
              .from('users')
              .select('user_id, name, lastname, username, photo_url')
              .inFilter('user_id', ownerIds);
          for (final owner in List<Map<String, dynamic>>.from(ownersResponse)) {
            final key = owner['user_id']?.toString() ?? '';
            if (key.isNotEmpty) ownersById[key] = owner;
          }
        } catch (_) {}
      }

      final merged = <Map<String, dynamic>>[];
      for (final savedRow in savedRows) {
        final videoId = savedRow['video_id']?.toString() ?? '';
        if (videoId.isEmpty) continue;
        final video = videosById[videoId];
        if (video == null) continue;
        final ownerId = video['user_id']?.toString() ?? '';
        merged.add({
          ...video,
          'saved_at': savedRow['created_at'],
          'owner_data': ownerIds.contains(ownerId) ? ownersById[ownerId] : null,
        });
      }

      if (mounted && refreshUi) {
        setState(() {
          _savedVideos = merged;
          _isLoadingSavedVideos = false;
        });
      }

      return merged;
    } catch (e) {
      debugPrint('Erro ao carregar vídeos guardados: $e');
      if (mounted && refreshUi) {
        setState(() => _isLoadingSavedVideos = false);
      }
      return [];
    }
  }

  Future<void> _removeSavedVideo(Map<String, dynamic> video) async {
    final uid = currentUserUid;
    final videoId = video['id']?.toString() ?? '';
    if (uid.isEmpty || videoId.isEmpty) return;

    final shouldRemove = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Quitar de guardados'),
            content: const Text(
              'Este video dejará de aparecer en tu pestaña Guardados.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                ),
                child: const Text(
                  'Quitar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRemove) return;

    setState(() => _removingSavedVideoId = videoId);
    try {
      await SupaFlow.client
          .from('saved_videos')
          .delete()
          .eq('user_id', uid)
          .eq('video_id', videoId);

      if (!mounted) return;
      setState(() {
        _savedVideos.removeWhere((item) => item['id']?.toString() == videoId);
        _removingSavedVideoId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video eliminado de Guardados')),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('No se pudo quitar el video guardado: $e');
      setState(() => _removingSavedVideoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No se pudo quitar el video. Verifica tu conexión e intenta de nuevo.')),
      );
    }
  }

  bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'sim';
  }

  bool _isVideoFeatured(Map<String, dynamic> video) {
    return _isTruthy(video['featured_in_explorer']) ||
        _isTruthy(video['is_featured']) ||
        _isTruthy(video['explorer_featured']) ||
        _isTruthy(video['highlighted']);
  }

  List<Map<String, dynamic>> _sortVideosForProfile(
    Iterable<Map<String, dynamic>> videos,
  ) {
    final ordered =
        videos.map((video) => Map<String, dynamic>.from(video)).toList();
    ordered.sort((a, b) {
      final featuredCompare =
          (_isVideoFeatured(b) ? 1 : 0) - (_isVideoFeatured(a) ? 1 : 0);
      if (featuredCompare != 0) return featuredCompare;

      final createdAtA = a['created_at']?.toString() ?? '';
      final createdAtB = b['created_at']?.toString() ?? '';
      return createdAtB.compareTo(createdAtA);
    });
    return ordered;
  }

  Future<void> _toggleFeaturedVideo(Map<String, dynamic> video) async {
    final uid = currentUserUid;
    final videoId = video['id']?.toString() ?? '';
    if (uid.isEmpty || videoId.isEmpty) return;

    final shouldFeature = !_isVideoFeatured(video);
    if (mounted) {
      setState(() => _updatingFeaturedVideoId = videoId);
    }

    try {
      await SupaFlow.client
          .from('videos')
          .update({'featured_in_explorer': false}).eq('user_id', uid);

      if (shouldFeature) {
        await SupaFlow.client
            .from('videos')
            .update({'featured_in_explorer': true}).eq('id', videoId);
      }

      if (!mounted) return;
      setState(() {
        for (final item in _videos) {
          final itemId = item['id']?.toString() ?? '';
          item['featured_in_explorer'] = shouldFeature && itemId == videoId;
        }
        _videos = _sortVideosForProfile(_videos);
        _updatingFeaturedVideoId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldFeature
                ? 'Video destacado seleccionado para Explorer'
                : 'Video destacado eliminado',
          ),
          backgroundColor:
              shouldFeature ? const Color(0xFF0F766E) : const Color(0xFF475569),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao atualizar vídeo destacado: $e');
      if (!mounted) return;
      setState(() => _updatingFeaturedVideoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar el video destacado. Si persiste, aplicá la policy SQL de update own en videos.',
          ),
        ),
      );
    }
  }

  Map<String, String>? _parseChallengeRef(String description) {
    final match = RegExp(r'\[challenge_ref:(course|exercise):([^\]]+)\]')
        .firstMatch(description);
    if (match == null) return null;
    return {
      'type': (match.group(1) ?? '').trim(),
      'id': (match.group(2) ?? '').trim(),
    };
  }

  Future<int> _loadCategoryRanking(
    String uid,
    Map<String, dynamic>? currentUserData,
  ) async {
    try {
      final progressRows = await SupaFlow.client
          .from('user_progress')
          .select('user_id, total_xp')
          .order('total_xp', ascending: false);
      final ordered = List<Map<String, dynamic>>.from(progressRows);
      if (ordered.isEmpty) return 1;

      final myYear = GamificationService.birthYearFromUser(currentUserData);
      if (myYear == null) {
        for (int i = 0; i < ordered.length; i++) {
          if (ordered[i]['user_id']?.toString() == uid) return i + 1;
        }
        return 1;
      }

      final ids = ordered
          .map((r) => r['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isEmpty) return 1;

      final usersRows = await SupaFlow.client
          .from('users')
          .select('user_id, birthday, birth_date')
          .inFilter('user_id', ids);
      final yearByUser = <String, int?>{};
      for (final row in (usersRows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['user_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        yearByUser[id] = GamificationService.birthYearFromUser(map);
      }

      final categoryRows = ordered.where((row) {
        final id = row['user_id']?.toString() ?? '';
        return id.isNotEmpty && yearByUser[id] == myYear;
      }).toList()
        ..sort((a, b) => GamificationService.toInt(
              b['total_xp'],
            ).compareTo(
              GamificationService.toInt(a['total_xp']),
            ));

      for (int i = 0; i < categoryRows.length; i++) {
        if (categoryRows[i]['user_id']?.toString() == uid) return i + 1;
      }
      return 1;
    } catch (e) {
      debugPrint('Erro ao calcular ranking por categoria: $e');
      return 1;
    }
  }

  String _normalizeContactRequestStatus(Map<String, dynamic> request) {
    return request['status']?.toString().toLowerCase().trim() ?? 'pending';
  }

  bool _isPendingContactRequest(Map<String, dynamic> request) {
    final status = _normalizeContactRequestStatus(request);
    return status == 'pending' || status == 'pendiente' || status.isEmpty;
  }

  bool _isUnreadContactRequest(Map<String, dynamic> request) {
    final readAt = request['receiver_read_at']?.toString().trim() ?? '';
    return _isPendingContactRequest(request) && readAt.isEmpty;
  }

  int _countUnreadContactRequests(List<Map<String, dynamic>> requests) {
    return requests.where(_isUnreadContactRequest).length;
  }

  String _contactRequestStatusLabel(Map<String, dynamic> request) {
    final status = _normalizeContactRequestStatus(request);
    switch (status) {
      case 'accepted':
      case 'aceptado':
      case 'aprobado':
      case 'aprovado':
        return 'Aprobado';
      case 'rejected':
      case 'rechazado':
      case 'recusado':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }

  Color _contactRequestStatusColor(Map<String, dynamic> request) {
    final status = _normalizeContactRequestStatus(request);
    switch (status) {
      case 'accepted':
      case 'aceptado':
      case 'aprobado':
        return const Color(0xFF15803D);
      case 'rejected':
      case 'rechazado':
      case 'recusado':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF0D3B66);
    }
  }

  Future<List<Map<String, dynamic>>> _loadContactRequests(
      String playerId) async {
    try {
      final response = await SupaFlow.client
          .from('contact_requests')
          .select()
          .eq('to_user_id', playerId)
          .order('created_at', ascending: false)
          .limit(60);

      final rows = List<Map<String, dynamic>>.from(response);
      if (rows.isEmpty) return [];

      final fromIds = rows
          .map((r) => r['from_user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final usersMap = <String, Map<String, dynamic>>{};
      if (fromIds.isNotEmpty) {
        try {
          final usersRes = await SupaFlow.client
              .from('users')
              .select('user_id, name, lastname, userType, club, photo_url')
              .inFilter('user_id', fromIds);
          for (final row in (usersRes as List)) {
            final map = Map<String, dynamic>.from(row);
            final id = map['user_id']?.toString() ?? '';
            if (id.isNotEmpty) usersMap[id] = map;
          }
        } catch (_) {}
      }

      for (final request in rows) {
        final fromId = request['from_user_id']?.toString() ?? '';
        request['from_user_data'] = usersMap[fromId];
      }

      return rows;
    } catch (_) {
      return [];
    }
  }

  String _formatRequestDate(dynamic rawDate) {
    if (rawDate == null) return '';
    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed == null) return '';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  bool get _requiresGuardianCodeForContactDecisions {
    return _userData?['is_minor'] == true;
  }

  bool get _isMinorApprovalPending {
    return _userData?['is_minor'] == true &&
        GuardianMvpService.normalizedGuardianStatus(_userData) !=
            GuardianMvpService.approvedStatus;
  }

  Future<void> _activateMinorAccountWithGuardianCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw Exception('Ingresá el código del responsable.');
    }

    final guardian = await SupaFlow.client
        .from('guardians')
        .select('approval_code')
        .eq('player_id', currentUserUid)
        .maybeSingle();
    final expectedCode =
        guardian?['approval_code']?.toString().trim().toUpperCase() ?? '';
    if (expectedCode.isEmpty || expectedCode != normalizedCode) {
      throw Exception('Código del responsable inválido.');
    }

    try {
      await GuardianMvpService.approveGuardianCode(normalizedCode);
      return;
    } catch (_) {}

    await SupaFlow.client.from('guardians').update({
      'status': GuardianMvpService.approvedStatus,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('player_id', currentUserUid);

    await SupaFlow.client.from('users').update({
      'has_guardian': true,
      'guardian_status': GuardianMvpService.approvedStatus,
      'visibility_status': GuardianMvpService.activeVisibility,
    }).eq('user_id', currentUserUid);

    try {
      await SupaFlow.client.from('videos').update({
        'moderation_status': GuardianMvpService.approvedStatus,
      }).eq('user_id', currentUserUid);
    } catch (_) {}
  }

  Future<bool> _promptGuardianCodeAndUpdateRequest(
    String requestId,
    String status,
  ) async {
    final codeController = TextEditingController();
    String? localError;
    bool isSubmitting = false;
    var handled = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Código del responsable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status == 'accepted'
                    ? 'Para aprobar esta solicitud, ingresá el código del adulto responsable.'
                    : 'Para rechazar esta solicitud, ingresá el código del adulto responsable.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'RESP-123456',
                  border: OutlineInputBorder(),
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 10),
                Text(
                  localError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        localError = null;
                      });
                      try {
                        await _activateMinorAccountWithGuardianCode(
                          codeController.text,
                        );
                        final ok = await _updateContactRequestStatus(
                            requestId, status);
                        if (!dialogContext.mounted) return;
                        if (ok) {
                          handled = true;
                          Navigator.pop(dialogContext);
                          await _loadData();
                        } else {
                          setDialogState(() => isSubmitting = false);
                        }
                      } catch (error) {
                        setDialogState(() {
                          isSubmitting = false;
                          localError = error.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(status == 'accepted' ? 'Aprobar' : 'Rechazar'),
            ),
          ],
        ),
      ),
    );

    codeController.dispose();
    return handled;
  }

  Future<bool> _updateContactRequestStatus(
    String requestId,
    String status,
  ) async {
    if (requestId.isEmpty || currentUserUid.isEmpty) return false;
    try {
      dynamic updatedRow;
      try {
        updatedRow = await SupaFlow.client
            .from('contact_requests')
            .update({
              'status': status,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', requestId)
            .eq('to_user_id', currentUserUid)
            .select('id')
            .maybeSingle();
      } catch (_) {
        updatedRow = await SupaFlow.client
            .from('contact_requests')
            .update({
              'status': status,
            })
            .eq('id', requestId)
            .eq('to_user_id', currentUserUid)
            .select('id')
            .maybeSingle();
      }

      if (updatedRow == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo actualizar. Verificá permisos en la base de datos.',
              ),
            ),
          );
        }
        return false;
      }

      final refreshed = await _loadContactRequests(currentUserUid);
      if (mounted) {
        setState(() {
          _contactRequests = refreshed;
          _pendingContactRequests = _countUnreadContactRequests(refreshed);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted'
                  ? 'Solicitud aprobada'
                  : 'Solicitud rechazada',
            ),
            backgroundColor: status == 'accepted'
                ? const Color(0xFF15803D)
                : const Color(0xFFB91C1C),
          ),
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar la solicitud'),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _markContactRequestAsRead(
    Map<String, dynamic> request, {
    StateSetter? setSheetState,
    List<Map<String, dynamic>>? localRequests,
  }) async {
    if (!_isUnreadContactRequest(request) || currentUserUid.isEmpty) return;

    final requestId = request['id']?.toString() ?? '';
    if (requestId.isEmpty) return;

    final readAt = DateTime.now().toIso8601String();
    try {
      await SupaFlow.client
          .from('contact_requests')
          .update({'receiver_read_at': readAt})
          .eq('id', requestId)
          .eq('to_user_id', currentUserUid);
    } catch (_) {
      // The local state is still updated so the badge reacts immediately.
      // The migration adds receiver_read_at for persistent read state.
    }

    void markRow(Map<String, dynamic> item) {
      if (item['id']?.toString() == requestId) {
        item['receiver_read_at'] = readAt;
      }
    }

    request['receiver_read_at'] = readAt;
    if (localRequests != null) {
      for (final item in localRequests) {
        markRow(item);
      }
    }

    if (!mounted) return;
    setState(() {
      for (final item in _contactRequests) {
        markRow(item);
      }
      _pendingContactRequests = _countUnreadContactRequests(_contactRequests);
    });
    setSheetState?.call(() {});
  }

  Future<String?> _showRequestDetail(Map<String, dynamic> request) async {
    final requester = request['from_user_data'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final requesterName =
        '${requester['name'] ?? ''} ${requester['lastname'] ?? ''}'.trim();
    final role = requester['userType']?.toString() ?? 'profesional';
    final club = requester['club']?.toString() ?? '';
    final createdAt = _formatRequestDate(request['created_at']);
    final status = _normalizeContactRequestStatus(request);
    final reqId = request['id']?.toString() ?? '';
    final requesterId = request['from_user_id']?.toString() ?? '';

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool actionLoading = false;

        return StatefulBuilder(
          builder: (ctx, setDetailState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Solicitud de contacto',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    requesterName.isNotEmpty ? requesterName : 'Scout',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      role,
                      if (club.isNotEmpty) club,
                      if (createdAt.isNotEmpty) 'Enviada el $createdAt',
                    ].join(' • '),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          _contactRequestStatusColor(request).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _contactRequestStatusLabel(request),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _contactRequestStatusColor(request),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (status == 'pending' &&
                      !_requiresGuardianCodeForContactDecisions)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: actionLoading
                                ? null
                                : () async {
                                    setDetailState(() => actionLoading = true);
                                    final ok =
                                        await _updateContactRequestStatus(
                                      reqId,
                                      'rejected',
                                    );
                                    if (!ctx.mounted) return;
                                    if (ok) {
                                      Navigator.pop(ctx, 'rejected');
                                    } else {
                                      setDetailState(
                                          () => actionLoading = false);
                                    }
                                  },
                            child: actionLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Rechazar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: actionLoading
                                ? null
                                : () async {
                                    setDetailState(() => actionLoading = true);
                                    final ok =
                                        await _updateContactRequestStatus(
                                      reqId,
                                      'accepted',
                                    );
                                    if (!ctx.mounted) return;
                                    if (ok) {
                                      Navigator.pop(ctx, 'accepted');
                                    } else {
                                      setDetailState(
                                          () => actionLoading = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D3B66),
                            ),
                            child: const Text(
                              'Aprobar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (status == 'pending' &&
                      _requiresGuardianCodeForContactDecisions)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                          child: Text(
                            'Como es una cuenta de menor, esta decisión requiere el código del responsable.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF9A3412),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: actionLoading
                                    ? null
                                    : () async {
                                        setDetailState(
                                            () => actionLoading = true);
                                        final ok =
                                            await _promptGuardianCodeAndUpdateRequest(
                                          reqId,
                                          'rejected',
                                        );
                                        if (!ctx.mounted) return;
                                        if (ok) {
                                          Navigator.pop(ctx, 'rejected');
                                        } else {
                                          setDetailState(
                                              () => actionLoading = false);
                                        }
                                      },
                                child: actionLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Rechazar con código'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: actionLoading
                                    ? null
                                    : () async {
                                        setDetailState(
                                            () => actionLoading = true);
                                        final ok =
                                            await _promptGuardianCodeAndUpdateRequest(
                                          reqId,
                                          'accepted',
                                        );
                                        if (!ctx.mounted) return;
                                        if (ok) {
                                          Navigator.pop(ctx, 'accepted');
                                        } else {
                                          setDetailState(
                                              () => actionLoading = false);
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D3B66),
                                ),
                                child: const Text(
                                  'Aprobar con código',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3B66),
                        ),
                        child: const Text(
                          'Entendido',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  if (requesterId.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: actionLoading
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                context.pushNamed(
                                  'perfil_profesional_solicitar_Contato',
                                  queryParameters: {'userId': requesterId},
                                );
                              },
                        child: const Text('Ver perfil de quien solicitó'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showContactRequestsSheet() async {
    if (currentUserUid.isEmpty) return;

    final refreshed = await _loadContactRequests(currentUserUid);
    if (mounted) {
      setState(() {
        _contactRequests = refreshed;
        _pendingContactRequests = _countUnreadContactRequests(refreshed);
      });
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        List<Map<String, dynamic>> localRequests =
            List<Map<String, dynamic>>.from(_contactRequests);
        bool isRefreshing = false;

        Future<void> refresh(StateSetter setSheetState) async {
          setSheetState(() => isRefreshing = true);
          final latest = await _loadContactRequests(currentUserUid);
          if (!mounted) return;
          setState(() {
            _contactRequests = latest;
            _pendingContactRequests = _countUnreadContactRequests(latest);
          });
          setSheetState(() {
            localRequests = latest;
            isRefreshing = false;
          });
        }

        return StatefulBuilder(
          builder: (ctx, setSheetState) => FractionallySizedBox(
            heightFactor: 0.78,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Notificaciones de contacto',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isRefreshing
                              ? null
                              : () => refresh(setSheetState),
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: isRefreshing
                        ? const Center(child: CircularProgressIndicator())
                        : localRequests.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Todavía no recibiste solicitudes de contacto.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: localRequests.length,
                                itemBuilder: (_, index) {
                                  final request = localRequests[index];
                                  final from = request['from_user_data']
                                          as Map<String, dynamic>? ??
                                      <String, dynamic>{};
                                  final fromName =
                                      '${from['name'] ?? ''} ${from['lastname'] ?? ''}'
                                          .trim();
                                  final statusLabel =
                                      _contactRequestStatusLabel(request);
                                  final statusColor =
                                      _contactRequestStatusColor(request);
                                  final dateLabel =
                                      _formatRequestDate(request['created_at']);
                                  final isUnread =
                                      _isUnreadContactRequest(request);

                                  return InkWell(
                                    onTap: () async {
                                      await _markContactRequestAsRead(
                                        request,
                                        setSheetState: setSheetState,
                                        localRequests: localRequests,
                                      );
                                      final updatedStatus =
                                          await _showRequestDetail(request);
                                      if (updatedStatus != null) {
                                        await refresh(setSheetState);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor:
                                                const Color(0xFFEAF2FF),
                                            backgroundImage: (from['photo_url']
                                                        ?.toString()
                                                        .isNotEmpty ??
                                                    false)
                                                ? NetworkImage(
                                                    from['photo_url']
                                                        .toString(),
                                                  )
                                                : null,
                                            child: (from['photo_url']
                                                        ?.toString()
                                                        .isNotEmpty ??
                                                    false)
                                                ? null
                                                : const Icon(
                                                    Icons.person,
                                                    color: Color(0xFF0D3B66),
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fromName.isNotEmpty
                                                      ? fromName
                                                      : 'Scout',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    fontWeight: isUnread
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                    color:
                                                        const Color(0xFF111827),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  dateLabel.isNotEmpty
                                                      ? 'Solicitó contacto el $dateLabel'
                                                      : 'Solicitó contacto',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color:
                                                        const Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isUnread) ...[
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFDC2626),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  statusColor.withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
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
          ),
        );
      },
    );
  }

  String _formatBirthDate(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return 'No definido';
    try {
      if (birthDate.contains('/')) return birthDate;
      final date = DateTime.parse(birthDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return birthDate;
    }
  }

  String _getLevelName(int xp) {
    return GamificationService.levelNameFromPoints(xp);
  }

  int _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return 0;
    try {
      DateTime birth;
      if (birthDate.contains('/')) {
        final parts = birthDate.split('/');
        birth = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      } else {
        birth = DateTime.parse(birthDate);
      }
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildMedalsRow() {
    final coursesCompleted = _userData?['courses_completed'] ?? 0;
    final exercisesCompleted = _userData?['exercises_completed'] ?? 0;
    final totalXp = _userData?['total_xp'] ?? 0;
    final xpInt =
        totalXp is int ? totalXp : int.tryParse(totalXp.toString()) ?? 0;

    final medals = <Map<String, dynamic>>[
      {
        'unlocked': (coursesCompleted is int ? coursesCompleted : 0) >= 1,
        'icon': Icons.school,
        'color': const Color(0xFF4CAF50),
      },
      {
        'unlocked': (exercisesCompleted is int ? exercisesCompleted : 0) >= 5,
        'icon': Icons.fitness_center,
        'color': const Color(0xFF2196F3),
      },
      {
        'unlocked': xpInt >= 300,
        'icon': Icons.star,
        'color': const Color(0xFFFF9800),
      },
      {
        'unlocked': _videos.length >= 3,
        'icon': Icons.videocam,
        'color': const Color(0xFF9C27B0),
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: medals.map((medal) {
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: medal['unlocked']
                ? Icon(medal['icon'], color: medal['color'], size: 30)
                : const Icon(Icons.lock, color: Colors.grey, size: 30),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatColumn(String value, String label, {bool compact = false}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: compact ? 68 : 76),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontSize: compact ? 13 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic num) {
    final n = num is int ? num : int.tryParse(num.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  Widget _buildPlayerStatusChip(String status) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.track_changes_rounded,
            size: 16,
            color: Color(0xFF92400E),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== TAB VIDEOS =====
  Widget _buildVideosTab() {
    final orderedVideos = _sortVideosForProfile(_videos);

    // 4.1 — Filtra por content_type
    final filteredVideos = _videoFilterType == 'todos'
        ? orderedVideos
        : orderedVideos.where((v) {
            final ct =
                v['content_type']?.toString().trim().toLowerCase() ?? 'video';
            return ct == _videoFilterType;
          }).toList();

    if (orderedVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              color: Colors.grey[400],
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              'Subí tu jugada y mostrá quién sos',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF0D3B66),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Este video puede ser visto por scouts y reforzar tu perfil dentro del app.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                try {
                  GoRouter.of(context).pushNamed('Crear_Publicacin_de_Video');
                } catch (e) {
                  context.pushNamed('Crear_Publicacin_de_Video');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D3B66),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Subí tu jugada',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 960
        ? 4
        : screenWidth >= 520
            ? 4
            : 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Vídeos destacados',
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // 4.1 — Filter chips por content_type
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _buildVideoFilterChip('todos', 'Todos'),
                  const SizedBox(width: 8),
                  _buildVideoFilterChip('video', 'Videos'),
                  const SizedBox(width: 8),
                  _buildVideoFilterChip('desafio', 'Desafíos'),
                  const SizedBox(width: 8),
                  _buildVideoFilterChip('convocatoria', 'Convocatorias'),
                ],
              ),
            ),
          ),
          if (filteredVideos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No hay videos de este tipo aún.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredVideos.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.66,
              ),
              itemBuilder: (context, index) {
                final video = filteredVideos[index];
                final videoId = video['id']?.toString() ?? '';
                final isFeatured = _isVideoFeatured(video);
                final isDeleting = _deletingVideoId == videoId;
                final isUpdating = _updatingFeaturedVideoId == videoId;
                final originalIndex = _videos.indexWhere(
                  (item) => item['id']?.toString() == videoId,
                );
                // 3.3 — Badge visual por content_type
                final contentType =
                    video['content_type']?.toString().trim().toLowerCase() ??
                        'video';
                Widget? typeBadge;
                if (contentType == 'desafio') {
                  typeBadge = Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Desafío',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                } else if (contentType == 'convocatoria') {
                  typeBadge = Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Convocatoria',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    _VideoCard(
                      videoUrl: video['video_url']?.toString() ?? '',
                      thumbnailUrl: (video['thumbnail_url'] ??
                              video['thumbnail'] ??
                              video['cover_url'] ??
                              '')
                          .toString(),
                      title: video['title']?.toString() ?? '',
                      onTap: () => _openVideoFeed(
                        originalIndex >= 0 ? originalIndex : index,
                        _videos,
                      ),
                      badge: isFeatured
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Destacado',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : typeBadge,
                      topRightAction: GestureDetector(
                        onTap: isUpdating
                            ? null
                            : () => _toggleFeaturedVideo(video),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: isUpdating
                              ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  isFeatured ? Icons.star : Icons.star_border,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                    // Botão de exclusão (canto superior esquerdo)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: isDeleting || isUpdating
                            ? null
                            : () => _deleteOwnVideo(video),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.85),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: isDeleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 10),
          Text(
            'Tocá un video para abrir el feed completo. Marcá uno como destacado para que Explorer lo muestre primero.',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 4.1 — Helper: chip de filtro de video
  Widget _buildVideoFilterChip(String value, String label) {
    final isSelected = _videoFilterType == value;
    return GestureDetector(
      onTap: () => setState(() => _videoFilterType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D3B66) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0D3B66) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ===== TAB FICHA COMPLETA =====
  Widget _buildFichaTab() {
    final birthDate = _userData?['birth_date'] ??
        _userData?['fecha_nacimiento'] ??
        _userData?['birthday'] ??
        '';
    final nationality = _profileNationalityText();
    final location = _profileLocationText();
    final height = _userData?['height'] ?? _userData?['altura'] ?? '';
    final weight = _userData?['weight'] ?? _userData?['peso'] ?? '';
    final playerStatus = _userData?['player_status']?.toString().trim() ?? '';
    final category = normalizePlayerCategory(
      _userData?['categoria']?.toString().trim() ?? '',
      birthday: birthDate,
    );
    final position = normalizePlayerPosition(_userData?['position'] ??
        _userData?['posicion']?.toString().trim() ??
        '');
    final dominantFoot = normalizeDominantFoot(_userData?['dominant_foot'] ??
        _userData?['pie_dominante']?.toString().trim() ??
        '');
    final age = _calculateAge(birthDate.toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información Personal',
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoRow(
            Icons.calendar_month,
            birthDate.toString().isNotEmpty
                ? '${_formatBirthDate(birthDate.toString())} | $age años'
                : 'No definido',
          ),
          _buildInfoRow(Icons.flag, nationality.toString()),
          _buildInfoRow(
            Icons.location_on_outlined,
            location.isNotEmpty ? location : 'Ubicación no definida',
          ),
          _buildInfoRow(
            Icons.height,
            height.toString().isNotEmpty ? '$height cm' : 'No definido',
          ),
          _buildInfoRow(
            Icons.fitness_center,
            weight.toString().isNotEmpty ? '$weight kg' : 'No definido',
          ),
          if (position.toString().isNotEmpty)
            _buildInfoRow(Icons.sports_soccer, position.toString()),
          if (category.toString().isNotEmpty)
            _buildInfoRow(Icons.group, category.toString()),
          if (dominantFoot.toString().isNotEmpty)
            _buildInfoRow(Icons.directions_walk, dominantFoot.toString()),
          _buildInfoRow(
            Icons.track_changes_rounded,
            playerStatus.isNotEmpty
                ? playerStatus
                : 'Status del jugador no definido',
          ),
          _buildInfoRow(
            Icons.remove_red_eye_outlined,
            '${_formatNumber(_profileViewsCount)} visualizaciones de perfil',
          ),
          const SizedBox(height: 20),
          Text(
            'Historial Deportivo',
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildHistorySection(),
          const SizedBox(height: 20),
          Text(
            'Estadísticas de Entrenamiento',
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildStatCard(
                'Cursos',
                (_userData?['courses_completed'] ?? 0).toString(),
                Icons.school,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                'Ejercicios',
                (_userData?['exercises_completed'] ?? 0).toString(),
                Icons.fitness_center,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                'Videos',
                _videos.length.toString(),
                Icons.videocam,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF444444)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: const Color(0xFF444444)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final clubs = normalizeProfileHistory(
      _userData?['clubs'] ?? _userData?['historial_clubes'],
    );

    if (clubs.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: clubs.map<Widget>((club) {
          final position = club['position'] ?? club['posicion'] ?? '';
          final note = club['note'] ?? club['nota'] ?? '';
          final period = formatProfileHistoryPeriod(club);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        club['name'] ?? club['nombre'] ?? 'Club',
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      period,
                      style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
                if (position.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      position.toString(),
                      style: GoogleFonts.inter(
                          color: const Color(0xFF444444), fontSize: 13),
                    ),
                  ),
                if (note.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      note.toString(),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF666666),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Text(
      'Agrega tu historial en Editar Perfil',
      style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF0D3B66), size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFF0D3B66),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF444444),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== TAB GUARDADOS =====
  Widget _buildGuardadosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: Color(0xFF0D3B66),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guardados es privado. Solo vos podés ver estos videos.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoadingSavedVideos)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
              ),
            )
          else if (_savedVideos.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.bookmark_border,
                    color: Colors.grey[400],
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay videos guardados',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los videos que guardes desde el feed aparecerán acá',
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _savedVideos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                final video = _savedVideos[index];
                final thumb = video['thumbnail_url'] ??
                    video['thumbnail'] ??
                    video['cover_url'] ??
                    '';
                final title =
                    video['title']?.toString().trim().isNotEmpty == true
                        ? video['title'].toString().trim()
                        : 'Video guardado';
                final owner = video['owner_data'] is Map<String, dynamic>
                    ? Map<String, dynamic>.from(video['owner_data'] as Map)
                    : <String, dynamic>{};
                final ownerName =
                    owner['name']?.toString().trim().isNotEmpty == true
                        ? owner['name'].toString().trim()
                        : owner['username']?.toString().trim() ?? 'Jugador';
                final videoId = video['id']?.toString() ?? '';
                final isRemoving = _removingSavedVideoId == videoId;

                return GestureDetector(
                  onTap: () => _openVideoFeed(index, _savedVideos),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: thumb.toString().isNotEmpty
                                ? Image.network(
                                    thumb.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[850],
                                      child: const Center(
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[850],
                                    child: const Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: isRemoving
                                ? null
                                : () => _removeSavedVideo(video),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.58),
                                shape: BoxShape.circle,
                              ),
                              child: isRemoving
                                  ? const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 30, 12, 12),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(14),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.88),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ownerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openVideoFeed(int selectedIndex, List<Map<String, dynamic>> videoList) {
    if (videoList.isEmpty) return;

    final selectedVideo = videoList[selectedIndex];
    final otherVideos = <Map<String, dynamic>>[];

    for (int i = selectedIndex + 1; i < videoList.length; i++) {
      otherVideos.add(videoList[i]);
    }
    for (int i = 0; i < selectedIndex; i++) {
      otherVideos.add(videoList[i]);
    }

    final reorderedVideos = [selectedVideo, ...otherVideos];

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _VideoFeedScreen(videos: reorderedVideos, userId: currentUserUid),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
        ),
      );
    }

    final name = _userData?['name'] ?? 'Usuario';
    final username = _userData?['username'] ?? 'username';
    final photoUrl = _userData?['photo_url'] ?? _userData?['avatar_url'] ?? '';
    final coverUrl =
        _userData?['cover_url'] ?? _userData?['cover_photo_url'] ?? '';
    final totalXp = _userData?['total_xp'] ?? 0;
    final xpInt =
        totalXp is int ? totalXp : int.tryParse(totalXp.toString()) ?? 0;
    final level = _getLevelName(xpInt);
    final position = normalizePlayerPosition(
      _userData?['position'] ?? _userData?['posicion'] ?? '',
    );
    final dominantFoot = normalizeDominantFoot(
      _userData?['dominant_foot'] ?? _userData?['pie_dominante'] ?? '',
    );
    final playerStatus = _userData?['player_status']?.toString().trim() ?? '';
    final location = _profileLocationText();
    final followers =
        _userData?['followers_count'] ?? _userData?['seguidores'] ?? 0;
    final screenSize = MediaQuery.sizeOf(context);
    final isCompactProfile = screenSize.width < 390;
    final tabViewHeight =
        (screenSize.height * 0.52).clamp(380.0, 560.0).toDouble();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // ===== HEADER COM FOTO DE CAPA =====
                    SizedBox(
                      height: 250,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Foto de capa
                          Container(
                            width: double.infinity,
                            height: 192,
                            decoration: BoxDecoration(color: Colors.grey[300]),
                            child: coverUrl.isNotEmpty
                                ? Image.network(
                                    coverUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/images/517529573247018df7fa574b80864b1d3ab2e6ae.jpg',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(color: Colors.grey[400]),
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/517529573247018df7fa574b80864b1d3ab2e6ae.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(color: Colors.grey[400]),
                                  ),
                          ),

                          // Ícones do topo
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 10,
                            left: 15,
                            right: 15,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Configuración
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    debugPrint('🔵 Configuración clicada!');
                                    showProfileSupportSheet(
                                      context: context,
                                      userId: currentUserUid,
                                      screenName: PerfilJugadorWidget.routeName,
                                      onEditProfile: () {
                                        context.pushNamed('editar_perfil');
                                      },
                                    );
                                  },
                                  child: Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9D9D9),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(Icons.settings, size: 24),
                                  ),
                                ),
                                Row(
                                  children: [
                                    // Notificações
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        _showContactRequestsSheet();
                                      },
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 35,
                                            height: 35,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD9D9D9),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                18,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.notifications_rounded,
                                              size: 24,
                                            ),
                                          ),
                                          if (_pendingContactRequests > 0)
                                            Positioned(
                                              right: -3,
                                              top: -3,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFDC2626),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Text(
                                                  _pendingContactRequests > 9
                                                      ? '9+'
                                                      : _pendingContactRequests
                                                          .toString(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Mensagens
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        print(
                                          '🔵 Logout button pressed (Perfil Jugador)',
                                        );
                                        try {
                                          await authManager.signOut();
                                          print('SignOut completed');
                                          if (context.mounted) {
                                            print('Navigating to login');
                                            context.goNamed('login');
                                          }
                                        } catch (e) {
                                          print('Error during logout: $e');
                                        }
                                      },
                                      child: Container(
                                        width: 35,
                                        height: 35,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD9D9D9),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.logout,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Foto de perfil
                          Positioned(
                            top: 140,
                            left: 20,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9D9D9),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: photoUrl.isNotEmpty
                                    ? Image.network(
                                        photoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Image.asset(
                                          'assets/images/codicon_account.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/images/codicon_account.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          // Botão Editar Perfil
                          Positioned(
                            top: 200,
                            right: 15,
                            child: Material(
                              color: const Color(0xFF0D3B66),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  context.pushNamed('editar_perfil');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Editar perfil',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (_isMinorApprovalPending)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cuenta protegida hasta aprobación del responsable',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF9A3412),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Podés completar el perfil y subir videos, pero no se mostrarán en Explorer ni se habilitará el contacto hasta validar el código del adulto responsable.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: const Color(0xFF9A3412),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final codeController =
                                      TextEditingController();
                                  try {
                                    final code = await showDialog<String>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text(
                                          'Validar código del responsable',
                                        ),
                                        content: TextField(
                                          controller: codeController,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          decoration: const InputDecoration(
                                            hintText: 'RESP-123456',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogContext),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              codeController.text,
                                            ),
                                            child: const Text('Validar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (code == null || code.trim().isEmpty) {
                                      return;
                                    }
                                    await _activateMinorAccountWithGuardianCode(
                                      code,
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Cuenta aprobada. El perfil del menor ya quedó activo.',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    await _loadData();
                                  } catch (error) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          error.toString().replaceFirst(
                                                'Exception: ',
                                                '',
                                              ),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } finally {
                                    codeController.dispose();
                                  }
                                },
                                icon: const Icon(Icons.verified_user),
                                label: const Text(
                                  'Validar código del responsable',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ===== NOME E INFO =====
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF444444),
                              fontSize: isCompactProfile ? 22 : 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Username e Stats
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrowStats = constraints.maxWidth < 390;
                              final userInfo = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@$username',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF444444),
                                      fontSize: isCompactProfile ? 13 : 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (followers > 0)
                                    Text(
                                      '${_formatNumber(followers)} seguidores',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF444444),
                                        fontSize: isCompactProfile ? 13 : 14,
                                      ),
                                    ),
                                  if (playerStatus.isNotEmpty)
                                    _buildPlayerStatusChip(playerStatus),
                                ],
                              );

                              final stats = Wrap(
                                spacing: isNarrowStats ? 10 : 14,
                                runSpacing: 8,
                                alignment: isNarrowStats
                                    ? WrapAlignment.start
                                    : WrapAlignment.end,
                                children: [
                                  _buildStatColumn(
                                    level,
                                    'Nivel',
                                    compact: isCompactProfile,
                                  ),
                                  _buildStatColumn(
                                    '#${_userRanking > 0 ? _userRanking : '-'}',
                                    'Ranking',
                                    compact: isCompactProfile,
                                  ),
                                  _buildStatColumn(
                                    xpInt.toString(),
                                    'XP',
                                    compact: isCompactProfile,
                                  ),
                                  _buildStatColumn(
                                    _formatNumber(_profileViewsCount),
                                    'Vistas',
                                    compact: isCompactProfile,
                                  ),
                                ],
                              );

                              if (isNarrowStats) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    userInfo,
                                    const SizedBox(height: 12),
                                    stats,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: userInfo),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: stats,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 25),

                          // Posición
                          Row(
                            children: [
                              const Icon(
                                Icons.shield,
                                color: Color(0xFF444444),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  position,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF444444),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Pie
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_walk,
                                color: Color(0xFF444444),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dominantFoot,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF444444),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Ubicación
                          if (location.toString().isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_pin,
                                  color: Color(0xFF444444),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF444444),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 25),

                          // ===== MEDALLAS Y LOGROS =====
                          Text(
                            'Medallas y Logros',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF444444),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),

                          _buildMedalsRow(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== TAB BAR =====
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: const Color(0xFF0D3B66),
                        unselectedLabelColor: Colors.grey,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        unselectedLabelStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                        indicatorColor: const Color(0xFF0D3B66),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        tabs: const [
                          Tab(text: 'Videos'),
                          Tab(text: 'Ficha completa'),
                          Tab(text: 'Guardados'),
                        ],
                      ),
                    ),

                    // ===== TAB BAR VIEW =====
                    SizedBox(
                      height: tabViewHeight,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildVideosTab(),
                          _buildFichaTab(),
                          _buildGuardadosTab(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            if (userType == 'jugador')
              Align(
                alignment: const AlignmentDirectional(0.0, 1.0),
                child: wrapWithModel(
                  model: _model.navBarJudadorModel,
                  updateCallback: () => safeSetState(() {}),
                  child: const NavBarJudadorWidget(),
                ),
              ),
            if (userType == 'profesional')
              Align(
                alignment: const AlignmentDirectional(0.0, 1.0),
                child: wrapWithModel(
                  model: _model.navBarProfesionalModel,
                  updateCallback: () => safeSetState(() {}),
                  child: const NavBarProfesionalWidget(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final VoidCallback onTap;
  final Widget? badge;
  final Widget? topRightAction;

  const _VideoCard({
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.onTap,
    this.badge,
    this.topRightAction,
  });

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _previewController;
  bool _isPreviewReady = false;

  bool get _hasThumbnail => widget.thumbnailUrl.trim().isNotEmpty;

  String get _displayTitle {
    final rawTitle = widget.title.trim();
    if (rawTitle.isNotEmpty) return rawTitle;

    final uri = Uri.tryParse(widget.videoUrl.trim());
    final fileName = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : widget.videoUrl.trim();
    final sanitized = fileName
        .replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    return sanitized.isNotEmpty ? sanitized : 'Video sin título';
  }

  @override
  void initState() {
    super.initState();
    _preparePreview();
  }

  @override
  void didUpdateWidget(covariant _VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl) {
      _disposePreviewController();
      _preparePreview();
    }
  }

  @override
  void dispose() {
    _disposePreviewController();
    super.dispose();
  }

  Future<void> _preparePreview() async {
    // The profile grid must not download a full video just to paint a preview.
    // Rows without thumbnails render the static video placeholder below.
    return;
  }

  void _disposePreviewController() {
    final controller = _previewController;
    _previewController = null;
    _isPreviewReady = false;
    controller?.dispose();
  }

  Widget _buildVideoPreview() {
    final controller = _previewController;
    if (controller == null ||
        !_isPreviewReady ||
        !controller.value.isInitialized) {
      return Container(
        color: const Color(0xFF1E293B),
        alignment: Alignment.center,
        child: Icon(
          Icons.video_library_rounded,
          color: Colors.white.withOpacity(0.24),
          size: 30,
        ),
      );
    }

    final size = controller.value.size;
    if (size.isEmpty) {
      return Container(color: const Color(0xFF1E293B));
    }

    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  Widget _buildThumbnailLayer() {
    if (_hasThumbnail) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl.trim(),
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildVideoPreview(),
        errorWidget: (_, __, ___) => _buildVideoPreview(),
      );
    }

    return _buildVideoPreview();
  }

  @override
  Widget build(BuildContext context) {
    final title = _displayTitle;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnailLayer(),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.04),
                          Colors.black.withOpacity(0.18),
                          Colors.black.withOpacity(0.52),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.42),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.badge != null)
              Positioned(
                left: 8,
                top: 8,
                child: widget.badge!,
              ),
            if (widget.topRightAction != null)
              Positioned(
                right: 8,
                top: 8,
                child: widget.topRightAction!,
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoFeedScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final String userId;

  const _VideoFeedScreen({required this.videos, required this.userId});

  @override
  State<_VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<_VideoFeedScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length + 1,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              if (index == widget.videos.length) {
                return _buildEndOfVideoFeedContent();
              }

              return _VideoPlayerItem(
                key: ValueKey(widget.videos[index]['id']),
                videoData: widget.videos[index],
                isCurrentVideo: index == _currentIndex,
                userId: widget.userId,
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndOfVideoFeedContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Llegaste al final',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ya viste todos los videos disponibles de este perfil.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeInOut,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.vertical_align_top_rounded, size: 18),
                label: Text(
                  'Volver al inicio',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPlayerItem extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final bool isCurrentVideo;
  final String userId;

  const _VideoPlayerItem({
    super.key,
    required this.videoData,
    required this.isCurrentVideo,
    required this.userId,
  });

  @override
  State<_VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<_VideoPlayerItem>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPaused = false;
  bool _isMuted = false;
  bool _showLikeAnimation = false;
  bool _isLiked = false;
  int _likesCount = 0;

  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  late AnimationController _likeAnimController;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _likesCount = widget.videoData['likes_count'] ?? 0;
    _initVideo();
    _checkIfLiked();
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && _isInitialized) {
      if (widget.isCurrentVideo && !_isPaused) {
        _controller?.play();
      } else if (!widget.isCurrentVideo) {
        _controller?.pause();
      }
    }
  }

  Future<void> _checkIfLiked() async {
    final videoId = widget.videoData['id']?.toString() ?? '';
    if (videoId.isEmpty) return;
    try {
      final snapshot = await fetchVideoLikeSnapshot(
        videoId: videoId,
        userId: widget.userId,
        fallbackCount: _likesCount,
      );
      if (mounted) {
        setState(() {
          _isLiked = snapshot.isLiked;
          _likesCount = snapshot.count;
          widget.videoData['likes_count'] = snapshot.count;
        });
      }
    } catch (e) {
      debugPrint('Error checking if liked: $e');
    }
  }

  Future<void> _toggleLike() async {
    final prev = _isLiked;
    final prevCount = _likesCount;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount =
          _isLiked ? _likesCount + 1 : (_likesCount > 0 ? _likesCount - 1 : 0);
    });

    try {
      if (_isLiked) {
        await SupaFlow.client.from('likes').insert({
          'user_id': widget.userId,
          'video_id': widget.videoData['id'],
        });
      } else {
        await SupaFlow.client
            .from('likes')
            .delete()
            .eq('user_id', widget.userId)
            .eq('video_id', widget.videoData['id']);
      }
      final snapshot = await fetchVideoLikeSnapshot(
        videoId: widget.videoData['id']?.toString() ?? '',
        userId: widget.userId,
        fallbackCount: _likesCount,
      );
      if (mounted) {
        setState(() {
          _isLiked = snapshot.isLiked;
          _likesCount = snapshot.count;
          widget.videoData['likes_count'] = snapshot.count;
        });
      }
      await persistVideoLikeCount(
        videoId: widget.videoData['id']?.toString() ?? '',
        count: snapshot.count,
      );
    } catch (e) {
      if (mounted) {
        try {
          final snapshot = await fetchVideoLikeSnapshot(
            videoId: widget.videoData['id']?.toString() ?? '',
            userId: widget.userId,
            fallbackCount: prevCount,
          );
          setState(() {
            _isLiked = snapshot.isLiked;
            _likesCount = snapshot.count;
            widget.videoData['likes_count'] = snapshot.count;
          });
        } catch (_) {
          setState(() {
            _isLiked = prev;
            _likesCount = prevCount;
          });
        }
      }
    }
  }

  Future<void> _initVideo() async {
    final url = widget.videoData['video_url'] ?? '';
    if (url.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(_isMuted ? 0 : 1);

      if (mounted) {
        setState(() => _isInitialized = true);
        if (widget.isCurrentVideo) _controller!.play();
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onTap(TapUpDetails details) {
    if (_controller == null || !_isInitialized) return;
    final now = DateTime.now();
    final pos = details.globalPosition;

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300 &&
        _lastTapPosition != null &&
        (pos - _lastTapPosition!).distance < 50) {
      _showLikeAnim();
      if (!_isLiked) _toggleLike();
      _lastTapTime = null;
    } else {
      _lastTapTime = now;
      _lastTapPosition = pos;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_lastTapTime == now) _togglePlayPause();
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPaused = true;
      } else {
        _controller!.play();
        _isPaused = false;
      }
    });
  }

  void _showLikeAnim() {
    setState(() => _showLikeAnimation = true);
    _likeAnimController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showLikeAnimation = false);
    });
  }

  String _formatCount(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return c.toString();
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.videoData['title'] ?? '';

    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text('Error al cargar', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTapUp: _onTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 250,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 80,
              bottom: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 120,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Column(
                      children: [
                        Icon(
                          _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          color:
                              _isLiked ? const Color(0xFF0D3B66) : Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCount(_likesCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isPaused)
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
            if (_showLikeAnimation)
              Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0, end: 1.5).animate(
                    CurvedAnimation(
                      parent: _likeAnimController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1, end: 0).animate(
                      CurvedAnimation(
                        parent: _likeAnimController,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: const Icon(
                      Icons.thumb_up,
                      color: Color(0xFF0D3B66),
                      size: 100,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
