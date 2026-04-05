import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/notificacoes/activity_notifications_service.dart';
import '/fluxo_compartilhado/perfil_publico_club/perfil_publico_club_widget.dart';
import '/flutter_flow/app_modals.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/gamification/gamification_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_club_model.dart';
export 'dashboard_club_model.dart';

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

class DashboardClubWidget extends StatefulWidget {
  const DashboardClubWidget({
    super.key,
    this.searchOnly = false,
    this.initialSearchQuery = '',
  });

  static String routeName = 'dashboard_club';
  static String routePath = '/dashboardClub';

  final bool searchOnly;
  final String initialSearchQuery;

  @override
  State<DashboardClubWidget> createState() => _DashboardClubWidgetState();
}

class _DashboardClubWidgetState extends State<DashboardClubWidget> {
  late DashboardClubModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String? _errorMessage;

  String? _clubName;
  int? _currentPlanId;
  bool _currentUserVerified = true;

  List<Map<String, dynamic>> _activeConvocatorias = [];
  List<Map<String, dynamic>> _recentPostulaciones = [];
  List<Map<String, dynamic>> _suggestedPlayers = [];

  Map<String, Map<String, int>> _pipelineByConvocatoria = {};
  final Map<String, Map<String, dynamic>> _latestVideoByPlayerId = {};
  final Map<String, int> _videoCountByPlayerId = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _homeScope = 'jugadores';
  bool _isSearchingPlayers = false;
  List<Map<String, dynamic>> _searchPlayers = [];
  List<Map<String, dynamic>> _searchClubs = [];
  List<Map<String, dynamic>> _searchTryouts = [];
  final Map<int, String> _countryNameById = {};
  final Set<String> _savedPlayerIds = <String>{};
  String? _savingPlayerId;
  String? _invitingPlayerId;

