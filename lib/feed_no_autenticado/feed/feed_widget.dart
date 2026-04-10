import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/app_modals.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/fluxo_jugador/cursos_ejercicios/cursos_ejercicios_widget.dart';
import '/gamification/gamification_service.dart';
import '/guardian/guardian_mvp_service.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/modal/comments_sheet/comments_sheet_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '/flutter_flow/nav/nav.dart';
import 'feed_model.dart';
export 'feed_model.dart';

class FeedWidget extends StatefulWidget {
  const FeedWidget({super.key});

  static String routeName = 'feed';
  static String routePath = '/feed';

  static bool globalMuted = false;
  static final ValueNotifier<bool> shouldPauseAll = ValueNotifier<bool>(false);
  static String? activeInstanceId;

  @override
  State<FeedWidget> createState() => _FeedWidgetState();
}

class _FeedWidgetState extends State<FeedWidget>
    with WidgetsBindingObserver, RouteAware {
  late FeedModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Video Feed State
  String _selectedTab = 'todos';
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _challengeCards = [];
  bool _isLoading = true;
  bool _isFollowingAnyone = true;
  PageController? _pageController;
  int _currentIndex = 0;
  late String _instanceId;
  bool _isVisible = true;
  bool _isActiveRoute = true;
  bool _isRouteObserverSubscribed = false;
  bool _hasShownLoginModal = false;
  int _videosWatchedWithoutLogin = 0;
  String? _scoutCategoryFilter;
  String? _scoutPositionFilter;
  String? _scoutLocationFilter;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FeedModel());
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _instanceId = DateTime.now().millisecondsSinceEpoch.toString();
    FeedWidget.activeInstanceId = _instanceId;

    // Se o usuário está logado mas o userType está vazio, sincroniza do banco
    _ensureUserType();
    _loadVideos();
  }

  Future<void> _ensureUserType() async {
    // Sempre sincroniza quando o usuário está logado
    // Isso garante que mudanças manuais no Supabase reflitam no app
    await FFAppState().syncUserType();

    final normalizedType = FFAppState.normalizeUserType(FFAppState().userType);
    if (normalizedType != FFAppState().userType) {
      FFAppState().userType = normalizedType;
    }

    // Fallback final
    if (FFAppState().userType.isEmpty) {
      FFAppState().userType = 'jugador';
    }

    debugPrint('🏠 Feed: userType = "${FFAppState().userType}"');
    if (mounted) safeSetState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteObserverSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
      _isRouteObserverSubscribed = true;
    }
  }

  @override
  void dispose() {
    _model.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController?.dispose();
    if (FeedWidget.activeInstanceId == _instanceId) {
      FeedWidget.activeInstanceId = null;
    }
    if (_isRouteObserverSubscribed) {
      routeObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }
    super.dispose();
  }

  @override
  void didPushNext() {
    _pauseAllVideos();
    _isActiveRoute = false;
    if (FeedWidget.activeInstanceId == _instanceId) {
      FeedWidget.activeInstanceId = null;
    }
    if (mounted) safeSetState(() {});
  }

  @override
  void didPopNext() {
    _isActiveRoute = true;
    FeedWidget.activeInstanceId = _instanceId;
    if (mounted) {
      safeSetState(() {});
      _loadVideos();
    }
  }

  @override
  void deactivate() {
    _pauseAllVideos();
    _isActiveRoute = false;
    if (FeedWidget.activeInstanceId == _instanceId) {
      FeedWidget.activeInstanceId = null;
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _isActiveRoute = true;
    if (_isVisible) {
      FeedWidget.activeInstanceId = _instanceId;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pauseAllVideos();
    }
  }

  void _pauseAllVideos() {
    FeedWidget.shouldPauseAll.value = !FeedWidget.shouldPauseAll.value;
  }

  String? get _currentUserId =>
      currentUserUid.isNotEmpty ? currentUserUid : null;
  bool get _isUserLoggedIn => currentUserUid.isNotEmpty;
  String get _normalizedViewerType =>
      FFAppState.normalizeUserType(FFAppState().userType);
  bool get _isScoutViewer => _normalizedViewerType == 'profesional';
  bool get _shouldShowChallengeFeedCards =>
      FFAppState().isFeatureEnabled('desafios') &&
      _selectedTab == 'todos' &&
      _normalizedViewerType != 'profesional' &&
      _normalizedViewerType != 'club' &&
      _normalizedViewerType != 'admin';

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  String? _categoryFromBirthday(dynamic birthday) {
    if (birthday == null) return null;
    try {
      final birth = DateTime.parse(birthday.toString());
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }

      if (age <= 12) return 'U12';
      if (age <= 14) return 'U14';
      if (age <= 16) return 'U16';
      if (age <= 19) return 'U19';
      return 'Senior';
    } catch (_) {
      return null;
    }
  }

  String _normalizeFilterValue(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _videoCategory(Map<String, dynamic> video) {
    final userData = video['user_data'];
    if (userData is! Map) return '';
    return _firstNonEmpty([
          userData['category'],
          userData['categoria'],
          _categoryFromBirthday(
            userData['birthday'] ?? userData['birth_date'],
          ),
        ]) ??
        '';
  }

  String _videoPosition(Map<String, dynamic> video) {
    final userData = video['user_data'];
    if (userData is! Map) return '';
    return _firstNonEmpty([
          userData['position'],
          userData['posicion'],
          userData['posição'],
        ]) ??
        '';
  }

  String _videoLocation(Map<String, dynamic> video) {
    final userData = video['user_data'];
    if (userData is! Map) return '';
    final city = _firstNonEmpty([
          userData['city'],
          userData['ciudad'],
          userData['location'],
          userData['lugar'],
        ]) ??
        '';
    final country = _firstNonEmpty([
          userData['country'],
          userData['pais'],
          userData['country_name'],
        ]) ??
        '';
    return [city, country].where((part) => part.isNotEmpty).join(' · ');
  }

  List<String> _collectVideoFilterOptions(
      String Function(Map<String, dynamic>) resolver) {
    final set = <String>{};
    for (final video in _videos) {
      final value = resolver(video).trim();
      if (value.isNotEmpty) {
        set.add(value);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _scoutCategoryOptions =>
      _collectVideoFilterOptions(_videoCategory);
  List<String> get _scoutPositionOptions =>
      _collectVideoFilterOptions(_videoPosition);
  List<String> get _scoutLocationOptions =>
      _collectVideoFilterOptions(_videoLocation);

  int get _activeScoutFeedFiltersCount => [
        _scoutCategoryFilter,
        _scoutPositionFilter,
        _scoutLocationFilter
      ].where((value) => value != null && value.trim().isNotEmpty).length;

  List<Map<String, dynamic>> get _scoutFilteredVideos {
    return _videos.where((video) {
      if (_scoutCategoryFilter != null && _scoutCategoryFilter!.isNotEmpty) {
        final category = _videoCategory(video);
        if (_normalizeFilterValue(category) !=
            _normalizeFilterValue(_scoutCategoryFilter!)) {
          return false;
        }
      }

      if (_scoutPositionFilter != null && _scoutPositionFilter!.isNotEmpty) {
        final position = _videoPosition(video);
        if (_normalizeFilterValue(position) !=
            _normalizeFilterValue(_scoutPositionFilter!)) {
          return false;
        }
      }

      if (_scoutLocationFilter != null && _scoutLocationFilter!.isNotEmpty) {
        final location = _videoLocation(video);
        if (_normalizeFilterValue(location) !=
            _normalizeFilterValue(_scoutLocationFilter!)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleFeedItems {
    final visibleVideos = _isScoutViewer ? _scoutFilteredVideos : _videos;
    if (!_shouldShowChallengeFeedCards || _challengeCards.isEmpty) {
      return visibleVideos
          .map(
            (video) => {
              'feed_item_type': 'video',
              'payload': video,
            },
          )
          .toList();
    }

    return _mixFeedItems(visibleVideos, _challengeCards);
  }

  List<Map<String, dynamic>> _mixFeedItems(
    List<Map<String, dynamic>> videos,
    List<Map<String, dynamic>> challenges,
  ) {
    final items = <Map<String, dynamic>>[];
    var videoIndex = 0;
    var challengeIndex = 0;

    if (videos.isNotEmpty) {
      items.add({
        'feed_item_type': 'video',
        'payload': videos.first,
      });
      videoIndex = 1;
    }

    while (videoIndex < videos.length || challengeIndex < challenges.length) {
      if (challengeIndex < challenges.length) {
        items.add({
          'feed_item_type': 'challenge',
          'payload': challenges[challengeIndex],
        });
        challengeIndex += 1;
      }

      for (var i = 0; i < 3 && videoIndex < videos.length; i++) {
        items.add({
          'feed_item_type': 'video',
          'payload': videos[videoIndex],
        });
        videoIndex += 1;
      }
    }

    return items;
  }

  Future<List<Map<String, dynamic>>> _loadChallengeFeedCards({
    required String? userId,
  }) async {
    if (!_shouldShowChallengeFeedCards) {
      return <Map<String, dynamic>>[];
    }

    try {
      final results = await Future.wait([
        SupaFlow.client
            .from('courses')
            .select(
              'id, title, description, thumbnail_url, video_url, difficulty, duration_minutes, order_index, created_at, updated_at',
            )
            .eq('is_active', true)
            .order('order_index', ascending: true)
            .limit(6),
        SupaFlow.client
            .from('exercises')
            .select(
              'id, title, description, thumbnail_url, video_url, difficulty, duration_minutes, order_index, created_at, updated_at',
            )
            .eq('is_active', true)
            .order('order_index', ascending: true)
            .limit(6),
      ]);

      final courses = List<Map<String, dynamic>>.from(results[0] as List);
      final exercises = List<Map<String, dynamic>>.from(results[1] as List);

      final courseStatusById = <String, String>{};
      final exerciseStatusById = <String, String>{};
      final attemptStatusByKey = <String, String>{};

      if (userId != null) {
        try {
          final userResults = await Future.wait([
            SupaFlow.client
                .from('user_courses')
                .select('course_id, status')
                .eq('user_id', userId),
            SupaFlow.client
                .from('user_exercises')
                .select('exercise_id, status')
                .eq('user_id', userId),
            SupaFlow.client
                .from('user_challenge_attempts')
                .select('item_id, item_type, status')
                .eq('user_id', userId),
          ]);

          for (final row in (userResults[0] as List)) {
            final itemId = row['course_id']?.toString() ?? '';
            if (itemId.isNotEmpty) {
              courseStatusById[itemId] = row['status']?.toString() ?? '';
            }
          }

          for (final row in (userResults[1] as List)) {
            final itemId = row['exercise_id']?.toString() ?? '';
            if (itemId.isNotEmpty) {
              exerciseStatusById[itemId] = row['status']?.toString() ?? '';
            }
          }

          for (final row in (userResults[2] as List)) {
            final itemId = row['item_id']?.toString() ?? '';
            final itemType = row['item_type']?.toString() ?? '';
            if (itemId.isEmpty || itemType.isEmpty) continue;
            attemptStatusByKey['$itemType:$itemId'] =
                row['status']?.toString() ?? '';
          }
        } catch (e) {
          debugPrint('Feed challenge statuses load failed: $e');
        }
      }

      final combined = <Map<String, dynamic>>[
        ...courses.map((item) => {
              ...item,
              'type': 'course',
            }),
        ...exercises.map((item) => {
              ...item,
              'type': 'exercise',
            }),
      ];

      combined.sort((a, b) {
        final orderCompare = GamificationService.toInt(a['order_index'])
            .compareTo(GamificationService.toInt(b['order_index']));
        if (orderCompare != 0) return orderCompare;
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime(1970);
        return bDate.compareTo(aDate);
      });

      String resolveFeedStatus(Map<String, dynamic> challenge) {
        final itemId = challenge['id']?.toString() ?? '';
        final itemType = challenge['type']?.toString() ?? '';
        if (itemId.isEmpty || itemType.isEmpty) return 'available';

        final baseStatus = (itemType == 'course'
                ? courseStatusById[itemId]
                : exerciseStatusById[itemId])
            ?.trim()
            .toLowerCase();
        final attemptStatus =
            attemptStatusByKey['$itemType:$itemId']?.trim().toLowerCase();

        if (baseStatus == 'completed' || attemptStatus == 'completed') {
          return 'completed';
        }
        if (attemptStatus == 'submitted') return 'submitted';
        if (baseStatus == 'in_progress' || attemptStatus == 'in_progress') {
          return 'in_progress';
        }
        return 'available';
      }

      return combined.take(4).map((challenge) {
        return {
          ...challenge,
          'feed_status': resolveFeedStatus(challenge),
        };
      }).toList();
    } catch (e) {
      debugPrint('Feed challenge cards load failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  void _openChallengeFromFeed(Map<String, dynamic> challenge) {
    if (!FFAppState().canAccessFeature('desafios')) {
      showPlanRequiredDialog(
        context,
        featureName: 'Desafíos y cursos',
        message:
            'Este contenido del feed activa desafíos del Plan Pro. Si el modo piloto está activo, se desbloquea automáticamente.',
      );
      return;
    }

    final challengeId = challenge['id']?.toString().trim() ?? '';
    final challengeType = challenge['type']?.toString().trim() ?? '';

    _pauseAllVideos();
    _isActiveRoute = false;
    FeedWidget.activeInstanceId = null;

    context.pushNamed(
      CursosEjerciciosWidget.routeName,
      queryParameters: {
        if (challengeId.isNotEmpty) 'challengeId': challengeId,
        if (challengeType.isNotEmpty) 'challengeType': challengeType,
      },
    );
  }

  Future<void> _openScoutFeedFilters() async {
    if (!_isScoutViewer) return;

    String? tempCategory = _scoutCategoryFilter;
    String? tempPosition = _scoutPositionFilter;
    String? tempLocation = _scoutLocationFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget buildFilterSection({
          required String title,
          required List<String> options,
          required String? selected,
          required ValueChanged<String?> onChanged,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (options.isEmpty)
                const Text(
                  'No hay datos disponibles para este filtro.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((option) {
                    final isSelected = selected == option;
                    return ChoiceChip(
                      label: Text(option),
                      selected: isSelected,
                      onSelected: (_) => onChanged(isSelected ? null : option),
                      selectedColor: const Color(0xFF0D3B66),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFF0F172A),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF0D3B66)
                            : const Color(0xFFCBD5E1),
                      ),
                      backgroundColor: Colors.white,
                    );
                  }).toList(),
                ),
            ],
          );
        }

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(ctx).padding.bottom + 16,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Filtrar feed de scouts',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    buildFilterSection(
                      title: 'Categoría',
                      options: _scoutCategoryOptions,
                      selected: tempCategory,
                      onChanged: (value) =>
                          setModalState(() => tempCategory = value),
                    ),
                    const SizedBox(height: 12),
                    buildFilterSection(
                      title: 'Posición',
                      options: _scoutPositionOptions,
                      selected: tempPosition,
                      onChanged: (value) =>
                          setModalState(() => tempPosition = value),
                    ),
                    const SizedBox(height: 12),
                    buildFilterSection(
                      title: 'Ubicación',
                      options: _scoutLocationOptions,
                      selected: tempLocation,
                      onChanged: (value) =>
                          setModalState(() => tempLocation = value),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _scoutCategoryFilter = null;
                                _scoutPositionFilter = null;
                                _scoutLocationFilter = null;
                                _currentIndex = 0;
                              });
                              if (_pageController?.hasClients ?? false) {
                                _pageController?.jumpToPage(0);
                              }
                              Navigator.pop(ctx);
                            },
                            child: const Text('Limpiar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _pauseAllVideos();
                              setState(() {
                                _scoutCategoryFilter = tempCategory;
                                _scoutPositionFilter = tempPosition;
                                _scoutLocationFilter = tempLocation;
                                _currentIndex = 0;
                              });
                              if (_pageController?.hasClients ?? false) {
                                _pageController?.jumpToPage(0);
                              }
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D3B66),
                            ),
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateProfileModal() {
    if (_hasShownLoginModal) return;
    _hasShownLoginModal = true;
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 331,
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Crea tu perfil para conectar',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D3B66))),
                  const SizedBox(height: 20),
                  const Text(
                      'Únete a FutbolTalent.Pro para mostrar tus habilidades y conectar con ojeadores y clubes',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () {
                      _pauseAllVideos();
                      _isActiveRoute = false;
                      FeedWidget.activeInstanceId = null;
                      Navigator.pop(dialogContext);
                      context.goNamed('login');
                    },
                    child: Container(
                        width: 261,
                        height: 40,
                        decoration: BoxDecoration(
                            color: const Color(0xFF0D3B66),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Center(
                            child: Text('Iniciar sesión',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)))),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('¿No tienes cuenta? ',
                        style: TextStyle(fontSize: 14)),
                    GestureDetector(
                        onTap: () {
                          _pauseAllVideos();
                          _isActiveRoute = false;
                          FeedWidget.activeInstanceId = null;
                          Navigator.pop(dialogContext);
                          context.goNamed('seleccionDelTipoDePerfil');
                        },
                        child: const Text('Registrarse',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D3B66),
                                decoration: TextDecoration.underline)))
                  ]),
                  const SizedBox(height: 30),
                  GestureDetector(
                      onTap: () {
                        Navigator.pop(dialogContext);
                        _videosWatchedWithoutLogin = 0;
                        _hasShownLoginModal = false;
                      },
                      child: const Text('Seguir viendo',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline))),
                ]),
              ),
            ));
  }

  void _checkLoginModal() {
    if (!_isUserLoggedIn) {
      _videosWatchedWithoutLogin++;
      if (_videosWatchedWithoutLogin >= 2 && !_hasShownLoginModal) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showCreateProfileModal();
        });
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visiblePercentage = info.visibleFraction * 100;
    final wasVisible = _isVisible;
    _isVisible = visiblePercentage > 50;

    if (_isVisible && !wasVisible) {
      if (FeedWidget.activeInstanceId != null &&
          FeedWidget.activeInstanceId != _instanceId) {
        _pauseAllVideos();
      }
      FeedWidget.activeInstanceId = _instanceId;
      if (_videos.isEmpty && _isActiveRoute) _loadVideos();
    } else if (!_isVisible && wasVisible) {
      _pauseAllVideos();
      if (FeedWidget.activeInstanceId == _instanceId) {
        FeedWidget.activeInstanceId = null;
      }
    }
  }

  Future<void> _loadVideos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = _currentUserId;
      List<dynamic> response;

      if (_selectedTab == 'todos') {
        response = await SupaFlow.client
            .from('videos')
            .select()
            .eq('is_public', true)
            .order('created_at', ascending: false);
        _isFollowingAnyone = true;
      } else {
        if (userId == null) {
          response = [];
          _isFollowingAnyone = false;
        } else {
          final followsResponse = await SupaFlow.client
              .from('followers')
              .select('following_id')
              .eq('follower_id', userId);
          final followingIds = (followsResponse as List)
              .map((f) => f['following_id'] as String)
              .where((id) => id.isNotEmpty)
              .toList();
          _isFollowingAnyone = followingIds.isNotEmpty;

          if (followingIds.isEmpty) {
            response = [];
          } else {
            response = await SupaFlow.client
                .from('videos')
                .select()
                .inFilter('user_id', followingIds)
                .eq('is_public', true)
                .order('created_at', ascending: false);
          }
        }
      }

      final videos = List<Map<String, dynamic>>.from(response);
      for (var video in videos) {
        final videoUserId = video['user_id']?.toString().trim() ?? '';
        final videoId = video['id']?.toString() ?? '';

        if (videoUserId.isNotEmpty) {
          try {
            final userResponse = await SupaFlow.client
                .from('users')
                .select()
                .eq('user_id', videoUserId)
                .maybeSingle();
            if (userResponse != null) video['user_data'] = userResponse;
          } catch (e) {}

          try {
            if (userId != null && videoUserId != userId) {
              final followCheck = await SupaFlow.client
                  .from('followers')
                  .select('id')
                  .eq('follower_id', userId)
                  .eq('following_id', videoUserId)
                  .maybeSingle();
              video['is_following'] = followCheck != null;
            } else {
              video['is_following'] = false;
            }
          } catch (e) {
            video['is_following'] = false;
          }

          try {
            if (userId != null && videoId.isNotEmpty) {
              final savedCheck = await SupaFlow.client
                  .from('saved_videos')
                  .select('id')
                  .eq('user_id', userId)
                  .eq('video_id', videoId)
                  .maybeSingle();
              video['is_saved'] = savedCheck != null;
            } else {
              video['is_saved'] = false;
            }
          } catch (e) {
            video['is_saved'] = false;
          }
        } else {
          video['is_following'] = false;
          video['is_saved'] = false;
          video['user_data'] = null;
        }

        try {
          if (videoId.isNotEmpty) {
            try {
              final commentsResponse = await SupaFlow.client
                  .from('comments')
                  .select('id')
                  .eq('video_id', videoId)
                  .isFilter('deleted_at', null)
                  .eq('moderation_status', GuardianMvpService.approvedStatus);
              video['comments_count'] = (commentsResponse as List).length;
            } catch (_) {
              final commentsResponse = await SupaFlow.client
                  .from('comments')
                  .select('id')
                  .eq('video_id', videoId);
              video['comments_count'] = (commentsResponse as List).length;
            }
          } else {
            video['comments_count'] = 0;
          }
        } catch (e) {
          video['comments_count'] = 0;
        }
      }

      final visibleVideos = videos.where((video) {
        final ownerData = video['user_data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(video['user_data'] as Map)
            : null;
        return GuardianMvpService.isVideoVisibleToPublic(
          video,
          ownerData: ownerData,
        );
      }).toList();

      final visibleUserIds = visibleVideos
          .map((video) => video['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final progressByUserId = <String, Map<String, dynamic>>{};
      if (visibleUserIds.isNotEmpty) {
        try {
          final progressRows = await SupaFlow.client
              .from('user_progress')
              .select(
                  'user_id, total_xp, current_level_id, courses_completed, exercises_completed')
              .inFilter('user_id', visibleUserIds);
          for (final row in (progressRows as List)) {
            final map = Map<String, dynamic>.from(row as Map);
            final uid = map['user_id']?.toString() ?? '';
            if (uid.isNotEmpty) {
              progressByUserId[uid] = map;
            }
          }
        } catch (e) {
          debugPrint('Feed progress load failed: $e');
        }
      }

      for (final video in visibleVideos) {
        final uid = video['user_id']?.toString() ?? '';
        video['user_progress'] = progressByUserId[uid];
      }

      final challengeFeedCards = await _loadChallengeFeedCards(userId: userId);

      if (mounted) {
        setState(() {
          _videos = visibleVideos;
          _challengeCards = challengeFeedCards;
          _isLoading = false;
          _currentIndex = 0;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController?.hasClients ?? false) {
            _pageController?.jumpToPage(0);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videos = [];
          _challengeCards = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onTabChanged(String tab) {
    if (_selectedTab != tab) {
      _pauseAllVideos();
      setState(() {
        _selectedTab = tab;
        _isLoading = true;
        _currentIndex = 0;
      });
      _loadVideos();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    final feedItems = _visibleFeedItems;
    if (index >= 0 &&
        index < feedItems.length &&
        feedItems[index]['feed_item_type'] == 'video') {
      _checkLoginModal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    final feedEnabled = FFAppState().isFeatureEnabled('feed');

    final size = MediaQuery.of(context).size;
    final feedHeight = size.height;

    if (!feedEnabled) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              FFAppState().uiText(
                'feed_empty_label',
                fallback: 'No hay videos disponibles por ahora.',
              ),
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).titleMedium,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            VisibilityDetector(
              key: Key('video-feed-$_instanceId'),
              onVisibilityChanged: _onVisibilityChanged,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black,
                child: Stack(children: [
                  _buildContent(feedHeight),
                  // Top Tabs
                  SafeArea(
                      child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildTab('Todos', 'todos'),
                              const SizedBox(width: 24),
                              _buildTab('Siguiendo', 'siguiendo'),
                            ],
                          ),
                          if (_isScoutViewer)
                            Positioned(
                              right: 0,
                              child: _buildScoutFeedFilterButton(),
                            ),
                        ],
                      ),
                    ),
                  )),
                ]),
              ),
            ),
            // Nav Bar
            if (userType == 'jugador')
              Align(
                  alignment: const AlignmentDirectional(0, 1),
                  child: wrapWithModel(
                      model: _model.navBarJudadorModel,
                      updateCallback: () => safeSetState(() {}),
                      child: const NavBarJudadorWidget())),
            if (userType == 'profesional')
              Align(
                  alignment: const AlignmentDirectional(0, 1),
                  child: wrapWithModel(
                      model: _model.navBarProfesionalModel,
                      updateCallback: () => safeSetState(() {}),
                      child: const NavBarProfesionalWidget())),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String id) {
    final isSelected = _selectedTab == id;
    return GestureDetector(
      onTap: () => _onTabChanged(id),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal)),
            const SizedBox(height: 4),
            Container(
                width: 24,
                height: 2,
                decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(1))),
          ])),
    );
  }

  Widget _buildScoutFeedFilterButton() {
    return GestureDetector(
      onTap: _openScoutFeedFilters,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.34),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.32)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            if (_activeScoutFeedFiltersCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D3B66),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '$_activeScoutFeedFiltersCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(double feedHeight) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_selectedTab == 'siguiendo' && !_isFollowingAnyone) {
      return _buildNoFollowingContent();
    }
    final visibleVideos = _isScoutViewer ? _scoutFilteredVideos : _videos;
    final feedItems = _visibleFeedItems;
    if (feedItems.isEmpty) {
      if (_isScoutViewer &&
          _activeScoutFeedFiltersCount > 0 &&
          visibleVideos.isEmpty) {
        return _buildNoFilteredVideosContent();
      }
      return _buildNoVideosContent();
    }

    if (_currentIndex >= feedItems.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentIndex = 0);
        if (_pageController?.hasClients ?? false) {
          _pageController?.jumpToPage(0);
        }
      });
    }

    return PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: feedItems.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final feedItem = feedItems[index];
          final payload = feedItem['payload'];
          final itemData = payload is Map
              ? Map<String, dynamic>.from(payload)
              : <String, dynamic>{};
          final currentUserType = FFAppState().userType;
          final hasBottomNav =
              currentUserType == 'jugador' || currentUserType == 'profesional';
          if (feedItem['feed_item_type'] == 'challenge') {
            return _ChallengeFeedItem(
              key: ValueKey(
                'challenge-${itemData['type']}-${itemData['id']}-$_selectedTab-$_instanceId',
              ),
              challengeData: itemData,
              isLoggedIn: _isUserLoggedIn,
              hasAccess: FFAppState().canAccessFeature('desafios'),
              onRequireLogin: _showCreateProfileModal,
              onOpenChallenge: () => _openChallengeFromFeed(itemData),
              onLockedTap: () => showPlanRequiredDialog(
                context,
                featureName: 'Desafíos y cursos',
                message:
                    'Los desafíos del feed forman parte del Plan Pro. Si el modo piloto está activo, el bloqueo desaparece.',
              ),
              topOverlayOffset: 58,
              bottomOverlayOffset: hasBottomNav ? 108 : 24,
            );
          }

          final video = itemData;
          return _VideoPlayerItem(
            key: ValueKey('${video['id']}-$_selectedTab-$_instanceId'),
            videoUrl: video['video_url'] ?? '',
            videoData: video,
            isCurrentVideo: index == _currentIndex,
            isParentVisible: _isVisible && _isActiveRoute,
            parentInstanceId: _instanceId,
            currentUserId: _currentUserId,
            onRefresh: _loadVideos,
            onRequireLogin: _showCreateProfileModal,
            onFollowChanged: (uid, val) => setState(() {
              for (var v in _videos) {
                if (v['user_id'] == uid) v['is_following'] = val;
              }
            }),
            onSaveChanged: (vid, val) => setState(() {
              for (var v in _videos) {
                if (v['id'] == vid) v['is_saved'] = val;
              }
            }),
          );
        });
  }

  Widget _buildNoFollowingContent() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.person_add_outlined, color: Colors.white, size: 50),
      const SizedBox(height: 24),
      const Text('Sigue a cuentas para ver\nsus videos aquí',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 32),
      ElevatedButton(
          onPressed: () => _onTabChanged('todos'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D3B66)),
          child: const Text('Descubrir personas')),
    ]));
  }

  Widget _buildNoFilteredVideosContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_alt_off, color: Colors.white54, size: 58),
            const SizedBox(height: 18),
            const Text(
              'No hay videos con estos filtros',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Probá cambiar categoría, posición o ubicación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _scoutCategoryFilter = null;
                  _scoutPositionFilter = null;
                  _scoutLocationFilter = null;
                  _currentIndex = 0;
                });
                if (_pageController?.hasClients ?? false) {
                  _pageController?.jumpToPage(0);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66),
              ),
              child: const Text('Limpiar filtros'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVideosContent() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.video_library_outlined, color: Colors.white38, size: 64),
      const SizedBox(height: 24),
      const Text('No hay videos',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      ElevatedButton(
          onPressed: _loadVideos,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D3B66)),
          child: const Text('Actualizar')),
    ]));
  }
}

