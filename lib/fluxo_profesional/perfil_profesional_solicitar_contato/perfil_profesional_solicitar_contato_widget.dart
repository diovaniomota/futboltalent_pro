import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/fluxo_compartilhado/player_public_progress_service.dart';
import '/fluxo_compartilhado/profile_history_utils.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/guardian/guardian_mvp_service.dart';
import '/gamification/gamification_service.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'dart:convert';
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
  String _selectedProfileTabKey = 'perfil';

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

  List<String> _parseCollaborations(dynamic rawValue) {
    if (rawValue is List) {
      return rawValue
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final text = rawValue?.toString().trim() ?? '';
    if (text.isEmpty) return [];

    if (text.startsWith('[') && text.endsWith(']')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
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
        final merged = <String, dynamic>{...u};
        var targetType = (u['userType']?.toString().trim().toLowerCase() ?? '');
        if (const ['jugador', 'jogador', 'player', 'athlete', 'atleta']
            .contains(targetType)) {
          targetType = 'jugador';
        }
        if (targetType == 'jugador') {
          try {
            final player = await SupaFlow.client
                .from('players')
                .select()
                .eq('id', widget.userId!)
                .maybeSingle();
            if (player != null) {
              _mergePlayerProfileData(
                merged,
                Map<String, dynamic>.from(player),
              );
            }
          } catch (_) {}
          Map<String, dynamic>? recalculatedProgress;
          if (currentUserUid == widget.userId) {
            try {
              recalculatedProgress =
                  await GamificationService.recalculateUserProgress(
                      userId: widget.userId!);
            } catch (_) {}
          }
          try {
            final progress = await PlayerPublicProgressService.loadOne(
                  widget.userId!,
                ) ??
                recalculatedProgress;
            if (progress != null) {
              merged.addAll(Map<String, dynamic>.from(progress));
            }
          } catch (_) {}
        } else if (targetType == 'profesional') {
          try {
            final scout = await SupaFlow.client
                .from('scouts')
                .select()
                .eq('id', widget.userId!)
                .maybeSingle();
            if (scout != null) {
              merged.addAll(Map<String, dynamic>.from(scout));
              if ((merged['bio']?.toString().trim().isEmpty ?? true) &&
                  (scout['biography']?.toString().trim().isNotEmpty ?? false)) {
                merged['bio'] = scout['biography'];
              }
            }
          } catch (_) {}
        }
        _userData = merged;
        _selectedProfileTabKey = targetType == 'jugador' ? 'videos' : 'perfil';
        _guardianStatus = GuardianMvpService.normalizedGuardianStatus(merged);
        if (merged['colaboraciones'] != null) {
          _colabs = _parseCollaborations(merged['colaboraciones']);
        }
        if (_isTargetPlayer) {
          await _registerProfileView();
        }
      }
      // Check if minor and load guardian before loading videos to ensure proper visibility
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
          _userData?['guardian_status'] = _guardianStatus;
        }
      }

      await _loadPlayerVideos();
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
      _playerVideos = _sortPublicVideos(
        List<Map<String, dynamic>>.from(response).where(
          (video) => GuardianMvpService.isVideoVisibleToPublic(
            video,
            ownerData: _userData,
          ),
        ),
      );
    } catch (_) {
      try {
        final response = await SupaFlow.client
            .from('videos')
            .select()
            .eq('user_id', widget.userId!)
            .eq('is_public', true)
            .order('created_at', ascending: false)
            .limit(60);
        _playerVideos = _sortPublicVideos(
          List<Map<String, dynamic>>.from(response).where(
            (video) => GuardianMvpService.isVideoVisibleToPublic(
              video,
              ownerData: _userData,
            ),
          ),
        );
      } catch (_) {
        _playerVideos = [];
      }
    }
  }

  void _openPlayerVideoFeed(int selectedIndex) {
    if (_playerVideos.isEmpty || selectedIndex >= _playerVideos.length) return;

    final selectedVideo = _playerVideos[selectedIndex];
    final reorderedVideos = <Map<String, dynamic>>[
      Map<String, dynamic>.from(selectedVideo),
      ..._playerVideos
          .where((video) =>
              video['id']?.toString() != selectedVideo['id']?.toString())
          .map((video) => Map<String, dynamic>.from(video)),
    ];

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _PublicPlayerVideoFeedScreen(videos: reorderedVideos),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _registerProfileView() async {
    final playerId = widget.userId?.trim() ?? '';
    if (playerId.isEmpty ||
        currentUserUid.isEmpty ||
        currentUserUid == playerId) {
      return;
    }

    if (_viewerType != 'profesional' && _viewerType != 'club') {
      return;
    }

    try {
      await SupaFlow.client.rpc(
        'register_player_profile_view',
        params: <String, dynamic>{'p_player_user_id': playerId},
      );
    } catch (e) {
      debugPrint('Profile view register skipped: $e');
    }
  }

  void _mergePlayerProfileData(
    Map<String, dynamic> target,
    Map<String, dynamic> player,
  ) {
    for (final entry in player.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == 'id' && _hasMeaningfulProfileValue(target['user_id'])) {
        target['player_id'] = value;
        continue;
      }
      if (!_hasMeaningfulProfileValue(value) &&
          _hasMeaningfulProfileValue(target[key])) {
        continue;
      }
      target[key] = value;
    }
  }

  bool _hasMeaningfulProfileValue(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      final text = value.trim().toLowerCase();
      return text.isNotEmpty && text != 'null';
    }
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
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

  String? _formatBirthDateDisplay(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  int _intValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String? _firstPositiveMetricValue(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty || text.toLowerCase() == 'null') continue;
      final parsed = double.tryParse(text.replaceAll(',', '.'));
      if (parsed == null || parsed <= 0) continue;
      if (parsed == parsed.roundToDouble()) return parsed.round().toString();
      return parsed.toStringAsFixed(1);
    }
    return null;
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
    final persistedType =
        (video['videoType'] ?? video['video_type'] ?? video['type'])
            ?.toString()
            .trim()
            .toLowerCase();
    if (persistedType == 'challenge') return true;
    if (persistedType == 'ugc') return false;

    final description = video['description']?.toString() ?? '';
    if (_parseChallengeRef(description) != null) return true;

    final title = video['title']?.toString().trim().toLowerCase() ?? '';
    return title.startsWith('desafío:') ||
        title.startsWith('desafio:') ||
        title.startsWith('challenge:');
  }

  bool _isFeaturedVideo(Map<String, dynamic> video) {
    final raw = video['featured_in_explorer'] ??
        video['is_featured'] ??
        video['explorer_featured'] ??
        video['highlighted'];
    if (raw is bool) return raw;
    final text = raw?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'sim';
  }

  List<Map<String, dynamic>> _sortPublicVideos(
    Iterable<Map<String, dynamic>> videos,
  ) {
    final ordered =
        videos.map((video) => Map<String, dynamic>.from(video)).toList();
    ordered.sort((a, b) {
      final featuredCompare =
          (_isFeaturedVideo(b) ? 1 : 0) - (_isFeaturedVideo(a) ? 1 : 0);
      if (featuredCompare != 0) return featuredCompare;

      final createdAtA = a['created_at']?.toString() ?? '';
      final createdAtB = b['created_at']?.toString() ?? '';
      return createdAtB.compareTo(createdAtA);
    });
    return ordered;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos enviar tu solicitud. Verifica tu conexión e intenta de nuevo.'),
            backgroundColor: Colors.red));
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

  String _contactButtonLabel({bool compact = false}) {
    if (_isContactAccepted) return compact ? 'Aprobado' : 'Contacto aprobado';
    if (_isContactPending) return 'Solicitado';
    if (_isLimitedMinorProfile) return 'Protegido';
    if (_isContactRejected) {
      return compact ? 'Reenviar' : 'Solicitar nuevamente';
    }
    return compact ? 'Solicitar' : 'Solicitar contacto';
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
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isGuardado
              ? 'Jugador agregado a mi Scouting'
              : 'Jugador eliminado de mi Scouting'),
          backgroundColor: _isGuardado ? Colors.green : const Color(0xFF475569),
          action: _isGuardado
              ? SnackBarAction(
                  label: 'Ver mi scouting',
                  textColor: Colors.white,
                  onPressed: () {
                    context.pushNamed('Lista_y_notas');
                  },
                )
              : null,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No pudimos agregar el jugador. Verifica tu conexión e intenta de nuevo.'),
              backgroundColor: Colors.red),
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
          const SnackBar(
              content: Text(
                  'No pudimos abrir la lista. Verifica tu conexión e intenta de nuevo.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildResponsiveActionGroup({
    required List<Widget> children,
    double spacing = 8,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep 2-column actions on most phones and only stack on very narrow widths.
        final useColumn = constraints.maxWidth < 280;
        if (useColumn) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                SizedBox(width: double.infinity, child: children[i]),
                if (i != children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActionLabel(
    String label, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.bold,
    Color color = Colors.white,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    final screenWidth = MediaQuery.of(context).size.width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;
    final actionButtonFontSize = screenWidth < 380 ? 13.0 : 14.0;
    final compactActionLabel = screenWidth < 390 || textScale > 1.05;
    if (_isLoading)
      return Container(
          color: Colors.white,
          child: Center(
              child: CircularProgressIndicator(color: Color(0xFF0D3B66))));
    if (_userData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                IconButton(
                  onPressed: () => context.safePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Spacer(),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_search_outlined,
                        size: 46,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No se pudo cargar el perfil público',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Volvé a intentarlo desde los resultados del jugador.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

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
                            child: _buildResponsiveActionGroup(
                              children: [
                                ElevatedButton(
                                  onPressed: (_isContactPending ||
                                          _isContactAccepted ||
                                          _isLimitedMinorProfile)
                                      ? null
                                      : _request,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _contactButtonColor(),
                                    disabledBackgroundColor: Colors.grey,
                                    minimumSize: const Size.fromHeight(46),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isProcessing && !_isFollowing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : _buildActionLabel(
                                          _contactButtonLabel(
                                            compact: compactActionLabel,
                                          ),
                                          fontSize: actionButtonFontSize,
                                        ),
                                ),
                                ElevatedButton(
                                  onPressed: _follow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing
                                        ? Colors.grey
                                        : const Color(0xFF0D3B66),
                                    minimumSize: const Size.fromHeight(46),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _buildActionLabel(
                                    _isFollowing ? 'Siguiendo' : 'Seguir',
                                    fontSize: actionButtonFontSize,
                                  ),
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
                              child: _buildResponsiveActionGroup(
                                children: [
                                  ElevatedButton(
                                    onPressed: _isGuardando
                                        ? null
                                        : _toggleGuardarJugador,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isGuardado
                                          ? const Color(0xFF38A169)
                                          : const Color(0xFF0D3B66),
                                      minimumSize: const Size.fromHeight(46),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isGuardado
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: _buildActionLabel(
                                            _isGuardado
                                                ? 'En mi scouting'
                                                : 'Agregar a scouting',
                                            fontSize: actionButtonFontSize,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _showAddToListSheet,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF818181),
                                      minimumSize: const Size.fromHeight(46),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.playlist_add,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: _buildActionLabel(
                                            'Agregar a lista',
                                            fontSize:
                                                screenWidth < 380 ? 12.5 : 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )),
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
                        _buildPublicTabbedContent(horizontalPadding),
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

  List<Map<String, String>> _publicTabs() {
    if (_isTargetPlayer) {
      return const [
        {'key': 'videos', 'label': 'Videos'},
        {'key': 'ficha', 'label': 'Ficha completa'},
      ];
    }

    return const [
      {'key': 'perfil', 'label': 'Perfil'},
      {'key': 'historial', 'label': 'Historial'},
    ];
  }

  Widget _buildPublicTabSelector(double horizontalPadding) {
    final tabs = _publicTabs();

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _selectedProfileTabKey == tab['key'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedProfileTabKey = tab['key']!);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected
                            ? const Color(0xFF0D3B66)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tab['label']!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0D3B66)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScoutProfessionalSection() {
    final club = _firstNonEmptyValue([
      _userData?['club'],
      _userData?['organization'],
    ]);
    final phone = _firstNonEmptyValue([
      _userData?['telephone'],
      _userData?['phone'],
    ]);
    final url = _firstNonEmptyValue([
      _userData?['url_profesional'],
      _userData?['website'],
    ]);
    final dni = _firstNonEmptyValue([
      _userData?['dni'],
      _userData?['documento'],
    ]);
    final city = _firstNonEmptyValue([
      _userData?['city'],
      _userData?['ciudad'],
    ]);
    final state = _firstNonEmptyValue([
      _userData?['state'],
      _userData?['estado'],
      _userData?['province'],
      _userData?['provincia'],
      _userData?['region'],
    ]);
    final country = _firstNonEmptyValue([
      _userData?['country'],
      _userData?['pais'],
    ]);

    final chips = <Widget>[
      if (club != null)
        _buildProfileInfoTile(Icons.apartment_rounded, 'Organización', club),
      if (phone != null)
        _buildProfileInfoTile(Icons.call_outlined, 'Teléfono', phone),
      if (url != null)
        _buildProfileInfoTile(Icons.language_rounded, 'Link profesional', url),
      if (dni != null)
        _buildProfileInfoTile(Icons.badge_outlined, 'Documento', dni),
      if (city != null || state != null || country != null)
        _buildProfileInfoTile(
          Icons.location_on_outlined,
          'Ubicación',
          [
            if (city != null) city,
            if (state != null && state != city) state,
            if (country != null && country != city && country != state) country,
          ].join(' · '),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perfil profesional',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 10),
          if (chips.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Este scout todavía no completó su ficha profesional.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            )
          else
            ...chips,
        ],
      ),
    );
  }

  Widget _buildProfileInfoTile(IconData icon, String label, String value) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildPublicTabbedContent(double horizontalPadding) {
    return Column(
      children: [
        _buildPublicTabSelector(horizontalPadding),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_selectedProfileTabKey),
            child: () {
              if (_isTargetPlayer) {
                switch (_selectedProfileTabKey) {
                  case 'videos':
                    return _buildVideosSection();
                  case 'ficha':
                  default:
                    return _buildFichaDeportivaSection();
                }
              }

              switch (_selectedProfileTabKey) {
                case 'historial':
                  return _scoutHistory.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: Text(
                            'Este scout todavía no registró historial de scouting.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : _list();
                case 'perfil':
                default:
                  return _buildScoutProfessionalSection();
              }
            }(),
          ),
        ),
      ],
    );
  }

  Widget _buildFichaDeportivaSection() {
    final normalizedHistory = normalizeProfileHistory(
        _userData?['historial_clubes'] ?? _userData?['clubs']);
    final position = normalizePlayerPosition(_firstNonEmptyValue([
      _userData?['position'],
      _userData?['posicion'],
      _userData?['posição'],
      _userData?['position_name'],
    ]));
    final dominantFoot = normalizeDominantFoot(_firstNonEmptyValue([
      _userData?['dominant_foot'],
      _userData?['pie_dominante'],
      _userData?['pierna_habil'],
      _userData?['perna_habil'],
      _userData?['foot'],
    ]));
    final birthDateRaw = _firstNonEmptyValue([
      _userData?['birth_date'],
      _userData?['birthday'],
      _userData?['fecha_nacimiento'],
      _userData?['data_nascimento'],
    ]);
    final category = normalizePlayerCategory(
      _firstNonEmptyValue([
            _userData?['category'],
            _userData?['categoria'],
            _userData?['categoría'],
          ]) ??
          '',
      birthday: birthDateRaw,
    );
    final height = _firstPositiveMetricValue([
      _userData?['height'],
      _userData?['altura'],
      _userData?['estatura'],
    ]);
    final weight = _firstPositiveMetricValue([
      _userData?['weight'],
      _userData?['peso'],
    ]);
    final country = normalizeCountryName(_firstNonEmptyValue([
      _userData?['country'],
      _userData?['pais'],
      _userData?['país'],
      _userData?['nationality'],
      _userData?['nacionalidad'],
    ]));
    final city = normalizeCityName(_firstNonEmptyValue([
      _userData?['city'],
      _userData?['location'],
      _userData?['lugar'],
      _userData?['cidade'],
    ]));
    final club = _firstNonEmptyValue([
      currentClubFromProfileHistory(normalizedHistory),
      _userData?['club'],
      _userData?['club_actual'],
      _userData?['current_club'],
    ]);
    final playerStatus = _firstNonEmptyValue([
      _userData?['player_status'],
    ]);
    final totalXp = _intValue(_userData?['total_xp']);
    final coursesCompleted = _intValue(_userData?['courses_completed']);
    final exercisesCompleted = _intValue(_userData?['exercises_completed']);
    final age = () {
      final year = int.tryParse(_birthYearFromRaw(birthDateRaw) ?? '');
      if (year == null) return null;
      return DateTime.now().year - year;
    }();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFichaSectionHeader('Información personal'),
          const SizedBox(height: 10),
          _buildPlayerPublicInfoRow(
            Icons.calendar_today_outlined,
            birthDateRaw != null && birthDateRaw.isNotEmpty
                ? [
                    _formatBirthDateDisplay(birthDateRaw) ?? birthDateRaw,
                    if (age != null && age >= 0) '$age años',
                  ].join(' · ')
                : null,
          ),
          _buildPlayerPublicInfoRow(Icons.shield_outlined, position),
          _buildPlayerPublicInfoRow(Icons.directions_walk, dominantFoot),
          _buildPlayerPublicInfoRow(Icons.category_outlined, category),
          _buildPlayerPublicInfoRow(
            Icons.height,
            height != null ? '$height cm' : null,
          ),
          _buildPlayerPublicInfoRow(
            Icons.fitness_center_outlined,
            weight != null ? '$weight kg' : null,
          ),
          _buildPlayerPublicInfoRow(Icons.flag_outlined, country),
          _buildPlayerPublicInfoRow(Icons.location_on_outlined, city),
          _buildPlayerPublicInfoRow(Icons.groups_outlined, club),
          _buildPlayerPublicInfoRow(
            Icons.track_changes_rounded,
            playerStatus,
          ),
          if (position.isEmpty &&
              dominantFoot.isEmpty &&
              category.isEmpty &&
              birthDateRaw == null &&
              height == null &&
              weight == null &&
              country.isEmpty &&
              city.isEmpty &&
              club == null &&
              playerStatus == null)
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
          const SizedBox(height: 20),
          _buildFichaSectionHeader('Historial deportivo'),
          const SizedBox(height: 10),
          if (normalizedHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Este jugador todavía no cargó su historial deportivo.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...normalizedHistory.map((item) {
              final name = item['name']?.toString().trim().isNotEmpty == true
                  ? item['name'].toString().trim()
                  : 'Club';
              final period = formatProfileHistoryPeriod(item);
              final itemPosition = _firstNonEmptyValue([
                item['position'],
                item['posicion'],
              ]);
              final note = _firstNonEmptyValue([
                item['note'],
                item['nota'],
              ]);

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.isNotEmpty ? '$name · $period' : name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (itemPosition != null && itemPosition.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          itemPosition,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (note != null && note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          note,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
          _buildFichaSectionHeader('Estadísticas de entrenamiento'),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildPlayerPublicStatCard(
                'Cursos',
                coursesCompleted.toString(),
                Icons.school_outlined,
              ),
              const SizedBox(width: 10),
              _buildPlayerPublicStatCard(
                'Ejercicios',
                exercisesCompleted.toString(),
                Icons.fitness_center_outlined,
              ),
              const SizedBox(width: 10),
              _buildPlayerPublicStatCard(
                'XP',
                totalXp.toString(),
                Icons.bolt_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFichaSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF0D3B66),
      ),
    );
  }

  Widget _buildPlayerPublicInfoRow(IconData icon, String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF444444)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFF444444),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPublicStatCard(
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF0D3B66), size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFF0D3B66),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
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

  Widget _buildVideosSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 960
        ? 4
        : screenWidth >= 520
            ? 4
            : 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_playerVideos.isEmpty)
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
                      'Cuando publique videos, acá se verán en formato de perfil.',
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _playerVideos.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.66,
              ),
              itemBuilder: (context, index) {
                final video = _playerVideos[index];
                final thumb = _firstNonEmptyValue([
                      video['thumbnail_url'],
                      video['thumbnail'],
                      video['cover_url'],
                    ]) ??
                    '';
                final isFeatured = _isFeaturedVideo(video);

                return InkWell(
                  onTap: () => _openPlayerVideoFeed(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (thumb.isNotEmpty)
                                Image.network(
                                  thumb,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFF1E293B),
                                  ),
                                )
                              else
                                Container(color: const Color(0xFF1E293B)),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.05),
                                      Colors.black.withOpacity(0.18),
                                      Colors.black.withOpacity(0.55),
                                    ],
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
                        if (isFeatured)
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
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
    final pos = normalizePlayerPosition(d?['posicion']) == ''
        ? 'Sin posición'
        : normalizePlayerPosition(d?['posicion']);
    final city = normalizeCityName(d?['city']);
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
                              ? 'Agregado: ${_date(item['created_at'])}'
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'No pudimos crear la lista. Verifica tu conexión e intenta de nuevo.'),
              backgroundColor: Colors.red));
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

class _PublicPlayerVideoFeedScreen extends StatefulWidget {
  const _PublicPlayerVideoFeedScreen({required this.videos});

  final List<Map<String, dynamic>> videos;

  @override
  State<_PublicPlayerVideoFeedScreen> createState() =>
      _PublicPlayerVideoFeedScreenState();
}

class _PublicPlayerVideoFeedScreenState
    extends State<_PublicPlayerVideoFeedScreen> {
  late final PageController _pageController;
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

              final video = widget.videos[index];
              return _PublicPlayerVideoFeedItem(
                key: ValueKey(video['id'] ?? video['video_url'] ?? index),
                video: video,
                active: index == _currentIndex,
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
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

class _PublicPlayerVideoFeedItem extends StatefulWidget {
  const _PublicPlayerVideoFeedItem({
    super.key,
    required this.video,
    required this.active,
  });

  final Map<String, dynamic> video;
  final bool active;

  @override
  State<_PublicPlayerVideoFeedItem> createState() =>
      _PublicPlayerVideoFeedItemState();
}

class _PublicPlayerVideoFeedItemState
    extends State<_PublicPlayerVideoFeedItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant _PublicPlayerVideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_isInitialized) return;

    if (widget.active) {
      _controller!.play();
    } else {
      _controller!.pause();
    }
  }

  Future<void> _initVideo() async {
    final url = widget.video['video_url']?.toString().trim() ?? '';
    if (!url.startsWith('http')) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize();
      await _controller!.setLooping(true);
      if (mounted) {
        setState(() => _isInitialized = true);
        if (widget.active) {
          await _controller!.play();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video['title']?.toString().trim();

    if (_hasError) {
      return const Center(
        child: Text(
          'No se pudo reproducir el video',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        if ((title ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title!,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
