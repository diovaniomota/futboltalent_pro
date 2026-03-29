import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/perfil_publico_club/perfil_publico_club_widget.dart';
import '/flutter_flow/app_modals.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/gamification/gamification_service.dart';
import '/guardian/guardian_mvp_service.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'explorar_model.dart';
export 'explorar_model.dart';

enum _ScoutTab { jugadores, clubes, convocatorias }

enum _JugadorSearchTab { jugadores, convocatorias, clubes, scouts }

String _clubRefFromMap(Map<String, dynamic> club) {
  final values = [
    club['id'],
    club['owner_id'],
    club['user_id'],
    club['club_id'],
  ];
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

void _openPublicClubProfile(
  BuildContext context,
  Map<String, dynamic> club,
) {
  final clubRef = _clubRefFromMap(club);
  if (clubRef.isEmpty) return;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PerfilPublicoClubWidget(
        clubRef: clubRef,
        initialClubData: Map<String, dynamic>.from(club),
      ),
    ),
  );
}

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

  String _searchQuery = '';
  bool _isJugadorSearchMode = false;
  _JugadorSearchTab _jugadorSearchTab = _JugadorSearchTab.convocatorias;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _convocatorias = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _recommendedChallenges = [];
  final Set<String> _savedPlayerIds = <String>{};
  String? _savingPlayerId;

  final Map<String, int> _videoCountByUserId = {};
  final Map<String, Map<String, dynamic>> _latestVideoByUserId = {};
  final Map<int, String> _countryNameById = {};

  _ScoutTab _scoutTab = _ScoutTab.jugadores;
  String? _scoutPosition;
  String? _scoutCategory;
  String? _scoutPlayerCountry;
  String? _scoutPlayerCity;
  String? _scoutPlayerLevel;
  String? _scoutClubCountry;
  String? _scoutClubCity;
  String? _scoutClubLeague;
  String? _scoutConvocatoriaCountry;
  String? _scoutConvocatoriaCity;
  String? _scoutConvocatoriaCategory;
  String? _scoutConvocatoriaPosition;
  String? _jugadorPlayerCategory;
  String? _jugadorPlayerPosition;
  String? _jugadorPlayerCountry;
  String? _jugadorPlayerCity;
  String? _jugadorPlayerLevel;
  String? _jugadorConvocatoriaCategory;
  String? _jugadorConvocatoriaPosition;
  String? _jugadorConvocatoriaCountry;
  String? _jugadorClubCountry;
  String? _jugadorClubCity;
  String? _jugadorClubLeague;
  String? _jugadorScoutCountry;

  int? _currentPlanId;
  bool _currentUserVerified = true;
  bool _currentUserFullAccess = false;
  bool _isClubStaff = false;
  Map<String, dynamic>? _nextChallenge;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ExplorarModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadAll();
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadViewerContext();
      await Future.wait([
        _loadUsers(),
        _loadClubs(),
        _loadConvocatorias(),
        _loadVideos(),
        _loadCountries(),
        _loadRecommendedChallenges(),
        _loadSavedPlayersForScout(),
      ]);
      await _loadNextChallenge();
      _decorateUserData();
      _decorateConvocatoriasData();
      await _loadPlayerProgressData();
    } catch (e) {
      _errorMessage = 'Error al cargar Explorer';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadViewerContext() async {
    if (currentUserUid.isEmpty) return;

    try {
      final user = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', currentUserUid)
          .maybeSingle();

      if (user != null) {
        _currentPlanId = user['plan_id'] as int?;
        _currentUserVerified = _resolveViewerVerification(user);
        _currentUserFullAccess = user['full_profile'] == true ||
            user['is_test_account'] == true ||
            user['is_admin'] == true;
      } else {
        _currentUserVerified = true;
        _currentUserFullAccess = false;
      }
    } catch (_) {
      _currentUserVerified = true;
      _currentUserFullAccess = false;
    }

    try {
      final response = await SupaFlow.client
          .from('club_staff')
          .select('id')
          .eq('user_id', currentUserUid)
          .limit(1);
      _isClubStaff = (response as List).isNotEmpty;
    } catch (_) {
      _isClubStaff = false;
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await SupaFlow.client
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .limit(120);

      final all = List<Map<String, dynamic>>.from(response)
          .map((u) => {
                ...u,
                'userType': FFAppState.normalizeUserType(u['userType']),
              })
          .where((u) => !GuardianMvpService.isLimitedProfile(u))
          .where((u) =>
              u['userType'] == 'jugador' || u['userType'] == 'profesional')
          .toList();
      _users = all;
      _players = all
          .where((u) =>
              (u['userType']?.toString().trim().toLowerCase() ?? '') ==
              'jugador')
          .toList();
    } catch (_) {
      _users = [];
      _players = [];
    }
  }

  Future<void> _loadClubs() async {
    try {
      final response = await SupaFlow.client
          .from('clubs')
          .select()
          .order('created_at', ascending: false)
          .limit(80);
      _clubs = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      _clubs = [];
    }
  }

  Future<void> _loadConvocatorias() async {
    try {
      final response = await SupaFlow.client
          .from('convocatorias')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(80);
      final convocatorias = List<Map<String, dynamic>>.from(response);
      await _hydrateConvocatoriaApplicationCounts(convocatorias);
      _convocatorias = convocatorias;
    } catch (_) {
      _convocatorias = [];
    }
  }

  Future<void> _loadVideos() async {
    try {
      final response = await SupaFlow.client
          .from('videos')
          .select()
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(200);

      _videos = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      _videos = [];
      _videoCountByUserId.clear();
      _latestVideoByUserId.clear();
    }
  }

  Future<void> _loadSavedPlayersForScout() async {
    _savedPlayerIds.clear();
    if (currentUserUid.isEmpty) return;

    try {
      final response = await SupaFlow.client
          .from('jugadores_guardados')
          .select('jugador_id')
          .eq('scout_id', currentUserUid);

      for (final row in List<Map<String, dynamic>>.from(response)) {
        final playerId = row['jugador_id']?.toString().trim() ?? '';
        if (playerId.isNotEmpty) {
          _savedPlayerIds.add(playerId);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCountries() async {
    try {
      final response =
          await SupaFlow.client.from('countrys').select('id, name').limit(400);
      _countryNameById.clear();
      for (final row in (response as List)) {
        final idRaw = row['id'];
        final id = idRaw is int ? idRaw : int.tryParse(idRaw.toString());
        final name = row['name']?.toString().trim() ?? '';
        if (id != null && name.isNotEmpty) {
          _countryNameById[id] = name;
        }
      }
    } catch (_) {
      _countryNameById.clear();
    }
  }

  Future<void> _loadRecommendedChallenges() async {
    _recommendedChallenges = [];
    try {
      final courses = await SupaFlow.client
          .from('courses')
          .select()
          .eq('is_active', true)
          .order('order_index')
          .limit(6);
      _recommendedChallenges.addAll((courses as List).map((item) {
        final map = Map<String, dynamic>.from(item);
        map['type'] = 'course';
        return map;
      }));
    } catch (_) {}

    try {
      final exercises = await SupaFlow.client
          .from('exercises')
          .select()
          .eq('is_active', true)
          .order('order_index')
          .limit(6);
      _recommendedChallenges.addAll((exercises as List).map((item) {
        final map = Map<String, dynamic>.from(item);
        map['type'] = 'exercise';
        return map;
      }));
    } catch (_) {}
  }

  Future<void> _loadNextChallenge() async {
    _nextChallenge = null;
    if (currentUserUid.isEmpty) return;

    try {
      final progress = await SupaFlow.client
          .from('user_progress_view')
          .select()
          .eq('user_id', currentUserUid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (progress != null) {
        _nextChallenge = progress;
      }
    } catch (_) {}
  }

  void _decorateUserData() {
    final ownerById = <String, Map<String, dynamic>>{};
    for (final user in _users) {
      final uid = user['user_id']?.toString() ?? '';
      if (uid.isEmpty) continue;
      ownerById[uid] = user;
    }

    _videoCountByUserId.clear();
    _latestVideoByUserId.clear();
    _videos = _videos.where((video) {
      final uid = video['user_id']?.toString() ?? '';
      if (uid.isEmpty) return false;
      final owner = ownerById[uid];
      final visible = GuardianMvpService.isVideoVisibleToPublic(
        video,
        ownerData: owner,
      );
      if (!visible) return false;

      _videoCountByUserId[uid] = (_videoCountByUserId[uid] ?? 0) + 1;
      _latestVideoByUserId.putIfAbsent(uid, () => video);
      return true;
    }).toList();

    for (final user in _users) {
      final uid = user['user_id']?.toString() ?? '';
      if (uid.isEmpty) continue;
      user['video_count'] = _videoCountByUserId[uid] ?? 0;
      user['latest_video'] = _latestVideoByUserId[uid];
    }
  }

  void _decorateConvocatoriasData() {
    final clubsById = <String, Map<String, dynamic>>{};
    for (final club in _clubs) {
      final directId = club['id']?.toString() ?? '';
      final userId = club['user_id']?.toString() ?? '';
      final ownerId = club['owner_id']?.toString() ?? '';
      if (directId.isNotEmpty) {
        clubsById[directId] = club;
      }
      if (userId.isNotEmpty) {
        clubsById[userId] = club;
      }
      if (ownerId.isNotEmpty) {
        clubsById[ownerId] = club;
      }
    }

    _convocatorias = _convocatorias.map((conv) {
      final map = Map<String, dynamic>.from(conv);
      final clubId = map['club_id']?.toString() ?? '';
      if (map['club_data'] == null && clubId.isNotEmpty) {
        final clubData = clubsById[clubId];
        if (clubData != null) {
          map['club_data'] = clubData;
        }
      }
      return map;
    }).toList();
  }

  Future<void> _hydrateConvocatoriaApplicationCounts(
    List<Map<String, dynamic>> convocatorias,
  ) async {
    final ids = convocatorias
        .map((conv) => conv['id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    final counts = <String, int>{};
    var countsLoaded = false;

    try {
      final response = await SupaFlow.client
          .from('aplicaciones_convocatoria')
          .select('convocatoria_id')
          .inFilter('convocatoria_id', ids);
      for (final row in List<Map<String, dynamic>>.from(response as List)) {
        final convocatoriaId = row['convocatoria_id']?.toString().trim() ?? '';
        if (convocatoriaId.isEmpty) continue;
        counts[convocatoriaId] = (counts[convocatoriaId] ?? 0) + 1;
      }
      countsLoaded = true;
    } catch (_) {}

    try {
      final response = await SupaFlow.client
          .from('postulaciones')
          .select('convocatoria_id')
          .inFilter('convocatoria_id', ids);
      for (final row in List<Map<String, dynamic>>.from(response as List)) {
        final convocatoriaId = row['convocatoria_id']?.toString().trim() ?? '';
        if (convocatoriaId.isEmpty) continue;
        counts[convocatoriaId] = (counts[convocatoriaId] ?? 0) + 1;
      }
      countsLoaded = true;
    } catch (_) {}

    if (!countsLoaded) {
      try {
        final response = await SupaFlow.client.rpc(
          'public_convocatoria_application_counts',
          params: <String, dynamic>{'p_convocatoria_ids': ids},
        );
        for (final row in List<Map<String, dynamic>>.from(response as List)) {
          final convocatoriaId =
              row['convocatoria_id']?.toString().trim() ?? '';
          if (convocatoriaId.isEmpty) continue;
          counts[convocatoriaId] =
              _readIntValue(row['applications_count']) ?? 0;
        }
        countsLoaded = true;
      } catch (_) {}
    }

    for (final convocatoria in convocatorias) {
      final id = convocatoria['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;

      final fallbackCount = _readIntValue(
        convocatoria['applications_count'] ??
            convocatoria['postulaciones_count'] ??
            convocatoria['candidatos_count'] ??
            convocatoria['candidate_count'],
      );

      if (countsLoaded) {
        convocatoria['applications_count'] = counts[id] ?? fallbackCount ?? 0;
      } else if (fallbackCount != null) {
        convocatoria['applications_count'] = fallbackCount;
      }
    }
  }

  Future<void> _loadPlayerProgressData() async {
    final playerIds = _players
        .map((player) => player['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (playerIds.isEmpty) return;

    final progressByUserId = <String, Map<String, dynamic>>{};
    try {
      final progressRows = await SupaFlow.client
          .from('user_progress')
          .select(
              'user_id, total_xp, current_level_id, courses_completed, exercises_completed')
          .inFilter('user_id', playerIds);
      for (final row in (progressRows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final uid = map['user_id']?.toString() ?? '';
        if (uid.isNotEmpty) {
          progressByUserId[uid] = map;
        }
      }
    } catch (e) {
      debugPrint('Explorer progress load failed: $e');
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final player in _players) {
      final uid = player['user_id']?.toString() ?? '';
      final progress = progressByUserId[uid] ?? <String, dynamic>{};
      final totalXp = GamificationService.toInt(progress['total_xp']);
      final categoryKey =
          GamificationService.resolveUserCategoryLabel(player) ?? 'general';

      player['user_progress'] = progress;
      player['total_xp'] = totalXp;
      player['level_name'] = GamificationService.levelNameFromPoints(totalXp);
      player['completed_challenges'] =
          GamificationService.completedChallengesCount(progress);

      groups.putIfAbsent(categoryKey, () => []).add(player);
    }

    for (final group in groups.values) {
      group.sort((a, b) {
        final xpCompare = GamificationService.toInt(b['total_xp']).compareTo(
          GamificationService.toInt(a['total_xp']),
        );
        if (xpCompare != 0) return xpCompare;
        return GamificationService.toInt(b['video_count']).compareTo(
          GamificationService.toInt(a['video_count']),
        );
      });

      for (int index = 0; index < group.length; index++) {
        group[index]['category_ranking'] = index + 1;
      }
    }
  }

  bool get _canUseSensitiveActions =>
      FFAppState().unlockSensitiveActions ||
      _currentUserFullAccess ||
      (_currentPlanId != null && _currentUserVerified);

  bool _resolveViewerVerification(Map<String, dynamic> user) {
    final hasVerificationField = user.containsKey('is_verified') ||
        user.containsKey('verification_status');
    if (!hasVerificationField) return true;

    final direct = user['is_verified'];
    if (direct is bool) return direct;

    final status = user['verification_status']?.toString().toLowerCase() ?? '';
    return status == 'verified' ||
        status == 'verificado' ||
        status == 'aprovado' ||
        status == 'aprobado';
  }

  bool _isVerified(Map<String, dynamic> user) {
    final dynamic direct = user['is_verified'];
    if (direct is bool) return direct;

    final status = user['verification_status']?.toString().toLowerCase() ?? '';
    return status == 'verified' || status == 'verificado';
  }

  bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'sim';
  }

  List<Map<String, dynamic>> _sortedPublicVideosForPlayer(String playerId) {
    final videos = _videos
        .where((video) => (video['user_id']?.toString() ?? '') == playerId)
        .map((video) => Map<String, dynamic>.from(video))
        .toList();

    videos.sort((a, b) {
      final featuredCompare = (_isTruthy(b['featured_in_explorer']) ? 1 : 0)
          .compareTo(_isTruthy(a['featured_in_explorer']) ? 1 : 0);
      if (featuredCompare != 0) return featuredCompare;

      final bCreated = b['created_at']?.toString() ?? '';
      final aCreated = a['created_at']?.toString() ?? '';
      return bCreated.compareTo(aCreated);
    });

    return videos;
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  List<String> _extractUniqueStrings(Iterable<dynamic> values) {
    final set = <String>{};
    for (final raw in values) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty) set.add(value);
    }
    final list = set.toList()..sort();
    return list;
  }

  String _resolveCountryFromUser(Map<String, dynamic> user) {
    final directCountry = [
      user['country'],
      user['pais'],
      user['country_name'],
    ].firstWhere(
      (value) => value?.toString().trim().isNotEmpty == true,
      orElse: () => '',
    );
    if (directCountry.toString().trim().isNotEmpty) {
      return directCountry.toString().trim();
    }

    final countryIdRaw = user['country_id'];
    final countryId = countryIdRaw is int
        ? countryIdRaw
        : int.tryParse(countryIdRaw?.toString() ?? '');
    if (countryId == null) return '';
    return _countryNameById[countryId] ?? '';
  }

  String _resolveCountryFromClub(Map<String, dynamic> club) {
    final value = [
      club['pais'],
      club['country'],
      club['country_name'],
    ].firstWhere(
      (item) => item?.toString().trim().isNotEmpty == true,
      orElse: () => '',
    );
    return value.toString().trim();
  }

  String _resolveClubLeague(Map<String, dynamic> club) {
    final value = [
      club['liga'],
      club['league'],
      club['league_name'],
    ].firstWhere(
      (item) => item?.toString().trim().isNotEmpty == true,
      orElse: () => '',
    );
    return value.toString().trim();
  }

  String _resolveState(Map<String, dynamic> row) {
    final value = [
      row['provincia'],
      row['province'],
      row['state'],
      row['estado'],
      row['provincia_estado'],
      row['state_name'],
      row['region'],
    ].firstWhere(
      (item) => item?.toString().trim().isNotEmpty == true,
      orElse: () => '',
    );
    return value.toString().trim();
  }

  String _resolveCity(Map<String, dynamic> row) {
    final value = [
      row['city'],
      row['ciudad'],
      row['localidad'],
      row['ubicacion'],
    ].firstWhere(
      (item) => item?.toString().trim().isNotEmpty == true,
      orElse: () => '',
    );
    return value.toString().trim();
  }

  String _resolveConvocatoriaCountry(Map<String, dynamic> convocatoria) {
    final direct = [
      convocatoria['pais'],
      convocatoria['country'],
      convocatoria['country_name'],
      convocatoria['país'],
    ].firstWhere(
      (item) => item?.toString().trim().isNotEmpty == true,
      orElse: () => '',
    );
    if (direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }

    final clubData = convocatoria['club_data'];
    if (clubData is Map) {
      return _resolveCountryFromClub(Map<String, dynamic>.from(clubData));
    }
    return '';
  }

  String _resolveConvocatoriaCity(Map<String, dynamic> convocatoria) {
    final direct = [
      convocatoria['city'],
      convocatoria['ciudad'],
      convocatoria['cidade'],
      convocatoria['localidad'],
    ].firstWhere(
      (item) => item?.toString().trim().isNotEmpty == true,
      orElse: () => '',
    );
    if (direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }

    final clubData = convocatoria['club_data'];
    if (clubData is Map) {
      final city = _resolveCity(Map<String, dynamic>.from(clubData));
      if (city.isNotEmpty) return city;
    }

    final fallbackLocation = convocatoria['ubicacion']?.toString().trim() ?? '';
    return fallbackLocation;
  }

  String _resolveConvocatoriaCategory(Map<String, dynamic> convocatoria) {
    return _firstNonEmpty([
          convocatoria['categoria'],
          convocatoria['category'],
        ]) ??
        '';
  }

  String _resolveConvocatoriaClubName(Map<String, dynamic> convocatoria) {
    final direct = _firstNonEmpty([
      convocatoria['club_name'],
      convocatoria['club_nombre'],
      convocatoria['nombre_club'],
      convocatoria['club'],
    ]);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final clubData = convocatoria['club_data'];
    if (clubData is Map) {
      return _firstNonEmpty([
            clubData['name'],
            clubData['nombre'],
            clubData['club_name'],
            clubData['nombre_corto'],
          ]) ??
          '';
    }

    return '';
  }

  String _resolveConvocatoriaPosition(Map<String, dynamic> convocatoria) {
    return _firstNonEmpty([
          convocatoria['posicion'],
          convocatoria['position'],
          convocatoria['posição'],
        ]) ??
        '';
  }

  int? _readIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  DateTime? _resolveConvocatoriaClosingDate(Map<String, dynamic> convocatoria) {
    final rawDate = _firstNonEmpty([
      convocatoria['fecha_fin'],
      convocatoria['fecha_cierre'],
      convocatoria['due_date'],
      convocatoria['closing_date'],
    ]);
    if (rawDate == null || rawDate.isEmpty) return null;
    return DateTime.tryParse(rawDate)?.toLocal();
  }

  String? _convocatoriaClosingLabel(Map<String, dynamic> convocatoria) {
    final closingDate = _resolveConvocatoriaClosingDate(convocatoria);
    if (closingDate == null) return null;

    final today = DateUtils.dateOnly(DateTime.now());
    final target = DateUtils.dateOnly(closingDate);
    final daysLeft = target.difference(today).inDays;

    if (daysLeft < 0) {
      return 'Fecha de cierre vencida';
    }
    if (daysLeft == 0) {
      return 'Fecha de cierre hoy';
    }
    if (daysLeft == 1) {
      return 'Fecha de cierre en 1 dia';
    }
    return 'Fecha de cierre en $daysLeft dias';
  }

  int? _convocatoriaApplicationsCount(Map<String, dynamic> convocatoria) {
    return _readIntValue(
      convocatoria['applications_count'] ??
          convocatoria['postulaciones_count'] ??
          convocatoria['candidatos_count'] ??
          convocatoria['candidate_count'],
    );
  }

  String? _convocatoriaApplicationsLabel(Map<String, dynamic> convocatoria) {
    final applicationsCount = _convocatoriaApplicationsCount(convocatoria);
    if (applicationsCount == null) return null;
    if (applicationsCount == 1) {
      return '1 candidato aplicado';
    }
    return '$applicationsCount candidatos aplicados';
  }

  String _resolvePlayerLevel(Map<String, dynamic> player) {
    final direct = player['level_name']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final totalXp = GamificationService.toInt(player['total_xp']);
    return GamificationService.levelNameFromPoints(totalXp);
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

  int? _birthYear(dynamic birthday) {
    if (birthday == null) return null;
    try {
      return DateTime.parse(birthday.toString()).year;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _scoutFilteredPlayers {
    Iterable<Map<String, dynamic>> filtered = _players;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((u) {
        final text =
            '${u['name'] ?? ''} ${u['lastname'] ?? ''} ${u['posicion'] ?? ''} '
                    '${_resolveCity(u)} ${_resolveCountryFromUser(u)} ${u['club'] ?? ''} ${_resolvePlayerLevel(u)}'
                .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    if (_scoutPosition != null) {
      filtered = filtered.where((u) =>
          (u['posicion']?.toString().trim().toLowerCase() ?? '') ==
          _scoutPosition!.toLowerCase());
    }

    if (_scoutPlayerCountry != null) {
      filtered = filtered.where((u) =>
          _resolveCountryFromUser(u).toLowerCase() ==
          _scoutPlayerCountry!.toLowerCase());
    }

    if (_scoutPlayerCity != null) {
      filtered = filtered.where((u) =>
          _resolveCity(u).toLowerCase() == _scoutPlayerCity!.toLowerCase());
    }

    if (_scoutCategory != null) {
      filtered = filtered.where(
        (u) => _categoryFromBirthday(u['birthday']) == _scoutCategory,
      );
    }

    if (_scoutPlayerLevel != null) {
      filtered = filtered.where(
        (u) =>
            _resolvePlayerLevel(u).toLowerCase() ==
            _scoutPlayerLevel!.toLowerCase(),
      );
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _scoutFilteredClubs {
    Iterable<Map<String, dynamic>> filtered = _clubs;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((club) {
        final text = '${club['nombre'] ?? ''} ${club['nombre_corto'] ?? ''} '
                '${_resolveCountryFromClub(club)} ${_resolveCity(club)} ${_resolveClubLeague(club)}'
            .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    if (_scoutClubCountry != null) {
      filtered = filtered.where((club) =>
          _resolveCountryFromClub(club).toLowerCase() ==
          _scoutClubCountry!.toLowerCase());
    }

    if (_scoutClubCity != null) {
      filtered = filtered.where((club) =>
          _resolveCity(club).toLowerCase() == _scoutClubCity!.toLowerCase());
    }

    if (_scoutClubLeague != null) {
      filtered = filtered.where((club) =>
          _resolveClubLeague(club).toLowerCase() ==
          _scoutClubLeague!.toLowerCase());
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _scoutFilteredConvocatorias {
    Iterable<Map<String, dynamic>> filtered = _convocatorias;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((conv) {
        final text = '${conv['titulo'] ?? ''} '
                '${_resolveConvocatoriaPosition(conv)} '
                '${_resolveConvocatoriaCategory(conv)} '
                '${_resolveConvocatoriaCity(conv)} '
                '${_resolveConvocatoriaCountry(conv)} '
                '${conv['ubicacion'] ?? ''} '
                '${_resolveConvocatoriaClubName(conv)}'
            .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    if (_scoutConvocatoriaPosition != null) {
      filtered = filtered.where((conv) =>
          _resolveConvocatoriaPosition(conv).toLowerCase() ==
          _scoutConvocatoriaPosition!.toLowerCase());
    }

    if (_scoutConvocatoriaCity != null) {
      filtered = filtered.where((conv) =>
          _resolveConvocatoriaCity(conv).toLowerCase() ==
          _scoutConvocatoriaCity!.toLowerCase());
    }

    if (_scoutConvocatoriaCountry != null) {
      filtered = filtered.where((conv) =>
          _resolveConvocatoriaCountry(conv).toLowerCase() ==
          _scoutConvocatoriaCountry!.toLowerCase());
    }

    if (_scoutConvocatoriaCategory != null) {
      filtered = filtered.where((conv) =>
          _resolveConvocatoriaCategory(conv).toLowerCase() ==
          _scoutConvocatoriaCategory!.toLowerCase());
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _jugadorFilteredPlayers {
    Iterable<Map<String, dynamic>> filtered = _players;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((u) {
        final text =
            '${u['name'] ?? ''} ${u['lastname'] ?? ''} ${u['posicion'] ?? ''} '
                    '${_resolveCity(u)} ${_resolveCountryFromUser(u)} ${u['club'] ?? ''} ${_resolvePlayerLevel(u)}'
                .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    if (_jugadorPlayerPosition != null) {
      filtered = filtered.where((u) =>
          (u['posicion']?.toString().trim().toLowerCase() ?? '') ==
          _jugadorPlayerPosition!.toLowerCase());
    }

    if (_jugadorPlayerCountry != null) {
      filtered = filtered.where((u) =>
          _resolveCountryFromUser(u).toLowerCase() ==
          _jugadorPlayerCountry!.toLowerCase());
    }

    if (_jugadorPlayerCity != null) {
      filtered = filtered.where((u) =>
          _resolveCity(u).toLowerCase() == _jugadorPlayerCity!.toLowerCase());
    }

    if (_jugadorPlayerCategory != null) {
      filtered = filtered.where(
        (u) => _categoryFromBirthday(u['birthday']) == _jugadorPlayerCategory,
      );
    }

    if (_jugadorPlayerLevel != null) {
      filtered = filtered.where(
        (u) =>
            _resolvePlayerLevel(u).toLowerCase() ==
            _jugadorPlayerLevel!.toLowerCase(),
      );
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _jugadorFilteredConvocatorias {
    Iterable<Map<String, dynamic>> filtered = _convocatorias;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((conv) {
        final text = '${conv['titulo'] ?? ''} '
                '${_resolveConvocatoriaPosition(conv)} '
                '${_resolveConvocatoriaCategory(conv)} '
                '${_resolveConvocatoriaCountry(conv)} '
                '${_resolveConvocatoriaCity(conv)} '
                '${_resolveConvocatoriaClubName(conv)}'
            .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    if (_jugadorConvocatoriaCategory != null) {
      filtered = filtered.where((conv) =>
          _resolveConvocatoriaCategory(conv).toLowerCase() ==
          _jugadorConvocatoriaCategory!.toLowerCase());
    }

    if (_jugadorConvocatoriaPosition != null) {
      filtered = filtered.where((conv) =>
          _resolveConvocatoriaPosition(conv).toLowerCase() ==
          _jugadorConvocatoriaPosition!.toLowerCase());
    }

    if (_jugadorConvocatoriaCountry != null) {
      filtered = filtered.where((conv) =>
          _resolveConvocatoriaCountry(conv).toLowerCase() ==
          _jugadorConvocatoriaCountry!.toLowerCase());
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _jugadorFilteredClubs {
    Iterable<Map<String, dynamic>> filtered = _clubs;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((club) {
        final text =
            '${club['nombre'] ?? ''} ${club['nombre_corto'] ?? ''} ${_resolveCountryFromClub(club)} ${_resolveCity(club)} ${_resolveClubLeague(club)}'
                .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    if (_jugadorClubCountry != null) {
      filtered = filtered.where((club) =>
          _resolveCountryFromClub(club).toLowerCase() ==
          _jugadorClubCountry!.toLowerCase());
    }

    if (_jugadorClubCity != null) {
      filtered = filtered.where((club) =>
          _resolveCity(club).toLowerCase() == _jugadorClubCity!.toLowerCase());
    }

    if (_jugadorClubLeague != null) {
      filtered = filtered.where((club) =>
          _resolveClubLeague(club).toLowerCase() ==
          _jugadorClubLeague!.toLowerCase());
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _jugadorFilteredScouts {
    Iterable<Map<String, dynamic>> filtered = _users.where((user) {
      final isScout =
          (user['userType']?.toString().trim().toLowerCase() ?? '') ==
              'profesional';
      return isScout && _isVerified(user);
    });

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final text =
            '${user['name'] ?? ''} ${user['lastname'] ?? ''} ${_resolveCity(user)} ${_resolveState(user)} ${_resolveCountryFromUser(user)} ${user['club'] ?? ''}'
                .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    if (_jugadorScoutCountry != null) {
      filtered = filtered.where((user) =>
          _resolveCountryFromUser(user).toLowerCase() ==
          _jugadorScoutCountry!.toLowerCase());
    }

    return filtered.toList();
  }

  void _resetJugadorSearchFilters() {
    _jugadorPlayerCategory = null;
    _jugadorPlayerPosition = null;
    _jugadorPlayerCountry = null;
    _jugadorPlayerCity = null;
    _jugadorPlayerLevel = null;
    _jugadorConvocatoriaCategory = null;
    _jugadorConvocatoriaPosition = null;
    _jugadorConvocatoriaCountry = null;
    _jugadorClubCountry = null;
    _jugadorClubCity = null;
    _jugadorClubLeague = null;
    _jugadorScoutCountry = null;
  }

  String _jugadorTabLabel(_JugadorSearchTab tab) {
    switch (tab) {
      case _JugadorSearchTab.jugadores:
        return 'Jugadores';
      case _JugadorSearchTab.convocatorias:
        return 'Convocatorias';
      case _JugadorSearchTab.clubes:
        return 'Clubes';
      case _JugadorSearchTab.scouts:
        return 'Scouts';
    }
  }

  IconData _jugadorTabIcon(_JugadorSearchTab tab) {
    switch (tab) {
      case _JugadorSearchTab.jugadores:
        return Icons.sports_soccer_rounded;
      case _JugadorSearchTab.convocatorias:
        return Icons.campaign_rounded;
      case _JugadorSearchTab.clubes:
        return Icons.shield_rounded;
      case _JugadorSearchTab.scouts:
        return Icons.manage_search_rounded;
    }
  }

  bool get _jugadorCurrentTabHasActiveFilters {
    switch (_jugadorSearchTab) {
      case _JugadorSearchTab.jugadores:
        return _jugadorPlayerCategory != null ||
            _jugadorPlayerPosition != null ||
            _jugadorPlayerCountry != null ||
            _jugadorPlayerCity != null ||
            _jugadorPlayerLevel != null;
      case _JugadorSearchTab.convocatorias:
        return _jugadorConvocatoriaCategory != null ||
            _jugadorConvocatoriaPosition != null ||
            _jugadorConvocatoriaCountry != null;
      case _JugadorSearchTab.clubes:
        return _jugadorClubCountry != null ||
            _jugadorClubCity != null ||
            _jugadorClubLeague != null;
      case _JugadorSearchTab.scouts:
        return _jugadorScoutCountry != null;
    }
  }

  List<Map<String, dynamic>> get _jugadorCurrentResults {
    switch (_jugadorSearchTab) {
      case _JugadorSearchTab.jugadores:
        return _jugadorFilteredPlayers;
      case _JugadorSearchTab.convocatorias:
        return _jugadorFilteredConvocatorias;
      case _JugadorSearchTab.clubes:
        return _jugadorFilteredClubs;
      case _JugadorSearchTab.scouts:
        return _jugadorFilteredScouts;
    }
  }

  bool _isPlayerSaved(String playerId) => _savedPlayerIds.contains(playerId);

  Future<void> _toggleSavePlayerForScout(Map<String, dynamic> player) async {
    if (!_canUseSensitiveActions) {
      _showUpsellDialog(
        title: 'Acción bloqueada',
        message:
            'Para guardar jugadores en listas necesitas verificación o un plan activo.',
      );
      return;
    }

    if (currentUserUid.isEmpty) return;
    final playerId = player['user_id']?.toString() ?? '';
    if (playerId.isEmpty || _savingPlayerId == playerId) return;

    final wasSaved = _isPlayerSaved(playerId);
    if (mounted) {
      setState(() => _savingPlayerId = playerId);
    }
    try {
      if (wasSaved) {
        await SupaFlow.client
            .from('jugadores_guardados')
            .delete()
            .eq('scout_id', currentUserUid)
            .eq('jugador_id', playerId);

        if (!mounted) return;
        setState(() {
          _savedPlayerIds.remove(playerId);
          _savingPlayerId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jugador removido de guardados'),
            backgroundColor: Color(0xFF475569),
          ),
        );
        return;
      }

      await SupaFlow.client.from('jugadores_guardados').insert({
        'scout_id': currentUserUid,
        'jugador_id': playerId,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() {
        _savedPlayerIds.add(playerId);
        _savingPlayerId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jugador guardado con éxito'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingPlayerId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSaved
                ? 'No se pudo remover el jugador'
                : 'No se pudo guardar el jugador',
          ),
        ),
      );
    }
  }

  void _openPlayerVideos(Map<String, dynamic> player) {
    if (!_canUseSensitiveActions) {
      _showUpsellDialog(
        title: 'Acción bloqueada',
        message:
            'Para ver vídeos desde Explorer necesitas verificación o un plan activo.',
      );
      return;
    }

    final playerId = player['user_id']?.toString() ?? '';
    if (playerId.isEmpty) return;

    final videos = _sortedPublicVideosForPlayer(playerId);

    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este jugador no tiene videos públicos')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _VideoPreviewSheet(videos: videos),
    );
  }

  void _openPublicPlayerProfile(Map<String, dynamic> player) {
    final uid = _firstNonEmpty([
          player['user_id'],
          player['jugador_id'],
          player['id'],
        ]) ??
        '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el perfil del jugador')),
      );
      return;
    }

    final rawType = FFAppState.normalizeUserType(
      player['userType'] ?? player['usertype'] ?? player['user_type'],
    );
    if (rawType.isNotEmpty && rawType != 'jugador') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Este resultado no corresponde a un jugador')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilProfesionalSolicitarContatoWidget(userId: uid),
      ),
    );
  }

  void _showUpsellDialog({required String title, required String message}) {
    showBlockedActionDialog(
      context,
      title: title,
      message: message,
      confirmLabel: 'Entendido',
    );
  }

  void _openVerifiedScoutsResults() {
    final scouts = _users
        .where((u) =>
            (u['userType']?.toString().trim().toLowerCase() ?? '') ==
                'profesional' &&
            _isVerified(u))
        .map((u) => {
              ...u,
              'country_name': _resolveCountryFromUser(u),
              'state_name': _resolveState(u),
              'city_name': _resolveCity(u),
            })
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _JugadorScoutsResultsPage(
          scouts: scouts,
        ),
      ),
    );
  }

  void _openClubShortcuts() {
    final clubs = _clubs
        .map((club) => {
              ...club,
              'country_name': _resolveCountryFromClub(club),
              'state_name': _resolveState(club),
              'city_name': _resolveCity(club),
            })
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _JugadorClubsResultsPage(
          clubs: clubs,
        ),
      ),
    );
  }

  void _openJugadorSearchMode() {
    if (!mounted) return;
    setState(() {
      _isJugadorSearchMode = true;
      _jugadorSearchTab = _JugadorSearchTab.convocatorias;
      _resetJugadorSearchFilters();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _closeJugadorSearchMode() {
    if (!mounted) return;
    setState(() {
      _isJugadorSearchMode = false;
      _searchQuery = '';
      _jugadorSearchTab = _JugadorSearchTab.convocatorias;
      _resetJugadorSearchFilters();
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;

    if (userType == 'club') {
      return const DashboardClubWidget();
    }

    return PopScope(
      canPop: !(userType == 'jugador' && _isJugadorSearchMode),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && userType == 'jugador' && _isJugadorSearchMode) {
          _closeJugadorSearchMode();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          body: Stack(
            children: [
              Positioned.fill(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0D3B66),
                        ),
                      )
                    : _errorMessage != null
                        ? _buildErrorState()
                        : (userType == 'profesional'
                            ? _buildScoutExplorer()
                            : _buildJugadorExplorer()),
              ),
              if (userType == 'jugador')
                Align(
                  alignment: const AlignmentDirectional(0, 1),
                  child: wrapWithModel(
                    model: _model.navBarJudadorModel,
                    updateCallback: () => safeSetState(() {}),
                    child: const NavBarJudadorWidget(),
                  ),
                ),
              if (userType == 'profesional')
                Align(
                  alignment: const AlignmentDirectional(0, 1),
                  child: wrapWithModel(
                    model: _model.navBarProfesionalModel,
                    updateCallback: () => safeSetState(() {}),
                    child: const NavBarProfesionalWidget(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Error',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF2D3748),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66),
              ),
              child: const Text(
                'Tentar novamente',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJugadorExplorer() {
    if (_isJugadorSearchMode) {
      return _buildJugadorSearchMode();
    }

    final promoted = _convocatorias.take(6).toList();
    final recommendedChallenges = _recommendedChallenges.take(8).toList();

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            Text(
              'Explorer · Jugador',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Descubre desafíos, convocatorias, clubes y usuarios.',
              style: GoogleFonts.inter(
                color: const Color(0xFF4A5568),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            _buildJugadorSearchEntry(),
            const SizedBox(height: 18),
            _buildQuickActionsJugador(),
            const SizedBox(height: 20),
            if (_nextChallenge != null) _buildNextChallengeCard(),
            if (_nextChallenge != null) const SizedBox(height: 20),
            _buildSectionTitle(
              'Tus próximos desafíos',
              icon: Icons.local_fire_department_outlined,
              subtitle:
                  'Acciones rápidas para avanzar y llegar mejor preparado.',
            ),
            _buildRecommendedChallengesRow(recommendedChallenges),
            const SizedBox(height: 20),
            _buildSectionTitle(
              'Convocatorias recomendadas',
              icon: Icons.campaign_rounded,
              subtitle: 'Oportunidades ativas para você decidir mais rápido.',
            ),
            _buildPromotedConvocatorias(promoted),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildScoutExplorer() {
    final playerPositionOptions =
        _extractUniqueStrings(_players.map((u) => u['posicion']));
    final playerCategoryOptions = _extractUniqueStrings(
      _players.map((u) => _categoryFromBirthday(u['birthday'])),
    );
    final playerCountryOptions = _extractUniqueStrings(
      _players.map(_resolveCountryFromUser),
    );
    final playerCityOptions = _extractUniqueStrings(
      _players.map(_resolveCity),
    );
    final playerLevelOptions = _extractUniqueStrings(
      _players.map(_resolvePlayerLevel),
    );
    final clubCountryOptions = _extractUniqueStrings(
      _clubs.map(_resolveCountryFromClub),
    );
    final clubCityOptions = _extractUniqueStrings(
      _clubs.map(_resolveCity),
    );
    final clubLeagueOptions = _extractUniqueStrings(
      _clubs.map(_resolveClubLeague),
    );
    final convocatoriaCountryOptions = _extractUniqueStrings(
      _convocatorias.map(_resolveConvocatoriaCountry),
    );
    final convocatoriaCityOptions = _extractUniqueStrings(
      _convocatorias.map(_resolveConvocatoriaCity),
    );
    final convocatoriaCategoryOptions = _extractUniqueStrings(
      _convocatorias.map(_resolveConvocatoriaCategory),
    );
    final convocatoriaPositionOptions = _extractUniqueStrings(
      _convocatorias.map(_resolveConvocatoriaPosition),
    );

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Explorer · Scout',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      context.pushNamed(ListaYNotasWidget.routeName),
                  icon: const Icon(Icons.bookmarks_rounded),
                  label: const Text('Minhas listas'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildSearchBar(
                    hint: _scoutTab == _ScoutTab.convocatorias
                        ? 'Buscar convocatoria, país, ciudad, categoría...'
                        : _scoutTab == _ScoutTab.clubes
                            ? 'Buscar club, país, ciudad, liga...'
                            : 'Buscar jugador, categoría, posición, país, ciudad...',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openScoutFilters(
                    playerPositionOptions: playerPositionOptions,
                    playerCategoryOptions: playerCategoryOptions,
                    playerCountryOptions: playerCountryOptions,
                    playerCityOptions: playerCityOptions,
                    playerLevelOptions: playerLevelOptions,
                    clubCountryOptions: clubCountryOptions,
                    clubCityOptions: clubCityOptions,
                    clubLeagueOptions: clubLeagueOptions,
                    convocatoriaCountryOptions: convocatoriaCountryOptions,
                    convocatoriaCityOptions: convocatoriaCityOptions,
                    convocatoriaCategoryOptions: convocatoriaCategoryOptions,
                    convocatoriaPositionOptions: convocatoriaPositionOptions,
                  ),
                  style: _explorerSecondaryButtonStyle(),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Filtros'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildScoutTabBar(),
            const SizedBox(height: 18),
            if (_scoutTab == _ScoutTab.jugadores)
              _buildScoutPlayersList()
            else if (_scoutTab == _ScoutTab.clubes)
              _buildScoutClubsList()
            else
              _buildScoutConvocatoriasList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar({required String hint}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6DEE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D3B66),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                color: Color(0xFF0D3B66),
                size: 18,
              ),
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFFA0AEC0)),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
        style: GoogleFonts.inter(fontSize: 14),
      ),
    );
  }

  Widget _explorerIconBadge(
    IconData icon, {
    Color background = const Color(0xFFE8F0FE),
    Color foreground = const Color(0xFF0D3B66),
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: foreground, size: 18),
    );
  }

  ButtonStyle _explorerPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF0D3B66),
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size.fromHeight(42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  ButtonStyle _explorerSecondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF0D3B66),
      side: const BorderSide(color: Color(0xFFD6DEE8)),
      minimumSize: const Size.fromHeight(42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildQuickActionsJugador() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.6,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _quickActionCard(
          icon: Icons.local_fire_department_rounded,
          title: 'Desafíos',
          onTap: () => context.pushNamed(CursosEjerciciosWidget.routeName),
        ),
        _quickActionCard(
          icon: Icons.campaign_rounded,
          title: 'Convocatorias',
          onTap: () => context.pushNamed(ConvocatoriaJugador1Widget.routeName),
        ),
        _quickActionCard(
          icon: Icons.shield_rounded,
          title: 'Clubes',
          onTap: _openClubShortcuts,
        ),
        _quickActionCard(
          icon: Icons.manage_search_rounded,
          title: 'Scouts verificados',
          onTap: _openVerifiedScoutsResults,
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120D3B66),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _explorerIconBadge(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF2D3748),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextChallengeCard() {
    final challenge = _nextChallenge!;
    final title = challenge['challenge_title']?.toString() ??
        challenge['title']?.toString() ??
        'Tu próximo desafío';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _explorerIconBadge(Icons.flag_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu próximo desafío',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0D3B66),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1A202C),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () =>
                context.pushNamed(CursosEjerciciosWidget.routeName),
            style: _explorerPrimaryButtonStyle(),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Continuar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedChallengesRow(List<Map<String, dynamic>> challenges) {
    if (challenges.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.sports_score_outlined,
        title: 'Sem resultados',
        subtitle: 'No hay desafíos recomendados en este momento.',
      );
    }

    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: challenges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final challenge = challenges[index];
          final title = challenge['title']?.toString().trim().isNotEmpty == true
              ? challenge['title'].toString()
              : 'Desafío';
          final category = challenge['category']?.toString() ??
              challenge['categoria']?.toString() ??
              '';
          final difficulty = challenge['difficulty']?.toString() ??
              challenge['dificultad']?.toString() ??
              '';
          final xp = challenge['xp_reward']?.toString() ?? '';
          final imageUrl = challenge['thumbnail_url']?.toString() ??
              challenge['image_url']?.toString() ??
              '';

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.pushNamed(CursosEjerciciosWidget.routeName),
            child: Container(
              width: 235,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        image: imageUrl.startsWith('http')
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          if (!imageUrl.startsWith('http'))
                            const Center(
                              child: Icon(
                                Icons.sports_score_rounded,
                                color: Color(0xFF0D3B66),
                                size: 36,
                              ),
                            ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D3B66)
                                    .withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '🔥 +${xp.isNotEmpty ? xp : GamificationService.challengeCompletedPoints} XP',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A202C),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [category, difficulty, if (xp.isNotEmpty) '+$xp XP']
                              .where((v) => v.trim().isNotEmpty)
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJugadorSearchMode() {
    final playerCategoryOptions = _extractUniqueStrings(
      _players.map((u) => _categoryFromBirthday(u['birthday'])),
    );
    final playerPositionOptions = _extractUniqueStrings(
      _players.map((u) => u['posicion']),
    );
    final playerCountryOptions = _extractUniqueStrings(
      _players.map(_resolveCountryFromUser),
    );
    final playerCityOptions = _extractUniqueStrings(
      _players.map(_resolveCity),
    );
    final playerLevelOptions = _extractUniqueStrings(
      _players.map(_resolvePlayerLevel),
    );
    final convocatoriaCategoryOptions = _extractUniqueStrings(
      _convocatorias.map(_resolveConvocatoriaCategory),
    );
    final convocatoriaPositionOptions = _extractUniqueStrings(
      _convocatorias.map(_resolveConvocatoriaPosition),
    );
    final convocatoriaCountryOptions = _extractUniqueStrings(
      _convocatorias.map(_resolveConvocatoriaCountry),
    );
    final clubCountryOptions = _extractUniqueStrings(
      _clubs.map(_resolveCountryFromClub),
    );
    final clubCityOptions = _extractUniqueStrings(
      _clubs.map(_resolveCity),
    );
    final clubLeagueOptions = _extractUniqueStrings(
      _clubs.map(_resolveClubLeague),
    );
    final verifiedScouts = _users.where((user) {
      final isScout =
          (user['userType']?.toString().trim().toLowerCase() ?? '') ==
              'profesional';
      return isScout && _isVerified(user);
    }).toList();
    final scoutCountryOptions = _extractUniqueStrings(
      verifiedScouts.map(_resolveCountryFromUser),
    );
    final currentResults = _jugadorCurrentResults;
    final hasActiveCriteria =
        _searchQuery.trim().length >= 2 || _jugadorCurrentTabHasActiveFilters;
    final resultLabel = currentResults.length == 1 ? 'resultado' : 'resultados';

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _closeJugadorSearchMode,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Buscar',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Buscá jugadores, convocatorias, clubes y scouts en un modo separado del contenido de descubrimiento.',
              style: GoogleFonts.inter(
                color: const Color(0xFF4A5568),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            _buildSearchBar(
              hint: 'Buscar jugadores, convocatorias, clubes o scouts...',
            ),
            const SizedBox(height: 14),
            _buildJugadorSearchTabBar(),
            const SizedBox(height: 12),
            _buildJugadorSearchFilters(
              playerCategoryOptions: playerCategoryOptions,
              playerPositionOptions: playerPositionOptions,
              playerCountryOptions: playerCountryOptions,
              playerCityOptions: playerCityOptions,
              playerLevelOptions: playerLevelOptions,
              convocatoriaCategoryOptions: convocatoriaCategoryOptions,
              convocatoriaPositionOptions: convocatoriaPositionOptions,
              convocatoriaCountryOptions: convocatoriaCountryOptions,
              clubCountryOptions: clubCountryOptions,
              clubCityOptions: clubCityOptions,
              clubLeagueOptions: clubLeagueOptions,
              scoutCountryOptions: scoutCountryOptions,
            ),
            const SizedBox(height: 12),
            if (!hasActiveCriteria)
              _buildInlineStatus(
                icon: Icons.search_rounded,
                title: 'Empezá una búsqueda',
                subtitle:
                    'Escribí al menos 2 letras o ajustá filtros para ver resultados.',
              )
            else ...[
              Text(
                '${currentResults.length} $resultLabel en ${_jugadorTabLabel(_jugadorSearchTab).toLowerCase()}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A5568),
                ),
              ),
              const SizedBox(height: 10),
              if (currentResults.isEmpty)
                _buildInlineStatus(
                  icon: Icons.search_off,
                  title: 'Sem resultados.',
                  subtitle: 'Tente outros termos ou ajuste os filtros.',
                )
              else
                _buildJugadorSearchResultsList(currentResults),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJugadorSearchTabBar() {
    Widget tab(_JugadorSearchTab tab) {
      final selected = _jugadorSearchTab == tab;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => setState(() => _jugadorSearchTab = tab),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0D3B66) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0D3B66)
                    : const Color(0xFFD6DEE8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.16)
                        : const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    _jugadorTabIcon(tab),
                    size: 15,
                    color: selected ? Colors.white : const Color(0xFF0D3B66),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _jugadorTabLabel(tab),
                  style: GoogleFonts.inter(
                    color: selected ? Colors.white : const Color(0xFF4A5568),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          tab(_JugadorSearchTab.convocatorias),
          tab(_JugadorSearchTab.clubes),
          tab(_JugadorSearchTab.scouts),
          tab(_JugadorSearchTab.jugadores),
        ],
      ),
    );
  }

  Widget _buildJugadorSearchFilters({
    required List<String> playerCategoryOptions,
    required List<String> playerPositionOptions,
    required List<String> playerCountryOptions,
    required List<String> playerCityOptions,
    required List<String> playerLevelOptions,
    required List<String> convocatoriaCategoryOptions,
    required List<String> convocatoriaPositionOptions,
    required List<String> convocatoriaCountryOptions,
    required List<String> clubCountryOptions,
    required List<String> clubCityOptions,
    required List<String> clubLeagueOptions,
    required List<String> scoutCountryOptions,
  }) {
    final filters = <Widget>[];

    switch (_jugadorSearchTab) {
      case _JugadorSearchTab.jugadores:
        filters.addAll([
          _ExplorerFilterDropdown(
            label: 'Categoría',
            value: _jugadorPlayerCategory,
            options: playerCategoryOptions,
            onChanged: (value) =>
                setState(() => _jugadorPlayerCategory = value),
          ),
          _ExplorerFilterDropdown(
            label: 'Posición',
            value: _jugadorPlayerPosition,
            options: playerPositionOptions,
            onChanged: (value) =>
                setState(() => _jugadorPlayerPosition = value),
          ),
          _ExplorerFilterDropdown(
            label: 'País',
            value: _jugadorPlayerCountry,
            options: playerCountryOptions,
            onChanged: (value) => setState(() => _jugadorPlayerCountry = value),
          ),
          _ExplorerFilterDropdown(
            label: 'Ciudad',
            value: _jugadorPlayerCity,
            options: playerCityOptions,
            onChanged: (value) => setState(() => _jugadorPlayerCity = value),
          ),
          _ExplorerFilterDropdown(
            label: 'Nivel',
            value: _jugadorPlayerLevel,
            options: playerLevelOptions,
            onChanged: (value) => setState(() => _jugadorPlayerLevel = value),
          ),
        ]);
        break;
      case _JugadorSearchTab.convocatorias:
        filters.addAll([
          _ExplorerFilterDropdown(
            label: 'Categoría',
            value: _jugadorConvocatoriaCategory,
            options: convocatoriaCategoryOptions,
            onChanged: (value) =>
                setState(() => _jugadorConvocatoriaCategory = value),
          ),
          _ExplorerFilterDropdown(
            label: 'Posición',
            value: _jugadorConvocatoriaPosition,
            options: convocatoriaPositionOptions,
            onChanged: (value) =>
                setState(() => _jugadorConvocatoriaPosition = value),
          ),
          _ExplorerFilterDropdown(
            label: 'País',
            value: _jugadorConvocatoriaCountry,
            options: convocatoriaCountryOptions,
            onChanged: (value) =>
                setState(() => _jugadorConvocatoriaCountry = value),
          ),
        ]);
        break;
      case _JugadorSearchTab.clubes:
        filters.addAll([
          _ExplorerFilterDropdown(
            label: 'País',
            value: _jugadorClubCountry,
            options: clubCountryOptions,
            onChanged: (value) => setState(() => _jugadorClubCountry = value),
          ),
          _ExplorerFilterDropdown(
            label: 'Ciudad',
            value: _jugadorClubCity,
            options: clubCityOptions,
            onChanged: (value) => setState(() => _jugadorClubCity = value),
          ),
          _ExplorerFilterDropdown(
            label: 'Liga',
            value: _jugadorClubLeague,
            options: clubLeagueOptions,
            onChanged: (value) => setState(() => _jugadorClubLeague = value),
          ),
        ]);
        break;
      case _JugadorSearchTab.scouts:
        filters.addAll([
          _ExplorerFilterDropdown(
            label: 'País',
            value: _jugadorScoutCountry,
            options: scoutCountryOptions,
            onChanged: (value) => setState(() => _jugadorScoutCountry = value),
          ),
        ]);
        break;
    }

    return Column(
      children: [
        _buildJugadorFilterWrap(filters),
        if (_jugadorCurrentTabHasActiveFilters) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                switch (_jugadorSearchTab) {
                  case _JugadorSearchTab.jugadores:
                    _jugadorPlayerCategory = null;
                    _jugadorPlayerPosition = null;
                    _jugadorPlayerCountry = null;
                    _jugadorPlayerCity = null;
                    _jugadorPlayerLevel = null;
                    break;
                  case _JugadorSearchTab.convocatorias:
                    _jugadorConvocatoriaCategory = null;
                    _jugadorConvocatoriaPosition = null;
                    _jugadorConvocatoriaCountry = null;
                    break;
                  case _JugadorSearchTab.clubes:
                    _jugadorClubCountry = null;
                    _jugadorClubCity = null;
                    _jugadorClubLeague = null;
                    break;
                  case _JugadorSearchTab.scouts:
                    _jugadorScoutCountry = null;
                    break;
                }
              }),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('Limpiar filtros'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildJugadorFilterWrap(List<Widget> filters) {
    if (filters.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 420;
        final itemWidth =
            twoColumns ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters
              .map((filter) => SizedBox(width: itemWidth, child: filter))
              .toList(),
        );
      },
    );
  }

  Widget _buildJugadorSearchResultsList(List<Map<String, dynamic>> results) {
    switch (_jugadorSearchTab) {
      case _JugadorSearchTab.jugadores:
        return _buildJugadorSearchPlayersList(results);
      case _JugadorSearchTab.convocatorias:
        return _buildPromotedConvocatorias(results);
      case _JugadorSearchTab.clubes:
        return _buildJugadorSearchClubsList(results);
      case _JugadorSearchTab.scouts:
        return _buildJugadorSearchScoutsList(results);
    }
  }

  Widget _buildJugadorSearchPlayersList(List<Map<String, dynamic>> players) {
    return Column(
      children: players.map((player) {
        final fullName =
            '${player['name'] ?? ''} ${player['lastname'] ?? ''}'.trim();
        final position = player['posicion']?.toString() ?? 'Sin posición';
        final city = _resolveCity(player);
        final country = _resolveCountryFromUser(player);
        final club = player['club']?.toString() ?? '';
        final uid = player['user_id']?.toString() ?? '';
        final hasVideo = _sortedPublicVideosForPlayer(uid).isNotEmpty;
        final category = _categoryFromBirthday(player['birthday']) ?? 'Senior';
        final levelName = _resolvePlayerLevel(player);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage:
                        (player['photo_url']?.toString().isNotEmpty ?? false)
                            ? NetworkImage(player['photo_url'])
                            : null,
                    backgroundColor: const Color(0xFFE8F0FE),
                    child: (player['photo_url']?.toString().isNotEmpty ?? false)
                        ? null
                        : Text(
                            fullName.isNotEmpty
                                ? fullName.substring(0, 1).toUpperCase()
                                : 'J',
                            style: const TextStyle(color: Color(0xFF0D3B66)),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isNotEmpty ? fullName : 'Jugador',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            category,
                            position,
                            if (club.isNotEmpty) club,
                            if (city.isNotEmpty) city,
                            if (country.isNotEmpty) country,
                          ].join(' • '),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF718096),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _simpleBadge(category, color: const Color(0xFF0D3B66)),
                  _simpleBadge(position, color: const Color(0xFF7C3AED)),
                  if (country.isNotEmpty)
                    _simpleBadge(country, color: const Color(0xFF0F766E)),
                  _simpleBadge(levelName, color: const Color(0xFF1D4ED8)),
                  _simpleBadge(
                    hasVideo ? 'Tem vídeo' : 'Sem vídeo',
                    color: hasVideo
                        ? const Color(0xFF2F855A)
                        : const Color(0xFF718096),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          hasVideo ? () => _openPlayerVideos(player) : null,
                      style: _explorerSecondaryButtonStyle(),
                      icon: const Icon(Icons.smart_display_rounded, size: 16),
                      label: const Text('Ver vídeo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openPublicPlayerProfile(player),
                      style: _explorerPrimaryButtonStyle(),
                      icon: const Icon(
                        Icons.person_search_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Ver perfil',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildJugadorSearchEntry() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _openJugadorSearchMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD6DEE8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFFA0AEC0)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Buscar jugadores, convocatorias, clubes o scouts...',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA0AEC0),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJugadorSearchClubsList(List<Map<String, dynamic>> clubs) {
    return Column(
      children: clubs.map((club) {
        final name = club['nombre']?.toString() ?? 'Club';
        final short = club['nombre_corto']?.toString() ?? '';
        final league = _resolveClubLeague(club);
        final country = _resolveCountryFromClub(club);
        final city = _resolveCity(club);
        final activeCount = _convocatorias.where((conv) {
          final clubData = conv['club_data'];
          if (clubData is Map) {
            return _clubRefFromMap(Map<String, dynamic>.from(clubData)) ==
                _clubRefFromMap(club);
          }
          return (conv['club_id']?.toString().trim() ?? '') ==
              _clubRefFromMap(club);
        }).length;

        return GestureDetector(
          onTap: () => _openPublicClubProfile(context, club),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE8F0FE),
                  backgroundImage:
                      club['logo_url']?.toString().isNotEmpty == true
                          ? NetworkImage(club['logo_url'].toString())
                          : null,
                  child: club['logo_url']?.toString().isNotEmpty == true
                      ? null
                      : const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF0D3B66),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (short.isNotEmpty) short,
                          if (league.isNotEmpty) league,
                          if (country.isNotEmpty) country,
                          if (city.isNotEmpty) city,
                        ].join(' • '),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF718096),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _simpleBadge(
                  activeCount > 0 ? '$activeCount activas' : 'Sin activas',
                  color: const Color(0xFF0D3B66),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildJugadorSearchScoutsList(List<Map<String, dynamic>> scouts) {
    return Column(
      children: scouts.map((scout) {
        final uid = scout['user_id']?.toString() ?? '';
        final name = '${scout['name'] ?? ''} ${scout['lastname'] ?? ''}'.trim();
        final city = _resolveCity(scout);
        final country = _resolveCountryFromUser(scout);
        final state = _resolveState(scout);
        final club = scout['club']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFE8F0FE),
                    backgroundImage:
                        scout['photo_url']?.toString().isNotEmpty == true
                            ? NetworkImage(scout['photo_url'].toString())
                            : null,
                    child: scout['photo_url']?.toString().isNotEmpty == true
                        ? null
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(color: Color(0xFF0D3B66)),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : 'Scout',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (club.isNotEmpty) club,
                            if (city.isNotEmpty) city,
                            if (state.isNotEmpty) state,
                            if (country.isNotEmpty) country,
                          ].join(' • '),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF718096),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: uid.isEmpty
                      ? null
                      : () {
                          context.pushNamed(
                            'perfil_profesional_solicitar_Contato',
                            queryParameters: {'userId': uid},
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                  ),
                  icon: const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Ver perfil',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Todos'),
        ),
        ...options.map(
          (opt) => DropdownMenuItem<String>(
            value: opt,
            child: Text(opt, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildSectionTitle(
    String title, {
    required IconData icon,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _explorerIconBadge(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0D3B66)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConvocatoriaInsightChips(Map<String, dynamic> convocatoria) {
    final closingLabel = _convocatoriaClosingLabel(convocatoria);
    final applicationsLabel = _convocatoriaApplicationsLabel(convocatoria);

    if ((closingLabel == null || closingLabel.isEmpty) &&
        (applicationsLabel == null || applicationsLabel.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (closingLabel != null && closingLabel.isNotEmpty)
          _buildInfoTag(Icons.schedule_outlined, closingLabel),
        if (applicationsLabel != null && applicationsLabel.isNotEmpty)
          _buildInfoTag(Icons.people_outline, applicationsLabel),
      ],
    );
  }

  Widget _buildPromotedConvocatorias(List<Map<String, dynamic>> convocatorias) {
    if (convocatorias.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.campaign_outlined,
        title: 'Sem resultados',
        subtitle: 'No hay convocatorias activas en este momento.',
      );
    }

    return Column(
      children: convocatorias.map(
        (conv) {
          final clubName = _resolveConvocatoriaClubName(conv);
          final details = [
            _resolveConvocatoriaPosition(conv),
            _resolveConvocatoriaCategory(conv),
            _resolveConvocatoriaCity(conv),
          ].where((value) => value.trim().isNotEmpty).join(' • ');

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FE),
                child: Icon(Icons.campaign_outlined,
                    color: Color(0xFF0D3B66), size: 18),
              ),
              title: Text(
                conv['titulo']?.toString() ?? 'Convocatoria',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (clubName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _openPublicClubProfile(
                        context,
                        conv['club_data'] is Map<String, dynamic>
                            ? Map<String, dynamic>.from(
                                conv['club_data'] as Map)
                            : {
                                'id': conv['club_id'],
                                'club_name': clubName,
                              },
                      ),
                      child: Text(
                        clubName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D3B66),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    details.isNotEmpty ? details : 'Sin detalles',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildConvocatoriaInsightChips(conv),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final id = conv['id']?.toString() ?? '';
                if (id.isEmpty) return;
                context.pushNamed(
                  DetallesDeLaConvocatoriaWidget.routeName,
                  queryParameters: {'convocatoriaId': id},
                );
              },
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _buildScoutTabBar() {
    Widget tab({
      required _ScoutTab tab,
      required String label,
      required IconData icon,
    }) {
      final selected = _scoutTab == tab;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _scoutTab = tab),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0D3B66) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0D3B66)
                    : const Color(0xFFD6DEE8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.16)
                        : const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: selected ? Colors.white : const Color(0xFF0D3B66),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: selected ? Colors.white : const Color(0xFF4A5568),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(
          tab: _ScoutTab.jugadores,
          label: 'Jugadores',
          icon: Icons.sports_soccer_rounded,
        ),
        const SizedBox(width: 8),
        tab(
          tab: _ScoutTab.clubes,
          label: 'Clubes',
          icon: Icons.shield_rounded,
        ),
        const SizedBox(width: 8),
        tab(
          tab: _ScoutTab.convocatorias,
          label: 'Convocatorias',
          icon: Icons.campaign_rounded,
        ),
      ],
    );
  }

  Widget _buildScoutPlayersList() {
    final players = _scoutFilteredPlayers;

    if (players.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.search_off,
        title: 'Sem resultados',
        subtitle: 'No se encontraron jugadores con los filtros aplicados.',
      );
    }

    return Column(
      children: players.map((player) {
        final fullName =
            '${player['name'] ?? ''} ${player['lastname'] ?? ''}'.trim();
        final position = player['posicion']?.toString() ?? 'Sin posición';
        final city = player['city']?.toString() ?? 'Sin ubicación';
        final club = player['club']?.toString() ?? '';
        final uid = player['user_id']?.toString() ?? '';
        final isSaved = _isPlayerSaved(uid);
        final isSaving = _savingPlayerId == uid;
        final hasVideo = _sortedPublicVideosForPlayer(uid).isNotEmpty;
        final category = _categoryFromBirthday(player['birthday']);
        final year = _birthYear(player['birthday']);
        final totalXp = GamificationService.toInt(player['total_xp']);
        final levelName = player['level_name']?.toString() ??
            GamificationService.levelNameFromPoints(totalXp);
        final rankingPosition = player['category_ranking'];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage:
                        (player['photo_url']?.toString().isNotEmpty ?? false)
                            ? NetworkImage(player['photo_url'])
                            : null,
                    backgroundColor: const Color(0xFFE8F0FE),
                    child: (player['photo_url']?.toString().isNotEmpty ?? false)
                        ? null
                        : Text(
                            fullName.isNotEmpty
                                ? fullName.substring(0, 1).toUpperCase()
                                : 'J',
                            style: const TextStyle(color: Color(0xFF0D3B66)),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isNotEmpty ? fullName : 'Jugador',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (year != null) year.toString(),
                            if (category != null) category,
                            position,
                            club,
                            city
                          ].where((v) => v.toString().isNotEmpty).join(' • '),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF718096),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _simpleBadge(
                    _isVerified(player) ? 'Verificado' : 'No verificado',
                    color: _isVerified(player)
                        ? const Color(0xFF2F855A)
                        : const Color(0xFFB7791F),
                  ),
                  _simpleBadge(
                    hasVideo ? 'Tem vídeo' : 'Sem vídeo',
                    color: hasVideo
                        ? const Color(0xFF0D3B66)
                        : const Color(0xFF718096),
                  ),
                  _simpleBadge(
                    '$totalXp XP',
                    color: const Color(0xFF1D4ED8),
                  ),
                  _simpleBadge(
                    levelName,
                    color: const Color(0xFF0F766E),
                  ),
                  if (rankingPosition != null)
                    _simpleBadge(
                      'Ranking #$rankingPosition',
                      color: const Color(0xFF7C3AED),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () => _toggleSavePlayerForScout(player),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor:
                            isSaved ? const Color(0xFF0F9D58) : Colors.white,
                        foregroundColor:
                            isSaved ? Colors.white : const Color(0xFF0D3B66),
                        side: BorderSide(
                          color: isSaved
                              ? const Color(0xFF0F9D58)
                              : const Color(0xFF0D3B66),
                        ),
                      ),
                      icon: isSaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isSaved
                                    ? Colors.white
                                    : const Color(0xFF0D3B66),
                              ),
                            )
                          : Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                              size: 16,
                            ),
                      label: Text(isSaved ? 'Guardado' : 'Salvar jugador'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          hasVideo ? () => _openPlayerVideos(player) : null,
                      style: _explorerSecondaryButtonStyle(),
                      icon: const Icon(Icons.smart_display_rounded, size: 16),
                      label: const Text('Ver vídeo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _openPublicPlayerProfile(player);
                      },
                      style: _explorerPrimaryButtonStyle(),
                      icon: const Icon(Icons.person_search_rounded,
                          size: 16, color: Colors.white),
                      label: const Text(
                        'Ver perfil',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScoutClubsList() {
    final clubs = _scoutFilteredClubs;

    if (clubs.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.search_off,
        title: 'Sem resultados',
        subtitle: 'No se encontraron clubes para esta búsqueda.',
      );
    }

    return Column(
      children: clubs.map((club) {
        final name = club['nombre']?.toString() ?? 'Club';
        final league = club['liga']?.toString() ?? '';
        final country = club['pais']?.toString() ?? '';
        final short = club['nombre_corto']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            onTap: () => _openPublicClubProfile(context, club),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8F0FE),
              child: Icon(Icons.shield_outlined, color: Color(0xFF0D3B66)),
            ),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (short.isNotEmpty) short,
                if (league.isNotEmpty) league,
                if (country.isNotEmpty) country
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Color(0xFF94A3B8),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScoutConvocatoriasList() {
    final convocatorias = _scoutFilteredConvocatorias;

    if (convocatorias.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.search_off,
        title: 'Sem resultados',
        subtitle: 'No hay convocatorias para los filtros seleccionados.',
      );
    }

    return Column(
      children: convocatorias.map((conv) {
        final id = conv['id']?.toString() ?? '';
        final clubName = _resolveConvocatoriaClubName(conv);
        final details = [
          _resolveConvocatoriaPosition(conv),
          _resolveConvocatoriaCategory(conv),
          _resolveConvocatoriaCity(conv),
          _resolveConvocatoriaCountry(conv),
        ].where((value) => value.trim().isNotEmpty).join(' • ');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8F0FE),
              child: Icon(Icons.campaign_outlined, color: Color(0xFF0D3B66)),
            ),
            title: Text(
              conv['titulo']?.toString() ?? 'Convocatoria',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (clubName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _openPublicClubProfile(
                      context,
                      conv['club_data'] is Map<String, dynamic>
                          ? Map<String, dynamic>.from(conv['club_data'] as Map)
                          : {
                              'id': conv['club_id'],
                              'club_name': clubName,
                            },
                    ),
                    child: Text(
                      clubName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  details.isNotEmpty ? details : 'Sin detalles',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _buildConvocatoriaInsightChips(conv),
              ],
            ),
            trailing: ElevatedButton.icon(
              onPressed: id.isEmpty
                  ? null
                  : () {
                      context.pushNamed(
                        DetallesDeLaConvocatoriaProfesionalWidget.routeName,
                        queryParameters: {'convocatoriasID': id},
                      );
                    },
              style: _explorerPrimaryButtonStyle(),
              icon: const Icon(
                Icons.visibility_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: const Text('Ver', style: TextStyle(color: Colors.white)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openScoutFilters({
    required List<String> playerPositionOptions,
    required List<String> playerCategoryOptions,
    required List<String> playerCountryOptions,
    required List<String> playerCityOptions,
    required List<String> playerLevelOptions,
    required List<String> clubCountryOptions,
    required List<String> clubCityOptions,
    required List<String> clubLeagueOptions,
    required List<String> convocatoriaCountryOptions,
    required List<String> convocatoriaCityOptions,
    required List<String> convocatoriaCategoryOptions,
    required List<String> convocatoriaPositionOptions,
  }) async {
    String? tempPosition = _scoutPosition;
    String? tempCategory = _scoutCategory;
    String? tempPlayerCountry = _scoutPlayerCountry;
    String? tempPlayerCity = _scoutPlayerCity;
    String? tempPlayerLevel = _scoutPlayerLevel;
    String? tempClubCountry = _scoutClubCountry;
    String? tempClubCity = _scoutClubCity;
    String? tempClubLeague = _scoutClubLeague;
    String? tempConvCountry = _scoutConvocatoriaCountry;
    String? tempConvCity = _scoutConvocatoriaCity;
    String? tempConvCategory = _scoutConvocatoriaCategory;
    String? tempConvPosition = _scoutConvocatoriaPosition;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _scoutTab == _ScoutTab.convocatorias
                        ? 'Filtros de convocatorias'
                        : _scoutTab == _ScoutTab.clubes
                            ? 'Filtros de clubes'
                            : 'Filtros de jugadores',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_scoutTab == _ScoutTab.convocatorias) ...[
                    _buildDropdownFilter(
                      label: 'País',
                      value: tempConvCountry,
                      options: convocatoriaCountryOptions,
                      onChanged: (v) =>
                          setSheetState(() => tempConvCountry = v),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Ciudad',
                      value: tempConvCity,
                      options: convocatoriaCityOptions,
                      onChanged: (v) => setSheetState(() => tempConvCity = v),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Categoría',
                      value: tempConvCategory,
                      options: convocatoriaCategoryOptions,
                      onChanged: (v) =>
                          setSheetState(() => tempConvCategory = v),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Posición buscada',
                      value: tempConvPosition,
                      options: convocatoriaPositionOptions,
                      onChanged: (v) =>
                          setSheetState(() => tempConvPosition = v),
                    ),
                  ] else if (_scoutTab == _ScoutTab.clubes) ...[
                    _buildDropdownFilter(
                      label: 'País',
                      value: tempClubCountry,
                      options: clubCountryOptions,
                      onChanged: (v) =>
                          setSheetState(() => tempClubCountry = v),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Ciudad',
                      value: tempClubCity,
                      options: clubCityOptions,
                      onChanged: (v) => setSheetState(() => tempClubCity = v),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Liga',
                      value: tempClubLeague,
                      options: clubLeagueOptions,
                      onChanged: (v) => setSheetState(() => tempClubLeague = v),
                    ),
                  ] else ...[
                    _buildDropdownFilter(
                      label: 'Categoría',
                      value: tempCategory,
                      options: playerCategoryOptions,
                      onChanged: (v) => setSheetState(() => tempCategory = v),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Posición',
                      value: tempPosition,
                      options: playerPositionOptions,
                      onChanged: (v) => setSheetState(() => tempPosition = v),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'País',
                      value: tempPlayerCountry,
                      options: playerCountryOptions,
                      onChanged: (v) =>
                          setSheetState(() => tempPlayerCountry = v),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Ciudad',
                      value: tempPlayerCity,
                      options: playerCityOptions,
                      onChanged: (v) => setSheetState(() => tempPlayerCity = v),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Nivel',
                      value: tempPlayerLevel,
                      options: playerLevelOptions,
                      onChanged: (v) =>
                          setSheetState(() => tempPlayerLevel = v),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              if (_scoutTab == _ScoutTab.convocatorias) {
                                tempConvCountry = null;
                                tempConvCity = null;
                                tempConvCategory = null;
                                tempConvPosition = null;
                              } else if (_scoutTab == _ScoutTab.clubes) {
                                tempClubCountry = null;
                                tempClubCity = null;
                                tempClubLeague = null;
                              } else {
                                tempPosition = null;
                                tempCategory = null;
                                tempPlayerCountry = null;
                                tempPlayerCity = null;
                                tempPlayerLevel = null;
                              }
                            });
                          },
                          child: const Text('Limpar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (_scoutTab == _ScoutTab.convocatorias) {
                                _scoutConvocatoriaCountry = tempConvCountry;
                                _scoutConvocatoriaCity = tempConvCity;
                                _scoutConvocatoriaCategory = tempConvCategory;
                                _scoutConvocatoriaPosition = tempConvPosition;
                              } else if (_scoutTab == _ScoutTab.clubes) {
                                _scoutClubCountry = tempClubCountry;
                                _scoutClubCity = tempClubCity;
                                _scoutClubLeague = tempClubLeague;
                              } else {
                                _scoutPosition = tempPosition;
                                _scoutCategory = tempCategory;
                                _scoutPlayerCountry = tempPlayerCountry;
                                _scoutPlayerCity = tempPlayerCity;
                                _scoutPlayerLevel = tempPlayerLevel;
                              }
                            });
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
                  const SizedBox(height: 4),
                  if (_scoutTab == _ScoutTab.jugadores && !_isClubStaff)
                    Text(
                      'Compartilhar listas só aparece para staff de clube.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF718096),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _simpleBadge(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInlineStatus({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFA0AEC0), size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: const Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }
}

class _JugadorScoutsResultsPage extends StatefulWidget {
  const _JugadorScoutsResultsPage({
    required this.scouts,
  });

  final List<Map<String, dynamic>> scouts;

  @override
  State<_JugadorScoutsResultsPage> createState() =>
      _JugadorScoutsResultsPageState();
}

class _JugadorScoutsResultsPageState extends State<_JugadorScoutsResultsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCountry;
  String? _selectedState;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _uniqueValues(Iterable<dynamic> values) {
    final set = <String>{};
    for (final raw in values) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty) set.add(value);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _filteredScouts {
    Iterable<Map<String, dynamic>> items = widget.scouts;

    if (_selectedCountry != null) {
      items = items.where(
        (item) =>
            (item['country_name']?.toString().trim().toLowerCase() ?? '') ==
            _selectedCountry!.toLowerCase(),
      );
    }

    if (_selectedState != null) {
      items = items.where(
        (item) =>
            (item['state_name']?.toString().trim().toLowerCase() ?? '') ==
            _selectedState!.toLowerCase(),
      );
    }

    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        final text =
            '${item['name'] ?? ''} ${item['lastname'] ?? ''} ${item['city_name'] ?? ''} ${item['country_name'] ?? ''} ${item['state_name'] ?? ''} ${item['club'] ?? ''}'
                .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    return items.toList();
  }

  @override
  Widget build(BuildContext context) {
    final countries =
        _uniqueValues(widget.scouts.map((item) => item['country_name']));
    final states = _uniqueValues(
      widget.scouts.where((item) {
        if (_selectedCountry == null) return true;
        return (item['country_name']?.toString().trim().toLowerCase() ?? '') ==
            _selectedCountry!.toLowerCase();
      }).map((item) => item['state_name']),
    );

    final scouts = _filteredScouts;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D3B66),
        title: Text(
          'Scouts verificados',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D3B66),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            children: [
              _ExplorerSearchField(
                controller: _searchController,
                hintText: 'Buscar scout...',
                onChanged: (value) => setState(
                  () => _searchQuery = value.trim().toLowerCase(),
                ),
                onClear: () => setState(() => _searchQuery = ''),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ExplorerFilterDropdown(
                      label: 'País',
                      value: _selectedCountry,
                      options: countries,
                      onChanged: (value) => setState(() {
                        _selectedCountry = value;
                        _selectedState = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExplorerFilterDropdown(
                      label: 'Provincia/Estado',
                      value: _selectedState,
                      options: states,
                      onChanged: (value) =>
                          setState(() => _selectedState = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: scouts.isEmpty
                    ? _ExplorerEmptyState(
                        icon: Icons.search_off,
                        title: 'Sem resultados',
                        subtitle:
                            'No se encontraron scouts con los filtros aplicados.',
                      )
                    : ListView.separated(
                        itemCount: scouts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final scout = scouts[index];
                          final uid = scout['user_id']?.toString() ?? '';
                          final name =
                              '${scout['name'] ?? ''} ${scout['lastname'] ?? ''}'
                                  .trim();
                          final city = scout['city_name']?.toString() ?? '';
                          final country =
                              scout['country_name']?.toString().trim() ?? '';
                          final state = scout['state_name']?.toString() ?? '';
                          final club = scout['club']?.toString() ?? '';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: const Color(0xFFE8F0FE),
                                      backgroundImage: scout['photo_url']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? NetworkImage(
                                              scout['photo_url'].toString(),
                                            )
                                          : null,
                                      child: scout['photo_url']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? null
                                          : Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : 'S',
                                              style: const TextStyle(
                                                color: Color(0xFF0D3B66),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name.isNotEmpty ? name : 'Scout',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if (club.isNotEmpty) club,
                                              if (city.isNotEmpty) city,
                                              if (state.isNotEmpty) state,
                                              if (country.isNotEmpty) country,
                                            ].join(' • '),
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF718096),
                                              fontSize: 12,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: uid.isEmpty
                                        ? null
                                        : () {
                                            context.pushNamed(
                                              'perfil_profesional_solicitar_Contato',
                                              queryParameters: {'userId': uid},
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D3B66),
                                    ),
                                    icon: const Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Ver perfil',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
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
  }
}

class _JugadorClubsResultsPage extends StatefulWidget {
  const _JugadorClubsResultsPage({
    required this.clubs,
  });

  final List<Map<String, dynamic>> clubs;

  @override
  State<_JugadorClubsResultsPage> createState() =>
      _JugadorClubsResultsPageState();
}

class _JugadorClubsResultsPageState extends State<_JugadorClubsResultsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCountry;
  String? _selectedState;
  String? _selectedCity;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _uniqueValues(Iterable<dynamic> values) {
    final set = <String>{};
    for (final raw in values) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty) set.add(value);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _filteredClubs {
    Iterable<Map<String, dynamic>> items = widget.clubs;

    if (_selectedCountry != null) {
      items = items.where(
        (item) =>
            (item['country_name']?.toString().trim().toLowerCase() ?? '') ==
            _selectedCountry!.toLowerCase(),
      );
    }

    if (_selectedState != null) {
      items = items.where(
        (item) =>
            (item['state_name']?.toString().trim().toLowerCase() ?? '') ==
            _selectedState!.toLowerCase(),
      );
    }

    if (_selectedCity != null) {
      items = items.where(
        (item) =>
            (item['city_name']?.toString().trim().toLowerCase() ?? '') ==
            _selectedCity!.toLowerCase(),
      );
    }

    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        final text =
            '${item['nombre'] ?? ''} ${item['nombre_corto'] ?? ''} ${item['country_name'] ?? ''} ${item['state_name'] ?? ''} ${item['city_name'] ?? ''} ${item['liga'] ?? ''}'
                .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    return items.toList();
  }

  @override
  Widget build(BuildContext context) {
    final countries =
        _uniqueValues(widget.clubs.map((item) => item['country_name']));
    final states = _uniqueValues(
      widget.clubs.where((item) {
        if (_selectedCountry == null) return true;
        return (item['country_name']?.toString().trim().toLowerCase() ?? '') ==
            _selectedCountry!.toLowerCase();
      }).map((item) => item['state_name']),
    );
    final cities = _uniqueValues(
      widget.clubs.where((item) {
        if (_selectedCountry != null &&
            (item['country_name']?.toString().trim().toLowerCase() ?? '') !=
                _selectedCountry!.toLowerCase()) {
          return false;
        }
        if (_selectedState == null) return true;
        return (item['state_name']?.toString().trim().toLowerCase() ?? '') ==
            _selectedState!.toLowerCase();
      }).map((item) => item['city_name']),
    );
    final clubs = _filteredClubs;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D3B66),
        title: Text(
          'Clubes',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D3B66),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            children: [
              _ExplorerSearchField(
                controller: _searchController,
                hintText: 'Buscar club...',
                onChanged: (value) => setState(
                  () => _searchQuery = value.trim().toLowerCase(),
                ),
                onClear: () => setState(() => _searchQuery = ''),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ExplorerFilterDropdown(
                      label: 'País',
                      value: _selectedCountry,
                      options: countries,
                      onChanged: (value) => setState(() {
                        _selectedCountry = value;
                        _selectedState = null;
                        _selectedCity = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExplorerFilterDropdown(
                      label: 'Provincia/Estado',
                      value: _selectedState,
                      options: states,
                      onChanged: (value) => setState(() {
                        _selectedState = value;
                        _selectedCity = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ExplorerFilterDropdown(
                label: 'Ciudad',
                value: _selectedCity,
                options: cities,
                onChanged: (value) => setState(() => _selectedCity = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: clubs.isEmpty
                    ? _ExplorerEmptyState(
                        icon: Icons.search_off,
                        title: 'Sem resultados',
                        subtitle:
                            'No se encontraron clubes con los filtros aplicados.',
                      )
                    : ListView.separated(
                        itemCount: clubs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final club = clubs[index];
                          final name = club['nombre']?.toString() ?? 'Club';
                          final short = club['nombre_corto']?.toString() ?? '';
                          final league = club['liga']?.toString() ?? '';
                          final country =
                              club['country_name']?.toString().trim() ?? '';
                          final state =
                              club['state_name']?.toString().trim() ?? '';
                          final city =
                              club['city_name']?.toString().trim() ?? '';
                          final description =
                              club['descripcion']?.toString().trim() ?? '';

                          return GestureDetector(
                            onTap: () => _openPublicClubProfile(context, club),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            const Color(0xFFE8F0FE),
                                        backgroundImage: club['logo_url']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true
                                            ? NetworkImage(
                                                club['logo_url'].toString(),
                                              )
                                            : null,
                                        child: club['logo_url']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true
                                            ? null
                                            : const Icon(
                                                Icons.shield_outlined,
                                                color: Color(0xFF0D3B66),
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              [
                                                if (short.isNotEmpty) short,
                                                if (league.isNotEmpty) league,
                                                if (city.isNotEmpty) city,
                                                if (state.isNotEmpty) state,
                                                if (country.isNotEmpty) country,
                                              ].join(' • '),
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF718096),
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ],
                                  ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF4A5568),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
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
  }
}

class _ExplorerSearchField extends StatelessWidget {
  const _ExplorerSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6DEE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D3B66),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                color: Color(0xFF0D3B66),
                size: 18,
              ),
            ),
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    controller.clear();
                    onClear();
                  },
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFFA0AEC0)),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
        style: GoogleFonts.inter(fontSize: 14),
      ),
    );
  }
}

class _ExplorerFilterDropdown extends StatelessWidget {
  const _ExplorerFilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Todos'),
        ),
        ...options.map(
          (opt) => DropdownMenuItem<String>(
            value: opt,
            child: Text(
              opt,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ExplorerEmptyState extends StatelessWidget {
  const _ExplorerEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFA0AEC0), size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: const Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreviewSheet extends StatefulWidget {
  const _VideoPreviewSheet({required this.videos});

  final List<Map<String, dynamic>> videos;

  @override
  State<_VideoPreviewSheet> createState() => _VideoPreviewSheetState();
}

class _VideoPreviewSheetState extends State<_VideoPreviewSheet> {
  late PageController _pageController;
  int _index = 0;

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
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.videos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final video = widget.videos[i];
              return _VideoPlayerCard(
                videoUrl: video['video_url']?.toString() ?? '',
                title: video['title']?.toString() ?? 'Vídeo',
                active: i == _index,
              );
            },
          ),
          Positioned(
            top: 14,
            left: 14,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerCard extends StatefulWidget {
  const _VideoPlayerCard({
    required this.videoUrl,
    required this.title,
    required this.active,
  });

  final String videoUrl;
  final String title;
  final bool active;

  @override
  State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_initialized) return;

    if (widget.active) {
      _controller!.play();
    } else {
      _controller!.pause();
    }
  }

  Future<void> _initVideo() async {
    if (!widget.videoUrl.startsWith('http')) {
      setState(() => _hasError = true);
      return;
    }

    try {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      _controller!.setLooping(true);
      if (mounted) {
        setState(() => _initialized = true);
        if (widget.active) {
          _controller!.play();
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
    if (_hasError) {
      return const Center(
        child: Text(
          'No se pudo reproducir el video',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (!_initialized || _controller == null) {
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