class _ChallengeFeedItem extends StatelessWidget {
  const _ChallengeFeedItem({
    super.key,
    required this.challengeData,
    required this.isLoggedIn,
    required this.hasAccess,
    required this.onRequireLogin,
    required this.onOpenChallenge,
    required this.onLockedTap,
    required this.topOverlayOffset,
    required this.bottomOverlayOffset,
  });

  final Map<String, dynamic> challengeData;
  final bool isLoggedIn;
  final bool hasAccess;
  final VoidCallback onRequireLogin;
  final VoidCallback onOpenChallenge;
  final VoidCallback onLockedTap;
  final double topOverlayOffset;
  final double bottomOverlayOffset;

  String get _status {
    return (challengeData['feed_status'] ?? 'available')
        .toString()
        .trim()
        .toLowerCase();
  }

  String get _title {
    final title = challengeData['title']?.toString().trim() ?? '';
    return title.isNotEmpty ? title : 'Desafío disponible';
  }

  String get _description {
    return challengeData['description']?.toString().trim() ?? '';
  }

  String get _typeLabel {
    return challengeData['type'] == 'course' ? 'Curso' : 'Ejercicio';
  }

  String get _statusLabel {
    switch (_status) {
      case 'completed':
        return 'Completado';
      case 'submitted':
        return 'Video enviado';
      case 'in_progress':
        return 'En curso';
      default:
        return 'Nuevo';
    }
  }

