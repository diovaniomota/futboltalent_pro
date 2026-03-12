import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/guardian/guardian_mvp_service.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
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
  List<Map<String, dynamic>> _playerVideos = [];
  List<String> _colabs = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  String _contactRequestStatus = '';
  String? _contactRequestId;
  bool _isProcessing = false;
  bool _isGuardado = false;
  bool _isGuardando = false;
  bool _isMinor = false;
  String? _guardianName;
  String? _guardianId;
  String _guardianStatus = GuardianMvpService.approvedStatus;

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
        _guardianStatus = GuardianMvpService.normalizedGuardianStatus(u);
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
      await _loadPlayerVideos();
      // Check if minor
      if (u != null && u['is_minor'] == true) {
        _isMinor = true;
        final guardian = await SupaFlow.client
            .from('guardians')
            .select('id, name, status')
            .eq('player_id', widget.userId!)
            .maybeSingle();
        _guardianId = guardian?['id']?.toString();
        _guardianName = guardian?['name'];
        final guardianStatus = guardian?['status']?.toString().trim();
        if (guardianStatus != null && guardianStatus.isNotEmpty) {
          _guardianStatus = guardianStatus.toLowerCase();
        }
      }
      await _checkStatus();
      await _loadHistory();
      await _checkGuardado();
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPlayerVideos() async {
    if (widget.userId == null || widget.userId!.isEmpty) return;
    try {
      final response = await SupaFlow.client
          .from('videos')
          .select()
          .eq('user_id', widget.userId!)
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(60);
      _playerVideos = List<Map<String, dynamic>>.from(response)
          .where((video) => GuardianMvpService.isVideoVisibleToPublic(
                video,
                ownerData: _userData,
              ))
          .toList();
    } catch (_) {
      try {
        final response = await SupaFlow.client
            .from('videos')
            .select()
            .eq('user_id', widget.userId!)
            .eq('is_public', true)
            .order('created_at', ascending: false)
            .limit(60);
        _playerVideos = List<Map<String, dynamic>>.from(response)
            .where((video) => GuardianMvpService.isVideoVisibleToPublic(
                  video,
                  ownerData: _userData,
                ))
            .toList();
      } catch (_) {
        _playerVideos = [];
      }
    }
  }

  String? _firstNonEmptyValue(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  String? _birthYearFromRaw(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed.year.toString();
    final match = RegExp(r'(\d{4})').firstMatch(text);
    return match?.group(1);
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

  bool _isChallengeVideo(Map<String, dynamic> video) {
    final description = video['description']?.toString() ?? '';
    if (_parseChallengeRef(description) != null) return true;

    final title = video['title']?.toString().trim().toLowerCase() ?? '';
    return title.startsWith('desafío:') ||
        title.startsWith('desafio:') ||
        title.startsWith('challenge:');
  }

  String get _viewerType => FFAppState().userType;

  bool get _viewerCanSavePlayers =>
      _viewerType == 'profesional' || _viewerType == 'club';

  bool get _isTargetPlayer {
    final role = _userData?['userType']?.toString().toLowerCase().trim() ?? '';
    return role == 'jugador' ||
        role == 'jogador' ||
        role == 'player' ||
        role == 'athlete' ||
        role == 'atleta';
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
      final requests = await SupaFlow.client
          .from('contact_requests')
          .select('id, status, created_at')
          .eq('from_user_id', uid)
          .eq('to_user_id', widget.userId!)
          .order('created_at', ascending: false)
          .limit(1);

      final latest = (requests as List).isNotEmpty
          ? Map<String, dynamic>.from(requests.first)
          : null;
      final normalizedStatus =
          latest?['status']?.toString().toLowerCase().trim() ?? '';

      if (mounted)
        setState(() {
          _isFollowing = f != null;
          _contactRequestId = latest?['id']?.toString();
          _contactRequestStatus = normalizedStatus;
        });
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final lists = await SupaFlow.client
          .from('listas')
          .select('id')
          .eq('profesional_id', widget.userId!);
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
    if (_isProcessing) return;
    final uid = currentUserUid;
    if (uid.isEmpty) return;
    if (_isLimitedMinorProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este perfil de menor todavía está en validación del responsable. El contacto directo sigue bloqueado.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      if (_contactRequestId != null &&
          _contactRequestId!.isNotEmpty &&
          (_contactRequestStatus == 'rejected' ||
              _contactRequestStatus == 'rechazado' ||
              _contactRequestStatus == 'recusado')) {
        try {
          await SupaFlow.client.from('contact_requests').update({
            'status': 'pending',
            'guardian_notified': _isMinor,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', _contactRequestId!);
        } catch (_) {
          await SupaFlow.client.from('contact_requests').update({
            'status': 'pending',
            'guardian_notified': _isMinor,
          }).eq('id', _contactRequestId!);
        }
      } else {
        final payload = <String, dynamic>{
          'from_user_id': uid,
          'to_user_id': widget.userId!,
          'status': 'pending',
          'guardian_notified': _isMinor,
          if (_guardianId != null && _guardianId!.isNotEmpty)
            'guardian_id': _guardianId,
        };
        try {
          await SupaFlow.client.from('contact_requests').insert(payload);
        } catch (_) {
          payload.remove('guardian_id');
          await SupaFlow.client.from('contact_requests').insert(payload);
        }
      }

      await _checkStatus();
      if (mounted) setState(() => _isProcessing = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isMinor
                ? 'Solicitud enviada al responsable del jugador'
                : 'Solicitud enviada'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  bool get _isContactAccepted {
    return _contactRequestStatus == 'accepted' ||
        _contactRequestStatus == 'aceptado' ||
        _contactRequestStatus == 'aprobado';
  }

  bool get _isContactPending => _contactRequestStatus == 'pending';

  bool get _isContactRejected {
    return _contactRequestStatus == 'rejected' ||
        _contactRequestStatus == 'rechazado' ||
        _contactRequestStatus == 'recusado';
  }

  String _contactButtonLabel() {
    if (_isContactAccepted) return 'Contacto aprobado';
    if (_isContactPending) return 'Solicitado';
    if (_isLimitedMinorProfile) return 'Protegido';
    if (_isContactRejected) return 'Solicitar nuevamente';
    return 'Solicitar Contacto';
  }

  Color _contactButtonColor() {
    if (_isContactAccepted) return const Color(0xFF15803D);
    if (_isContactPending) return Colors.grey;
    if (_isLimitedMinorProfile) return const Color(0xFF9CA3AF);
    return const Color(0xFF0D3B66);
  }

  bool get _isLimitedMinorProfile {
    return _isMinor && GuardianMvpService.isLimitedProfile(_userData);
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

  Future<void> _checkGuardado() async {
    final uid = currentUserUid;
    if (uid.isEmpty || widget.userId == null) return;
    if (!_viewerCanSavePlayers) return;
    try {
      var result = await SupaFlow.client
          .from('jugadores_guardados')
          .select('id')
          .eq('scout_id', uid)
          .eq('jugador_id', widget.userId!)
          .maybeSingle();
      if (result == null && _viewerType == 'club') {
        try {
          result = await SupaFlow.client
              .from('jugadores_guardados')
              .select('id')
              .eq('club_id', uid)
              .eq('jugador_id', widget.userId!)
              .maybeSingle();
        } catch (_) {}
      }
      if (mounted) setState(() => _isGuardado = result != null);
    } catch (_) {}
  }

  Future<void> _toggleGuardarJugador() async {
    if (_isGuardando) return;
    final uid = currentUserUid;
    if (uid.isEmpty || widget.userId == null) return;
    setState(() => _isGuardando = true);
    try {
      if (_isGuardado) {
        await SupaFlow.client
            .from('jugadores_guardados')
            .delete()
            .eq('scout_id', uid)
            .eq('jugador_id', widget.userId!);
        if (_viewerType == 'club') {
          try {
            await SupaFlow.client
                .from('jugadores_guardados')
                .delete()
                .eq('club_id', uid)
                .eq('jugador_id', widget.userId!);
          } catch (_) {}
        }
        if (mounted) setState(() => _isGuardado = false);
      } else {
        if (_viewerType == 'club') {
          try {
            await SupaFlow.client.from('jugadores_guardados').insert({
              'club_id': uid,
              'jugador_id': widget.userId!,
            });
          } catch (_) {
            await SupaFlow.client.from('jugadores_guardados').insert({
              'scout_id': uid,
              'jugador_id': widget.userId!,
            });
          }
        } else {
          await SupaFlow.client.from('jugadores_guardados').insert({
            'scout_id': uid,
            'jugador_id': widget.userId!,
          });
        }
        if (mounted) setState(() => _isGuardado = true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isGuardado ? 'Jugador guardado' : 'Jugador removido'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isGuardando = false);
  }

  Future<void> _showAddToListSheet() async {
    final uid = currentUserUid;
    if (uid.isEmpty || widget.userId == null) return;
    if (!_viewerCanSavePlayers) return;
    if (!_isGuardado) await _toggleGuardarJugador();
    try {
      final isClubViewer = _viewerType == 'club';
      List<Map<String, dynamic>> listas = [];
      String? clubIdForCreation;

      if (isClubViewer) {
        final managedClubIds = <String>{uid};

        try {
          final ownedClubs = await SupaFlow.client
              .from('clubs')
              .select('id')
              .eq('owner_id', uid)
              .limit(20);
          for (final row in (ownedClubs as List)) {
            final id = row['id']?.toString().trim() ?? '';
            if (id.isNotEmpty) managedClubIds.add(id);
          }
        } catch (_) {}

        try {
          final staffClubs = await SupaFlow.client
              .from('club_staff')
              .select('club_id')
              .eq('user_id', uid)
              .limit(50);
          for (final row in (staffClubs as List)) {
            final id = row['club_id']?.toString().trim() ?? '';
            if (id.isNotEmpty) managedClubIds.add(id);
          }
        } catch (_) {}

        final raw = await SupaFlow.client
            .from('listas_club')
            .select()
            .order('created_at', ascending: false)
            .limit(250);

        listas = List<Map<String, dynamic>>.from(raw).where((lista) {
          final clubId = lista['club_id']?.toString().trim() ?? '';
          return clubId.isNotEmpty && managedClubIds.contains(clubId);
        }).toList();

        if (listas.isNotEmpty) {
          clubIdForCreation = listas.first['club_id']?.toString();
        } else {
          clubIdForCreation =
              managedClubIds.firstWhere((id) => id != uid, orElse: () => uid);
        }
      } else {
        final raw = await SupaFlow.client
            .from('listas')
            .select()
            .eq('profesional_id', uid)
            .order('created_at', ascending: false);
        listas = List<Map<String, dynamic>>.from(raw);
      }

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _AddToListBottomSheet(
          listas: listas,
          jugadorId: widget.userId!,
          scoutId: uid,
          isClubOwner: isClubViewer,
          clubIdForCreation: clubIdForCreation,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;
    final actionButtonWidth =
        ((screenWidth - (horizontalPadding * 2) - 10).clamp(220.0, 640.0)) / 2;
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
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
                                          image:
                                              CachedNetworkImageProvider(cover),
                                          fit: BoxFit.cover)
                                      : null)),
                          SafeArea(
                              child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      horizontalPadding, 10, 0, 0),
                                  child: Row(children: [
                                    _iconBtn(Icons.arrow_back_rounded, () {
                                      context.safePop();
                                    }),
                                  ]))),
                          Positioned(
                              left: horizontalPadding + 4,
                              bottom: -60,
                              child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                      color: Color(0xFFE0E0E0),
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
                                          size: 60, color: Colors.grey[600])
                                      : null))
                        ]),
                        SizedBox(height: 70),
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: actionButtonWidth,
                                  child: ElevatedButton(
                                      onPressed: (_isContactPending ||
                                              _isContactAccepted ||
                                              _isLimitedMinorProfile)
                                          ? null
                                          : _request,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              _contactButtonColor(),
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
                                          : Text(_contactButtonLabel(),
                                              style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white))),
                                ),
                                SizedBox(
                                  width: actionButtonWidth,
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
                                              color: Colors.white))),
                                ),
                              ],
                            )),
                        if (_isContactAccepted)
                          Padding(
                              padding: EdgeInsets.fromLTRB(
                                  horizontalPadding, 10, horizontalPadding, 0),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAFBEF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF86EFAC),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF15803D),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _isMinor
                                            ? 'La solicitud fue aprobada por el responsable. Ya podés avanzar con el contacto.'
                                            : 'La solicitud fue aprobada por el jugador. Ya podés avanzar con el contacto.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF166534),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        if (_viewerCanSavePlayers && _isTargetPlayer)
                          Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding, vertical: 8),
                              child:
                                  Wrap(spacing: 10, runSpacing: 10, children: [
                                SizedBox(
                                  width: actionButtonWidth,
                                  child: ElevatedButton.icon(
                                      onPressed: _isGuardando
                                          ? null
                                          : _toggleGuardarJugador,
                                      icon: Icon(
                                          _isGuardado
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          color: Colors.white),
                                      label: Text(
                                          _isGuardado
                                              ? 'Guardado'
                                              : 'Guardar Jugador',
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: _isGuardado
                                              ? const Color(0xFF38A169)
                                              : const Color(0xFF0D3B66),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)))),
                                ),
                                SizedBox(
                                  width: actionButtonWidth,
                                  child: ElevatedButton.icon(
                                      onPressed: _showAddToListSheet,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF818181),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12)),
                                      icon: const Icon(Icons.playlist_add,
                                          color: Colors.white),
                                      label: Text('Agregar a lista',
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white))),
                                ),
                              ])),
                        Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalPadding, 20, horizontalPadding, 0),
                            child: Text(name,
                                style: GoogleFonts.inter(
                                    fontSize: screenWidth < 380 ? 26 : 30,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF444444)))),
                        Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalPadding, 5, horizontalPadding, 0),
                            child: Text(user.startsWith('@') ? user : '@$user',
                                style: GoogleFonts.inter(
                                    fontSize: 15, color: Color(0xFF444444)))),
                        if (_isMinor)
                          Padding(
                              padding: EdgeInsets.fromLTRB(
                                  horizontalPadding, 10, horizontalPadding, 0),
                              child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: Color(0xFFFFF3CD),
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Color(0xFFFFD93D))),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield,
                                            color: Color(0xFF856404), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                            _guardianName != null
                                                ? 'Menor de edad · Responsable: $_guardianName · ${_guardianStatus == GuardianMvpService.approvedStatus ? 'Aprobado' : 'Pendiente'}'
                                                : 'Menor de edad · Contacto vía responsable',
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Color(0xFF856404),
                                                fontWeight: FontWeight.w500)),
                                      ]))),
                        if (_isLimitedMinorProfile)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              10,
                              horizontalPadding,
                              0,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Text(
                                'El perfil está en modo protegido hasta que el responsable apruebe el acceso. Mientras tanto no se muestran videos públicos ni se habilita el contacto directo.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ),
                        if (bio.isNotEmpty)
                          Padding(
                              padding: EdgeInsets.fromLTRB(
                                  horizontalPadding, 15, horizontalPadding, 0),
                              child: Text(bio,
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: Color(0xFF444444),
                                      height: 1.4))),
                        if (_colabs.isNotEmpty) ...[
                          Padding(
                              padding: EdgeInsets.fromLTRB(
                                  horizontalPadding, 20, horizontalPadding, 0),
                              child: Text('Colaboraciones destacadas:',
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF444444)))),
                          Padding(
                              padding: EdgeInsets.fromLTRB(
                                  horizontalPadding, 10, horizontalPadding, 0),
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
                                              border: Border.all(
                                                  color: Colors.grey)),
                                          child: Text(c,
                                              style: GoogleFonts.inter(
                                                  fontSize: 12))))
                                      .toList()))
                        ],
                        _buildFichaDeportivaSection(),
                        _buildVideosSection(),
                        if (_scoutHistory.isNotEmpty) ...[
                          Padding(
                              padding: EdgeInsets.fromLTRB(0, 20, 0, 10),
                              child: Center(
                                  child: Text('Historial de Scouting',
                                      style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF0D3B66),
                                          decoration:
                                              TextDecoration.underline)))),
                          _list(),
                        ],
                        SizedBox(height: 100)
                      ]),
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

  Widget _iconBtn(IconData i, VoidCallback? t) => GestureDetector(
      onTap: t,
      child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
          child: Icon(i, color: Colors.black, size: 24)));

  Widget _buildFichaDeportivaSection() {
    final position = _firstNonEmptyValue([
      _userData?['position'],
      _userData?['posicion'],
      _userData?['posição'],
      _userData?['position_name'],
    ]);
    final dominantFoot = _firstNonEmptyValue([
      _userData?['dominant_foot'],
      _userData?['pie_dominante'],
      _userData?['pierna_habil'],
      _userData?['perna_habil'],
      _userData?['foot'],
    ]);
    final birthDateRaw = _firstNonEmptyValue([
      _userData?['birth_date'],
      _userData?['birthday'],
      _userData?['fecha_nacimiento'],
      _userData?['data_nascimento'],
    ]);
    final category = _birthYearFromRaw(birthDateRaw);
    final height = _firstNonEmptyValue([
      _userData?['height'],
      _userData?['altura'],
      _userData?['estatura'],
    ]);
    final weight = _firstNonEmptyValue([
      _userData?['weight'],
      _userData?['peso'],
    ]);
    final country = _firstNonEmptyValue([
      _userData?['country'],
      _userData?['pais'],
      _userData?['país'],
      _userData?['nationality'],
      _userData?['nacionalidad'],
    ]);
    final city = _firstNonEmptyValue([
      _userData?['city'],
      _userData?['location'],
      _userData?['lugar'],
      _userData?['cidade'],
    ]);
    final club = _firstNonEmptyValue([
      _userData?['club'],
      _userData?['club_actual'],
      _userData?['current_club'],
    ]);

    Widget dataTile(IconData icon, String label, dynamic rawValue) {
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0D3B66)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label: $value',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ficha deportiva',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 10),
          dataTile(Icons.shield_outlined, 'Posición', position),
          dataTile(Icons.directions_walk, 'Pierna hábil', dominantFoot),
          dataTile(Icons.category_outlined, 'Categoría', category),
          dataTile(
            Icons.height,
            'Altura',
            height != null ? '$height cm' : null,
          ),
          dataTile(
            Icons.fitness_center_outlined,
            'Peso',
            weight != null ? '$weight kg' : null,
          ),
          dataTile(Icons.flag_outlined, 'Nacionalidad / País', country),
          dataTile(Icons.location_on_outlined, 'Ciudad', city),
          dataTile(Icons.groups_outlined, 'Club', club),
          if (position == null &&
              dominantFoot == null &&
              category == null &&
              birthDateRaw == null &&
              height == null &&
              weight == null &&
              country == null &&
              city == null &&
              club == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Este jugador todavía no completó su ficha deportiva.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideosSection() {
    final challengeVideos = _playerVideos.where(_isChallengeVideo).toList();
    final ugcVideos =
        _playerVideos.where((v) => !_isChallengeVideo(v)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Videos',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _playerVideos.isEmpty
                ? 'Este jugador todavía no subió videos.'
                : '${_playerVideos.length} video(s) subido(s) · ${challengeVideos.length} desafío(s) · ${ugcVideos.length} UGC',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          _buildVideoGroup(
            title: 'Videos de desafíos',
            videos: challengeVideos,
            emptyMessage: 'Este jugador no subió videos de desafíos todavía.',
          ),
          const SizedBox(height: 12),
          _buildVideoGroup(
            title: 'Videos UGC',
            videos: ugcVideos,
            emptyMessage: 'Este jugador no subió videos UGC todavía.',
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGroup({
    required String title,
    required List<Map<String, dynamic>> videos,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${videos.length})',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        if (videos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    emptyMessage,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final video = videos[index];
                final thumb = _firstNonEmptyValue([
                      video['thumbnail_url'],
                      video['thumbnail'],
                    ]) ??
                    '';
                final title =
                    (video['title']?.toString().trim().isNotEmpty ?? false)
                        ? video['title'].toString()
                        : 'Video ${index + 1}';
                final url = video['video_url']?.toString() ?? '';

                return InkWell(
                  onTap: url.isEmpty
                      ? null
                      : () => showDialog<void>(
                            context: context,
                            builder: (_) => _PublicVideoPlayerDialog(
                                title: title, url: url),
                          ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 210,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Container(
                              width: double.infinity,
                              color: const Color(0xFF0F172A),
                              child: thumb.isNotEmpty
                                  ? Image.network(
                                      thumb,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
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
    );
  }

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

// ===== BOTTOM SHEET: AGREGAR A LISTA =====
class _AddToListBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> listas;
  final String jugadorId;
  final String scoutId;
  final bool isClubOwner;
  final String? clubIdForCreation;
  const _AddToListBottomSheet({
    required this.listas,
    required this.jugadorId,
    required this.scoutId,
    required this.isClubOwner,
    this.clubIdForCreation,
  });
  @override
  State<_AddToListBottomSheet> createState() => _AddToListBottomSheetState();
}

class _AddToListBottomSheetState extends State<_AddToListBottomSheet> {
  final _notaCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _addToList(String listaId) async {
    setState(() => _saving = true);
    try {
      final normalizedListaId = listaId.toString().trim();
      if (normalizedListaId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lista inválida')),
          );
        }
        setState(() => _saving = false);
        return;
      }

      final existing = await SupaFlow.client
          .from('listas_jugadores')
          .select('id')
          .eq('lista_id', normalizedListaId)
          .eq('jugador_id', widget.jugadorId)
          .maybeSingle();
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jugador ya está en esta lista')),
          );
        }
        setState(() => _saving = false);
        return;
      }
      await SupaFlow.client.from('listas_jugadores').insert({
        'lista_id': normalizedListaId,
        'jugador_id': widget.jugadorId,
        'nota': _notaCtrl.text,
        'calificacion': 3,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jugador agregado a la lista'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final msg = e.toString();
      final isFkListError = msg.contains('listas_jugadores_lista_id_fkey');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFkListError
                  ? 'No se pudo agregar: la lista seleccionada no está disponible para este perfil.'
                  : 'No se pudo agregar el jugador a la lista.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _createAndAdd() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Lista'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'Nombre de la lista'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      try {
        final ownerKey = widget.isClubOwner ? 'club_id' : 'profesional_id';
        final ownerValue = widget.isClubOwner
            ? (widget.clubIdForCreation ?? widget.scoutId)
            : widget.scoutId;
        final res = await SupaFlow.client
            .from(widget.isClubOwner ? 'listas_club' : 'listas')
            .insert({
              ownerKey: ownerValue,
              'nombre': name.trim(),
            })
            .select()
            .single();
        await _addToList(res['id']);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Agregar a Lista',
              style:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _notaCtrl,
            decoration: const InputDecoration(
              hintText: 'Nota sobre el jugador (opcional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          if (widget.listas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No tienes listas aún',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: widget.listas
                    .map((lista) => ListTile(
                          title: Text(lista['nombre'] ?? 'Lista'),
                          subtitle: Text(
                            lista['descripcion'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add_circle_outline),
                          onTap: _saving ? null : () => _addToList(lista['id']),
                        ))
                    .toList(),
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle, color: Color(0xFF0D3B66)),
            title: const Text('Crear nueva lista y agregar'),
            onTap: _saving ? null : _createAndAdd,
          ),
        ],
      ),
    );
  }
}

class _PublicVideoPlayerDialog extends StatefulWidget {
  const _PublicVideoPlayerDialog({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<_PublicVideoPlayerDialog> createState() =>
      _PublicVideoPlayerDialogState();
}

class _PublicVideoPlayerDialogState extends State<_PublicVideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0B1220),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio:
                    (_controller != null && _controller!.value.isInitialized)
                        ? _controller!.value.aspectRatio
                        : 16 / 9,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _hasError || _controller == null
                        ? Center(
                            child: Text(
                              'No se pudo reproducir el video.',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 13,
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
                                  onTap: () {
                                    if (_controller == null) return;
                                    if (_controller!.value.isPlaying) {
                                      _controller!.pause();
                                    } else {
                                      _controller!.play();
                                    }
                                    setState(() {});
                                  },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      _controller!.value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
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
