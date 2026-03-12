import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/gamification/gamification_service.dart';
import '/guardian/guardian_mvp_service.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/modal/comments_sheet/comments_sheet_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
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
  bool get _isScoutViewer =>
      FFAppState.normalizeUserType(FFAppState().userType) == 'profesional';

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
                  'Sem dados disponíveis para este filtro.',
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
            final commentsResponse = await SupaFlow.client
                .from('comments')
                .select('id')
                .eq('video_id', videoId);
            video['comments_count'] = (commentsResponse as List).length;
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

      if (mounted) {
        setState(() {
          _videos = visibleVideos;
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
    _checkLoginModal();
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;

    final size = MediaQuery.of(context).size;
    final feedHeight = size.height;

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
    if (_videos.isEmpty) return _buildNoVideosContent();

    final visibleVideos = _isScoutViewer ? _scoutFilteredVideos : _videos;
    if (visibleVideos.isEmpty) {
      if (_isScoutViewer && _activeScoutFeedFiltersCount > 0) {
        return _buildNoFilteredVideosContent();
      }
      return _buildNoVideosContent();
    }

    if (_currentIndex >= visibleVideos.length) {
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
        itemCount: visibleVideos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final video = visibleVideos[index];
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

  bool get _isScoutViewer =>
      FFAppState.normalizeUserType(FFAppState().userType) == 'profesional';

  String _videoKindLabel() {
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

  Widget _buildGamificationOverlay() {
    final progress = widget.videoData['user_progress'] is Map
        ? Map<String, dynamic>.from(widget.videoData['user_progress'] as Map)
        : <String, dynamic>{};
    final hasAnyData =
        progress.isNotEmpty || (widget.videoData['user_data'] is Map);
    if (!hasAnyData) return const SizedBox.shrink();

    final totalXp = GamificationService.toInt(progress['total_xp']);
    final levelName = GamificationService.levelNameFromPoints(totalXp);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildScoutOverlayChip(
          icon: Icons.workspace_premium_outlined,
          label: levelName,
          backgroundColor: Colors.black.withOpacity(0.34),
        ),
        _buildScoutOverlayChip(
          icon: Icons.bolt,
          label: '$totalXp XP',
          backgroundColor: const Color(0xFF0D3B66).withOpacity(0.82),
        ),
      ],
    );
  }

  Widget _buildScoutVideoContextOverlay(dynamic rawUserData) {
    if (!_isScoutViewer) return const SizedBox.shrink();

    final userData = rawUserData is Map
        ? Map<String, dynamic>.from(rawUserData)
        : <String, dynamic>{};

    final category = _firstNonEmpty([
          userData['category'],
          userData['categoria'],
          _categoryFromBirthday(
            userData['birthday'] ?? userData['birth_date'],
          ),
        ]) ??
        '';

    final position = _firstNonEmpty([
          userData['position'],
          userData['posicion'],
          userData['posição'],
        ]) ??
        '';

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

    final location = [city, country].where((p) => p.isNotEmpty).join(' · ');
    final videoKind = _videoKindLabel();

    final chips = <Widget>[
      _buildScoutOverlayChip(
        icon:
            videoKind == 'Desafío' ? Icons.track_changes : Icons.ondemand_video,
        label: videoKind,
        backgroundColor: videoKind == 'Desafío'
            ? const Color(0xFF7C2D12).withOpacity(0.85)
            : const Color(0xFF1E3A8A).withOpacity(0.85),
      ),
      if (category.isNotEmpty)
        _buildScoutOverlayChip(icon: Icons.category_outlined, label: category),
      if (position.isNotEmpty)
        _buildScoutOverlayChip(icon: Icons.shield_outlined, label: position),
      if (location.isNotEmpty)
        _buildScoutOverlayChip(
            icon: Icons.location_on_outlined, label: location),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
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
            content: Text(_isSaved ? 'Video guardado' : 'Video eliminado'),
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

  void _shareVideo() {
    Share.share('${widget.videoData['title'] ?? ''}\n\n${widget.videoUrl}');
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
            height: MediaQuery.of(context).size.height * 0.7));
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
                bottom: 72,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isScoutViewer) ...[
                        _buildScoutVideoContextOverlay(userData),
                        const SizedBox(height: 14),
                      ],
                      _buildUserIdentityRow(userName),
                      const SizedBox(height: 10),
                      _buildGamificationOverlay(),
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
                      const SizedBox(height: 2),
                    ])),
            // Buttons
            Positioned(
                right: 12,
                bottom: 120,
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
                  _buildSideBtn(Icons.share, false, 'Share', _shareVideo),
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