  Color get _statusColor {
    switch (_status) {
      case 'completed':
        return const Color(0xFF15803D);
      case 'submitted':
        return const Color(0xFFD97706);
      case 'in_progress':
        return const Color(0xFF0D3B66);
      default:
        return Colors.white.withOpacity(0.18);
    }
  }

  String get _headline {
    final reward = GamificationService.challengeCompletedPoints;
    if (!hasAccess) {
      return 'Este desafío aparece en el feed, pero se habilita completo con el Plan Pro.';
    }
    switch (_status) {
      case 'completed':
        return 'Desafío completado. Tus $reward puntos ya cuentan en tu progreso.';
      case 'submitted':
        return 'Tu intento ya fue enviado. Abrí el desafío para revisar los próximos pasos.';
      case 'in_progress':
        return 'Ya lo empezaste. Solo te falta avanzar para sumar los $reward puntos.';
      default:
        return 'Comenzá $_title y sumá $reward XP al completarlo.';
    }
  }

  String get _primaryActionLabel {
    if (!isLoggedIn) return 'Crear perfil para activar';
    if (!hasAccess) return 'Desbloquear en Pro';
    switch (_status) {
      case 'completed':
        return 'Ver desafío';
      case 'submitted':
        return 'Ver envío';
      case 'in_progress':
        return 'Continuar';
      default:
        return 'Comenzar desafío';
    }
  }

