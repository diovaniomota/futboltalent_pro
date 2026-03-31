import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/fluxo_compartilhado/notificacoes/notificacoes_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/index.dart'; // For EditarPerfilWidget and PerfilProfesionalSolicitarContatoWidget
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'perfil_profesioanl_model.dart';
export 'perfil_profesioanl_model.dart';

class PerfilProfesioanlWidget extends StatefulWidget {
  const PerfilProfesioanlWidget({super.key});

  static String routeName = 'perfil_profesioanl';
  static String routePath = '/perfil_profesioanl';

  @override
  State<PerfilProfesioanlWidget> createState() =>
      _PerfilProfesioanlWidgetState();
}

class _PerfilProfesioanlWidgetState extends State<PerfilProfesioanlWidget>
    with SingleTickerProviderStateMixin {
  late PerfilProfesioanlModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _scoutHistory = [];
  List<Map<String, dynamic>> _savedVideos = [];
  List<String> _colabs = [];
  bool _isLoading = true;
  bool _isLoadingSavedVideos = false;
  String? _removingSavedVideoId;
  int _followers = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PerfilProfesioanlModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadProfile();
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
    if (_tabController.index == 1 && currentUserUid.isNotEmpty) {
      _loadSaved(currentUserUid, refreshUi: true);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final uid = currentUserUid;
    if (uid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final u = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (u != null) {
        final merged = <String, dynamic>{...u};
        try {
          final scout = await SupaFlow.client
              .from('scouts')
              .select()
              .eq('id', uid)
              .maybeSingle();
          if (scout != null) {
            merged.addAll(Map<String, dynamic>.from(scout));
            if ((merged['bio']?.toString().trim().isEmpty ?? true) &&
                (scout['biography']?.toString().trim().isNotEmpty ?? false)) {
              merged['bio'] = scout['biography'];
            }
          }
        } catch (_) {}
        _userData = merged;
        _followers = merged['followers_count'] ?? 0;
        if (merged['colaboraciones'] != null) {
          if (merged['colaboraciones'] is List) {
            _colabs = List<String>.from(merged['colaboraciones']);
          } else if (merged['colaboraciones'] is String)
            _colabs = (merged['colaboraciones'] as String)
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
        }
      }
      await _loadHistory(uid);
      await _loadSaved(uid);
    } catch (e) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadHistory(String uid) async {
    try {
      final lists = await SupaFlow.client
          .from('listas')
          .select('id')
          .eq('profesional_id', uid);
      final lids = (lists as List).map((e) => e['id']).toList();
      if (lids.isEmpty) return;

      final res = await SupaFlow.client
          .from('listas_jugadores')
          .select()
          .inFilter('lista_id', lids)
          .order('created_at', ascending: false);
      final l = List<Map<String, dynamic>>.from(res);
      for (var i in l) {
        if (i['jugador_id'] != null) {
          final d = await SupaFlow.client
              .from('users')
              .select()
              .eq('user_id', i['jugador_id'])
              .maybeSingle();
          i['jugador_data'] = d;
        }
      }
      _scoutHistory = l;
    } catch (_) {}
  }

  Future<void> _loadSaved(String uid, {bool refreshUi = false}) async {
    if (mounted && refreshUi) {
      setState(() => _isLoadingSavedVideos = true);
    }
    try {
      final res = await SupaFlow.client
          .from('saved_videos')
          .select('video_id, created_at')
          .eq('user_id', uid);

      final savedRows = List<Map<String, dynamic>>.from(res);
      savedRows.sort((a, b) {
        final aDate = a['created_at']?.toString() ?? '';
        final bDate = b['created_at']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

      final videoIds = savedRows
          .map((e) => e['video_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (videoIds.isEmpty) {
        if (mounted) {
          setState(() {
            _savedVideos = [];
            _isLoadingSavedVideos = false;
          });
        }
        return;
      }

      final videosResponse = await SupaFlow.client
          .from('videos')
          .select()
          .inFilter('id', videoIds);

      final videos = List<Map<String, dynamic>>.from(videosResponse);
      final videosById = <String, Map<String, dynamic>>{
        for (final video in videos)
          (video['id']?.toString() ?? ''): Map<String, dynamic>.from(video),
      };

      final ownerIds = videos
          .map((v) => v['user_id']?.toString())
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
      for (final saved in savedRows) {
        final videoId = saved['video_id']?.toString() ?? '';
        if (videoId.isEmpty) continue;
        final video = videosById[videoId];
        if (video == null) continue;
        final ownerId = video['user_id']?.toString() ?? '';
        merged.add({
          ...video,
          'saved_at': saved['created_at'],
          'owner_data': ownerIds.contains(ownerId) ? ownersById[ownerId] : null,
        });
      }

      if (mounted) {
        setState(() {
          _savedVideos = merged;
          _isLoadingSavedVideos = false;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingSavedVideos = false);
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  String _date(String? d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  void _openVideo(Map<String, dynamic> v) {
    showDialog(
        context: context,
        builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: _VideoPlayerDialog(url: v['video_url'] ?? '')));
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
        const SnackBar(content: Text('Video removido de Guardados')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _removingSavedVideoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo quitar el video: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    if (_isLoading) {
      return Container(
          color: Colors.white,
          child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D3B66))));
    }

    final name = _userData?['name'] ?? _userData?['nombre'] ?? 'Usuario';
    final bio = _userData?['bio'] ?? _userData?['descripcion'] ?? '';
    final photo = _userData?['photo_url'] ?? '';
    final cover = _userData?['cover_url'] ?? _userData?['banner_url'] ?? '';
    final ver = _userData?['is_verified'] ?? false;
    final scoutClub = _userData?['club']?.toString().trim() ?? '';
    final scoutPhone = _userData?['telephone']?.toString().trim() ?? '';
    final scoutUrl = _userData?['url_profesional']?.toString().trim() ?? '';
    final scoutDni = _userData?['dni']?.toString().trim() ?? '';

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Column(children: [
              Expanded(
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    SizedBox(
                        height: 160,
                        child: Stack(clipBehavior: Clip.none, children: [
                          Container(
                              width: double.infinity,
                              height: 160,
                              decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  image: cover.isNotEmpty
                                      ? DecorationImage(
                                          image:
                                              CachedNetworkImageProvider(cover),
                                          fit: BoxFit.cover)
                                      : null)),
                          SafeArea(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _iconBtn(Icons.settings, () {
                                          context.pushNamed(
                                              EditarPerfilWidget.routeName);
                                        }),
                                        Row(children: [
                                          _iconBtn(Icons.notifications, () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const NotificacionesWidget(
                                                  initialUserType: 'scout',
                                                ),
                                              ),
                                            );
                                          }),
                                          const SizedBox(width: 12),
                                          _iconBtn(Icons.logout, () async {
                                            print('Logout button pressed');
                                            try {
                                              await authManager.signOut();
                                              print('SignOut completed');
                                              if (context.mounted) {
                                                print('Navigating to login');
                                                context.goNamed(
                                                    LoginWidget.routeName);
                                              }
                                            } catch (e) {
                                              print('Error during logout: $e');
                                            }
                                          })
                                        ])
                                      ]))),
                          Positioned(
                              left: 20,
                              bottom: -50,
                              child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFE0E0E0),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 4),
                                      image: photo.isNotEmpty
                                          ? DecorationImage(
                                              image: CachedNetworkImageProvider(
                                                  photo),
                                              fit: BoxFit.cover)
                                          : null),
                                  child: photo.isEmpty
                                      ? Icon(Icons.person_outline,
                                          size: 50, color: Colors.grey[600])
                                      : null))
                        ])),
                    const SizedBox(height: 55),
                    Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: ElevatedButton(
                                onPressed: () => context
                                    .pushNamed(EditarPerfilWidget.routeName),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D3B66),
                                    minimumSize: const Size(110, 36),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8))),
                                child: Text('Editar perfil',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white))))),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(children: [
                          Text(name,
                              style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1A1A))),
                          if (ver) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                color: Color(0xFF0D3B66), size: 22)
                          ]
                        ])),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Text('${_fmt(_followers)} seguidores',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: const Color(0xFF666666)))),
                    if (bio.isNotEmpty) ...[
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Text('Resumen',
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1A1A)))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Text(bio,
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: const Color(0xFF444444),
                                  height: 1.5)))
                    ],
                    if (_colabs.isNotEmpty) ...[
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Text('Colaboraciones destacadas:',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF666666)))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _colabs
                                  .map((c) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: const Color(0xFFD0D0D0))),
                                      child: Text(c,
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: const Color(0xFF444444)))))
                                  .toList()))
                    ],
                    if (scoutClub.isNotEmpty ||
                        scoutPhone.isNotEmpty ||
                        scoutUrl.isNotEmpty ||
                        scoutDni.isNotEmpty) ...[
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Text('Perfil profesional',
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1A1A)))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            if (scoutClub.isNotEmpty)
                              _profileChip(Icons.apartment_rounded, scoutClub),
                            if (scoutPhone.isNotEmpty)
                              _profileChip(Icons.call_outlined, scoutPhone),
                            if (scoutUrl.isNotEmpty)
                              _profileChip(Icons.language_rounded, scoutUrl),
                            if (scoutDni.isNotEmpty)
                              _profileChip(
                                  Icons.badge_outlined, 'ID $scoutDni'),
                          ])),
                    ],
                    const SizedBox(height: 24),
                    Container(
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Color(0xFFE0E0E0)))),
                        child: TabBar(
                            controller: _tabController,
                            labelColor: const Color(0xFF0D3B66),
                            unselectedLabelColor: const Color(0xFF888888),
                            indicatorColor: const Color(0xFF0D3B66),
                            tabs: const [
                              Tab(text: 'Historial de Scouting'),
                              Tab(text: 'Guardados')
                            ])),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _tabController.index == 0
                          ? _buildScoutingHistoryTab()
                          : _buildSavedVideosTab(),
                    ),
                    const SizedBox(height: 100)
                  ])))
            ]),
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
                      child: const NavBarProfesionalWidget()))
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData i, VoidCallback t) => GestureDetector(
      onTap: t,
      child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
          child: Icon(i, color: Colors.black87, size: 22)));

  Widget _profileChip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: const Color(0xFF0D3B66)),
        const SizedBox(width: 6),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w600)))
      ]));

  Widget _buildScoutingHistoryTab() {
    if (_scoutHistory.isEmpty) {
      return Padding(
        key: const ValueKey('scouting_history_empty'),
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
        child: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No hay historial de scouting',
              style: TextStyle(color: Colors.grey))
        ])),
      );
    }
    return ListView.builder(
        key: const ValueKey('scouting_history_list'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _scoutHistory.length,
        itemBuilder: (ctx, i) => _card(_scoutHistory[i]));
  }

  Widget _card(Map<String, dynamic> item) {
    final d = item['jugador_data'];
    final name = '${d?['name'] ?? ''} ${d?['lastname'] ?? ''}'.trim();
    final pos = d?['posicion'] ?? 'Sin posición';
    final city = d?['city'] ?? '';
    String age = '';
    if (d?['birthday'] != null) {
      try {
        final b = DateTime.parse(d['birthday']);
        final n = DateTime.now();
        int y = n.year - b.year;
        if (n.month < b.month || (n.month == b.month && n.day < b.day)) y--;
        age = '$y años';
      } catch (_) {}
    }
    final info =
        [pos, if (age.isNotEmpty) age, if (city.isNotEmpty) city].join(' • ');

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8E8))),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name.isNotEmpty ? name : 'Jugador',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text(info,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF666666))),
                if (item['club_fichado'] != null ||
                    item['created_at'] != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(
                            item['club_fichado'] != null
                                ? 'Fichado: ${_date(item['created_at'])}'
                                : 'Agregado: ${_date(item['created_at'])}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)))
                  ])
                ]
              ])),
          OutlinedButton(
              onPressed: () {
                if (item['jugador_id'] != null) {
                  context.pushNamed('perfil_profesional_solicitar_Contato',
                      queryParameters: {
                        'userId': item['jugador_id'].toString()
                      });
                }
              },
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Ver Perfil',
                  style: TextStyle(color: Color(0xFF444444))))
        ]));
  }

  Widget _buildSavedVideosTab() {
    if (_isLoadingSavedVideos) {
      return const Padding(
        key: ValueKey('saved_videos_loading'),
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
        ),
      );
    }

    if (_savedVideos.isEmpty) {
      return Padding(
        key: const ValueKey('saved_videos_empty'),
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
        child: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bookmark_border, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No hay videos guardados',
              style: TextStyle(color: Colors.grey))
        ])),
      );
    }

    return Column(
      key: const ValueKey('saved_videos_content'),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline,
                  color: Color(0xFF0D3B66), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Guardados es privado. Solo vos podés ver estos videos.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.76,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12),
            itemCount: _savedVideos.length,
            itemBuilder: (ctx, i) {
              final v = _savedVideos[i];
              final thumb =
                  v['thumbnail_url'] ?? v['thumbnail'] ?? v['cover_url'] ?? '';
              final owner = v['owner_data'] is Map<String, dynamic>
                  ? Map<String, dynamic>.from(v['owner_data'] as Map)
                  : <String, dynamic>{};
              final ownerName =
                  owner['name']?.toString().trim().isNotEmpty == true
                      ? owner['name'].toString().trim()
                      : owner['username']?.toString().trim() ?? 'Jugador';
              final title = v['title']?.toString().trim().isNotEmpty == true
                  ? v['title'].toString().trim()
                  : 'Video guardado';
              final videoId = v['id']?.toString() ?? '';
              final isRemoving = _removingSavedVideoId == videoId;

              return GestureDetector(
                  onTap: () => _openVideo(v),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: thumb.isNotEmpty
                                ? Image.network(thumb, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey[850],
                                    child: const Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white,
                                        size: 38,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap:
                                isRemoving ? null : () => _removeSavedVideo(v),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                shape: BoxShape.circle,
                              ),
                              child: isRemoving
                                  ? const Padding(
                                      padding: EdgeInsets.all(9),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 26, 12, 12),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.86),
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
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ));
            }),
      ],
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String url;
  const _VideoPlayerDialog({required this.url});
  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  VideoPlayerController? _c;
  bool _init = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
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
  Widget build(BuildContext context) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
          color: Colors.black87,
          child: Center(
              child: _init
                  ? AspectRatio(
                      aspectRatio: _c!.value.aspectRatio,
                      child: VideoPlayer(_c!))
                  : const CircularProgressIndicator(color: Colors.white))));
}
