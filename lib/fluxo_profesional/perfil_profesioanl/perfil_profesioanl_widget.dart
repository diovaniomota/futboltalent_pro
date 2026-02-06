import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
  int _followers = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PerfilProfesioanlModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _model.dispose();
    _tabController.dispose();
    super.dispose();
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
        _userData = u;
        _followers = u['followers_count'] ?? 0;
        if (u['colaboraciones'] != null) {
          if (u['colaboraciones'] is List) {
            _colabs = List<String>.from(u['colaboraciones']);
          } else if (u['colaboraciones'] is String)
            _colabs = (u['colaboraciones'] as String)
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
          .from('listas_club')
          .select('id')
          .eq('club_id', uid);
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

  Future<void> _loadSaved(String uid) async {
    try {
      final res = await SupaFlow.client
          .from('saved_videos')
          .select('video_id')
          .eq('user_id', uid);
      final vids = (res as List)
          .map((e) => e['video_id'])
          .where((id) => id != null)
          .toList();
      if (vids.isNotEmpty) {
        final vs =
            await SupaFlow.client.from('videos').select().inFilter('id', vids);
        _savedVideos = List<Map<String, dynamic>>.from(vs);
      }
    } catch (_) {}
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
                                        _iconBtn(Icons.settings, () {}),
                                        Row(children: [
                                          _iconBtn(Icons.notifications, () {}),
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
                    if (_tabController.index == 0)
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('+ Crear una nueva colección',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: const Color(0xFF444444))),
                                const Icon(Icons.arrow_forward,
                                    size: 20, color: Color(0xFF444444))
                              ])),
                    SizedBox(
                        height: 500,
                        child: TabBarView(
                            controller: _tabController,
                            children: [_list(), _grid()])),
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

  Widget _list() {
    if (_scoutHistory.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('No hay historial de scouting',
            style: TextStyle(color: Colors.grey))
      ]));
    }
    return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _grid() {
    if (_savedVideos.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bookmark_border, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('No hay videos guardados',
            style: TextStyle(color: Colors.grey))
      ]));
    }
    return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8),
        itemCount: _savedVideos.length,
        itemBuilder: (ctx, i) {
          final v = _savedVideos[i];
          final thumb =
              v['thumbnail_url'] ?? v['thumbnail'] ?? v['cover_url'] ?? '';
          return GestureDetector(
              onTap: () => _openVideo(v),
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      image: thumb.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(thumb), fit: BoxFit.cover)
                          : null),
                  child: thumb.isEmpty
                      ? const Center(
                          child: Icon(Icons.play_circle_outline,
                              color: Colors.white))
                      : null));
        });
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