  IconData get _primaryActionIcon {
    if (!isLoggedIn) return Icons.login_rounded;
    if (!hasAccess) return Icons.workspace_premium_outlined;
    switch (_status) {
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'submitted':
        return Icons.ondemand_video_outlined;
      case 'in_progress':
        return Icons.play_arrow_rounded;
      default:
        return Icons.track_changes_rounded;
    }
  }

  void _handleTap() {
    if (!isLoggedIn) {
      onRequireLogin();
      return;
    }
    if (!hasAccess) {
      onLockedTap();
      return;
    }
    onOpenChallenge();
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color backgroundColor = const Color(0x1FFFFFFF),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _cacheBustedImageUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) return '';
    final version = (challengeData['updated_at'] ??
            challengeData['created_at'] ??
            challengeData['id'])
        ?.toString()
        .trim();
    if (version == null || version.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=${Uri.encodeComponent(version)}';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _cacheBustedImageUrl(
      challengeData['thumbnail_url']?.toString().trim() ?? '',
    );
    final difficulty = challengeData['difficulty']?.toString().trim() ?? '';
    final durationMinutes =
        GamificationService.toInt(challengeData['duration_minutes']);
    final participationReward = GamificationService.challengeParticipatedPoints;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        color: const Color(0xFF050816),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF071126),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF102542),
                      Color(0xFF06111F),
                      Color(0xFF1C3D5A),
                    ],
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.20),
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.86),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18 + topOverlayOffset,
                  18,
                  28 + bottomOverlayOffset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C2D12).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Desafío en el feed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _buildInfoChip(
                          icon: Icons.bolt_rounded,
                          label: _statusLabel,
                          backgroundColor: _statusColor,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          icon: challengeData['type'] == 'course'
                              ? Icons.school_outlined
                              : Icons.fitness_center_outlined,
                          label: _typeLabel,
                        ),
                        _buildInfoChip(
                          icon: Icons.stars_rounded,
                          label:
                              '+${GamificationService.challengeCompletedPoints} XP',
                        ),
                        _buildInfoChip(
                          icon: Icons.videocam_rounded,
                          label: '+$participationReward XP por video',
                        ),
                        if (difficulty.isNotEmpty)
                          _buildInfoChip(
                            icon: Icons.tune_rounded,
                            label: difficulty,
                          ),
                        if (durationMinutes > 0)
                          _buildInfoChip(
                            icon: Icons.schedule_rounded,
                            label: '$durationMinutes min',
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _headline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (_description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.80),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF071126),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 6,
                          shadowColor: const Color(0x33071126),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: Icon(_primaryActionIcon),
                        label: Text(
                          _primaryActionLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
  }
}

