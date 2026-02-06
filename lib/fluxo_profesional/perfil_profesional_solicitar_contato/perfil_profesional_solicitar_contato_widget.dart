import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'perfil_profesional_solicitar_contato_model.dart';
export 'perfil_profesional_solicitar_contato_model.dart';

class PerfilProfesionalSolicitarContatoWidget extends StatefulWidget {
  const PerfilProfesionalSolicitarContatoWidget({
    super.key,
    required this.userId,
  });

  final String? userId;

  static String routeName = 'perfil_profesional_solicitar_Contato';
  static String routePath = '/perfil_profesional_solicitar_Contato';

  @override
  State<PerfilProfesionalSolicitarContatoWidget> createState() =>
      _PerfilProfesionalSolicitarContatoWidgetState();
}

class _PerfilProfesionalSolicitarContatoWidgetState
    extends State<PerfilProfesionalSolicitarContatoWidget> {
  late PerfilProfesionalSolicitarContatoModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _scoutHistory = [];
  List<String> _colabs = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _hasRequested = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _model =
        createModel(context, () => PerfilProfesionalSolicitarContatoModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadProfile();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (widget.userId == null || widget.userId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final u = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', widget.userId!)
          .maybeSingle();
      if (u != null) {
        _userData = u;
        if (u['colaboraciones'] != null) {
          if (u['colaboraciones'] is List)
            _colabs = List<String>.from(u['colaboraciones']);
          else if (u['colaboraciones'] is String)
            _colabs = (u['colaboraciones'] as String)
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
        }
      }
      await _checkStatus();
      await _loadHistory();
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkStatus() async {
    final uid = currentUserUid;
    if (uid.isEmpty) return;
    try {
      final f = await SupaFlow.client
          .from('follows')
          .select('id')
          .eq('follower_id', uid)
          .eq('following_id', widget.userId!)
          .maybeSingle();
      final r = await SupaFlow.client
          .from('contact_requests')
          .select('id')
          .eq('from_user_id', uid)
          .eq('to_user_id', widget.userId!)
          .maybeSingle();
      if (mounted)
        setState(() {
          _isFollowing = f != null;
          _hasRequested = r != null;
        });
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final lists = await SupaFlow.client
          .from('listas_club')
          .select('id')
          .eq('club_id', widget.userId!);
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

  Future<void> _request() async {
    if (_isProcessing || _hasRequested) return;
    final uid = currentUserUid;
    if (uid.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      await SupaFlow.client.from('contact_requests').insert({
        'from_user_id': uid,
        'to_user_id': widget.userId!,
        'status': 'pending'
      });
      if (mounted)
        setState(() {
          _hasRequested = true;
          _isProcessing = false;
        });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Solicitud enviada'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _follow() async {
    if (_isProcessing) return;
    final uid = currentUserUid;
    if (uid.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      if (_isFollowing) {
        await SupaFlow.client
            .from('follows')
            .delete()
            .eq('follower_id', uid)
            .eq('following_id', widget.userId!);
        if (mounted) setState(() => _isFollowing = false);
      } else {
        await SupaFlow.client
            .from('follows')
            .insert({'follower_id': uid, 'following_id': widget.userId!});
        if (mounted) setState(() => _isFollowing = true);
      }
      if (mounted) setState(() => _isProcessing = false);
    } catch (_) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    if (_isLoading)
      return Container(
          color: Colors.white,
          child: Center(
              child: CircularProgressIndicator(color: Color(0xFF0D3B66))));

    final name = _userData?['name'] ?? _userData?['nombre'] ?? 'Usuario';
    final user = _userData?['username'] ?? '@usuario';
    final bio = _userData?['bio'] ?? _userData?['descripcion'] ?? '';
    final photo = _userData?['photo_url'] ?? '';
    final cover = _userData?['cover_url'] ?? _userData?['banner_url'] ?? '';

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                              color: Colors.grey[400],
                              image: cover.isNotEmpty
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(cover),
                                      fit: BoxFit.cover)
                                  : null)),
                      SafeArea(
                          child: Padding(
                              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _iconBtn(Icons.settings, null),
                                    Row(children: [
                                      _iconBtn(Icons.notifications, null),
                                      SizedBox(width: 10),
                                      _iconBtn(Icons.message, null)
                                    ])
                                  ]))),
                      Positioned(
                          left: 20,
                          bottom: -60,
                          child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                  color: Color(0xFFE0E0E0),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 4),
                                  image: photo.isNotEmpty
                                      ? DecorationImage(
                                          image:
                                              CachedNetworkImageProvider(photo),
                                          fit: BoxFit.cover)
                                      : null),
                              child: photo.isEmpty
                                  ? Icon(Icons.person_outline,
                                      size: 60, color: Colors.grey[600])
                                  : null))
                    ]),
                    SizedBox(height: 70),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          Expanded(
                              child: ElevatedButton(
                                  onPressed: _hasRequested ? null : _request,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: _hasRequested
                                          ? Colors.grey
                                          : Color(0xFF0D3B66),
                                      disabledBackgroundColor: Colors.grey,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8))),
                                  child: _isProcessing && !_isFollowing
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : Text(
                                          _hasRequested
                                              ? 'Solicitado'
                                              : 'Solicitar Contacto',
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)))),
                          SizedBox(width: 10),
                          Expanded(
                              child: ElevatedButton(
                                  onPressed: _follow,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFollowing
                                          ? Colors.grey
                                          : Color(0xFF0D3B66),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8))),
                                  child: Text(
                                      _isFollowing ? 'Siguiendo' : 'Seguir',
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white))))
                        ])),
                    Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Text(name,
                            style: GoogleFonts.inter(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF444444)))),
                    Padding(
                        padding: EdgeInsets.fromLTRB(16, 5, 16, 0),
                        child: Text(user.startsWith('@') ? user : '@$user',
                            style: GoogleFonts.inter(
                                fontSize: 15, color: Color(0xFF444444)))),
                    if (bio.isNotEmpty)
                      Padding(
                          padding: EdgeInsets.fromLTRB(16, 15, 16, 0),
                          child: Text(bio,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Color(0xFF444444),
                                  height: 1.4))),
                    if (_colabs.isNotEmpty) ...[
                      Padding(
                          padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: Text('Colaboraciones destacadas:',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF444444)))),
                      Padding(
                          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _colabs
                                  .map((c) => Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border:
                                              Border.all(color: Colors.grey)),
                                      child: Text(c,
                                          style:
                                              GoogleFonts.inter(fontSize: 12))))
                                  .toList()))
                    ],
                    Padding(
                        padding: EdgeInsets.fromLTRB(0, 30, 0, 10),
                        child: Center(
                            child: Text('Historial de Scouting',
                                style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0D3B66),
                                    decoration: TextDecoration.underline)))),
                    _list(),
                    SizedBox(height: 100)
                  ]),
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

  Widget _iconBtn(IconData i, VoidCallback? t) => GestureDetector(
      onTap: t,
      child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
          child: Icon(i, color: Colors.black, size: 24)));

  Widget _list() {
    if (_scoutHistory.isEmpty)
      return Padding(
          padding: EdgeInsets.all(40),
          child: Center(
              child: Text('No hay historial de scouting',
                  style: TextStyle(color: Colors.grey))));
    return ListView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(horizontal: 16),
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
        margin: EdgeInsets.only(bottom: 15),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Color(0xFFB5BECA))),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name.isNotEmpty ? name : 'Jugador',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(info,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
                SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.remove_red_eye,
                      size: 14, color: Color(0xFF444444)),
                  SizedBox(width: 4),
                  Expanded(
                      child: Text(
                          item['club_fichado'] != null
                              ? 'Fichado: ${_date(item['created_at'])}'
                              : 'Agregado: ${_date(item['created_at'])}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.grey)))
                ])
              ]))
        ]));
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
}