  String? _playerFilterCategory;
  String? _playerFilterPosition;
  String? _playerFilterCountry;
  String? _playerFilterCity;
  String? _playerFilterLevel;
  String? _clubFilterCountry;
  String? _clubFilterCity;
  String? _clubFilterLeague;
  String? _tryoutFilterCategory;
  String? _tryoutFilterPosition;
  String? _tryoutFilterCountry;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardClubModel());
    _searchController.addListener(_onSearchChanged);
    final initialQuery = widget.initialSearchQuery.trim();
    if (widget.searchOnly && initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchController.text = initialQuery;
        _searchController.selection = TextSelection.collapsed(
          offset: initialQuery.length,
        );
      });
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _model.dispose();
    super.dispose();
  }

  bool get _canUseSensitiveActions =>
      FFAppState().unlockSensitiveActions ||
      (_currentPlanId != null && _currentUserVerified);

  Future<void> _loadData() async {
    if (currentUserUid.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se encontró sesión activa.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadViewerCapabilities(),
        _loadClubName(),
        _loadCountryNames(),
        _loadSavedPlayers(),
      ]);

      final convocatoriasResponse = await SupaFlow.client
          .from('convocatorias')
          .select()
          .eq('club_id', currentUserUid)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(60);

      _activeConvocatorias =
          List<Map<String, dynamic>>.from(convocatoriasResponse);

      final convocatoriaIds = _activeConvocatorias
          .map((c) => c['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (convocatoriaIds.isEmpty) {
        _recentPostulaciones = [];
        _suggestedPlayers = [];
        _pipelineByConvocatoria = {};
        _latestVideoByPlayerId.clear();
        _videoCountByPlayerId.clear();
        return;
      }

      final postulaciones = await _fetchApplicationsForConvocatorias(
        convocatoriaIds: convocatoriaIds,
        limit: 500,
      );

      final playerIds = postulaciones
          .map(_postulacionPlayerId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final usersMap = await _loadUsersMap(playerIds);
      await _loadVideoDataForPlayers(playerIds);

      _computeConvocatoriaCardStats(postulaciones);
      _computePipelineStats(postulaciones);
      _buildRecentPostulaciones(postulaciones, usersMap);
      await _buildSuggestedPlayers(usersMap, postulaciones);
    } catch (e) {
      _errorMessage = 'Error al cargar Dashboard del club';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadViewerCapabilities() async {
    try {
      final user = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', currentUserUid)
          .maybeSingle();

      if (user != null) {
        _currentPlanId = user['plan_id'] as int?;
        _currentUserVerified =
            _resolveVerification(user, defaultIfMissing: true);
      } else {
        _currentPlanId = null;
        _currentUserVerified = true;
      }
    } catch (_) {
      _currentPlanId = null;
      _currentUserVerified = true;
    }
  }

  Future<void> _loadClubName() async {
    try {
      final club = await SupaFlow.client
          .from('clubs')
          .select('nombre')
          .eq('owner_id', currentUserUid)
          .maybeSingle();
      _clubName = club?['nombre']?.toString();
    } catch (_) {
      _clubName = null;
    }
  }

  Future<void> _loadCountryNames() async {
    try {
      final response = await SupaFlow.client
          .from('countrys')
          .select('id, name')
          .order('name');
      _countryNameById.clear();
      for (final row in (response as List)) {
        final map = Map<String, dynamic>.from(row);
        final id = map['id'] is int
            ? map['id'] as int
            : int.tryParse(map['id']?.toString() ?? '');
        final name = map['name']?.toString().trim() ?? '';
        if (id != null && name.isNotEmpty) {
          _countryNameById[id] = name;
        }
      }
    } catch (_) {
      _countryNameById.clear();
    }
  }

  Future<void> _loadSavedPlayers() async {
    _savedPlayerIds.clear();

    if (currentUserUid.isEmpty) return;

    try {
      final savedByClub = await SupaFlow.client
          .from('jugadores_guardados')
          .select('jugador_id')
          .eq('club_id', currentUserUid)
          .limit(800);
      for (final row in (savedByClub as List)) {
        final id = row['jugador_id']?.toString() ?? '';
        if (id.isNotEmpty) _savedPlayerIds.add(id);
      }
    } catch (_) {}

    if (_savedPlayerIds.isNotEmpty) return;

    try {
      final savedByScout = await SupaFlow.client
          .from('jugadores_guardados')
          .select('jugador_id')
          .eq('scout_id', currentUserUid)
          .limit(800);
      for (final row in (savedByScout as List)) {
        final id = row['jugador_id']?.toString() ?? '';
        if (id.isNotEmpty) _savedPlayerIds.add(id);
      }
    } catch (_) {}
  }

  Future<Map<String, Map<String, dynamic>>> _loadUsersMap(
      List<String> ids) async {
    if (ids.isEmpty) return {};

    try {
      final response =
          await SupaFlow.client.from('users').select().inFilter('user_id', ids);

      final map = <String, Map<String, dynamic>>{};
      for (final row in (response as List)) {
        final id = row['user_id']?.toString() ?? '';
        if (id.isNotEmpty) {
          map[id] = Map<String, dynamic>.from(row);
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadVideoDataForPlayers(List<String> playerIds) async {
    _latestVideoByPlayerId.clear();
    _videoCountByPlayerId.clear();

    if (playerIds.isEmpty) return;

    try {
      final response = await SupaFlow.client
          .from('videos')
          .select('id, user_id, title, thumbnail_url, video_url, created_at')
          .eq('is_public', true)
          .inFilter('user_id', playerIds)
          .order('created_at', ascending: false)
          .limit(400);

      final videos = List<Map<String, dynamic>>.from(response);
      for (final video in videos) {
        final uid = video['user_id']?.toString() ?? '';
        if (uid.isEmpty) continue;

        _videoCountByPlayerId[uid] = (_videoCountByPlayerId[uid] ?? 0) + 1;
        _latestVideoByPlayerId.putIfAbsent(uid, () => video);
      }
    } catch (_) {}
  }

  void _onSearchChanged() {
    final previousQuery = _searchQuery;
    final value = _searchController.text.trim();
    if (value == _searchQuery) return;
    _searchQuery = value;

    final wasSearchMode = previousQuery.trim().length >= 2;
    final willSearch = value.trim().length >= 2;

    if (!willSearch) {
      if (!mounted) return;
      setState(() {
        _homeScope = 'jugadores';
        _resetSearchFilters();
        _isSearchingPlayers = false;
        _searchPlayers = [];
        _searchClubs = [];
        _searchTryouts = [];
      });
      return;
    }

    if (!wasSearchMode && willSearch && mounted) {
      setState(() {
        _homeScope = 'jugadores';
        _resetSearchFilters();
      });
    }

    _searchHome(value);
  }

  void _setHomeScope(String scope) {
    if (!_isSearchMode) return;
    if (_homeScope == scope) return;
    setState(() {
      _homeScope = scope;
      _resetSearchFilters();
    });
    _searchHome(_searchQuery);
  }

  void _resetSearchFilters() {
    _playerFilterCategory = null;
    _playerFilterPosition = null;
    _playerFilterCountry = null;
    _playerFilterCity = null;
    _playerFilterLevel = null;
    _clubFilterCountry = null;
    _clubFilterCity = null;
    _clubFilterLeague = null;
    _tryoutFilterCategory = null;
    _tryoutFilterPosition = null;
    _tryoutFilterCountry = null;
  }

  Future<void> _searchHome(String value) async {
    switch (_homeScope) {
      case 'clubes':
        await _searchClubsForHome(value);
        break;
      case 'tryouts':
        await _searchTryoutsForHome(value);
        break;
      default:
        await _searchPlayersForClub(value);
        break;
    }
  }

  Future<void> _searchPlayersForClub(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _isSearchingPlayers = false;
        _searchPlayers = [];
        _searchClubs = [];
        _searchTryouts = [];
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isSearchingPlayers = true;
      });
    }

    try {
      List<Map<String, dynamic>> players;
      try {
        final response = await SupaFlow.client
            .from('users')
            .select(
                'user_id, name, lastname, username, posicion, position, city, ciudad, club, birthday, birth_date, categoria, category, photo_url, userType, pais, country, country_name, country_id')
            .inFilter('userType',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta'])
            .or('name.ilike.%$query%,lastname.ilike.%$query%,username.ilike.%$query%,posicion.ilike.%$query%,position.ilike.%$query%,city.ilike.%$query%,ciudad.ilike.%$query%,club.ilike.%$query%,categoria.ilike.%$query%,category.ilike.%$query%,pais.ilike.%$query%,country.ilike.%$query%,country_name.ilike.%$query%')
            .limit(80);
        players = List<Map<String, dynamic>>.from(response);
      } catch (_) {
        final response = await SupaFlow.client
            .from('users')
            .select(
                'user_id, name, lastname, username, posicion, position, city, ciudad, club, birthday, birth_date, categoria, category, photo_url, usertype, pais, country, country_name, country_id')
            .inFilter('usertype',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta'])
            .or('name.ilike.%$query%,lastname.ilike.%$query%,username.ilike.%$query%,posicion.ilike.%$query%,position.ilike.%$query%,city.ilike.%$query%,ciudad.ilike.%$query%,club.ilike.%$query%,categoria.ilike.%$query%,category.ilike.%$query%,pais.ilike.%$query%,country.ilike.%$query%,country_name.ilike.%$query%')
            .limit(80);
        players = List<Map<String, dynamic>>.from(response);
      }
      final ids = players
          .map((p) => p['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final latestVideoByUser = <String, Map<String, dynamic>>{};
      final videoCountByUser = <String, int>{};
      if (ids.isNotEmpty) {
        try {
          final videos = await SupaFlow.client
              .from('videos')
              .select(
                  'id, user_id, title, thumbnail_url, video_url, created_at')
              .eq('is_public', true)
              .inFilter('user_id', ids)
              .order('created_at', ascending: false)
              .limit(200);
          for (final row in (videos as List)) {
            final map = Map<String, dynamic>.from(row);
            final uid = map['user_id']?.toString() ?? '';
            if (uid.isEmpty) continue;
            videoCountByUser[uid] = (videoCountByUser[uid] ?? 0) + 1;
            latestVideoByUser.putIfAbsent(uid, () => map);
          }
        } catch (_) {}
      }

      for (final player in players) {
        final uid = player['user_id']?.toString() ?? '';
        player['latest_video'] = latestVideoByUser[uid];
        player['video_count'] = videoCountByUser[uid] ?? 0;
      }

      await _loadSearchPlayerProgress(players);

      if (!mounted) return;
      setState(() {
        _searchPlayers = players;
        _searchClubs = [];
        _searchTryouts = [];
        _isSearchingPlayers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchPlayers = [];
        _searchClubs = [];
        _searchTryouts = [];
        _isSearchingPlayers = false;
      });
    }
  }

  Future<void> _searchClubsForHome(String value) async {
    final query = value.trim().toLowerCase();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _isSearchingPlayers = false;
        _searchPlayers = [];
        _searchClubs = [];
        _searchTryouts = [];
      });
      return;
    }
    if (mounted) {
      setState(() => _isSearchingPlayers = true);
    }

    try {
      final response = await SupaFlow.client
          .from('clubs')
          .select()
          .order('created_at', ascending: false)
          .limit(140);
      final allClubs = List<Map<String, dynamic>>.from(response);
      final clubs = allClubs.where((club) {
        final name =
            (club['nombre'] ?? club['name'] ?? club['club_name'] ?? 'Club')
                .toString()
                .toLowerCase();
        final city =
            (club['city'] ?? club['ubicacion'] ?? '').toString().toLowerCase();
        final league =
            (club['liga'] ?? club['league'] ?? club['league_name'] ?? '')
                .toString()
                .toLowerCase();
        final country =
            (club['pais'] ?? club['country'] ?? club['country_name'] ?? '')
                .toString()
                .toLowerCase();
        return name.contains(query) ||
            city.contains(query) ||
            league.contains(query) ||
            country.contains(query);
      }).toList();

      if (!mounted) return;
      setState(() {
        _searchPlayers = [];
        _searchTryouts = [];
        _searchClubs = clubs.take(40).toList();
        _isSearchingPlayers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchPlayers = [];
        _searchTryouts = [];
        _searchClubs = [];
        _isSearchingPlayers = false;
      });
    }
  }

  Future<void> _searchTryoutsForHome(String value) async {
    final query = value.trim().toLowerCase();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _isSearchingPlayers = false;
        _searchPlayers = [];
        _searchClubs = [];
        _searchTryouts = [];
      });
      return;
    }
    if (mounted) {
      setState(() => _isSearchingPlayers = true);
    }

    try {
      final response = await SupaFlow.client
          .from('convocatorias')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(180);

      final allTryouts = List<Map<String, dynamic>>.from(response);
      await _decorateTryoutsWithClubData(allTryouts);
      final tryouts = allTryouts.where((row) {
        final title =
            (row['titulo'] ?? row['title'] ?? '').toString().toLowerCase();
        final desc = (row['descripcion'] ?? row['description'] ?? '')
            .toString()
            .toLowerCase();
        final zone = (row['ubicacion'] ?? row['location'] ?? '')
            .toString()
            .toLowerCase();
        final category = _resolveTryoutCategory(row).toLowerCase();
        final position = _resolveTryoutPosition(row).toLowerCase();
        final clubName = _resolveTryoutClubName(row).toLowerCase();
        final country = _resolveTryoutCountry(row).toLowerCase();
        return title.contains(query) ||
            desc.contains(query) ||
            zone.contains(query) ||
            category.contains(query) ||
            position.contains(query) ||
            clubName.contains(query) ||
            country.contains(query);
      }).toList();

      if (!mounted) return;
      setState(() {
        _searchPlayers = [];
        _searchClubs = [];
        _searchTryouts = tryouts.take(50).toList();
        _isSearchingPlayers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchPlayers = [];
        _searchClubs = [];
        _searchTryouts = [];
        _isSearchingPlayers = false;
      });
    }
  }

  Future<void> _decorateTryoutsWithClubData(
    List<Map<String, dynamic>> tryouts,
  ) async {
    if (tryouts.isEmpty) return;

    try {
      final clubsResponse = await SupaFlow.client
          .from('clubs')
          .select()
          .order('created_at', ascending: false)
          .limit(400);
      final clubs = List<Map<String, dynamic>>.from(clubsResponse);
      final clubByRef = <String, Map<String, dynamic>>{};

      for (final club in clubs) {
        final refs = [
          club['id'],
          club['owner_id'],
          club['user_id'],
        ];
        for (final ref in refs) {
          final key = ref?.toString().trim() ?? '';
          if (key.isNotEmpty) {
            clubByRef[key] = club;
          }
        }
      }

      for (final tryout in tryouts) {
        final clubRef = tryout['club_id']?.toString().trim() ?? '';
        if (clubRef.isEmpty) continue;
        final club = clubByRef[clubRef];
        if (club != null) {
          tryout['club_data'] = club;
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSearchPlayerProgress(
    List<Map<String, dynamic>> players,
  ) async {
    final ids = players
        .map((player) => player['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    final progressByUserId = <String, Map<String, dynamic>>{};
    try {
      final progressRows = await SupaFlow.client
          .from('user_progress')
          .select('user_id, total_xp, current_level_id')
          .inFilter('user_id', ids);
      for (final row in (progressRows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final uid = map['user_id']?.toString() ?? '';
        if (uid.isNotEmpty) {
          progressByUserId[uid] = map;
        }
      }
    } catch (_) {}

    for (final player in players) {
      final uid = player['user_id']?.toString() ?? '';
      final progress = progressByUserId[uid] ?? const <String, dynamic>{};
      final totalXp = GamificationService.toInt(progress['total_xp']);
      player['user_progress'] = progress;
      player['total_xp'] = totalXp;
      player['level_name'] = GamificationService.levelNameFromPoints(totalXp);
    }
  }

  void _computeConvocatoriaCardStats(List<Map<String, dynamic>> postulaciones) {
    for (final conv in _activeConvocatorias) {
      final convId = conv['id']?.toString() ?? '';
      final list = postulaciones
          .where((p) => (p['convocatoria_id']?.toString() ?? '') == convId)
          .toList();

      final savedCount =
          list.where((p) => _isSavedPipelineStage(p['estado'])).length;

      conv['postulaciones_count'] = list.length;
      conv['saved_count'] = savedCount;
    }
  }

  void _computePipelineStats(List<Map<String, dynamic>> postulaciones) {
    final map = <String, Map<String, int>>{};

    for (final conv in _activeConvocatorias) {
      final convId = conv['id']?.toString() ?? '';
      final list = postulaciones
          .where((p) => (p['convocatoria_id']?.toString() ?? '') == convId)
          .toList();

      final postulated = list.length;
      final saved =
          list.where((p) => _isSavedPipelineStage(p['estado'])).length;
      final interest =
          list.where((p) => _isInterestPipelineStage(p['estado'])).length;

      map[convId] = {
        'postulated': postulated,
        'saved': saved,
        'interest': interest,
      };
    }

    _pipelineByConvocatoria = map;
  }

  void _buildRecentPostulaciones(
    List<Map<String, dynamic>> postulaciones,
    Map<String, Map<String, dynamic>> usersMap,
  ) {
    final convocatoriaMap = {
      for (final conv in _activeConvocatorias)
        (conv['id']?.toString() ?? ''): conv,
    };

    _recentPostulaciones = postulaciones.take(20).map((post) {
      final playerId = _postulacionPlayerId(post);
      return {
        ...post,
        'player_data': usersMap[playerId],
        'video_data': _latestVideoByPlayerId[playerId],
        'has_video': (_videoCountByPlayerId[playerId] ?? 0) > 0,
        'convocatoria_titulo':
            convocatoriaMap[post['convocatoria_id']?.toString() ?? '']
                        ?['titulo']
                    ?.toString() ??
                'Convocatoria',
      };
    }).toList();
  }

  Future<void> _buildSuggestedPlayers(
    Map<String, Map<String, dynamic>> usersMap,
    List<Map<String, dynamic>> postulaciones,
  ) async {
    final excludedIds = postulaciones
        .map(_postulacionPlayerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toSet();

    final suggestedPlayers = <Map<String, dynamic>>[];

    try {
      final response = await SupaFlow.client
          .from('users')
          .select(
              'user_id, name, lastname, username, posicion, city, country_id, club, birthday, photo_url, userType, plan_id, full_profile, is_test_account, verification_status, is_verified, created_at')
          .inFilter(
              'userType', ['jugador', 'jogador', 'player', 'athlete', 'atleta'])
          .order('created_at', ascending: false)
          .limit(40);

      for (final row in (response as List)) {
        final user = Map<String, dynamic>.from(row);
        final userId = user['user_id']?.toString() ?? '';
        if (userId.isEmpty || excludedIds.contains(userId)) continue;
        if (!_resolveVerification(user, defaultIfMissing: false)) continue;
        if (!_isProSuggestedPlayer(user)) continue;

        usersMap.putIfAbsent(userId, () => user);
        suggestedPlayers.add({
          'user_id': userId,
          'user_data': usersMap[userId],
        });

        if (suggestedPlayers.length >= 10) break;
      }
    } catch (_) {}

    _suggestedPlayers = suggestedPlayers;
  }

  String _postulacionPlayerId(Map<String, dynamic> post) {
    return post['jugador_id']?.toString() ??
        post['player_id']?.toString() ??
        post['user_id']?.toString() ??
        '';
  }

  bool _hasVerificationInfo(Map<String, dynamic>? user) {
    if (user == null) return false;
    return user.containsKey('is_verified') ||
        user.containsKey('verification_status');
  }

  bool _resolveVerification(Map<String, dynamic>? user,
      {required bool defaultIfMissing}) {
    if (user == null) return defaultIfMissing;

    final hasInfo = _hasVerificationInfo(user);
    if (!hasInfo) return defaultIfMissing;

    final direct = user['is_verified'];
    if (direct is bool) return direct;

    final status = user['verification_status']?.toString().toLowerCase() ?? '';
    return status == 'verified' ||
        status == 'verificado' ||
        status == 'aprovado' ||
        status == 'aprobado';
  }

  bool _isSavedPipelineStage(dynamic rawStatus) {
    final status = _normalizeStatus(rawStatus);
    const savedStages = {
      'guardado',
      'preseleccionado',
      'invitar_prueba',
      'convidar_teste',
      'en_prueba',
      'em_teste',
      'contratado',
      'acompanhamento',
      'acompanamiento',
    };
    return savedStages.contains(status);
  }

  bool _isInterestPipelineStage(dynamic rawStatus) {
    final status = _normalizeStatus(rawStatus);
    const interestedStages = {
      'preseleccionado',
      'invitar_prueba',
      'convidar_teste',
      'en_prueba',
      'em_teste',
      'contratado',
      'acompanhamento',
      'acompanamiento',
    };
    return interestedStages.contains(status);
  }

  String _normalizeStatus(dynamic raw) {
    return raw?.toString().trim().toLowerCase().replaceAll(' ', '_') ?? '';
  }

  String _pipelineLabel(String status) {
    switch (_normalizeStatus(status)) {
      case 'guardado':
        return 'Guardado';
      case 'preseleccionado':
        return 'Preseleccionado';
      case 'invitar_prueba':
      case 'convidar_teste':
        return 'Invitar a prueba';
      case 'en_prueba':
      case 'em_teste':
        return 'En prueba';
      case 'descartado':
        return 'Descartado';
      case 'contratado':
      case 'acompanhamento':
      case 'acompanamiento':
        return 'Contratado/Seguimiento';
      default:
        return 'Guardado';
    }
  }

  String _categoryFromBirthday(dynamic birthday) {
    if (birthday == null) return 'N/A';

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
      return 'N/A';
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

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return null;
  }

  List<String> _extractUniqueStrings(Iterable<dynamic> values) {
    final set = <String>{};
    for (final raw in values) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        set.add(value);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  String _playerCountry(Map<String, dynamic> player) {
    final direct = _firstNonEmpty([
      player['pais'],
      player['country'],
      player['country_name'],
    ]);
    if (direct != null) return direct;

    final rawCountryId = player['country_id'];
    final countryId = rawCountryId is int
        ? rawCountryId
        : int.tryParse(rawCountryId?.toString() ?? '');
    if (countryId == null) return '';
    return _countryNameById[countryId] ?? '';
  }

  String _clubCountry(Map<String, dynamic> club) {
    return _firstNonEmpty([
          club['pais'],
          club['country'],
          club['country_name'],
        ]) ??
        '';
  }

  String _clubCity(Map<String, dynamic> club) {
    return _firstNonEmpty([
          club['city'],
          club['ciudad'],
          club['ubicacion'],
          club['location'],
        ]) ??
        '';
  }

  String _clubLeague(Map<String, dynamic> club) {
    return _firstNonEmpty([
          club['liga'],
          club['league'],
          club['league_name'],
        ]) ??
        '';
  }

  String _playerPosition(Map<String, dynamic> player) {
    return _firstNonEmpty([
          player['posicion'],
          player['position'],
        ]) ??
        'Sin posición';
  }

  String _playerCategory(Map<String, dynamic> player) {
    return _firstNonEmpty([
          player['categoria'],
          player['category'],
        ]) ??
        _categoryFromBirthday(player['birthday'] ?? player['birth_date']);
  }

  String _playerLevel(Map<String, dynamic> player) {
    final direct = player['level_name']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final totalXp = GamificationService.toInt(player['total_xp']);
    return GamificationService.levelNameFromPoints(totalXp);
  }

  String _playerCity(Map<String, dynamic> player) {
    return _firstNonEmpty([
          player['city'],
          player['ciudad'],
        ]) ??
        '';
  }

  String _resolveTryoutClubName(Map<String, dynamic> tryout) {
    final direct = _firstNonEmpty([
      tryout['club_name'],
      tryout['club_nombre'],
      tryout['nombre_club'],
      tryout['club'],
    ]);
    if (direct != null) return direct;

    final clubData = tryout['club_data'];
    if (clubData is Map) {
      return _firstNonEmpty([
            clubData['nombre'],
            clubData['name'],
            clubData['club_name'],
            clubData['nombre_corto'],
          ]) ??
          '';
    }
    return '';
  }

  String _resolveTryoutCategory(Map<String, dynamic> tryout) {
    final direct = _firstNonEmpty([
      tryout['categoria'],
      tryout['category'],
    ]);
    if (direct != null) return direct;

    final minAge = tryout['edad_minima'] ?? tryout['edad_min'];
    final maxAge = tryout['edad_maxima'] ?? tryout['edad_max'];
    if (minAge != null || maxAge != null) {
      return '${minAge ?? '-'}-${maxAge ?? '-'}';
    }
    return '';
  }

  String _resolveTryoutPosition(Map<String, dynamic> tryout) {
    return _firstNonEmpty([
          tryout['posicion'],
          tryout['position'],
          tryout['posição'],
        ]) ??
        '';
  }

  String _resolveTryoutLocation(Map<String, dynamic> tryout) {
    final direct = _firstNonEmpty([
      tryout['ubicacion'],
      tryout['location'],
      tryout['city'],
      tryout['ciudad'],
    ]);
    if (direct != null) return direct;

    final clubData = tryout['club_data'];
    if (clubData is Map) {
      return _clubCity(Map<String, dynamic>.from(clubData));
    }
    return '';
  }

  String _resolveTryoutCountry(Map<String, dynamic> tryout) {
    final direct = _firstNonEmpty([
      tryout['pais'],
      tryout['country'],
      tryout['country_name'],
    ]);
    if (direct != null) return direct;

    final clubData = tryout['club_data'];
    if (clubData is Map) {
      return _clubCountry(Map<String, dynamic>.from(clubData));
    }
    return '';
  }

  String _resolveTryoutMode(Map<String, dynamic> tryout) {
    final virtualFlag = tryout['is_virtual'] == true ||
        (tryout['virtual']?.toString().toLowerCase() == 'true');
    final presentialFlag = tryout['is_presencial'] == true ||
        tryout['is_in_person'] == true ||
        (tryout['presencial']?.toString().toLowerCase() == 'true');
    if (virtualFlag && presentialFlag) return 'Híbrida';
    if (virtualFlag) return 'Virtual';
    if (presentialFlag) return 'Presencial';

    final raw = _firstNonEmpty([
          tryout['modalidad'],
          tryout['modality'],
          tryout['tipo_modalidad'],
          tryout['formato'],
          tryout['format'],
          tryout['tipo'],
        ]) ??
        '';
    final normalized = raw.toLowerCase();
    if (normalized.contains('hibr')) return 'Híbrida';
    if (normalized.contains('virtual') ||
        normalized.contains('online') ||
        normalized.contains('remote') ||
        normalized.contains('remot')) {
      return 'Virtual';
    }
    if (normalized.contains('presencial') ||
        normalized.contains('in person') ||
        normalized.contains('presential')) {
      return 'Presencial';
    }
    return 'Presencial';
  }

  Color _tryoutModeColor(String mode) {
    switch (mode) {
      case 'Virtual':
        return const Color(0xFF0EA5E9);
      case 'Híbrida':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF16A34A);
    }
  }

  int _readPlanId(dynamic rawValue) {
    if (rawValue is int) return rawValue;
    return int.tryParse(rawValue?.toString() ?? '') ?? 0;
  }

  bool _isProSuggestedPlayer(Map<String, dynamic>? user) {
    if (user == null) return false;
    final planId = _readPlanId(user['plan_id']);
    return planId >= 2 ||
        user['full_profile'] == true ||
        user['is_test_account'] == true;
  }

  String _formatRelative(dynamic rawDate) {
    final parsed =
        rawDate == null ? null : DateTime.tryParse(rawDate.toString());
    if (parsed == null) return '';
    return dateTimeFormat('relative', parsed, locale: 'es');
  }

  bool get _isSearchMode => _searchQuery.trim().length >= 2;

  List<Map<String, dynamic>> get _filteredSearchPlayers {
    Iterable<Map<String, dynamic>> filtered = _searchPlayers;

    if (_playerFilterCategory != null) {
      filtered = filtered.where(
        (player) =>
            _playerCategory(player).toLowerCase() ==
            _playerFilterCategory!.toLowerCase(),
      );
    }
    if (_playerFilterPosition != null) {
      filtered = filtered.where(
        (player) =>
            _playerPosition(player).toLowerCase() ==
            _playerFilterPosition!.toLowerCase(),
      );
    }
    if (_playerFilterCountry != null) {
      filtered = filtered.where(
        (player) =>
            _playerCountry(player).toLowerCase() ==
            _playerFilterCountry!.toLowerCase(),
      );
    }
    if (_playerFilterCity != null) {
      filtered = filtered.where(
        (player) =>
            _playerCity(player).toLowerCase() ==
            _playerFilterCity!.toLowerCase(),
      );
    }
    if (_playerFilterLevel != null) {
      filtered = filtered.where(
        (player) =>
            _playerLevel(player).toLowerCase() ==
            _playerFilterLevel!.toLowerCase(),
      );
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _filteredSearchClubs {
    Iterable<Map<String, dynamic>> filtered = _searchClubs;

    if (_clubFilterCountry != null) {
      filtered = filtered.where(
        (club) =>
            _clubCountry(club).toLowerCase() ==
            _clubFilterCountry!.toLowerCase(),
      );
    }
    if (_clubFilterCity != null) {
      filtered = filtered.where(
        (club) =>
            _clubCity(club).toLowerCase() == _clubFilterCity!.toLowerCase(),
      );
    }
    if (_clubFilterLeague != null) {
      filtered = filtered.where(
        (club) =>
            _clubLeague(club).toLowerCase() == _clubFilterLeague!.toLowerCase(),
      );
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _filteredSearchTryouts {
    Iterable<Map<String, dynamic>> filtered = _searchTryouts;

    if (_tryoutFilterCategory != null) {
      filtered = filtered.where(
        (tryout) =>
            _resolveTryoutCategory(tryout).toLowerCase() ==
            _tryoutFilterCategory!.toLowerCase(),
      );
    }
    if (_tryoutFilterPosition != null) {
      filtered = filtered.where(
        (tryout) =>
            _resolveTryoutPosition(tryout).toLowerCase() ==
            _tryoutFilterPosition!.toLowerCase(),
      );
    }
    if (_tryoutFilterCountry != null) {
      filtered = filtered.where(
        (tryout) =>
            _resolveTryoutCountry(tryout).toLowerCase() ==
            _tryoutFilterCountry!.toLowerCase(),
      );
    }

    return filtered.toList();
  }

  int get _searchResultsCount {
    switch (_homeScope) {
      case 'clubes':
        return _filteredSearchClubs.length;
      case 'tryouts':
        return _filteredSearchTryouts.length;
      default:
        return _filteredSearchPlayers.length;
    }
  }

  void _openPublicClubProfile(Map<String, dynamic> club) {
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

  void _openSearchMode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DashboardClubWidget(
          searchOnly: true,
          initialSearchQuery: _searchController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _toggleSavePlayer(Map<String, dynamic> player) async {
    if (_savingPlayerId != null) return;
    if (!_canUseSensitiveActions) {
      _showUpsellDialog();
      return;
    }

    final playerId = player['user_id']?.toString() ?? '';
    if (playerId.isEmpty || currentUserUid.isEmpty) return;

    setState(() => _savingPlayerId = playerId);
    try {
      if (_savedPlayerIds.contains(playerId)) {
        try {
          await SupaFlow.client
              .from('jugadores_guardados')
              .delete()
              .eq('club_id', currentUserUid)
              .eq('jugador_id', playerId);
        } catch (_) {}
        try {
          await SupaFlow.client
              .from('jugadores_guardados')
              .delete()
              .eq('scout_id', currentUserUid)
              .eq('jugador_id', playerId);
        } catch (_) {}
        _savedPlayerIds.remove(playerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jugador removido de guardados')),
          );
        }
      } else {
        try {
          await SupaFlow.client.from('jugadores_guardados').insert({
            'club_id': currentUserUid,
            'jugador_id': playerId,
          });
        } catch (_) {
          await SupaFlow.client.from('jugadores_guardados').insert({
            'scout_id': currentUserUid,
            'jugador_id': playerId,
          });
        }
        _savedPlayerIds.add(playerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jugador guardado para seguimiento')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el jugador: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingPlayerId = null);
      }
    }
  }

  Future<void> _invitePlayerToConvocatoria({
    required Map<String, dynamic> player,
    required Map<String, dynamic> convocatoria,
  }) async {
    if (_invitingPlayerId != null) return;
    if (!FFAppState().canSendConvocatoria) {
      _showPlanRequiredForConvocatoriaSend();
      return;
    }
    if (!_canUseSensitiveActions) {
      _showUpsellDialog();
      return;
    }

    final playerId = player['user_id']?.toString() ?? '';
    final convocatoriaId = convocatoria['id']?.toString() ?? '';
    if (playerId.isEmpty || convocatoriaId.isEmpty) return;

    setState(() => _invitingPlayerId = playerId);
    try {
      bool saved = false;

      try {
        final existing = await SupaFlow.client
            .from('aplicaciones_convocatoria')
            .select('id')
            .eq('convocatoria_id', convocatoriaId)
            .eq('jugador_id', playerId)
            .maybeSingle();

        if (existing != null) {
          await SupaFlow.client.from('aplicaciones_convocatoria').update({
            'estado': 'invitar_prueba',
            'mensaje': 'Invitación enviada por el club',
          }).eq('id', existing['id']);
        } else {
          await SupaFlow.client.from('aplicaciones_convocatoria').insert({
            'convocatoria_id': convocatoriaId,
            'jugador_id': playerId,
            'estado': 'invitar_prueba',
            'mensaje': 'Invitación enviada por el club',
          });
        }
        saved = true;
      } catch (_) {}

      if (!saved) {
        final existing = await SupaFlow.client
            .from('postulaciones')
            .select('id')
            .eq('convocatoria_id', convocatoriaId)
            .eq('player_id', playerId)
            .maybeSingle();
        if (existing != null) {
          await SupaFlow.client.from('postulaciones').update({
            'estado': 'invitar_prueba',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', existing['id']);
        } else {
          await SupaFlow.client.from('postulaciones').insert({
            'convocatoria_id': convocatoriaId,
            'player_id': playerId,
            'estado': 'invitar_prueba',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      await ActivityNotificationsService.notifyPlayerApplicationStatusUpdated(
        playerId: playerId,
        convocatoriaId: convocatoriaId,
        convocatoriaTitle: convocatoria['titulo']?.toString() ?? 'Convocatoria',
        clubName: _clubName ?? 'Club',
        status: 'invitar_prueba',
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitación enviada a la convocatoria'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo invitar al jugador: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _invitingPlayerId = null);
      }
    }
  }

  void _showInviteToConvocatoriaSheet(Map<String, dynamic> player) {
    if (!FFAppState().canSendConvocatoria) {
      _showPlanRequiredForConvocatoriaSend();
      return;
    }

    if (_activeConvocatorias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Crea una convocatoria activa antes de invitar jugadores'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.72,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Invitar a convocatoria',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Elegí una convocatoria propia para invitar al jugador.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _activeConvocatorias.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final convocatoria = _activeConvocatorias[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _invitePlayerToConvocatoria(
                        player: player,
                        convocatoria: convocatoria,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.campaign_outlined,
                                color: Color(0xFF0D3B66),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    convocatoria['titulo']?.toString() ??
                                        'Convocatoria',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      _resolveTryoutCategory(convocatoria),
                                      _resolveTryoutPosition(convocatoria),
                                      _resolveTryoutLocation(convocatoria),
                                    ]
                                        .where((item) => item.trim().isNotEmpty)
                                        .join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_invitingPlayerId ==
                                (player['user_id']?.toString() ?? ''))
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF94A3B8),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlanRequiredForConvocatoriaSend() {
    showPlanRequiredDialog(
      context,
      featureName: 'Envío de convocatorias',
      message:
          'Enviar invitaciones para una convocatoria es un beneficio del Plan Pro. Con modo piloto activo, este bloqueo desaparece.',
    );
  }

  Future<void> _updatePipelineStatus(
    String postulacionId,
    String status, {
    String? sourceTable,
  }) async {
    if (postulacionId.isEmpty) return;

    if (!_canUseSensitiveActions) {
      _showUpsellDialog();
      return;
    }

    final targetTable = sourceTable == 'aplicaciones_convocatoria'
        ? 'aplicaciones_convocatoria'
        : 'postulaciones';

    try {
      try {
        await SupaFlow.client.from(targetTable).update({
          'estado': status,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', postulacionId);
      } catch (_) {
        await SupaFlow.client.from(targetTable).update({
          'estado': status,
        }).eq('id', postulacionId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pipeline actualizado: ${_pipelineLabel(status)}'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el pipeline')),
      );
    }
  }

  void _openPlayerVideo(Map<String, dynamic>? videoData) {
    if (!_canUseSensitiveActions) {
      _showUpsellDialog();
      return;
    }

    if (videoData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este jugador no tiene video público')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _SingleVideoSheet(video: videoData),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCandidatesForConvocatoria(
    String convocatoriaId,
    String convocatoriaTitle,
  ) async {
    final posts = await _fetchApplicationsForConvocatorias(
      convocatoriaId: convocatoriaId,
      limit: 300,
    );
    final playerIds = posts
        .map(_postulacionPlayerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final usersMap = await _loadUsersMap(playerIds);

    final latestVideoMap = <String, Map<String, dynamic>>{};
    if (playerIds.isNotEmpty) {
      try {
        final videosResponse = await SupaFlow.client
            .from('videos')
            .select('id, user_id, title, thumbnail_url, video_url, created_at')
            .eq('is_public', true)
            .inFilter('user_id', playerIds)
            .order('created_at', ascending: false)
            .limit(300);

        for (final row in (videosResponse as List)) {
          final video = Map<String, dynamic>.from(row);
          final uid = video['user_id']?.toString() ?? '';
          if (uid.isNotEmpty) {
            latestVideoMap.putIfAbsent(uid, () => video);
          }
        }
      } catch (_) {}
    }

    return posts.map((post) {
      final playerId = _postulacionPlayerId(post);
      return {
        ...post,
        'player_data': usersMap[playerId],
        'video_data': latestVideoMap[playerId],
        'has_video': latestVideoMap[playerId] != null,
        'convocatoria_titulo': convocatoriaTitle,
      };
    }).toList();
  }

  Future<void> _showCandidatesSheet(Map<String, dynamic> convocatoria) async {
    final convId = convocatoria['id']?.toString() ?? '';
    if (convId.isEmpty) return;

    final convTitle = convocatoria['titulo']?.toString() ?? 'Convocatoria';
    bool initialized = false;
    bool isLoading = true;
    String? error;
    List<Map<String, dynamic>> candidates = [];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxSheetHeight = media.size.height * 0.82;

        double computeHeight() {
          if (isLoading || error != null || candidates.isEmpty) {
            return 340;
          }

          final estimated = 170 + (candidates.length.clamp(1, 4) * 150.0);
          return estimated.clamp(360.0, maxSheetHeight);
        }

        Future<void> load(StateSetter setSheetState) async {
          setSheetState(() {
            isLoading = true;
            error = null;
          });

          try {
            candidates =
                await _fetchCandidatesForConvocatoria(convId, convTitle);
          } catch (_) {
            error = 'Error al cargar candidatos';
          } finally {
            setSheetState(() => isLoading = false);
          }
        }

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (!initialized) {
              initialized = true;
              Future.microtask(() => load(setSheetState));
            }

            return SafeArea(
              top: false,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: computeHeight(),
                constraints: BoxConstraints(
                  minHeight: 280,
                  maxHeight: maxSheetHeight,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Candidatos · $convTitle',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : error != null
                                ? SingleChildScrollView(
                                    child: _buildInlineStatus(
                                      icon: Icons.error_outline,
                                      title: 'Erro',
                                      subtitle: error!,
                                      onRetry: () => load(setSheetState),
                                    ),
                                  )
                                : candidates.isEmpty
                                    ? SingleChildScrollView(
                                        child: _buildInlineStatus(
                                          icon: Icons.people_outline,
                                          title: 'Sem resultados',
                                          subtitle:
                                              'No hay candidatos para esta convocatoria.',
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: candidates.length,
                                        itemBuilder: (_, index) {
                                          return _buildPostulacionCard(
                                            candidates[index],
                                            compact: true,
                                          );
                                        },
                                      ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchApplicationsForConvocatorias({
    String? convocatoriaId,
    List<String>? convocatoriaIds,
    int limit = 500,
  }) async {
    final normalized = <Map<String, dynamic>>[];

    Future<void> loadFromTable(String tableName) async {
      try {
        dynamic query = SupaFlow.client.from(tableName).select();

        if (convocatoriaId != null && convocatoriaId.isNotEmpty) {
          query = query.eq('convocatoria_id', convocatoriaId);
        } else if (convocatoriaIds != null && convocatoriaIds.isNotEmpty) {
          query = query.inFilter('convocatoria_id', convocatoriaIds);
        } else {
          return;
        }

        final response = await query
            .order('created_at', ascending: false)
            .limit(limit) as List;

        for (final row in response) {
          final map = Map<String, dynamic>.from(row as Map);
          map['_source_table'] = tableName;
          map['player_id'] = map['player_id'] ?? map['jugador_id'];
          map['jugador_id'] = map['jugador_id'] ?? map['player_id'];
          map['estado'] = map['estado'] ?? 'pendiente';
          normalized.add(map);
        }
      } catch (_) {}
    }

    await Future.wait([
      loadFromTable('postulaciones'),
      loadFromTable('aplicaciones_convocatoria'),
    ]);

    if (normalized.isEmpty) return [];

    final dedup = <String, Map<String, dynamic>>{};
    for (final post in normalized) {
      final conv = post['convocatoria_id']?.toString() ?? '';
      final player = _postulacionPlayerId(post);
      final fallbackId = post['id']?.toString() ?? '';
      final source = post['_source_table']?.toString() ?? '';
      final key = conv.isNotEmpty && player.isNotEmpty
          ? '$conv::$player'
          : '$source::$fallbackId';

      final current = dedup[key];
      if (current == null ||
          _postCreatedAt(post).isAfter(_postCreatedAt(current))) {
        dedup[key] = post;
      }
    }

    final merged = dedup.values.toList();
    merged.sort((a, b) => _postCreatedAt(b).compareTo(_postCreatedAt(a)));
    return merged;
  }

  DateTime _postCreatedAt(Map<String, dynamic> post) {
    final raw = post['created_at'];
    if (raw is DateTime) return raw;
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _showUpsellDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF0D3B66),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ação bloqueada',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Para ações sensíveis, sua conta precisa estar verificada e com plano ativo.',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF4B5563),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _upsellRequirement(
                      icon: Icons.verified_user_outlined,
                      label: 'Conta verificada',
                    ),
                    const SizedBox(height: 8),
                    _upsellRequirement(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Plano ativo',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      child: const Text('Agora não'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (mounted) {
                          context.pushNamed(ConfiguracinWidget.routeName);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: const Color(0xFF0D3B66),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Ajustar agora',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upsellRequirement({
    required IconData icon,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: const Color(0xFF0D3B66), size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  void _openClubMenu(BuildContext ctx) {
    Navigator.of(ctx).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.78,
                  height: double.infinity,
                  color: Colors.white,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D3B66),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child:
                                    const Icon(Icons.menu, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Menú del club',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D3B66),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: [
                              _drawerItem(
                                context,
                                label: 'Dashboard',
                                icon: Icons.home_outlined,
                                selected: true,
                                onTap: () => context
                                    .pushNamed(DashboardClubWidget.routeName),
                              ),
                              _drawerItem(
                                context,
                                label: 'Convocatorias',
                                icon: Icons.campaign_outlined,
                                selected: false,
                                onTap: () => context.pushNamed(
                                    ConvocatoriasClubWidget.routeName),
                              ),
                              _drawerItem(
                                context,
                                label: 'Jugadores',
                                icon: Icons.people_outline,
                                selected: false,
                                onTap: () => context
                                    .pushNamed(PostulacionesWidget.routeName),
                              ),
                              _drawerItem(
                                context,
                                label: 'Scouting',
                                icon: Icons.list_alt_outlined,
                                selected: false,
                                onTap: () => context
                                    .pushNamed(ListaYNotaWidget.routeName),
                              ),
                              _drawerItem(
                                context,
                                label: 'Club',
                                icon: Icons.settings_outlined,
                                selected: false,
                                onTap: () => context
                                    .pushNamed(ConfiguracinWidget.routeName),
                              ),
                              const Divider(),
                              _drawerItem(
                                context,
                                label: 'Cerrar sesión',
                                icon: Icons.logout,
                                selected: false,
                                onTap: () async {
                                  await authManager.signOut();
                                  if (ctx.mounted) {
                                    ctx.goNamed(LoginWidget.routeName);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required Future<void> Function() onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? const Color(0xFF0D3B66) : Colors.grey[700],
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: selected ? const Color(0xFF0D3B66) : Colors.grey[800],
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.circle, color: Color(0xFF0D3B66), size: 10)
          : null,
      onTap: () async {
        Navigator.pop(context);
        if (!selected) {
          await onTap();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? _buildErrorState()
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SafeArea(
                  child: widget.searchOnly
                      ? _buildSearchModeBody()
                      : _buildDashboardBody(),
                ),
              );

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: content,
      ),
    );
  }

  Widget _buildDashboardBody() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _openClubMenu(context),
              icon: const Icon(Icons.menu),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Dashboard',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 14),
          child: Text(
            'Gestão de talento de ${_clubName ?? 'tu club'} a partir de convocatórias e seguimento de candidatos.',
            style: GoogleFonts.inter(
              color: const Color(0xFF4A5568),
              fontSize: 13,
            ),
          ),
        ),
        _buildSearchBar(),
        const SizedBox(height: 16),
        _buildSectionHeader(
          title: 'Convocatorias activas',
          trailing: OutlinedButton.icon(
            onPressed: () => context.pushNamed(
              ConvocatoriasClubWidget.routeName,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Mis convocatórias'),
          ),
        ),
        _buildActiveConvocatoriasSection(),
        const SizedBox(height: 18),
        _buildSectionHeader(title: 'Postulaciones recientes'),
        _buildRecentPostulacionesSection(),
        const SizedBox(height: 18),
        _buildSectionHeader(title: 'Jogadores novos verificados'),
        _buildSuggestedPlayersSection(),
        const SizedBox(height: 18),
        _buildSectionHeader(title: 'Seguimento de candidatos'),
        _buildPipelineSection(),
      ],
    );
  }

  Widget _buildSearchModeBody() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Buscar',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 14),
          child: Text(
            'Buscá jugadores, clubes y convocatorias sin mezclar resultados con el dashboard.',
            style: GoogleFonts.inter(
              color: const Color(0xFF4A5568),
              fontSize: 13,
            ),
          ),
        ),
        _buildSearchBar(),
        if (_isSearchMode) ...[
          const SizedBox(height: 10),
          _buildHomeScopeTabs(),
          const SizedBox(height: 16),
          _buildSectionHeader(
            title: _homeScope == 'jugadores'
                ? 'Resultados de jugadores'
                : _homeScope == 'clubes'
                    ? 'Resultados de clubes'
                    : 'Resultados de convocatorias',
          ),
          _buildSearchFilters(),
          const SizedBox(height: 10),
          _buildSearchResultsCounter(),
          const SizedBox(height: 10),
          _buildSearchResultsSection(),
        ] else ...[
          const SizedBox(height: 18),
          _buildInlineStatus(
            icon: Icons.search_rounded,
            title: 'Empezá una búsqueda',
            subtitle:
                'Escribí al menos 2 letras para ver resultados en Jugadores, Clubes o Convocatorias.',
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Error',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
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

  Widget _buildSectionHeader({required String title, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final hintText = !widget.searchOnly
        ? 'Buscar jugador, club o convocatoria...'
        : _homeScope == 'clubes'
            ? 'Buscar club, ciudad...'
            : _homeScope == 'tryouts'
                ? 'Buscar convocatoria, categoría, posición, país...'
                : 'Buscar jugador, club, posición, año, ciudad...';

    if (!widget.searchOnly) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openSearchMode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8E0EC)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140D3B66),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.search,
                  color: Color(0xFF4F6788),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hintText,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E0EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140D3B66),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.search,
              color: Color(0xFF4F6788),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
              },
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsSection() {
    if (_isSearchingPlayers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_homeScope == 'clubes') {
      final clubs = _filteredSearchClubs;
      if (clubs.isEmpty) {
        return _buildInlineStatus(
          icon: Icons.shield_outlined,
          title: 'Sem resultados',
          subtitle: 'No se encontraron clubes para esta búsqueda.',
        );
      }
      return Column(
        children: clubs.map(_buildSearchClubCard).toList(),
      );
    }

    if (_homeScope == 'tryouts') {
      final tryouts = _filteredSearchTryouts;
      if (tryouts.isEmpty) {
        return _buildInlineStatus(
          icon: Icons.campaign_outlined,
          title: 'Sem resultados',
          subtitle: 'No se encontraron convocatorias para esta búsqueda.',
        );
      }
      return Column(
        children: tryouts.map(_buildSearchTryoutCard).toList(),
      );
    }

    final players = _filteredSearchPlayers;
    if (players.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.search_off,
        title: 'Sem resultados',
        subtitle: 'No se encontraron jugadores para esta búsqueda.',
      );
    }

    return Column(
      children: players.map(_buildSearchPlayerCard).toList(),
    );
  }

  Widget _buildSearchFilters() {
    if (_homeScope == 'clubes') {
      final countries =
          _extractUniqueStrings(_searchClubs.map((club) => _clubCountry(club)));
      final cities =
          _extractUniqueStrings(_searchClubs.map((club) => _clubCity(club)));
      final leagues =
          _extractUniqueStrings(_searchClubs.map((club) => _clubLeague(club)));

      return _buildFiltersWrap([
        _buildFilterPill(
          label: 'País',
          value: _clubFilterCountry,
          options: countries,
          onSelected: (value) => setState(() => _clubFilterCountry = value),
        ),
        _buildFilterPill(
          label: 'Ciudad',
          value: _clubFilterCity,
          options: cities,
          onSelected: (value) => setState(() => _clubFilterCity = value),
        ),
        _buildFilterPill(
          label: 'Liga',
          value: _clubFilterLeague,
          options: leagues,
          onSelected: (value) => setState(() => _clubFilterLeague = value),
        ),
      ]);
    }

    if (_homeScope == 'tryouts') {
      final categories = _extractUniqueStrings(
        _searchTryouts.map((tryout) => _resolveTryoutCategory(tryout)),
      );
      final positions = _extractUniqueStrings(
        _searchTryouts.map((tryout) => _resolveTryoutPosition(tryout)),
      );

      return _buildFiltersWrap([
        _buildFilterPill(
          label: 'Categoría',
          value: _tryoutFilterCategory,
          options: categories,
          onSelected: (value) => setState(() => _tryoutFilterCategory = value),
        ),
        _buildFilterPill(
          label: 'Posición',
          value: _tryoutFilterPosition,
          options: positions,
          onSelected: (value) => setState(() => _tryoutFilterPosition = value),
        ),
        _buildFilterPill(
          label: 'País',
          value: _tryoutFilterCountry,
          options: _extractUniqueStrings(
            _searchTryouts.map((tryout) => _resolveTryoutCountry(tryout)),
          ),
          onSelected: (value) => setState(() => _tryoutFilterCountry = value),
        ),
      ]);
    }

    final categories = _extractUniqueStrings(
      _searchPlayers.map((player) => _playerCategory(player)),
    );
    final positions = _extractUniqueStrings(
      _searchPlayers.map((player) => _playerPosition(player)),
    );
    final countries = _extractUniqueStrings(
      _searchPlayers.map((player) => _playerCountry(player)),
    );
    final cities = _extractUniqueStrings(
      _searchPlayers.map((player) => _playerCity(player)),
    );
    final levels = _extractUniqueStrings(
      _searchPlayers.map((player) => _playerLevel(player)),
    );

    return _buildFiltersWrap([
      _buildFilterPill(
        label: 'Categoría',
        value: _playerFilterCategory,
        options: categories,
        onSelected: (value) => setState(() => _playerFilterCategory = value),
      ),
      _buildFilterPill(
        label: 'Posición',
        value: _playerFilterPosition,
        options: positions,
        onSelected: (value) => setState(() => _playerFilterPosition = value),
      ),
      _buildFilterPill(
        label: 'País',
        value: _playerFilterCountry,
        options: countries,
        onSelected: (value) => setState(() => _playerFilterCountry = value),
      ),
      _buildFilterPill(
        label: 'Ciudad',
        value: _playerFilterCity,
        options: cities,
        onSelected: (value) => setState(() => _playerFilterCity = value),
      ),
      _buildFilterPill(
        label: 'Nivel',
        value: _playerFilterLevel,
        options: levels,
        onSelected: (value) => setState(() => _playerFilterLevel = value),
      ),
    ]);
  }

  Widget _buildFiltersWrap(List<Widget> children) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: children
            .expand((widget) => [widget, const SizedBox(width: 8)])
            .toList()
          ..removeLast(),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onSelected,
  }) {
    final hasOptions = options.isNotEmpty;
    final display = value == null || value.isEmpty ? label : '$label: $value';

    return PopupMenuButton<String>(
      enabled: hasOptions || value != null,
      onSelected: (raw) {
        onSelected(raw == '__all__' ? null : raw);
      },
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          value: '__all__',
          child: Text('Todos'),
        ),
        ...options.map(
          (option) => PopupMenuItem<String>(
            value: option,
            child: Text(option),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value != null ? const Color(0xFF0D3B66) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value != null
                ? const Color(0xFF0D3B66)
                : const Color(0xFFD8E2EF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              display,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: value != null ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: value != null ? Colors.white : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsCounter() {
    return Text(
      '$_searchResultsCount resultados encontrados',
      style: GoogleFonts.inter(
        fontSize: 13,
        color: const Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSearchPlayerCard(Map<String, dynamic> player) {
    final userId = player['user_id']?.toString() ?? '';
    final name = '${player['name'] ?? ''} ${player['lastname'] ?? ''}'.trim();
    final category = _playerCategory(player);
    final position = _playerPosition(player);
    final country = _playerCountry(player);
    final city = _playerCity(player);
    final club = player['club']?.toString() ?? '';
    final latestVideo = player['latest_video'] as Map<String, dynamic>?;
    final hasVideo = (player['video_count'] as int? ?? 0) > 0;
    final mediaUrl = latestVideo?['thumbnail_url']?.toString().trim() ?? '';
    final photoUrl = player['photo_url']?.toString().trim() ?? '';
    final isSaved = _savedPlayerIds.contains(userId);
    final isSaving = _savingPlayerId == userId;
    final isInviting = _invitingPlayerId == userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D3B66),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              height: 170,
              width: double.infinity,
              color: const Color(0xFFEAF1FC),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (mediaUrl.isNotEmpty)
                    Image.network(
                      mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  else if (photoUrl.isNotEmpty)
                    Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  else
                    const Icon(
                      Icons.person_outline,
                      size: 62,
                      color: Color(0xFF0D3B66),
                    ),
                  if (hasVideo)
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.36),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Jugador',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaChip('Categoría: $category'),
                    _metaChip('Posición: $position'),
                    _metaChip('País: ${country.isNotEmpty ? country : 'N/A'}'),
                    if (city.isNotEmpty) _metaChip(city),
                  ],
                ),
                if (club.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    club,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: userId.isEmpty
                            ? null
                            : () {
                                context.pushNamed(
                                  'perfil_profesional_solicitar_Contato',
                                  queryParameters: {'userId': userId},
                                );
                              },
                        child: const Text('Ver perfil'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            isSaving ? null : () => _toggleSavePlayer(player),
                        icon: isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isSaved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                        label: Text(
                          isSaved ? 'Guardado' : 'Guardar',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSaved
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF0D3B66),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isInviting
                        ? null
                        : () => _showInviteToConvocatoriaSheet(player),
                    icon: isInviting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.campaign_outlined, size: 18),
                    label: const Text('Invitar a convocatoria'),
                  ),
                ),
                if (hasVideo) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openPlayerVideo(latestVideo),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Ver preview'),
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

  Widget _buildSearchClubCard(Map<String, dynamic> club) {
    final name = (club['nombre'] ?? club['name'] ?? club['club_name'] ?? 'Club')
        .toString();
    final country = _clubCountry(club);
    final city = _clubCity(club);
    final league = _clubLeague(club);
    final logo =
        (club['logo_url'] ?? club['photo_url'] ?? club['avatar_url'] ?? '')
            .toString();

    return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPublicClubProfile(club),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100D3B66),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE8F0FE),
                backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
                child: logo.isNotEmpty
                    ? null
                    : const Icon(Icons.shield, color: Color(0xFF0D3B66)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (country.isNotEmpty) _metaChip('País: $country'),
                        if (league.isNotEmpty) _metaChip('Liga: $league'),
                        if (city.isNotEmpty) _metaChip(city),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ));
  }

  Widget _buildSearchTryoutCard(Map<String, dynamic> tryout) {
    final title = (tryout['titulo'] ?? tryout['title'] ?? 'Tryout').toString();
    final zone = _resolveTryoutLocation(tryout);
    final desc = (tryout['descripcion'] ?? tryout['description'] ?? '')
        .toString()
        .trim();
    final clubName = _resolveTryoutClubName(tryout);
    final category = _resolveTryoutCategory(tryout);
    final position = _resolveTryoutPosition(tryout);
    final mode = _resolveTryoutMode(tryout);
    final clubData = tryout['club_data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(tryout['club_data'] as Map)
        : null;
    final clubTarget = clubData ??
        {
          'id': tryout['club_id'],
          'club_name': clubName,
        };

    return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (_clubRefFromMap(clubTarget).isNotEmpty) {
            _openPublicClubProfile(clubTarget);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDDE4EF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: Color(0xFF0D3B66),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A202C),
                        height: 1.15,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _tryoutModeColor(mode).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      mode,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _tryoutModeColor(mode),
                      ),
                    ),
                  ),
                ],
              ),
              if (clubName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  clubName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D3B66),
                  ),
                ),
              ],
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (category.isNotEmpty) _metaChip('Categoría: $category'),
                  if (position.isNotEmpty) _metaChip('Posición: $position'),
                  if (zone.isNotEmpty) _metaChip('Ubicación: $zone'),
                ],
              ),
            ],
          ),
        ));
  }

  Widget _buildHomeScopeTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E2EF)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _homeScopeChip(
                  label: 'Jugadores',
                  value: 'jugadores',
                  icon: Icons.groups_outlined)),
          const SizedBox(width: 6),
          Expanded(
              child: _homeScopeChip(
                  label: 'Clubes',
                  value: 'clubes',
                  icon: Icons.shield_outlined)),
          const SizedBox(width: 6),
          Expanded(
              child: _homeScopeChip(
                  label: 'Convocatorias',
                  value: 'tryouts',
                  icon: Icons.campaign_outlined)),
        ],
      ),
    );
  }

  Widget _homeScopeChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final selected = _homeScope == value;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => _setHomeScope(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D3B66) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? const Color(0xFF0D3B66) : const Color(0xFFD1D9E6),
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x220D3B66),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF526581),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveConvocatoriasSection() {
    if (_activeConvocatorias.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.campaign_outlined,
        title: 'Sem resultados',
        subtitle: 'Crea tu primera convocatoria en el módulo Convocatorias.',
      );
    }

    final previewItems = _activeConvocatorias.take(3).toList();

    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: previewItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final conv = previewItems[index];
          final title = conv['titulo']?.toString() ?? 'Convocatoria';
          final zone = conv['ubicacion']?.toString() ?? 'Sin zona';
          final minAge = conv['edad_minima'] ?? conv['edad_min'];
          final maxAge = conv['edad_maxima'] ?? conv['edad_max'];
          final category = (minAge != null || maxAge != null)
              ? '${minAge ?? '-'}-${maxAge ?? '-'}'
              : 'N/A';
          final postulaciones = conv['postulaciones_count'] ?? 0;
          final saved = conv['saved_count'] ?? 0;

          return Container(
            width: 286,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Activa',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D3B66),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${index + 1}/${previewItems.length}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF1A202C),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _metaChip('Zona: $zone'),
                    _metaChip('Categoria: $category'),
                    _metaChip('Nº postulações: $postulaciones'),
                    _metaChip('En seguimiento: $saved'),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showCandidatesSheet(conv),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3B66),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: const Text(
                          'Ver candidatos',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            context.pushNamed(PostulacionesWidget.routeName),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: const Text('Postulaciones'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentPostulacionesSection() {
    if (_recentPostulaciones.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.people_outline,
        title: 'Sem resultados',
        subtitle: 'No hay postulaciones nuevas.',
      );
    }

    final items = _recentPostulaciones.take(4).toList();

    return Column(
      children: items
          .map(
            (post) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final playerId = _postulacionPlayerId(post);
                  if (playerId.isEmpty) {
                    context.pushNamed(PostulacionesWidget.routeName);
                    return;
                  }
                  context.pushNamed(
                    'perfil_profesional_solicitar_Contato',
                    queryParameters: {'userId': playerId},
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFE8F0FE),
                      backgroundImage: (post['player_data']?['photo_url']
                                  ?.toString()
                                  .isNotEmpty ??
                              false)
                          ? NetworkImage(post['player_data']['photo_url'])
                          : null,
                      child: (post['player_data']?['photo_url']
                                  ?.toString()
                                  .isNotEmpty ??
                              false)
                          ? null
                          : const Icon(
                              Icons.person_outline,
                              color: Color(0xFF0D3B66),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${post['player_data']?['name'] ?? ''} ${post['player_data']?['lastname'] ?? ''}'
                                    .trim()
                                    .isEmpty
                                ? 'Jugador'
                                : '${post['player_data']?['name'] ?? ''} ${post['player_data']?['lastname'] ?? ''}'
                                    .trim(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A202C),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            post['convocatoria_titulo']?.toString() ??
                                'Convocatoria',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatRelative(post['created_at']).isEmpty
                                ? 'Ahora'
                                : _formatRelative(post['created_at']),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _pipelineLabel(post['estado']?.toString() ?? ''),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D3B66),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPostulacionCard(Map<String, dynamic> post,
      {bool compact = false}) {
    final user = post['player_data'] as Map<String, dynamic>?;
    final userId = _postulacionPlayerId(post);
    final name = '${user?['name'] ?? ''} ${user?['lastname'] ?? ''}'.trim();
    final year = _birthYear(user?['birthday']);
    final category = _categoryFromBirthday(user?['birthday']);
    final position = user?['posicion']?.toString() ?? 'Sin posición';
    final playerClub = user?['club']?.toString() ?? '';
    final city = user?['city']?.toString() ?? 'Sin ubicación';
    final convocatoriaTitle =
        post['convocatoria_titulo']?.toString() ?? 'Convocatoria';
    final stage = _normalizeStatus(post['estado']);
    final videoData = post['video_data'] as Map<String, dynamic>?;
    final hasVideo = post['has_video'] == true || videoData != null;

    final isVerified = _resolveVerification(user, defaultIfMissing: false);
    final hasVerificationInfo = _hasVerificationInfo(user);

    final thumb = videoData?['thumbnail_url']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 8 : 10),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 62,
                  height: 62,
                  color: const Color(0xFFE8F0FE),
                  child: thumb.isNotEmpty
                      ? Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            color: Color(0xFF0D3B66),
                          ),
                        )
                      : (user?['photo_url']?.toString().isNotEmpty ?? false)
                          ? Image.network(
                              user!['photo_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Color(0xFF0D3B66),
                              ),
                            )
                          : const Icon(Icons.person, color: Color(0xFF0D3B66)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.isNotEmpty ? name : 'Jugador',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            _updatePipelineStatus(
                              post['id']?.toString() ?? '',
                              value,
                              sourceTable: post['_source_table']?.toString(),
                            );
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'guardado',
                              child: Text('Guardado'),
                            ),
                            PopupMenuItem(
                              value: 'preseleccionado',
                              child: Text('Pré-selecionado'),
                            ),
                            PopupMenuItem(
                              value: 'invitar_prueba',
                              child: Text('Convidar para teste'),
                            ),
                            PopupMenuItem(
                              value: 'en_prueba',
                              child: Text('Em teste'),
                            ),
                            PopupMenuItem(
                              value: 'descartado',
                              child: Text('Descartado'),
                            ),
                            PopupMenuItem(
                              value: 'contratado',
                              child: Text('Contratado/Acompanhamento'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      [
                        if (year != null) year.toString(),
                        category,
                        position,
                        if (playerClub.isNotEmpty) playerClub,
                        city
                      ].join(' • '),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF718096),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      convocatoriaTitle,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF4A5568),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (hasVerificationInfo && isVerified) _metaChip('Verificado'),
              if (hasVideo) _metaChip('Tiene vídeo'),
              _metaChip('Pipeline: ${_pipelineLabel(stage)}'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: compact ? 110 : 130,
                child: OutlinedButton(
                  onPressed: userId.isEmpty
                      ? null
                      : () {
                          context.pushNamed(
                            'perfil_profesional_solicitar_Contato',
                            queryParameters: {'userId': userId},
                          );
                        },
                  child: const Text('Ver perfil'),
                ),
              ),
              SizedBox(
                width: compact ? 110 : 130,
                child: OutlinedButton(
                  onPressed:
                      hasVideo ? () => _openPlayerVideo(videoData) : null,
                  child: const Text('Ver vídeo'),
                ),
              ),
              SizedBox(
                width: compact ? 150 : 190,
                child: ElevatedButton(
                  onPressed: () => _updatePipelineStatus(
                    post['id']?.toString() ?? '',
                    'guardado',
                    sourceTable: post['_source_table']?.toString(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                  ),
                  child: const Text(
                    'Agregar al pipeline',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedPlayersSection() {
    if (_suggestedPlayers.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.workspace_premium_outlined,
        title: 'Sem resultados',
        subtitle: 'Todavía no hay jugadores Pro recientes para recomendar.',
      );
    }

    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedPlayers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final row = _suggestedPlayers[index];
          final user = row['user_data'] as Map<String, dynamic>;
          final userId = row['user_id']?.toString() ?? '';
          final name = '${user['name'] ?? ''} ${user['lastname'] ?? ''}'.trim();
          final category = _categoryFromBirthday(user['birthday']);
          final position = user['posicion']?.toString() ?? 'Sin posición';
          final city = user['city']?.toString() ?? '';

          return Container(
            width: 230,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFE8F0FE),
                            backgroundImage:
                                (user['photo_url']?.toString().isNotEmpty ??
                                        false)
                                    ? NetworkImage(user['photo_url'])
                                    : null,
                            child: (user['photo_url']?.toString().isNotEmpty ??
                                    false)
                                ? null
                                : const Icon(
                                    Icons.person_outline,
                                    color: Color(0xFF0D3B66),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name.isNotEmpty ? name : 'Jugador',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _metaChip('Plan Pro'),
                          _metaChip('Verificado'),
                          _metaChip(category),
                          _metaChip(position),
                          if (city.isNotEmpty) _metaChip(city),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Recomendación ligera para seguimiento reciente.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: userId.isEmpty
                              ? null
                              : () {
                                  context.pushNamed(
                                    'perfil_profesional_solicitar_Contato',
                                    queryParameters: {'userId': userId},
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D3B66),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text(
                            'Ver perfil',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPipelineSection() {
    if (_activeConvocatorias.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.alt_route,
        title: 'Sem resultados',
        subtitle:
            'El seguimiento aparecerá cuando existan convocatorias activas.',
      );
    }

    return Column(
      children: _activeConvocatorias.map((conv) {
        final convId = conv['id']?.toString() ?? '';
        final stats = _pipelineByConvocatoria[convId] ??
            {
              'postulated': 0,
              'saved': 0,
              'interest': 0,
            };
        final postulated = stats['postulated'] ?? 0;
        final saved = stats['saved'] ?? 0;
        final interest = stats['interest'] ?? 0;
        final total = max(postulated, 1);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conv['titulo']?.toString() ?? 'Convocatoria',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 10),
              _pipelineProgressBar(
                total: total,
                postulated: postulated,
                saved: saved,
                interest: interest,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _seguimientoMetric(
                      'Postulados',
                      postulated.toString(),
                      const Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _seguimientoMetric(
                      'Guardados',
                      saved.toString(),
                      const Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _seguimientoMetric(
                      'En acción',
                      interest.toString(),
                      const Color(0xFF22C55E),
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

  Widget _pipelineProgressBar({
    required int total,
    required int postulated,
    required int saved,
    required int interest,
  }) {
    final pendingFlex = max(postulated - saved, 0);
    final savedFlex = max(saved - interest, 0);
    final interestFlex = max(interest, 0);
    final safeTotal =
        max(pendingFlex + savedFlex + interestFlex, max(total, 1));

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (pendingFlex > 0)
              Expanded(
                flex: pendingFlex,
                child: Container(color: const Color(0xFFCBD5E1)),
              ),
            if (savedFlex > 0)
              Expanded(
                flex: savedFlex,
                child: Container(color: const Color(0xFF0D3B66)),
              ),
            if (interestFlex > 0)
              Expanded(
                flex: interestFlex,
                child: Container(color: const Color(0xFF22C55E)),
              ),
            if (savedFlex + interestFlex < safeTotal)
              Expanded(
                flex: safeTotal - savedFlex - interestFlex,
                child: Container(color: Colors.transparent),
              ),
          ],
        ),
      ),
    );
  }

  Widget _seguimientoMetric(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF4A5568),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: const Color(0xFF4A5568),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInlineStatus({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
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
          Icon(icon, color: const Color(0xFFA0AEC0), size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
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
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SingleVideoSheet extends StatefulWidget {
  const _SingleVideoSheet({required this.video});

  final Map<String, dynamic> video;

  @override
  State<_SingleVideoSheet> createState() => _SingleVideoSheetState();
}

class _SingleVideoSheetState extends State<_SingleVideoSheet> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = widget.video['video_url']?.toString() ?? '';
    if (!url.startsWith('http')) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _paused = true;
      } else {
        _controller!.play();
        _paused = false;
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video['title']?.toString() ?? 'Vídeo';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _hasError || _controller == null
                    ? const Center(
                        child: Text(
                          'No se pudo reproducir el video',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : GestureDetector(
                        onTap: _togglePlayPause,
                        child: Stack(
                          children: [
                            Center(
                              child: AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                            if (_paused)
                              const Center(
                                child: Icon(
                                  Icons.play_arrow,
                                  size: 60,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