class _VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final Map<String, dynamic> videoData;
  final bool isCurrentVideo;
  final bool isParentVisible;
  final String parentInstanceId;
  final String? currentUserId;
  final VoidCallback onRefresh;
  final VoidCallback onRequireLogin;
  final Function(String, bool) onFollowChanged;
  final Function(String, bool) onSaveChanged;

  const _VideoPlayerItem(
      {super.key,
      required this.videoUrl,
      required this.videoData,
      required this.isCurrentVideo,
      required this.isParentVisible,
      required this.parentInstanceId,
      required this.currentUserId,
      required this.onRefresh,
      required this.onRequireLogin,
      required this.onFollowChanged,
      required this.onSaveChanged});

  @override
  State<_VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<_VideoPlayerItem>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  VoidCallback? _controllerListener;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = ''; // Debug logging
  bool _isLoading = true;
  bool _isPaused = false; // Intenção do usuário
  bool _isPausedBySystem = false; // Gestão automática (navegação/lifecycle)
  final bool _isPausedByHold = false;
  final bool _wasPlayingBeforeHold = false;
  bool _showLikeAnimation = false;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isSaved = false;
  bool _isSaveLoading = false;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  late AnimationController _likeAnimController;

  bool get _isOwnVideo {
    final owner = widget.videoData['user_id']?.toString().trim() ?? '';
    final current = widget.currentUserId?.trim() ?? '';
    return current.isNotEmpty && owner.isNotEmpty && owner == current;
  }

  bool get _canSeeAuthorMetadata {
    if ((widget.currentUserId?.trim().isEmpty ?? true)) return false;
    final viewerType = FFAppState.normalizeUserType(FFAppState().userType);
    return viewerType == 'jugador' || viewerType == 'profesional';
  }

  bool get _isChallengeVideo => _videoKindLabel() == 'Desafío';

  bool get _isPlayerAuthor {
    final rawUserData = widget.videoData['user_data'];
    if (rawUserData is! Map) return false;
    final userData = Map<String, dynamic>.from(rawUserData);
    final authorType = FFAppState.normalizeUserType(
      userData['userType'] ?? userData['usertype'] ?? userData['user_type'],
    );
    return authorType == 'jugador';
  }

  String _videoKindLabel() {
    final persistedType = (widget.videoData['videoType'] ??
            widget.videoData['video_type'] ??
            widget.videoData['type'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (persistedType == 'challenge') return 'Desafío';
    if (persistedType == 'ugc') return 'UGC';

    final description = widget.videoData['description']?.toString() ?? '';
    final title =
        widget.videoData['title']?.toString().trim().toLowerCase() ?? '';
    final hasChallengeTag =
        RegExp(r'\[challenge_ref:(course|exercise):([^\]]+)\]')
            .hasMatch(description);
    final looksChallengeTitle = title.startsWith('desafío:') ||
        title.startsWith('desafio:') ||
        title.startsWith('challenge:');
    return (hasChallengeTag || looksChallengeTitle) ? 'Desafío' : 'UGC';
  }

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return null;
  }

  String? _categoryFromBirthday(dynamic birthday) {
    if (birthday == null) return null;
    try {
      final birth = DateTime.parse(birthday.toString());
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      if (age <= 12) return 'U12';
      if (age <= 14) return 'U14';
      if (age <= 16) return 'U16';
      if (age <= 19) return 'U19';
      return 'Senior';
    } catch (_) {
      return null;
    }
  }

  String? _birthYearFromRaw(dynamic rawDate) {
    if (rawDate == null) return null;
    try {
      return DateTime.parse(rawDate.toString()).year.toString();
    } catch (_) {
      return null;
    }
  }

  Widget _buildScoutOverlayChip({
    required IconData icon,
    required String label,
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeFeedBadge() {
    if (!_isChallengeVideo) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF7C2D12).withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.track_changes,
            size: 13,
            color: Colors.white,
          ),
          SizedBox(width: 6),
          Text(
            'Desafío',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeTypeLabel() {
    return const SizedBox.shrink();
  }

  Widget _buildAuthorMetadataOverlay(dynamic rawUserData) {
    if (!_canSeeAuthorMetadata || !_isPlayerAuthor) {
      return const SizedBox.shrink();
    }

    final userData = rawUserData is Map
        ? Map<String, dynamic>.from(rawUserData)
        : <String, dynamic>{};

    final category = _firstNonEmpty([
          userData['category'],
          userData['categoria'],
          _birthYearFromRaw(
            userData['birthday'] ??
                userData['birth_date'] ??
                userData['fecha_nacimiento'] ??
                userData['data_nascimento'],
          ),
          _categoryFromBirthday(
            userData['birthday'] ??
                userData['birth_date'] ??
                userData['fecha_nacimiento'] ??
                userData['data_nascimento'],
          ),
        ]) ??
        '';

    final position = _firstNonEmpty([
          userData['position'],
          userData['posicion'],
          userData['posição'],
          userData['position_name'],
        ]) ??
        '';

    final country = _firstNonEmpty([
          userData['country'],
          userData['pais'],
          userData['país'],
          userData['country_name'],
          userData['nationality'],
          userData['nacionalidad'],
        ]) ??
        '';

    final club = _firstNonEmpty([
          userData['club'],
          userData['club_actual'],
          userData['current_club'],
          userData['club_name'],
          userData['team'],
          userData['team_name'],
        ]) ??
        '';

    final chips = <Widget>[
      if (category.isNotEmpty)
        _buildScoutOverlayChip(icon: Icons.category_outlined, label: category),
      if (position.isNotEmpty)
        _buildScoutOverlayChip(
          icon: Icons.shield_outlined,
          label: position,
        ),
      if (country.isNotEmpty)
        _buildScoutOverlayChip(
          icon: Icons.flag_outlined,
          label: country,
        ),
      if (club.isNotEmpty)
        _buildScoutOverlayChip(
          icon: Icons.groups_outlined,
          label: club,
        ),
    ].take(3).toList();

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips,
      ),
    );
  }

  bool _isRouteCurrent() => ModalRoute.of(context)?.isCurrent ?? false;

  bool _canAutoPlay() {
    final isActiveInstance = FeedWidget.activeInstanceId == null ||
        FeedWidget.activeInstanceId == widget.parentInstanceId;
    return widget.isCurrentVideo &&
        widget.isParentVisible &&
        !_isPaused &&
        _isRouteCurrent() &&
        isActiveInstance;
  }

  bool _canManuallyPlay() {
    final isActiveInstance = FeedWidget.activeInstanceId == null ||
        FeedWidget.activeInstanceId == widget.parentInstanceId;
    return widget.isCurrentVideo &&
        widget.isParentVisible &&
        _isRouteCurrent() &&
        isActiveInstance;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FeedWidget.shouldPauseAll.addListener(_onShouldPauseAll);
    _likeAnimController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _likesCount = widget.videoData['likes_count'] ?? 0;
    _commentsCount = widget.videoData['comments_count'] ?? 0;
    _isFollowing = widget.videoData['is_following'] ?? false;
    _isSaved = widget.videoData['is_saved'] ?? false;
    _initializeVideo();
    _checkIfLiked();
  }

  void _onShouldPauseAll() {
    if (_controller != null) {
      try {
        _controller!.pause();
        _controller!.setVolume(0.0);
      } catch (_) {}
    }
    if (mounted && !_isPausedBySystem) {
      setState(() => _isPausedBySystem = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _controller?.pause();
      _controller?.setVolume(0.0);
      if (mounted) setState(() => _isPausedBySystem = true);
    }
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_isInitialized) return;
    if (widget.videoData['is_following'] !=
        oldWidget.videoData['is_following']) {
      setState(() => _isFollowing = widget.videoData['is_following'] ?? false);
    }
    if (widget.videoData['is_saved'] != oldWidget.videoData['is_saved']) {
      setState(() => _isSaved = widget.videoData['is_saved'] ?? false);
    }

    if (!_canAutoPlay()) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      }
      _controller!.setVolume(0.0);
      if (mounted && !_isPausedBySystem) {
        setState(() => _isPausedBySystem = true);
      }
      return;
    }

    if (_isPausedBySystem || !_controller!.value.isPlaying) {
      _controller!.play();
      _controller!.setVolume(FeedWidget.globalMuted ? 0.0 : 1.0);
      if (mounted && _isPausedBySystem) {
        setState(() => _isPausedBySystem = false);
      }
    }
  }

  Future<void> _checkIfLiked() async {
    final uid = widget.currentUserId;
    if (uid == null) return;
    try {
      final res = await SupaFlow.client
          .from('likes')
          .select('id')
          .eq('video_id', widget.videoData['id'])
          .eq('user_id', uid)
          .maybeSingle();
      if (mounted) setState(() => _isLiked = res != null);
    } catch (e) {}
  }

  Future<void> _toggleLike() async {
    final uid = widget.currentUserId;
    if (uid == null) {
      widget.onRequireLogin();
      return;
    }
    final vid = widget.videoData['id']?.toString() ?? '';
    if (vid.isEmpty) return;
    final prevLiked = _isLiked;
    final prevCount = _likesCount;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount =
          _isLiked ? _likesCount + 1 : (_likesCount > 0 ? _likesCount - 1 : 0);
    });

    try {
      if (_isLiked) {
        await SupaFlow.client
            .from('likes')
            .insert({'user_id': uid, 'video_id': vid});
      } else {
        await SupaFlow.client
            .from('likes')
            .delete()
            .eq('user_id', uid)
            .eq('video_id', vid);
      }
      await SupaFlow.client
          .from('videos')
          .update({'likes_count': _likesCount}).eq('id', vid);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = prevLiked;
          _likesCount = prevCount;
        });
      }
    }
  }

  Future<void> _toggleSave() async {
    final uid = widget.currentUserId;
    if (uid == null) {
      widget.onRequireLogin();
      return;
    }
    final vid = widget.videoData['id']?.toString() ?? '';
    setState(() => _isSaveLoading = true);
    try {
      if (_isSaved) {
        await SupaFlow.client
            .from('saved_videos')
            .delete()
            .eq('user_id', uid)
            .eq('video_id', vid);
      } else {
        await SupaFlow.client
            .from('saved_videos')
            .insert({'user_id': uid, 'video_id': vid});
      }
      setState(() => _isSaved = !_isSaved);
      widget.onSaveChanged(vid, _isSaved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isSaved
                ? 'Video guardado en Guardados'
                : 'Video removido de Guardados'),
            duration: const Duration(seconds: 1)));
      }
    } catch (e) {}
    setState(() => _isSaveLoading = false);
  }

  Future<void> _toggleFollow() async {
    final uid = widget.currentUserId;
    if (uid == null) {
      widget.onRequireLogin();
      return;
    }
    final ownerId = widget.videoData['user_id']?.toString() ?? '';
    if (ownerId.isEmpty || _isOwnVideo) return;
    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        await SupaFlow.client
            .from('followers')
            .delete()
            .eq('follower_id', uid)
            .eq('following_id', ownerId);
        await _updateFollowCounts(ownerId, -1);
      } else {
        await SupaFlow.client
            .from('followers')
            .insert({'follower_id': uid, 'following_id': ownerId});
        await _updateFollowCounts(ownerId, 1);
      }
      setState(() => _isFollowing = !_isFollowing);
      widget.onFollowChanged(ownerId, _isFollowing);
    } catch (e) {}
    setState(() => _isFollowLoading = false);
  }

  Future<void> _updateFollowCounts(String targetId, int delta) async {
    try {
      final tUser = await SupaFlow.client
          .from('users')
          .select('followers_count')
          .eq('user_id', targetId)
          .maybeSingle();
      if (tUser != null) {
        await SupaFlow.client.from('users').update({
          'followers_count': (tUser['followers_count'] ?? 0) + delta
        }).eq('user_id', targetId);
      }
      final cUser = await SupaFlow.client
          .from('users')
          .select('following_count')
          .eq('user_id', widget.currentUserId!)
          .maybeSingle();
      if (cUser != null) {
        await SupaFlow.client.from('users').update({
          'following_count': (cUser['following_count'] ?? 0) + delta
        }).eq('user_id', widget.currentUserId!);
      }
    } catch (e) {}
  }

  Future<void> _initializeVideo() async {
    if (widget.videoUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }
    try {
      if (!widget.videoUrl.startsWith('http')) {
        throw Exception('URL inválida: ${widget.videoUrl}');
      }

      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      _controller!.setLooping(true);
      _controller!.setVolume(FeedWidget.globalMuted ? 0.0 : 1.0);
      _controllerListener = () {
        final controller = _controller;
        if (controller == null || !_isInitialized) return;
        final value = controller.value;
        if (!value.isInitialized || value.duration <= Duration.zero) return;
        final reachedEnd = value.position >=
            value.duration - const Duration(milliseconds: 150);
        if (reachedEnd &&
            !_isPaused &&
            !_isPausedBySystem &&
            !value.isPlaying &&
            _canAutoPlay()) {
          controller.seekTo(Duration.zero);
          controller.play();
        }
      };
      _controller!.addListener(_controllerListener!);
      final canAutoPlay = _canAutoPlay();
      setState(() {
        _isInitialized = true;
        _hasError = false;
        _isLoading = false;
        _isPausedBySystem = !canAutoPlay;
      });
      if (canAutoPlay) {
        _controller!.play();
      } else {
        _controller!.pause();
        _controller!.setVolume(0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
        print('Error initializes video: $e');
      }
    }
  }

  void _onTap(TapUpDetails details) {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300) {
      _showLikeAnim();
      if (!_isLiked) _toggleLike();
      _lastTapTime = null;
    } else {
      _lastTapTime = now;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_lastTapTime == now) _togglePlayPause();
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _controller!.setVolume(0.0);
        _isPaused = true;
        _isPausedBySystem = false;
      } else {
        if (!_canManuallyPlay()) {
          _controller!.pause();
          _controller!.setVolume(0.0);
          _isPausedBySystem = true;
          return;
        }
        final duration = _controller!.value.duration;
        final position = _controller!.value.position;
        if (duration > Duration.zero &&
            position >= duration - const Duration(milliseconds: 200)) {
          _controller!.seekTo(Duration.zero);
        }
        _controller!.play();
        _isPaused = false;
        _isPausedBySystem = false;
        _controller!.setVolume(FeedWidget.globalMuted ? 0.0 : 1.0);
      }
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      FeedWidget.globalMuted = !FeedWidget.globalMuted;
      _controller!.setVolume(FeedWidget.globalMuted ? 0.0 : 1.0);
    });
  }

  void _showLikeAnim() {
    setState(() => _showLikeAnimation = true);
    _likeAnimController.forward(from: 0.0);
    Future.delayed(const Duration(milliseconds: 600),
        () => setState(() => _showLikeAnimation = false));
  }

  void _openComments() {
    final uid = widget.currentUserId;
    if (uid == null) {
      widget.onRequireLogin();
      return;
    }
    showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => CommentsSheetWidget(
                videoID: widget.videoData['id']?.toString(),
                height: MediaQuery.of(context).size.height * 0.7))
        .whenComplete(_refreshCommentsCount);
  }

  Future<void> _refreshCommentsCount() async {
    final videoId = widget.videoData['id']?.toString().trim() ?? '';
    if (videoId.isEmpty) return;
    try {
      int count = 0;
      try {
        final response = await SupaFlow.client
            .from('comments')
            .select('id')
            .eq('video_id', videoId)
            .isFilter('deleted_at', null)
            .eq('moderation_status', GuardianMvpService.approvedStatus);
        count = (response as List).length;
      } catch (_) {
        final response = await SupaFlow.client
            .from('comments')
            .select('id')
            .eq('video_id', videoId);
        count = (response as List).length;
      }
      if (!mounted) return;
      setState(() => _commentsCount = count);
      widget.videoData['comments_count'] = count;
    } catch (_) {}
  }

  @override
  void dispose() {
    FeedWidget.shouldPauseAll.removeListener(_onShouldPauseAll);
    WidgetsBinding.instance.removeObserver(this);
    _likeAnimController.dispose();
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    _controller?.dispose();
    super.dispose();
  }

  String _formatCount(int count) => count >= 1000000
      ? '${(count / 1000000).toStringAsFixed(1)}M'
      : count >= 1000
          ? '${(count / 1000).toStringAsFixed(1)}K'
          : '$count';

  Widget _buildFollowButton() {
    return GestureDetector(
      onTap: _isFollowLoading ? null : _toggleFollow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _isFollowing ? 'Siguiendo' : 'Seguir',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildUserIdentityRow(String userName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              final uid = widget.videoData['user_id']?.toString() ?? '';
              if (uid.isNotEmpty) {
                context.pushNamed(
                  'perfil_profesional_solicitar_Contato',
                  queryParameters: {'userId': uid},
                );
              }
            },
            child: Text(
              '@$userName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        if (!_isOwnVideo) ...[
          const SizedBox(width: 12),
          _buildFollowButton(),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
          color: Colors.black,
          child: const Center(
              child: CircularProgressIndicator(color: Colors.white)));
    }
    if (_hasError) {
      return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(16),
          child: Center(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                'Error al cargar video:\n$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                widget.videoUrl,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          )));
    }
    if (!_isInitialized || _controller == null) {
      return Container(color: Colors.black);
    }

    final userData = widget.videoData['user_data'];
    final userName = userData?['name'] ?? 'Usuario';
    final userPhoto = userData?['photo_url'];
    final normalizedUserType =
        FFAppState.normalizeUserType(FFAppState().userType);
    final hasBottomNav =
        normalizedUserType == 'jugador' || normalizedUserType == 'profesional';
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final metadataBottom = (hasBottomNav ? 108.0 : 72.0) + safeBottom;
    final actionsBottom = (hasBottomNav ? 150.0 : 116.0) + safeBottom;

    return GestureDetector(
      onTapUp: _onTap,
      child: Container(
          color: Colors.black,
          child: Stack(children: [
            Center(
                child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!))),
            // Shadow
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
                      Colors.black.withOpacity(0.8)
                    ])))),
            Positioned(
                left: 16,
                right: 96,
                bottom: metadataBottom,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isChallengeVideo) ...[
                        _buildChallengeFeedBadge(),
                        const SizedBox(height: 12),
                      ],
                      if (_canSeeAuthorMetadata && _isPlayerAuthor) ...[
                        _buildAuthorMetadataOverlay(userData),
                        const SizedBox(height: 14),
                      ],
                      _buildUserIdentityRow(userName),
                      const SizedBox(height: 10),
                      Text(
                        widget.videoData['title'] ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),
                      if (_isChallengeVideo) ...[
                        const SizedBox(height: 10),
                        _buildChallengeTypeLabel(),
                      ],
                      const SizedBox(height: 2),
                    ])),
            // Buttons
            Positioned(
                right: 12,
                bottom: actionsBottom,
                child: Column(children: [
                  GestureDetector(
                    onTap: () {
                      final uid = widget.videoData['user_id']?.toString() ?? '';
                      if (uid.isNotEmpty) {
                        context.pushNamed(
                            'perfil_profesional_solicitar_Contato',
                            queryParameters: {'userId': uid});
                      }
                    },
                    child: CircleAvatar(
                        backgroundImage:
                            userPhoto != null ? NetworkImage(userPhoto) : null,
                        child: userPhoto == null
                            ? const Icon(Icons.person)
                            : null),
                  ),
                  const SizedBox(height: 20),
                  _buildSideBtn(Icons.thumb_up, _isLiked,
                      _formatCount(_likesCount), _toggleLike),
                  _buildSideBtn(Icons.chat_bubble_outline, false,
                      _formatCount(_commentsCount), _openComments),
                  _buildSideBtn(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      _isSaved,
                      _isSaved ? 'Guardado' : 'Guardar',
                      _toggleSave),
                ])),
            if (_isPaused)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          FeedWidget.globalMuted
                              ? Icons.volume_off
                              : Icons.volume_up,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_showLikeAnimation)
              const Center(
                  child: Icon(Icons.thumb_up,
                      color: Color(0xFF0D3B66), size: 100)),
          ])),
    );
  }

  Widget _buildSideBtn(
      IconData icon, bool active, String label, VoidCallback onTap) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: GestureDetector(
            onTap: onTap,
            child: Column(children: [
              Icon(icon,
                  color: active ? const Color(0xFF0D3B66) : Colors.white,
                  size: 32),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ])));
  }
}
