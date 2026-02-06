import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
  bool _hasShownLoginModal = false;
  int _videosWatchedWithoutLogin = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FeedModel());
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _instanceId = DateTime.now().millisecondsSinceEpoch.toString();
    FeedWidget.activeInstanceId = _instanceId;

    _loadVideos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    _model.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController?.dispose();
    if (FeedWidget.activeInstanceId == _instanceId) {
      FeedWidget.activeInstanceId = null;
    }
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    _pauseAllVideos();
    _isActiveRoute = false;
  }

  @override
  void didPopNext() {
    _isActiveRoute = true;
    setState(() {});
  }

  @override
  void deactivate() {
    _pauseAllVideos();
    _isActiveRoute = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _isActiveRoute = true;
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

  void _showCreateProfileModal() {
    if (_hasShownLoginModal) return;
    _hasShownLoginModal = true;
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
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
                      Navigator.pop(context);
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
                          Navigator.pop(context);
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
                        Navigator.pop(context);
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

      if (mounted) {
        setState(() {
          _videos = videos;
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
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTab('Todos', 'todos'),
                          const SizedBox(width: 24),
                          _buildTab('Siguiendo', 'siguiendo'),
                        ]),
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

  Widget _buildContent(double feedHeight) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_selectedTab == 'siguiendo' && !_isFollowingAnyone) {
      return _buildNoFollowingContent();
    }
    if (_videos.isEmpty) return _buildNoVideosContent();

    return PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final video = _videos[index];
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
    if (_controller != null && _isInitialized) {
      _controller!.pause();
      _controller!.setVolume(0.0);
      if (mounted) setState(() => _isPausedBySystem = true);
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

    if (!widget.isParentVisible) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _controller!.setVolume(0.0);
        if (mounted) setState(() => _isPausedBySystem = true);
      }
    } else if (widget.isCurrentVideo && widget.isParentVisible && !_isPaused) {
      if (_isPausedBySystem || !_controller!.value.isPlaying) {
        _controller!.play();
        _controller!.setVolume(FeedWidget.globalMuted ? 0.0 : 1.0);
        if (mounted) setState(() => _isPausedBySystem = false);
      }
    } else if (!widget.isCurrentVideo) {
      _controller!.pause();
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
      setState(() {
        _isInitialized = true;
        _hasError = false;
        _isLoading = false;
      });
      if (widget.isCurrentVideo && widget.isParentVisible) _controller!.play();
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
        _isPaused = true;
      } else {
        _controller!.play();
        _isPaused = false;
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
    _controller?.dispose();
    super.dispose();
  }

  String _formatCount(int count) => count >= 1000000
      ? '${(count / 1000000).toStringAsFixed(1)}M'
      : count >= 1000
          ? '${(count / 1000).toStringAsFixed(1)}K'
          : '$count';

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
            // Info
            Positioned(
                left: 16,
                right: 80,
                bottom: 100,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('@$userName',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        if (!_isOwnVideo) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                              onTap: _isFollowLoading ? null : _toggleFollow,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                      _isFollowing ? 'Siguiendo' : 'Seguir',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12))))
                        ]
                      ]),
                      const SizedBox(height: 8),
                      Text(widget.videoData['title'] ?? '',
                          style: const TextStyle(color: Colors.white)),
                    ])),
            // Buttons
            Positioned(
                right: 12,
                bottom: 120,
                child: Column(children: [
                  CircleAvatar(
                      backgroundImage:
                          userPhoto != null ? NetworkImage(userPhoto) : null,
                      child:
                          userPhoto == null ? const Icon(Icons.person) : null),
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
                    Container(
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
