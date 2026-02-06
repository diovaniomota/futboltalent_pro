import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/comments_sheet/comments_sheet_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'explorar_model.dart';
export 'explorar_model.dart';

class ExplorarWidget extends StatefulWidget {
  const ExplorarWidget({super.key});

  static String routeName = 'Explorar';
  static String routePath = '/explorar';

  @override
  State<ExplorarWidget> createState() => _ExplorarWidgetState();
}

class _ExplorarWidgetState extends State<ExplorarWidget> {
  late ExplorarModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allVideos = [];
  List<Map<String, dynamic>> _filteredVideos = [];
  String _selectedFilter = 'todos';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ExplorarModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadVideos();
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await SupaFlow.client
          .from('videos')
          .select()
          .eq('is_public', true)
          .order('created_at', ascending: false);
      final videos = List<Map<String, dynamic>>.from(response);

      for (var video in videos) {
        try {
          final uid = video['user_id'];
          if (uid != null) {
            final u = await SupaFlow.client
                .from('users')
                .select()
                .eq('user_id', uid)
                .maybeSingle();
            if (u != null) video['user_data'] = u;
          }
        } catch (_) {}
        try {
          final c = await SupaFlow.client
              .from('comments')
              .select('id')
              .eq('video_id', video['id']);
          video['comments_count'] = (c as List).length;
        } catch (_) {
          video['comments_count'] = 0;
        }
      }
      _allVideos = videos;
      _filteredVideos = videos;
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error al cargar videos');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterVideos() {
    setState(() {
      _filteredVideos = _allVideos.where((v) {
        // Filtro por Categoria (userType)
        if (_selectedFilter != 'todos') {
          final videoUserType =
              (v['user_data']?['userType'] ?? '').toString().toLowerCase();
          if (videoUserType != _selectedFilter) {
            return false;
          }
        }

        // Filtro por Busca (Texto)
        if (_searchQuery.isNotEmpty) {
          final t = (v['title'] ?? '').toString().toLowerCase();
          final d = (v['description'] ?? '').toString().toLowerCase();
          final u = (v['user_data']?['name'] ?? '').toString().toLowerCase();
          if (!t.contains(_searchQuery) &&
              !d.contains(_searchQuery) &&
              !u.contains(_searchQuery)) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  void _onSearch(String val) {
    _searchQuery = val.toLowerCase();
    _filterVideos();
  }

  void _openVideoFeed(int idx) {
    final selected = _filteredVideos[idx];
    final others = [
      ..._filteredVideos.sublist(idx + 1),
      ..._filteredVideos.sublist(0, idx)
    ];
    final reordered = [selected, ...others];
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (ctx, _, __) =>
          _VideoFeedScreen(videos: reordered, userId: currentUserUid),
      transitionsBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Stack(
          children: [
            Container(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height * 0.91,
              color: Colors.white,
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF0D3B66)))
                  : _errorMessage != null
                      ? _buildError()
                      : _buildContent(),
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

  Widget _buildError() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.red)),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: _loadVideos,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66)),
            child:
                const Text('Reintentar', style: TextStyle(color: Colors.white)))
      ]));

  Widget _buildContent() => SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadVideos,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildFilters(),
              const SizedBox(height: 20),
              _buildVideoGridLimited(),
              const SizedBox(height: 24),
              _buildTrending(),
              const SizedBox(height: 100)
            ]),
          ),
        ),
      );

  Widget _buildSearchBar() => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFA0AEC0))),
        child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearch,
            decoration: InputDecoration(
                hintText: 'Buscar jugadores, clubes, videos...',
                hintStyle: GoogleFonts.inter(
                    color: const Color(0xFFA0AEC0), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFA0AEC0)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFFA0AEC0)),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        })
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            style: GoogleFonts.inter(fontSize: 14)),
      );

  Widget _buildFilters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _chip('Jugadores', 'jugador'),
          const SizedBox(width: 12),
          _chip('Clubes', 'club'),
          const SizedBox(width: 12),
          _chip('Scouts', 'scout')
        ]),
      );

  Widget _chip(String label, String value) {
    final sel = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = sel ? 'todos' : value;
        });
        _filterVideos();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: sel ? const Color(0xFF0D3B66) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color:
                    sel ? const Color(0xFF0D3B66) : const Color(0xFFA0AEC0))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: sel ? Colors.white : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down,
              color: sel ? Colors.white : const Color(0xFF718096), size: 20)
        ]),
      ),
    );
  }

  Widget _buildVideoGridLimited() {
    if (_filteredVideos.isEmpty) return _empty();
    final list = _filteredVideos.take(5).toList();
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (list.isNotEmpty) Expanded(flex: 2, child: _largeCard(list[0], 0)),
        const SizedBox(width: 12),
        Expanded(
            flex: 1,
            child: Column(children: [
              if (list.length > 1) _medCard(list[1], 1),
              const SizedBox(height: 12),
              if (list.length > 2) _medCard(list[2], 2)
            ]))
      ]),
      const SizedBox(height: 12),
      if (list.length > 3)
        Row(children: [
          Expanded(child: _smallCard(list[3], 3)),
          const SizedBox(width: 12),
          if (list.length > 4)
            Expanded(child: _smallCard(list[4], 4))
          else
            const Expanded(child: SizedBox())
        ])
    ]);
  }

  Widget _largeCard(Map<String, dynamic> v, int i) => GestureDetector(
        onTap: () => _openVideoFeed(i),
        child: Container(
            height: 280,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(fit: StackFit.expand, children: [
                  _VideoThumbnail(
                      thumbnailUrl: v['thumbnail_url'] ?? '',
                      videoUrl: v['video_url'] ?? ''),
                  Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7)
                      ]))),
                  Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v['title'] ?? '',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.play_arrow,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(_formatViews(v['views_count']),
                                  style: GoogleFonts.inter(
                                      color: Colors.white70, fontSize: 12))
                            ])
                          ]))
                ]))),
      );

  Widget _medCard(Map<String, dynamic> v, int i) => GestureDetector(
      onTap: () => _openVideoFeed(i),
      child: Container(
          height: 134,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _VideoThumbnail(
                  thumbnailUrl: v['thumbnail_url'] ?? '',
                  videoUrl: v['video_url'] ?? ''))));
  Widget _smallCard(Map<String, dynamic> v, int i) => GestureDetector(
      onTap: () => _openVideoFeed(i),
      child: Container(
          height: 120,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _VideoThumbnail(
                  thumbnailUrl: v['thumbnail_url'] ?? '',
                  videoUrl: v['video_url'] ?? ''))));

  Widget _empty() => Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.video_library_outlined,
            color: Color(0xFFA0AEC0), size: 48),
        const SizedBox(height: 12),
        Text('No se encontraron videos',
            style: GoogleFonts.inter(
                color: const Color(0xFF718096), fontSize: 16)),
        if (_searchQuery.isNotEmpty)
          TextButton(
              onPressed: () {
                _searchController.clear();
                _onSearch('');
              },
              child: Text('Limpiar filtros',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF0D3B66),
                      fontWeight: FontWeight.w600)))
      ]));

  Widget _buildTrending() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Trending',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(height: 16),
        _trend('#MejorGol', '120k', Icons.sports_soccer),
        const SizedBox(height: 16),
        _trend('#DefensaDeAcero', '96k', Icons.shield_outlined)
      ]);
  Widget _trend(String t, String v, IconData i) => GestureDetector(
      onTap: () {
        _searchController.text = t;
        _onSearch(t);
      },
      child: Row(children: [
        Icon(i, color: const Color(0xFFD69E2E), size: 30),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF444444))),
          Text('+$v views',
              style: GoogleFonts.inter(
                  fontSize: 14, color: const Color(0xFF718096)))
        ])),
        const Icon(Icons.chevron_right, color: Color(0xFF718096), size: 24)
      ]));

  String _formatViews(dynamic v) {
    final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String thumbnailUrl, videoUrl;
  const _VideoThumbnail({required this.thumbnailUrl, required this.videoUrl});
  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _c;
  bool _init = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    if (widget.videoUrl.isEmpty) return;
    try {
      _c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true))
        ..setVolume(0)
        ..setLooping(true);
      await _c!.initialize();
      if (mounted) {
        setState(() => _init = true);
        _c!.play();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _init
      ? SizedBox.expand(
          child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                  width: _c!.value.size.width,
                  height: _c!.value.size.height,
                  child: VideoPlayer(_c!))))
      : Container(
          color: Colors.grey[900],
          child: const Center(
              child: Icon(Icons.videocam_outlined, color: Colors.white54)));
}

class _VideoFeedScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final String userId;
  const _VideoFeedScreen({required this.videos, required this.userId});
  @override
  State<_VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<_VideoFeedScreen> {
  late PageController _pc;
  int _idx = 0;
  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (ctx, i) => _Player(
                key: ValueKey(widget.videos[i]['id']),
                data: widget.videos[i],
                active: i == _idx,
                userId: widget.userId)),
        Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, color: Colors.white))))
      ]));
}

class _Player extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool active;
  final String userId;
  const _Player(
      {super.key,
      required this.data,
      required this.active,
      required this.userId});
  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> with TickerProviderStateMixin {
  VideoPlayerController? _c;
  bool _init = false;
  bool _paused = false;
  final bool _muted = false;
  bool _showLike = false;
  bool _liked = false;
  int _likes = 0;
  int _comments = 0;
  late AnimationController _ac;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _likes = widget.data['likes_count'] ?? 0;
    _comments = widget.data['comments_count'] ?? 0;
    _checkLike();
    _load();
  }

  @override
  void dispose() {
    _ac.dispose();
    _c?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Player old) {
    super.didUpdateWidget(old);
    if (_c != null && _init && widget.active != old.active) {
      if (widget.active) {
        _c!.play();
      } else {
        _c!.pause();
      }
    }
  }

  void _checkLike() async {
    try {
      final r = await SupaFlow.client
          .from('likes')
          .select('id')
          .eq('video_id', widget.data['id'])
          .eq('user_id', widget.userId)
          .maybeSingle();
      if (mounted) setState(() => _liked = r != null);
    } catch (_) {}
  }

  void _load() async {
    final url = widget.data['video_url'] ?? '';
    if (url.isEmpty) return;
    try {
      _c = VideoPlayerController.networkUrl(Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true))
        ..setLooping(true);
      await _c!.initialize();
      if (mounted) {
        setState(() => _init = true);
        if (widget.active) _c!.play();
      }
    } catch (_) {}
  }

  void _tap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < 300) {
      setState(() {
        _showLike = true;
        _ac.forward(from: 0);
      });
      if (!_liked) _toggleLike();
      Future.delayed(const Duration(milliseconds: 600),
          () => setState(() => _showLike = false));
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_lastTap == now) _togglePlay();
      });
    }
    _lastTap = now;
  }

  void _togglePlay() {
    if (_c == null || !_init) return;
    setState(() {
      if (_c!.value.isPlaying) {
        _c!.pause();
        _paused = true;
      } else {
        _c!.play();
        _paused = false;
      }
    });
  }

  void _toggleLike() async {
    final prev = _liked;
    setState(() {
      _liked = !_liked;
      _likes = _liked ? _likes + 1 : (_likes > 0 ? _likes - 1 : 0);
    });
    try {
      if (_liked) {
        await SupaFlow.client
            .from('likes')
            .insert({'user_id': widget.userId, 'video_id': widget.data['id']});
      } else {
        await SupaFlow.client
            .from('likes')
            .delete()
            .eq('user_id', widget.userId)
            .eq('video_id', widget.data['id']);
      }
      await SupaFlow.client
          .from('videos')
          .update({'likes_count': _likes}).eq('id', widget.data['id']);
    } catch (_) {
      setState(() => _liked = prev);
    }
  }

  void _openComments() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CommentsSheetWidget(
            videoID: widget.data['id']?.toString(),
            height: MediaQuery.of(context).size.height * 0.7));
  }

  @override
  Widget build(BuildContext context) {
    if (!_init) {
      return Container(
          color: Colors.black,
          child: const Center(
              child: CircularProgressIndicator(color: Colors.white)));
    }
    final u = widget.data['user_data'];
    return GestureDetector(
      onTapUp: (_) => _tap(),
      child: Container(
          color: Colors.black,
          child: Stack(children: [
            Center(
                child: AspectRatio(
                    aspectRatio: _c!.value.aspectRatio,
                    child: VideoPlayer(_c!))),
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 250,
                child: Container(
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87])))),
            Positioned(
                left: 16,
                right: 80,
                bottom: 100,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@${u?['name'] ?? 'User'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(widget.data['title'] ?? '',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                      if (widget.data['description'] != null)
                        Text(widget.data['description'],
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12))
                    ])),
            Positioned(
                right: 12,
                bottom: 120,
                child: Column(children: [
                  CircleAvatar(
                      backgroundImage: u?['photo_url'] != null
                          ? NetworkImage(u['photo_url'])
                          : null),
                  const SizedBox(height: 20),
                  _btn(_liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      _likes.toString(), _toggleLike,
                      color: _liked ? const Color(0xFF0D3B66) : Colors.white),
                  _btn(Icons.chat_bubble_outline, _comments.toString(),
                      _openComments),
                  _btn(
                      Icons.share,
                      'Share',
                      () => Share.share(
                          '${widget.data['title']}\n${widget.data['video_url']}')),
                ])),
            if (_paused)
              const Center(
                  child:
                      Icon(Icons.play_arrow, color: Colors.white54, size: 60)),
            if (_showLike)
              const Center(
                  child:
                      Icon(Icons.thumb_up, color: Color(0xFF0D3B66), size: 100))
          ])),
    );
  }

  Widget _btn(IconData i, String l, VoidCallback t,
          {Color color = Colors.white}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GestureDetector(
              onTap: t,
              child: Column(children: [
                Icon(i, color: color, size: 32),
                Text(l,
                    style: const TextStyle(color: Colors.white, fontSize: 12))
              ])));
}
