import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/perfil_publico_club/perfil_publico_club_widget.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/flutter_flow/app_modals.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/gamification/gamification_service.dart';
import '/guardian/guardian_mvp_service.dart';
import 'latam_taxonomy.dart';
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
    club['club_ref'],
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
  const ExplorarWidget({
    super.key,
    this.initialScoutTab,
  });

  static String routeName = 'Explorar';
  static String routePath = '/explorar';

  final String? initialScoutTab;

  @override
  State<ExplorarWidget> createState() => _ExplorarWidgetState();
}

class _ExplorarWidgetState extends State<ExplorarWidget> {
  static const int _explorerPageSize = 200;
  static const int _explorerFilterMaxRows = 900;
  static const int _explorerClubMaxRows = 900;

  late ExplorarModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  bool _isJugadorSearchMode = false;
  bool _isJugadorFiltersExpanded = false;
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
  String? _scoutPlayerState;
  String? _scoutPlayerCity;
  String? _scoutPlayerLevel;
  String? _scoutClubCountry;
  String? _scoutClubState;
  String? _scoutClubCity;
  String? _scoutClubLeague;
  String? _scoutConvocatoriaCountry;
  String? _scoutConvocatoriaState;
  String? _scoutConvocatoriaCity;
  String? _scoutConvocatoriaCategory;
  String? _scoutConvocatoriaPosition;
  String? _jugadorPlayerCategory;
  String? _jugadorPlayerPosition;
  String? _jugadorPlayerCountry;
  String? _jugadorPlayerState;
  String? _jugadorPlayerCity;
  String? _jugadorPlayerLevel;
  String? _jugadorConvocatoriaCategory;
  String? _jugadorConvocatoriaPosition;
  String? _jugadorConvocatoriaLocation;
  String? _jugadorClubCountry;
  String? _jugadorClubState;
  String? _jugadorClubCity;
  String? _jugadorClubLeague;
  String? _jugadorScoutCountry;
  String? _jugadorScoutState;

  int? _currentPlanId;
  bool _currentUserVerified = true;
  bool _currentUserFullAccess = false;
  bool _isClubStaff = false;
  Map<String, dynamic>? _nextChallenge;

  // Filtros "Valores reales" pre-cargados
  List<String> _realPlayerPositions = [];
  List<String> _realPlayerCategories = [];
  List<String> _realPlayerCities = [];
  List<String> _realClubCities = [];
  List<String> _realClubLeagues = [];
  List<String> _realConvocatoriaCategories = [];
  List<String> _realConvocatoriaPositions = [];
  List<String> _realConvocatoriaCities = [];
  List<String> _realConvocatoriaLocations = [];

  Widget _buildFeatureUnavailableState({
    required String title,
    required String message,
  }) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 34,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => context.goNamed(FeedWidget.routeName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ir al feed'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ExplorarModel());
    final initialScoutTab = widget.initialScoutTab?.trim().toLowerCase();
    if (initialScoutTab == 'convocatorias') {
      _scoutTab = _ScoutTab.convocatorias;
    } else if (initialScoutTab == 'clubes') {
      _scoutTab = _ScoutTab.clubes;
    } else if (initialScoutTab == 'jugadores') {
      _scoutTab = _ScoutTab.jugadores;
    }
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
        _loadRealFilterOptions(),
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

  Future<void> _loadRealFilterOptions() async {
    try {
      var listP = await _selectExplorerRowsPaged(
        'users',
        equalsColumn: 'userType',
        equalsValue: 'jugador',
      );
      if (listP.isEmpty) {
        listP = await _selectExplorerRowsPaged(
          'users',
          equalsColumn: 'usertype',
          equalsValue: 'jugador',
        );
      }
      if (listP.isEmpty) {
        final allUsers = await _selectExplorerRowsPaged('users');
        listP = allUsers.where((u) {
          return FFAppState.normalizeUserType(
                u['userType'] ?? u['usertype'] ?? u['user_type'],
              ) ==
              'jugador';
        }).toList(growable: false);
      }
      _realPlayerPositions = buildNormalizedOptions(
          listP.map(_resolvePlayerPosition), normalizePlayerPosition);
      _realPlayerCategories = buildNormalizedOptions(
        listP.map((u) => _resolvePlayerCategory(u)),
        normalizePlayerCategory,
      );
      _realPlayerCities =
          buildNormalizedOptions(listP.map(_resolveCity), normalizeCityName);
    } catch (_) {}
    try {
      final listC = await _fetchVisibleExplorerClubs();
      _setRealClubFilterOptions(listC);
    } catch (_) {}
    try {
      final listConv = await _selectExplorerRowsPaged(
        'convocatorias',
        equalsColumn: 'is_active',
        equalsValue: true,
        orderByCreatedAt: true,
      );
      _realConvocatoriaCategories = buildNormalizedOptions(
        listConv.map(_resolveConvocatoriaCategory),
        normalizePlayerCategory,
      );
      _realConvocatoriaPositions = buildNormalizedOptions(
        listConv.map(_resolveConvocatoriaPosition),
        normalizePlayerPosition,
      );
      _realConvocatoriaCities = buildNormalizedOptions(
        listConv.map(_resolveConvocatoriaCity),
        normalizeCityName,
      );
      _realConvocatoriaLocations = buildNormalizedOptions(
        listConv.map(_resolveConvocatoriaLocationLabel),
        titleCaseLabel,
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _selectExplorerRowsPaged(
    String table, {
    String? equalsColumn,
    Object? equalsValue,
    bool orderByCreatedAt = false,
    int maxRows = _explorerFilterMaxRows,
    int pageSize = _explorerPageSize,
  }) async {
    final rows = <Map<String, dynamic>>[];
    var from = 0;

    while (rows.length < maxRows) {
      final remaining = maxRows - rows.length;
      final currentPageSize = remaining < pageSize ? remaining : pageSize;
      final to = from + currentPageSize - 1;

      try {
        dynamic query = SupaFlow.client.from(table).select();
        if (equalsColumn != null) {
          query = query.eq(equalsColumn, equalsValue);
        }
        if (orderByCreatedAt) {
          query = query.order('created_at', ascending: false);
        }
        final response = await query.range(from, to);
        final page = List<Map<String, dynamic>>.from(response as List);
        rows.addAll(page);
        if (page.length < currentPageSize) break;
        from += currentPageSize;
      } catch (_) {
        return rows;
      }
    }

    return rows;
  }

  Future<void> _loadViewerContext() async {
    if (currentUserUid.isEmpty) return;

    try {
      await FFAppState().refreshCurrentUserAccess();
      final appState = FFAppState();
      _currentPlanId = appState.currentPlanId;
      _currentUserVerified = appState.currentUserVerified;
      _currentUserFullAccess = appState.currentUserFullAccess;
    } catch (_) {
      _currentPlanId = null;
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
      _clubs = await _fetchVisibleExplorerClubs();
      _setRealClubFilterOptions(_clubs);
    } catch (_) {
      _clubs = [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVisibleExplorerClubs({
    int maxRows = _explorerClubMaxRows,
  }) async {
    final clubUsers = await _loadClubUsersForExplorer(maxRows: maxRows);

    final ownerByRef = <String, String>{};
    final ownerDataById = <String, Map<String, dynamic>>{};
    for (final user in clubUsers) {
      final ownerId = _cleanRef(user['user_id']);
      if (ownerId.isEmpty) continue;
      ownerDataById[ownerId] = user;
      ownerByRef[ownerId] = ownerId;
      final legacyRef = _legacyClubRef(ownerId);
      if (legacyRef.isNotEmpty) {
        ownerByRef[legacyRef] = ownerId;
      }
    }

    final visibleByOwner = <String, Map<String, dynamic>>{};

    final modernRows = await _safeSelectExplorerRows(
      'clubs',
      maxRows: maxRows,
      orderByCreatedAt: true,
    );
    for (final row in modernRows) {
      if (_isSoftDeletedRow(row)) continue;
      var ownerId = _resolveClubOwnerId(row, ownerByRef);
      if (ownerId.isEmpty) ownerId = _fallbackClubOwnerId(row);
      if (ownerId.isEmpty) continue;
      visibleByOwner[ownerId] = _mergeClubWithOwner(
        row,
        ownerDataById[ownerId],
        ownerId,
        source: 'clubs',
      );
    }

    final legacyRows = await _safeSelectExplorerRows(
      'clubes',
      maxRows: maxRows,
      orderByCreatedAt: true,
    );
    for (final row in legacyRows) {
      if (_isSoftDeletedRow(row)) continue;
      var ownerId = _resolveClubOwnerId(row, ownerByRef);
      if (ownerId.isEmpty) ownerId = _fallbackClubOwnerId(row);
      if (ownerId.isEmpty || visibleByOwner.containsKey(ownerId)) continue;
      visibleByOwner[ownerId] = _mergeClubWithOwner(
        row,
        ownerDataById[ownerId],
        ownerId,
        source: 'clubes',
      );
    }

    for (final user in clubUsers) {
      final ownerId = _cleanRef(user['user_id']);
      if (ownerId.isEmpty || visibleByOwner.containsKey(ownerId)) continue;
      visibleByOwner[ownerId] = _clubFromOwnerUser(user);
    }

    final visible = visibleByOwner.values.toList()
      ..sort((a, b) => _clubSortValue(b).compareTo(_clubSortValue(a)));
    return visible.take(maxRows).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadClubUsersForExplorer({
    int maxRows = _explorerClubMaxRows,
  }) async {
    final byUserId = <String, Map<String, dynamic>>{};
    final attempts = <Future<List<Map<String, dynamic>>> Function()>[
      () => _selectExplorerRowsPaged(
            'users',
            equalsColumn: 'userType',
            equalsValue: 'club',
            maxRows: maxRows,
          ),
      () => _selectExplorerRowsPaged(
            'users',
            equalsColumn: 'usertype',
            equalsValue: 'club',
            maxRows: maxRows,
          ),
      () => _selectExplorerRowsPaged('users', maxRows: maxRows),
    ];

    for (final attempt in attempts) {
      try {
        final response = await attempt();
        for (final user in response) {
          if (_isSoftDeletedRow(user)) continue;
          final type = FFAppState.normalizeUserType(
            user['userType'] ?? user['usertype'] ?? user['user_type'],
          );
          final userId = _cleanRef(user['user_id']);
          if (type == 'club' && userId.isNotEmpty) {
            byUserId[userId] = user;
          }
        }
      } catch (_) {}
    }

    return byUserId.values.toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _safeSelectExplorerRows(
    String table, {
    required int maxRows,
    bool orderByCreatedAt = false,
  }) async {
    final orderedRows = await _selectExplorerRowsPaged(
      table,
      orderByCreatedAt: orderByCreatedAt,
      maxRows: maxRows,
    );
    if (orderedRows.isNotEmpty || !orderByCreatedAt) {
      return orderedRows;
    }

    return _selectExplorerRowsPaged(table, maxRows: maxRows);
  }

  String _resolveClubOwnerId(
    Map<String, dynamic> club,
    Map<String, String> ownerByRef,
  ) {
    for (final value in [
      club['owner_id'],
      club['user_id'],
      club['id'],
      club['club_id'],
    ]) {
      final ref = _cleanRef(value);
      final ownerId = ownerByRef[ref];
      if (ownerId != null && ownerId.isNotEmpty) return ownerId;
    }
    return '';
  }

  String _fallbackClubOwnerId(Map<String, dynamic> club) {
    for (final value in [
      club['owner_id'],
      club['user_id'],
      club['club_id'],
      club['id'],
    ]) {
      final ref = _cleanRef(value);
      if (ref.isNotEmpty) return ref;
    }
    return '';
  }

  Map<String, dynamic> _mergeClubWithOwner(
    Map<String, dynamic> club,
    Map<String, dynamic>? ownerData,
    String ownerId, {
    required String source,
  }) {
    final merged = Map<String, dynamic>.from(club);
    final modernClubId = source == 'clubs' ? _cleanRef(club['id']) : '';
    merged['owner_id'] = ownerId;
    merged['user_id'] = ownerId;
    merged['club_ref'] = modernClubId.isNotEmpty ? modernClubId : ownerId;
    merged['owner_data'] = ownerData;
    merged['nombre'] = _firstNonEmpty([
          merged['nombre'],
          merged['name'],
          merged['club_name'],
          merged['nombre_corto'],
          ownerData?['name'],
        ]) ??
        'Club';
    merged['nombre_corto'] = _firstNonEmpty([
          merged['nombre_corto'],
          merged['short_name'],
          merged['name'],
          ownerData?['name'],
        ]) ??
        merged['nombre'];
    merged['logo_url'] = _firstNonEmpty([
      merged['logo_url'],
      merged['escudo_url'],
      merged['shield_url'],
      ownerData?['photo_url'],
    ]);
    merged['country'] = _firstNonEmpty([
      merged['country'],
      merged['pais'],
      ownerData?['country'],
      ownerData?['pais'],
    ]);
    merged['pais'] = _firstNonEmpty([merged['pais'], merged['country']]);
    merged['state'] = _firstNonEmpty([
      merged['state'],
      merged['estado'],
      ownerData?['state'],
      ownerData?['estado'],
    ]);
    merged['estado'] = _firstNonEmpty([merged['estado'], merged['state']]);
    merged['city'] = _firstNonEmpty([
      merged['city'],
      merged['ciudad'],
      ownerData?['city'],
      ownerData?['ciudad'],
    ]);
    merged['ciudad'] = _firstNonEmpty([merged['ciudad'], merged['city']]);
    merged['is_visible_explorer_club'] = true;
    return merged;
  }

  Map<String, dynamic> _clubFromOwnerUser(Map<String, dynamic> user) {
    final ownerId = _cleanRef(user['user_id']);
    return _mergeClubWithOwner(
      {
        'id': ownerId,
        'owner_id': ownerId,
        'user_id': ownerId,
        'nombre': user['name'],
        'nombre_corto': user['name'],
        'logo_url': user['photo_url'],
        'created_at': user['created_at'],
      },
      user,
      ownerId,
      source: 'users',
    );
  }

  void _setRealClubFilterOptions(List<Map<String, dynamic>> clubs) {
    _realClubCities =
        buildNormalizedOptions(clubs.map(_resolveCity), normalizeCityName);
    _realClubLeagues = buildNormalizedOptions(
      clubs.map(_resolveClubLeague),
      normalizeLeagueName,
    );
  }

  String _cleanRef(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _legacyClubRef(String userId) {
    final compact = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (compact.isEmpty) return '';
    return compact.length <= 10 ? compact : compact.substring(0, 10);
  }

  bool _isSoftDeletedRow(Map<String, dynamic> row) {
    final deletedAt = row['deleted_at']?.toString().trim() ?? '';
    if (deletedAt.isNotEmpty && deletedAt.toLowerCase() != 'null') return true;
    final isDeleted = row['is_deleted'];
    if (isDeleted is bool) return isDeleted;
    final deletedText = isDeleted?.toString().trim().toLowerCase() ?? '';
    return deletedText == 'true' || deletedText == '1';
  }

  int _clubSortValue(Map<String, dynamic> club) {
    final raw = _firstNonEmpty([
      club['created_at'],
      club['updated_at'],
      club['owner_data'] is Map
          ? (club['owner_data'] as Map)['created_at']
          : null,
    ]);
    return DateTime.tryParse(raw ?? '')?.millisecondsSinceEpoch ?? 0;
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

    _convocatorias = _convocatorias
        .map((conv) {
          final map = Map<String, dynamic>.from(conv);
          final clubId = map['club_id']?.toString() ?? '';
          if (map['club_data'] == null && clubId.isNotEmpty) {
            final clubData = clubsById[clubId];
            if (clubData != null) {
              map['club_data'] = clubData;
            }
          }
          return map;
        })
        .where((conv) => conv['club_data'] is Map)
        .toList();
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
      FFAppState().canUseSensitiveActions ||
      _currentUserFullAccess ||
      ((_currentPlanId ?? 0) >= 2 && _currentUserVerified);

  Future<bool> _ensureSensitiveAccess({required String message}) async {
    await _loadViewerContext();
    if (_canUseSensitiveActions) {
      return true;
    }

    if (mounted) {
      _showUpsellDialog(
        title: 'Acción bloqueada',
        message: message,
      );
    }
    return false;
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
    setState(() => _searchQuery = value.trim());
  }

  String _normalizeSearchText(String value) {
    var normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return '';

    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ñ': 'n',
      'ç': 'c',
    };

    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });

    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  List<String> _searchTerms(String query) {
    final normalized = _normalizeSearchText(query);
    if (normalized.isEmpty) return const [];
    return normalized
        .split(' ')
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();
  }

  int _computeSearchScore({
    required String normalizedQuery,
    required List<String> terms,
    required Iterable<dynamic> primaryFields,
    Iterable<dynamic> relatedFields = const [],
  }) {
    final primary = primaryFields
        .map((field) => _normalizeSearchText(field?.toString() ?? ''))
        .where((field) => field.isNotEmpty)
        .toList(growable: false);
    final related = relatedFields
        .map((field) => _normalizeSearchText(field?.toString() ?? ''))
        .where((field) => field.isNotEmpty)
        .toList(growable: false);

    final allFields = <String>[...primary, ...related];
    if (allFields.isEmpty) return 0;

    final haystack = allFields.join(' ');
    final matchesAllTerms =
        terms.isNotEmpty && terms.every((term) => haystack.contains(term));
    final matchesWholeQuery =
        normalizedQuery.isNotEmpty && haystack.contains(normalizedQuery);
    if (!matchesAllTerms && !matchesWholeQuery) return 0;

    var score = 0;

    if (primary.any((field) => field == normalizedQuery)) {
      score += 180;
    }
    if (primary.any((field) => field.startsWith(normalizedQuery))) {
      score += 120;
    } else if (matchesWholeQuery) {
      score += 80;
    }

    for (final term in terms) {
      if (primary.any((field) => field == term)) {
        score += 48;
      } else if (primary.any((field) => field.startsWith(term))) {
        score += 30;
      } else if (primary.any((field) => field.contains(term))) {
        score += 18;
      } else if (related.any((field) => field.startsWith(term))) {
        score += 12;
      } else if (related.any((field) => field.contains(term))) {
        score += 8;
      }
    }

    return score;
  }

  List<Map<String, dynamic>> _applySearchRanking(
    Iterable<Map<String, dynamic>> source, {
    required Iterable<dynamic> Function(Map<String, dynamic> item)
        primaryFields,
    Iterable<dynamic> Function(Map<String, dynamic> item)? relatedFields,
  }) {
    final normalizedQuery = _normalizeSearchText(_searchQuery);
    if (normalizedQuery.isEmpty) return source.toList();

    final terms = _searchTerms(normalizedQuery);
    final items = source.toList(growable: false);
    final scoredItems = <({Map<String, dynamic> item, int score, int index})>[];

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final score = _computeSearchScore(
        normalizedQuery: normalizedQuery,
        terms: terms,
        primaryFields: primaryFields(item),
        relatedFields: relatedFields == null ? const [] : relatedFields(item),
      );
      if (score > 0) {
        scoredItems.add((item: item, score: score, index: index));
      }
    }

    scoredItems.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.index.compareTo(b.index);
    });

    return scoredItems.map((entry) => entry.item).toList(growable: false);
  }

  Iterable<dynamic> _playerSearchPrimaryFields(Map<String, dynamic> player) {
    final fullName =
        '${player['name'] ?? ''} ${player['lastname'] ?? ''}'.trim();
    return [
      fullName,
      player['name'],
      player['lastname'],
      player['username'],
      _resolvePlayerPosition(player),
      _resolvePlayerCategory(player),
      player['club'],
      _resolveCity(player),
      _resolveState(player),
      _resolveCountryFromUser(player),
      _resolvePlayerLevel(player),
    ];
  }

  Iterable<dynamic> _playerSearchRelatedFields(Map<String, dynamic> player) {
    return [
      player['bio'],
      player['description'],
      player['descripcion'],
      player['team'],
      player['equipo'],
      player['academy'],
      player['school'],
      player['country'],
      player['city'],
      player['state'],
      player['categoria'],
      player['posicion'],
      _birthYear(
        player['birthday'] ??
            player['birth_date'] ??
            player['fecha_nacimiento'],
      ),
      GamificationService.toInt(player['total_xp']).toString(),
    ];
  }

  Iterable<dynamic> _clubSearchPrimaryFields(Map<String, dynamic> club) {
    return [
      club['nombre'],
      club['name'],
      club['club_name'],
      club['nombre_corto'],
      club['short_name'],
      club['username'],
      _resolveClubLeague(club),
      _resolveCity(club),
      _resolveState(club),
      _resolveCountryFromClub(club),
    ];
  }

  Iterable<dynamic> _clubSearchRelatedFields(Map<String, dynamic> club) {
    return [
      club['descripcion'],
      club['description'],
      club['bio'],
      club['sitio_web'],
      club['website'],
      club['web'],
      club['city'],
      club['state'],
      club['country'],
      club['league'],
    ];
  }

  Iterable<dynamic> _convocatoriaSearchPrimaryFields(
    Map<String, dynamic> convocatoria,
  ) {
    return [
      convocatoria['titulo'],
      convocatoria['title'],
      _resolveConvocatoriaClubName(convocatoria),
      _resolveConvocatoriaPosition(convocatoria),
      _resolveConvocatoriaCategory(convocatoria),
      _resolveConvocatoriaLocationLabel(convocatoria),
      _resolveConvocatoriaCity(convocatoria),
      _resolveConvocatoriaCountry(convocatoria),
    ];
  }

  Iterable<dynamic> _convocatoriaSearchRelatedFields(
    Map<String, dynamic> convocatoria,
  ) {
    return [
      convocatoria['descripcion'],
      convocatoria['description'],
      convocatoria['details'],
      convocatoria['requirements'],
      convocatoria['ubicacion'],
      convocatoria['location'],
      _convocatoriaClosingLabel(convocatoria),
      _convocatoriaApplicationsLabel(convocatoria),
    ];
  }

  Iterable<dynamic> _scoutSearchPrimaryFields(Map<String, dynamic> scout) {
    final fullName = '${scout['name'] ?? ''} ${scout['lastname'] ?? ''}'.trim();
    return [
      fullName,
      scout['name'],
      scout['lastname'],
      scout['username'],
      scout['club'],
      scout['organization'],
      scout['cargo'],
      scout['role'],
      _resolveCity(scout),
      _resolveState(scout),
      _resolveCountryFromUser(scout),
    ];
  }

  Iterable<dynamic> _scoutSearchRelatedFields(Map<String, dynamic> scout) {
    return [
      scout['bio'],
      scout['description'],
      scout['descripcion'],
      scout['country'],
      scout['state'],
      scout['city'],
      scout['team'],
      scout['equipo'],
    ];
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
      return normalizeCountryName(directCountry);
    }

    final countryIdRaw = user['country_id'];
    final countryId = countryIdRaw is int
        ? countryIdRaw
        : int.tryParse(countryIdRaw?.toString() ?? '');
    if (countryId == null) return '';
    return normalizeCountryName(_countryNameById[countryId]);
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
    return normalizeCountryName(value);
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
    return normalizeLeagueName(value);
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
    return normalizeStateName(value);
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
    return normalizeCityName(value);
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

  String _resolveConvocatoriaLocationLabel(Map<String, dynamic> convocatoria) {
    final direct = _firstNonEmpty([
      convocatoria['ubicacion'],
      convocatoria['location'],
      convocatoria['localidad'],
      convocatoria['cidade'],
    ]);
    if (direct != null && direct.isNotEmpty) return titleCaseLabel(direct);

    final city = _resolveConvocatoriaCity(convocatoria);
    final country = _resolveConvocatoriaCountry(convocatoria);
    if (city.isNotEmpty && country.isNotEmpty) {
      if (city.toLowerCase() == country.toLowerCase()) return city;
      return '$city, $country';
    }
    if (city.isNotEmpty) return city;
    return country;
  }

  String _resolveConvocatoriaCategory(Map<String, dynamic> convocatoria) {
    return normalizePlayerCategory(_firstNonEmpty([
          convocatoria['categoria'],
          convocatoria['category'],
        ]) ??
        '');
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
    return normalizePlayerPosition(_firstNonEmpty([
          convocatoria['posicion'],
          convocatoria['position'],
          convocatoria['posição'],
        ]) ??
        '');
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
      return 'Cierre vencido';
    }
    if (daysLeft == 0) {
      return 'Cierra hoy';
    }
    if (daysLeft == 1) {
      return 'Cierra en 1d';
    }
    return 'Cierra en ${daysLeft}d';
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
    return '$applicationsCount aplic.';
  }

  String _resolveExplorerClubLogo(Map<String, dynamic>? clubData) {
    return _firstNonEmpty([
          clubData?['photo_url'],
          clubData?['logo_url'],
          clubData?['avatar_url'],
          clubData?['escudo_url'],
        ]) ??
        '';
  }

  String _resolveExplorerConvocatoriaMode(Map<String, dynamic> convocatoria) {
    final virtualFlag = convocatoria['is_virtual'] == true ||
        (convocatoria['virtual']?.toString().toLowerCase() == 'true');
    final presentialFlag = convocatoria['is_presencial'] == true ||
        convocatoria['is_in_person'] == true ||
        (convocatoria['presencial']?.toString().toLowerCase() == 'true');
    if (virtualFlag && presentialFlag) return 'Híbrida';
    if (virtualFlag) return 'Virtual';
    if (presentialFlag) return 'Presencial';

    final raw = (_firstNonEmpty([
              convocatoria['modalidad'],
              convocatoria['modality'],
              convocatoria['tipo_modalidad'],
              convocatoria['formato'],
              convocatoria['format'],
              convocatoria['tipo'],
            ]) ??
            'Presencial')
        .toLowerCase();

    if (raw.contains('hibr')) return 'Híbrida';
    if (raw.contains('virtual') ||
        raw.contains('online') ||
        raw.contains('remote') ||
        raw.contains('remot')) {
      return 'Virtual';
    }
    return 'Presencial';
  }

  Color _explorerConvocatoriaModeColor(String mode) {
    switch (mode) {
      case 'Virtual':
        return const Color(0xFF0284C7);
      case 'Híbrida':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF15803D);
    }
  }

  int _explorerRequiredChallengesCount(Map<String, dynamic> convocatoria) {
    dynamic raw = convocatoria['required_challenges'];
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return 0;
      try {
        raw = jsonDecode(trimmed);
      } catch (_) {
        return 0;
      }
    }
    if (raw is! List) return 0;

    var count = 0;
    for (final entry in raw) {
      final map = entry is Map<String, dynamic>
          ? entry
          : entry is Map
              ? Map<String, dynamic>.from(entry)
              : null;
      if (map == null) continue;
      final id = map['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) count++;
    }
    return count;
  }

  Widget _buildExplorerConvocatoriaPlaceholderImage() => Container(
        width: double.infinity,
        height: 156,
        color: const Color(0xFFE0E0E0),
        child: const Center(
          child: Icon(
            Icons.sports_soccer,
            size: 50,
            color: Color(0xFF0D3B66),
          ),
        ),
      );

  Widget _buildExplorerClubPlaceholderIcon({double size = 24}) => Container(
        width: size,
        height: size,
        color: const Color(0xFF0D3B66),
        child: Icon(
          Icons.shield_outlined,
          size: size * 0.58,
          color: Colors.white,
        ),
      );

  String _resolvePlayerPosition(Map<String, dynamic> player) {
    return normalizePlayerPosition(
      _firstNonEmpty([
            player['posicion'],
            player['position'],
            player['posição'],
            player['position_name'],
          ]) ??
          '',
    );
  }

  String _resolvePlayerCategory(Map<String, dynamic> player) {
    return normalizePlayerCategory(
      _firstNonEmpty([
            player['categoria'],
            player['category'],
          ]) ??
          '',
      birthday: player['birthday'] ??
          player['birth_date'] ??
          player['fecha_nacimiento'],
    );
  }

  String _resolvePlayerLevel(Map<String, dynamic> player) {
    final direct = player['level_name']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final totalXp = GamificationService.toInt(player['total_xp']);
    return GamificationService.levelNameFromPoints(totalXp);
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

    if (_scoutPosition != null) {
      filtered = filtered.where(
        (u) =>
            _resolvePlayerPosition(u).toLowerCase() ==
            _scoutPosition!.toLowerCase(),
      );
    }

    if (_scoutPlayerCountry != null) {
      filtered = filtered.where((u) =>
          _resolveCountryFromUser(u).toLowerCase() ==
          _scoutPlayerCountry!.toLowerCase());
    }

    if (_scoutPlayerState != null) {
      filtered = filtered.where((u) =>
          _resolveState(u).toLowerCase() == _scoutPlayerState!.toLowerCase());
    }

    if (_scoutPlayerCity != null) {
      filtered = filtered.where((u) =>
          _resolveCity(u).toLowerCase() == _scoutPlayerCity!.toLowerCase());
    }

    if (_scoutCategory != null) {
      filtered = filtered.where(
        (u) => _resolvePlayerCategory(u) == _scoutCategory,
      );
    }

    if (_scoutPlayerLevel != null) {
      filtered = filtered.where(
        (u) =>
            _resolvePlayerLevel(u).toLowerCase() ==
            _scoutPlayerLevel!.toLowerCase(),
      );
    }

    return _applySearchRanking(
      filtered,
      primaryFields: _playerSearchPrimaryFields,
      relatedFields: _playerSearchRelatedFields,
    );
  }

  List<Map<String, dynamic>> get _scoutFilteredClubs {
    Iterable<Map<String, dynamic>> filtered = _clubs;

    if (_scoutClubCountry != null) {
      filtered = filtered.where((club) =>
          _resolveCountryFromClub(club).toLowerCase() ==
          _scoutClubCountry!.toLowerCase());
    }

    if (_scoutClubState != null) {
      filtered = filtered.where((club) =>
          _resolveState(club).toLowerCase() == _scoutClubState!.toLowerCase());
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

    return _applySearchRanking(
      filtered,
      primaryFields: _clubSearchPrimaryFields,
      relatedFields: _clubSearchRelatedFields,
    );
  }

  List<Map<String, dynamic>> get _scoutFilteredConvocatorias {
    Iterable<Map<String, dynamic>> filtered = _convocatorias;

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

    return _applySearchRanking(
      filtered,
      primaryFields: _convocatoriaSearchPrimaryFields,
      relatedFields: _convocatoriaSearchRelatedFields,
    );
  }

  List<Map<String, dynamic>> get _jugadorFilteredPlayers {
    Iterable<Map<String, dynamic>> filtered = _players;

    if (_jugadorPlayerPosition != null) {
      filtered = filtered.where(
        (u) =>
            _resolvePlayerPosition(u).toLowerCase() ==
            _jugadorPlayerPosition!.toLowerCase(),
      );
    }

    if (_jugadorPlayerCountry != null) {
      filtered = filtered.where((u) =>
          _resolveCountryFromUser(u).toLowerCase() ==
          _jugadorPlayerCountry!.toLowerCase());
    }

    if (_jugadorPlayerState != null) {
      filtered = filtered.where((u) =>
          _resolveState(u).toLowerCase() == _jugadorPlayerState!.toLowerCase());
    }

    if (_jugadorPlayerCity != null) {
      filtered = filtered.where((u) =>
          _resolveCity(u).toLowerCase() == _jugadorPlayerCity!.toLowerCase());
    }

    if (_jugadorPlayerCategory != null) {
      filtered = filtered.where(
        (u) => _resolvePlayerCategory(u) == _jugadorPlayerCategory,
      );
    }

    if (_jugadorPlayerLevel != null) {
      filtered = filtered.where(
        (u) =>
            _resolvePlayerLevel(u).toLowerCase() ==
            _jugadorPlayerLevel!.toLowerCase(),
      );
    }

    return _applySearchRanking(
      filtered,
      primaryFields: _playerSearchPrimaryFields,
      relatedFields: _playerSearchRelatedFields,
    );
  }

  List<Map<String, dynamic>> get _jugadorFilteredConvocatorias {
    Iterable<Map<String, dynamic>> filtered = _convocatorias;

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

    if (_jugadorConvocatoriaLocation != null) {
      filtered = filtered.where((conv) =>
          _resolveConvocatoriaLocationLabel(conv).toLowerCase() ==
          _jugadorConvocatoriaLocation!.toLowerCase());
    }

    return _applySearchRanking(
      filtered,
      primaryFields: _convocatoriaSearchPrimaryFields,
      relatedFields: _convocatoriaSearchRelatedFields,
    );
  }

  List<Map<String, dynamic>> get _jugadorFilteredClubs {
    Iterable<Map<String, dynamic>> filtered = _clubs;

    if (_jugadorClubCountry != null) {
      filtered = filtered.where((club) =>
          _resolveCountryFromClub(club).toLowerCase() ==
          _jugadorClubCountry!.toLowerCase());
    }

    if (_jugadorClubState != null) {
      filtered = filtered.where((club) =>
          _resolveState(club).toLowerCase() ==
          _jugadorClubState!.toLowerCase());
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

    return _applySearchRanking(
      filtered,
      primaryFields: _clubSearchPrimaryFields,
      relatedFields: _clubSearchRelatedFields,
    );
  }

  List<Map<String, dynamic>> get _jugadorFilteredScouts {
    Iterable<Map<String, dynamic>> filtered = _users.where((user) {
      final isScout =
          (user['userType']?.toString().trim().toLowerCase() ?? '') ==
              'profesional';
      return isScout && _isVerified(user);
    });

    if (_jugadorScoutCountry != null) {
      filtered = filtered.where((user) =>
          _resolveCountryFromUser(user).toLowerCase() ==
          _jugadorScoutCountry!.toLowerCase());
    }

    if (_jugadorScoutState != null) {
      filtered = filtered.where((user) =>
          _resolveState(user).toLowerCase() ==
          _jugadorScoutState!.toLowerCase());
    }

    return _applySearchRanking(
      filtered,
      primaryFields: _scoutSearchPrimaryFields,
      relatedFields: _scoutSearchRelatedFields,
    );
  }

  void _resetJugadorSearchFilters() {
    _jugadorPlayerCategory = null;
    _jugadorPlayerPosition = null;
    _jugadorPlayerCountry = null;
    _jugadorPlayerState = null;
    _jugadorPlayerCity = null;
    _jugadorPlayerLevel = null;
    _jugadorConvocatoriaCategory = null;
    _jugadorConvocatoriaPosition = null;
    _jugadorConvocatoriaLocation = null;
    _jugadorClubCountry = null;
    _jugadorClubState = null;
    _jugadorClubCity = null;
    _jugadorClubLeague = null;
    _jugadorScoutCountry = null;
    _jugadorScoutState = null;
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
            _jugadorPlayerState != null ||
            _jugadorPlayerCity != null ||
            _jugadorPlayerLevel != null;
      case _JugadorSearchTab.convocatorias:
        return _jugadorConvocatoriaCategory != null ||
            _jugadorConvocatoriaPosition != null ||
            _jugadorConvocatoriaLocation != null;
      case _JugadorSearchTab.clubes:
        return _jugadorClubCountry != null ||
            _jugadorClubState != null ||
            _jugadorClubCity != null ||
            _jugadorClubLeague != null;
      case _JugadorSearchTab.scouts:
        return _jugadorScoutCountry != null || _jugadorScoutState != null;
    }
  }

  List<MapEntry<String, String>> get _jugadorCurrentFilterEntries {
    final entries = <MapEntry<String, String>>[];

    void add(String label, String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return;
      entries.add(MapEntry(label, text));
    }

    switch (_jugadorSearchTab) {
      case _JugadorSearchTab.jugadores:
        add('Categoría', _jugadorPlayerCategory);
        add('Posición', _jugadorPlayerPosition);
        add('País', _jugadorPlayerCountry);
        add('Provincia', _jugadorPlayerState);
        add('Ciudad', _jugadorPlayerCity);
        add('Nivel', _jugadorPlayerLevel);
        break;
      case _JugadorSearchTab.convocatorias:
        add('Categoría', _jugadorConvocatoriaCategory);
        add('Posición', _jugadorConvocatoriaPosition);
        add('Ubicación', _jugadorConvocatoriaLocation);
        break;
      case _JugadorSearchTab.clubes:
        add('País', _jugadorClubCountry);
        add('Provincia', _jugadorClubState);
        add('Ciudad', _jugadorClubCity);
        add('Liga', _jugadorClubLeague);
        break;
      case _JugadorSearchTab.scouts:
        add('País', _jugadorScoutCountry);
        add('Provincia', _jugadorScoutState);
        break;
    }

    return entries;
  }

  void _clearJugadorCurrentTabFilters() {
    switch (_jugadorSearchTab) {
      case _JugadorSearchTab.jugadores:
        _jugadorPlayerCategory = null;
        _jugadorPlayerPosition = null;
        _jugadorPlayerCountry = null;
        _jugadorPlayerState = null;
        _jugadorPlayerCity = null;
        _jugadorPlayerLevel = null;
        break;
      case _JugadorSearchTab.convocatorias:
        _jugadorConvocatoriaCategory = null;
        _jugadorConvocatoriaPosition = null;
        _jugadorConvocatoriaLocation = null;
        break;
      case _JugadorSearchTab.clubes:
        _jugadorClubCountry = null;
        _jugadorClubState = null;
        _jugadorClubCity = null;
        _jugadorClubLeague = null;
        break;
      case _JugadorSearchTab.scouts:
        _jugadorScoutCountry = null;
        _jugadorScoutState = null;
        break;
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

  void _showScoutScoutingFeedback({required bool added}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Jugador agregado a mi Scouting'
              : 'Jugador eliminado de mi Scouting',
        ),
        backgroundColor: added ? Colors.green : const Color(0xFF475569),
        action: added
            ? SnackBarAction(
                label: 'Ver mi scouting',
                textColor: Colors.white,
                onPressed: () {
                  context.pushNamed(ListaYNotasWidget.routeName);
                },
              )
            : null,
      ),
    );
  }

  Future<void> _toggleSavePlayerForScout(Map<String, dynamic> player) async {
    if (!await _ensureSensitiveAccess(
      message:
          'Para agregar jugadores a scouting necesitas verificación o un plan activo.',
    )) {
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
        _showScoutScoutingFeedback(added: false);
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
      _showScoutScoutingFeedback(added: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingPlayerId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSaved
                ? 'No se pudo eliminar de mi Scouting'
                : 'No se pudo agregar a mi Scouting',
          ),
        ),
      );
    }
  }

  Future<void> _openPlayerVideos(Map<String, dynamic> player) async {
    if (!await _ensureSensitiveAccess(
      message:
          'Para ver videos desde Explorer necesitás verificación o un plan activo.',
    )) {
      return;
    }
    if (!mounted) return;

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

    if (uid == currentUserUid) {
      final viewerType = FFAppState.normalizeUserType(FFAppState().userType);
      final routeName = viewerType == 'profesional'
          ? PerfilProfesioanlWidget.routeName
          : PerfilJugadorWidget.routeName;
      context.pushNamed(routeName);
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

  void _openJugadorSearchMode({
    _JugadorSearchTab initialTab = _JugadorSearchTab.convocatorias,
  }) {
    if (!mounted) return;
    setState(() {
      _isJugadorSearchMode = true;
      _isJugadorFiltersExpanded = false;
      _jugadorSearchTab = initialTab;
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
      _isJugadorFiltersExpanded = false;
      _searchQuery = '';
      _jugadorSearchTab = _JugadorSearchTab.convocatorias;
      _resetJugadorSearchFilters();
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<FFAppState>();
    final userType = appState.userType;
    final canUseExplorer = appState.canAccessFeature('explorer');

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
                child: !canUseExplorer
                    ? _buildFeatureUnavailableState(
                        title: 'Explorer no disponible',
                        message:
                            'Esta funcionalidad no está habilitada para tu cuenta en este momento.',
                      )
                    : _isLoading
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
                'Intentar de nuevo',
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
              'Explorer',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Buscá jugadores y convocatorias desde un solo lugar.',
              style: GoogleFonts.inter(
                color: const Color(0xFF4A5568),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            _buildJugadorSearchEntry(),
            const SizedBox(height: 14),
            _buildQuickLinksJugador(),
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
              subtitle: 'Oportunidades activas para decidir más rápido.',
            ),
            _buildPromotedConvocatorias(promoted),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildScoutExplorer() {
    final playerPositionOptions = _realPlayerPositions;
    final playerCategoryOptions = _realPlayerCategories;
    const playerCountryOptions = LatamTaxonomy.countries;
    final playerCityOptions = _realPlayerCities;
    final playerLevelOptions = GamificationService.allLevelNames;

    const clubCountryOptions = LatamTaxonomy.countries;
    final clubCityOptions = _realClubCities;
    final clubLeagueOptions = _realClubLeagues;

    const convocatoriaCountryOptions = LatamTaxonomy.countries;
    final convocatoriaCityOptions = _realConvocatoriaCities;
    final convocatoriaCategoryOptions = _realConvocatoriaCategories;
    final convocatoriaPositionOptions = _realConvocatoriaPositions;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explorer · Scout',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D3B66),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Explorar jugadores y oportunidades',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF4A5568),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      context.pushNamed(ListaYNotasWidget.routeName),
                  icon: const Icon(Icons.bookmarks_rounded),
                  label: const Text('Mi scouting'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0D3B66),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 430;
                final filterButton = OutlinedButton.icon(
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
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchBar(
                      hint: _scoutTab == _ScoutTab.convocatorias
                          ? 'Buscar por convocatoria, club, posición, ciudad o categoría...'
                          : _scoutTab == _ScoutTab.clubes
                              ? 'Buscar por club, liga, ciudad, país o descripción...'
                              : 'Buscar por jugador, club, nivel, categoría, posición o ciudad...',
                    ),
                    const SizedBox(height: 8),
                    if (isCompact)
                      SizedBox(width: double.infinity, child: filterButton)
                    else
                      Align(
                        alignment: Alignment.centerRight,
                        child: filterButton,
                      ),
                  ],
                );
              },
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
        onSubmitted: _onSearchChanged,
        textInputAction: TextInputAction.search,
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

  Widget _compactButtonLabel(
    String label, {
    required Color color,
    FontWeight weight = FontWeight.w700,
    double fontSize = 12.5,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        softWrap: false,
        maxLines: 1,
        style: GoogleFonts.inter(
          color: color,
          fontWeight: weight,
          fontSize: fontSize,
        ),
      ),
    );
  }

  Widget _buildPlayerCardActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
    required Color borderColor,
    bool isLoading = false,
  }) {
    final isDisabled = onPressed == null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDisabled ? const Color(0xFFF8FAFC) : backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled ? const Color(0xFFE2E8F0) : borderColor,
            ),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foregroundColor,
                    ),
                  )
                : Icon(
                    icon,
                    size: 18,
                    color:
                        isDisabled ? const Color(0xFF94A3B8) : foregroundColor,
                  ),
          ),
        ),
      ),
    );
  }

  String _challengeIdFromMap(Map<String, dynamic> challenge) {
    final candidates = [
      challenge['id'],
      challenge['challenge_id'],
      challenge['item_id'],
      challenge['course_id'],
      challenge['exercise_id'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  String _challengeTypeFromMap(Map<String, dynamic> challenge) {
    final candidates = [
      challenge['type'],
      challenge['challenge_type'],
      challenge['item_type'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim().toLowerCase() ?? '';
      if (value == 'course' || value == 'curso') return 'course';
      if (value == 'exercise' || value == 'ejercicio') return 'exercise';
    }
    if ((challenge['course_id']?.toString().trim() ?? '').isNotEmpty) {
      return 'course';
    }
    if ((challenge['exercise_id']?.toString().trim() ?? '').isNotEmpty) {
      return 'exercise';
    }
    return '';
  }

  void _openExplorerChallenge(Map<String, dynamic> challenge) {
    final challengeId = _challengeIdFromMap(challenge);
    final challengeType = _challengeTypeFromMap(challenge);
    if (challengeId.isEmpty) {
      context.pushNamed(CursosEjerciciosWidget.routeName);
      return;
    }

    context.pushNamed(
      CursosEjerciciosWidget.routeName,
      queryParameters: {
        'challengeId': serializeParam(challengeId, ParamType.String),
        'challengeType': serializeParam(
          challengeType.isEmpty ? null : challengeType,
          ParamType.String,
        ),
      }.withoutNulls,
    );
  }

  Widget _buildQuickLinksJugador() {
    final links = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.campaign_rounded,
        label: 'Convocatorias',
        onTap: () => context.pushNamed(ConvocatoriaJugador1Widget.routeName),
      ),
      (
        icon: Icons.local_fire_department_rounded,
        label: 'Desafíos',
        onTap: () => context.pushNamed(CursosEjerciciosWidget.routeName),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accesos rápidos',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: links
              .map(
                (link) => _quickLinkChip(
                  icon: link.icon,
                  label: link.label,
                  onTap: link.onTap,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _quickLinkChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: const Color(0xFF0D3B66),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
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
            onPressed: () => _openExplorerChallenge(challenge),
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
        title: 'Sin resultados',
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
            onTap: () => _openExplorerChallenge(challenge),
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
    final playerCategoryOptions = _realPlayerCategories;
    final playerPositionOptions = _realPlayerPositions;
    const playerCountryOptions = LatamTaxonomy.countries;
    final playerStateOptions =
        LatamTaxonomy.statesForCountry(_jugadorPlayerCountry);
    final playerCityOptions = LatamTaxonomy.citiesForState(
        _jugadorPlayerCountry, _jugadorPlayerState);
    final playerLevelOptions = GamificationService.allLevelNames;

    final convocatoriaCategoryOptions = _realConvocatoriaCategories;
    final convocatoriaPositionOptions = _realConvocatoriaPositions;
    final convocatoriaLocationOptions = _realConvocatoriaLocations;

    const clubCountryOptions = LatamTaxonomy.countries;
    final clubStateOptions =
        LatamTaxonomy.statesForCountry(_jugadorClubCountry);
    final clubCityOptions =
        LatamTaxonomy.citiesForState(_jugadorClubCountry, _jugadorClubState);
    final clubLeagueOptions = _realClubLeagues;

    const scoutCountryOptions = LatamTaxonomy.countries;
    final scoutStateOptions =
        LatamTaxonomy.statesForCountry(_jugadorScoutCountry);
    final currentResults = _jugadorCurrentResults;
    final hasActiveCriteria = _searchQuery.trim().length >= 2 ||
        _jugadorCurrentTabHasActiveFilters ||
        _jugadorSearchTab == _JugadorSearchTab.convocatorias ||
        _jugadorSearchTab == _JugadorSearchTab.clubes ||
        _jugadorSearchTab == _JugadorSearchTab.scouts;
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
            const SizedBox(height: 14),
            _buildSearchBar(
              hint:
                  'Buscar por nombre, club, ciudad, país, posición o convocatoria',
            ),
            const SizedBox(height: 14),
            _buildJugadorSearchTabBar(),
            const SizedBox(height: 12),
            _buildJugadorSearchFilters(
              playerCategoryOptions: playerCategoryOptions,
              playerPositionOptions: playerPositionOptions,
              playerCountryOptions: playerCountryOptions,
              playerStateOptions: playerStateOptions,
              playerCityOptions: playerCityOptions,
              playerLevelOptions: playerLevelOptions,
              convocatoriaCategoryOptions: convocatoriaCategoryOptions,
              convocatoriaPositionOptions: convocatoriaPositionOptions,
              convocatoriaLocationOptions: convocatoriaLocationOptions,
              clubCountryOptions: clubCountryOptions,
              clubStateOptions: clubStateOptions,
              clubCityOptions: clubCityOptions,
              clubLeagueOptions: clubLeagueOptions,
              scoutCountryOptions: scoutCountryOptions,
              scoutStateOptions: scoutStateOptions,
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
                  title: 'Sin resultados.',
                  subtitle: 'Probá con otros términos o ajustá los filtros.',
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
          onTap: () => setState(() {
            _jugadorSearchTab = tab;
            _isJugadorFiltersExpanded = false;
          }),
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
    required List<String> playerStateOptions,
    required List<String> playerCityOptions,
    required List<String> playerLevelOptions,
    required List<String> convocatoriaCategoryOptions,
    required List<String> convocatoriaPositionOptions,
    required List<String> convocatoriaLocationOptions,
    required List<String> clubCountryOptions,
    required List<String> clubStateOptions,
    required List<String> clubCityOptions,
    required List<String> clubLeagueOptions,
    required List<String> scoutCountryOptions,
    required List<String> scoutStateOptions,
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
            onChanged: (value) => setState(() {
              _jugadorPlayerCountry = value;
              _jugadorPlayerState = null;
              _jugadorPlayerCity = null;
            }),
          ),
          _ExplorerFilterDropdown(
            label: 'Provincia/Estado',
            value: _jugadorPlayerState,
            options: playerStateOptions,
            onChanged: (value) => setState(() {
              _jugadorPlayerState = value;
              _jugadorPlayerCity = null;
            }),
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
            label: 'Ubicación',
            value: _jugadorConvocatoriaLocation,
            options: convocatoriaLocationOptions,
            onChanged: (value) =>
                setState(() => _jugadorConvocatoriaLocation = value),
          ),
        ]);
        break;
      case _JugadorSearchTab.clubes:
        filters.addAll([
          _ExplorerFilterDropdown(
            label: 'País',
            value: _jugadorClubCountry,
            options: clubCountryOptions,
            onChanged: (value) => setState(() {
              _jugadorClubCountry = value;
              _jugadorClubState = null;
              _jugadorClubCity = null;
            }),
          ),
          _ExplorerFilterDropdown(
            label: 'Provincia/Estado',
            value: _jugadorClubState,
            options: clubStateOptions,
            onChanged: (value) => setState(() {
              _jugadorClubState = value;
              _jugadorClubCity = null;
            }),
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
            onChanged: (value) => setState(() {
              _jugadorScoutCountry = value;
              _jugadorScoutState = null;
            }),
          ),
          _ExplorerFilterDropdown(
            label: 'Provincia/Estado',
            value: _jugadorScoutState,
            options: scoutStateOptions,
            onChanged: (value) => setState(() => _jugadorScoutState = value),
          ),
        ]);
        break;
    }

    final activeEntries = _jugadorCurrentFilterEntries;
    final activeCount = activeEntries.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(
            () => _isJugadorFiltersExpanded = !_isJugadorFiltersExpanded,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD6DEE8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF0D3B66),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtros',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        activeCount == 0
                            ? 'Opcionales para afinar la búsqueda'
                            : '$activeCount filtro(s) activos',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (activeCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$activeCount',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                  ),
                Icon(
                  _isJugadorFiltersExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (activeEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activeEntries
                .map(
                  (entry) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFDCE6F4)),
                    ),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF355070),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E8F5)),
              ),
              child: _buildJugadorFilterWrap(filters),
            ),
          ),
          crossFadeState: _isJugadorFiltersExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
        ),
        if (_jugadorCurrentTabHasActiveFilters) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _clearJugadorCurrentTabFilters();
                _isJugadorFiltersExpanded = false;
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
        final position = _resolvePlayerPosition(player);
        final city = _resolveCity(player);
        final country = _resolveCountryFromUser(player);
        final club = player['club']?.toString() ?? '';
        final uid = player['user_id']?.toString() ?? '';
        final hasVideo = _sortedPublicVideosForPlayer(uid).isNotEmpty;
        final category = _resolvePlayerCategory(player).isNotEmpty
            ? _resolvePlayerCategory(player)
            : 'Senior';
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
                  InkWell(
                    onTap: () => _openPublicPlayerProfile(player),
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          (player['photo_url']?.toString().isNotEmpty ?? false)
                              ? NetworkImage(player['photo_url'])
                              : null,
                      backgroundColor: const Color(0xFFE8F0FE),
                      child: (player['photo_url']?.toString().isNotEmpty ??
                              false)
                          ? null
                          : Text(
                              fullName.isNotEmpty
                                  ? fullName.substring(0, 1).toUpperCase()
                                  : 'J',
                              style: const TextStyle(color: Color(0xFF0D3B66)),
                            ),
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
                    hasVideo ? 'Tiene video' : 'Sin video',
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D3B66),
                        side: const BorderSide(color: Color(0xFFD6DEE8)),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.smart_display_rounded, size: 16),
                      label: _compactButtonLabel(
                        'Ver video',
                        color: hasVideo
                            ? const Color(0xFF0D3B66)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openPublicPlayerProfile(player),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D3B66),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(
                        Icons.person_search_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: _compactButtonLabel(
                        'Ver perfil',
                        color: Colors.white,
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
      borderRadius: BorderRadius.circular(18),
      onTap: _openJugadorSearchMode,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD6DEE8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120D3B66),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.manage_search_rounded,
                color: Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encuentra oportunidades',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jugadores y convocatorias',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
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
        ...(options.toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())))
            .map(
          (opt) => DropdownMenuItem<String>(
            value: opt,
            child: Text(opt.trim(), overflow: TextOverflow.ellipsis),
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
        title: 'Sin resultados',
        subtitle: 'No hay convocatorias activas en este momento.',
      );
    }

    return Column(
      children: convocatorias.map((conv) {
        final id = conv['id']?.toString() ?? '';
        final clubData = conv['club_data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(conv['club_data'] as Map)
            : conv['club_data'] is Map
                ? Map<String, dynamic>.from(conv['club_data'] as Map)
                : null;
        final clubName = _resolveConvocatoriaClubName(conv);
        final titulo = conv['titulo']?.toString() ?? 'Convocatoria';
        final categoria = _resolveConvocatoriaCategory(conv);
        final ubicacion = _resolveConvocatoriaLocationLabel(conv);
        final posicion = _resolveConvocatoriaPosition(conv);
        final imagenUrl = (_firstNonEmpty([
              conv['imagen_url'],
              conv['image_url'],
              conv['thumbnail_url'],
              conv['banner_url'],
              conv['cover_url'],
            ]) ??
            '');
        final clubImageUrl = _resolveExplorerClubLogo(clubData);
        final clubLeague = clubData != null ? _resolveClubLeague(clubData) : '';
        final clubCountry =
            clubData != null ? _resolveCountryFromClub(clubData) : '';
        final clubSecondary = clubLeague.isNotEmpty ? clubLeague : clubCountry;
        final mode = _resolveExplorerConvocatoriaMode(conv);
        final requiredChallengesCount = _explorerRequiredChallengesCount(conv);
        final clubRef = _clubRefFromMap({
          ...?clubData,
          'id': clubData?['id'] ?? conv['club_id'],
          'club_id': conv['club_id'],
        });
        final activeCount = _convocatorias.where((item) {
          final itemClubData = item['club_data'];
          if (itemClubData is Map) {
            return _clubRefFromMap(Map<String, dynamic>.from(itemClubData)) ==
                clubRef;
          }
          return (item['club_id']?.toString().trim() ?? '') == clubRef;
        }).length;
        final closingDate = _resolveConvocatoriaClosingDate(conv);
        String closingText = '';
        if (closingDate != null) {
          closingText =
              'Cierra el ${closingDate.day}/${closingDate.month} a las ${closingDate.hour.toString().padLeft(2, '0')}:${closingDate.minute.toString().padLeft(2, '0')}';
        }

        return GestureDetector(
          onTap: () {
            if (id.isEmpty) return;
            context.pushNamed(
              DetallesDeLaConvocatoriaWidget.routeName,
              queryParameters: {'convocatoriaId': id},
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D3B66),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Image ---
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      imagenUrl.isNotEmpty
                          ? Image.network(
                              imagenUrl,
                              width: double.infinity,
                              height: 156,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildExplorerConvocatoriaPlaceholderImage(),
                            )
                          : _buildExplorerConvocatoriaPlaceholderImage(),
                      if (mode.isNotEmpty)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _explorerConvocatoriaModeColor(mode)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              mode,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _explorerConvocatoriaModeColor(mode),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // --- Title + Closing + Tags + Club ---
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        '$titulo${ubicacion.isNotEmpty ? ' en $ubicacion' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Closing date
                      if (closingText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          closingText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                      // Tags
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (ubicacion.isNotEmpty)
                            _buildInfoTag(
                              Icons.location_on_outlined,
                              ubicacion,
                            ),
                          if (posicion.isNotEmpty)
                            _buildInfoTag(
                              Icons.sports_soccer,
                              posicion,
                            ),
                          if (categoria.isNotEmpty)
                            _buildInfoTag(
                              Icons.category_outlined,
                              categoria,
                            ),
                          if (requiredChallengesCount > 0)
                            _buildInfoTag(
                              Icons.task_alt_rounded,
                              '$requiredChallengesCount desafíos',
                            ),
                        ],
                      ),
                      // Club info (bottom)
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: clubRef.isEmpty
                            ? null
                            : () => _openPublicClubProfile(
                                  context,
                                  clubData ??
                                      {
                                        'id': conv['club_id'],
                                        'club_name': clubName,
                                      },
                                ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: clubImageUrl.isNotEmpty
                                  ? Image.network(
                                      clubImageUrl,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildExplorerClubPlaceholderIcon(
                                              size: 32),
                                    )
                                  : _buildExplorerClubPlaceholderIcon(
                                      size: 32,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clubName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (clubSecondary.isNotEmpty)
                                    Text(
                                      clubSecondary,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                activeCount > 0
                                    ? '$activeCount activas'
                                    : 'Sin activas',
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScoutTabBar() {
    Widget tab({
      required _ScoutTab tab,
      required String label,
      required IconData icon,
    }) {
      final selected = _scoutTab == tab;
      return InkWell(
        onTap: () => setState(() => _scoutTab = tab),
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0D3B66) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  selected ? const Color(0xFF0D3B66) : const Color(0xFFD6DEE8),
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1A0D3B66),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x0D0D3B66),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.16)
                      : const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: selected ? Colors.white : const Color(0xFF0D3B66),
                ),
              ),
              const SizedBox(width: 10),
              _compactButtonLabel(
                label,
                color: selected ? Colors.white : const Color(0xFF334155),
                weight: FontWeight.w700,
                fontSize: 13,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          tab(
            tab: _ScoutTab.jugadores,
            label: 'Jugadores',
            icon: Icons.sports_soccer_rounded,
          ),
          const SizedBox(width: 10),
          tab(
            tab: _ScoutTab.clubes,
            label: 'Clubes',
            icon: Icons.shield_rounded,
          ),
          const SizedBox(width: 10),
          tab(
            tab: _ScoutTab.convocatorias,
            label: 'Convocatorias',
            icon: Icons.campaign_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildScoutPlayersList() {
    final players = _scoutFilteredPlayers;

    if (players.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.search_off,
        title: 'Sin resultados',
        subtitle: 'No se encontraron jugadores con los filtros aplicados.',
      );
    }

    return Column(
      children: players.map((player) {
        final fullName =
            '${player['name'] ?? ''} ${player['lastname'] ?? ''}'.trim();
        final position = _resolvePlayerPosition(player);
        final city = player['city']?.toString() ?? 'Sin ubicación';
        final uid = player['user_id']?.toString() ?? '';
        final isSaved = _isPlayerSaved(uid);
        final isSaving = _savingPlayerId == uid;
        final hasVideo = _sortedPublicVideosForPlayer(uid).isNotEmpty;
        final category = _resolvePlayerCategory(player);
        final year = _birthYear(player['birthday']);
        final totalXp = GamificationService.toInt(player['total_xp']);
        final levelName = player['level_name']?.toString() ??
            GamificationService.levelNameFromPoints(totalXp);
        final rankingPosition = player['category_ranking'];
        final subtitle = [
          if (year != null) year.toString(),
          if (category.isNotEmpty) category,
          position,
          city,
        ].where((v) => v.toString().isNotEmpty).join(' • ');
        final badges = <Widget>[
          if (hasVideo)
            _simpleBadge(
              'Tiene video',
              color: const Color(0xFF0D3B66),
            ),
          if (position.isNotEmpty)
            _simpleBadge(
              position,
              color: const Color(0xFF7C3AED),
            ),
          if (rankingPosition != null)
            _simpleBadge(
              'Ranking #$rankingPosition',
              color: const Color(0xFF1D4ED8),
            ),
          _simpleBadge(
            '$totalXp XP',
            color: const Color(0xFF0F766E),
          ),
          _simpleBadge(
            levelName,
            color: const Color(0xFF0F766E),
          ),
          _subtleBadge(
            _isVerified(player) ? 'Verificado' : 'No verificado',
          ),
          if (!hasVideo) _subtleBadge('Sin video'),
        ];

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSaved ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _openPublicPlayerProfile(player),
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          (player['photo_url']?.toString().isNotEmpty ?? false)
                              ? NetworkImage(player['photo_url'])
                              : null,
                      backgroundColor: const Color(0xFFE8F0FE),
                      child: (player['photo_url']?.toString().isNotEmpty ??
                              false)
                          ? null
                          : Text(
                              fullName.isNotEmpty
                                  ? fullName.substring(0, 1).toUpperCase()
                                  : 'J',
                              style: const TextStyle(color: Color(0xFF0D3B66)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fullName.isNotEmpty ? fullName : 'Jugador',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildPlayerCardActionButton(
                          icon:
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                          tooltip:
                              isSaved ? 'En mi scouting' : 'Agregar a scouting',
                          onPressed: () => _toggleSavePlayerForScout(player),
                          backgroundColor:
                              isSaved ? const Color(0xFF0F9D58) : Colors.white,
                          foregroundColor:
                              isSaved ? Colors.white : const Color(0xFF0D3B66),
                          borderColor: isSaved
                              ? const Color(0xFF0F9D58)
                              : const Color(0xFFD6DEE8),
                          isLoading: isSaving,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFF718096),
                  fontSize: 11.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: badges,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPublicPlayerProfile(player),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D3B66),
                        side: const BorderSide(color: Color(0xFFDCE3EC)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size.fromHeight(36),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                      ),
                      icon: const Icon(Icons.person_outline_rounded, size: 15),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Ver perfil',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D3B66),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          hasVideo ? () => _openPlayerVideos(player) : null,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF0D3B66),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFF1F5F9),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size.fromHeight(36),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                      ),
                      icon: Icon(Icons.play_circle_outline_rounded,
                          size: 15,
                          color: hasVideo
                              ? Colors.white
                              : const Color(0xFF94A3B8)),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Ver video',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: hasVideo
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
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
        title: 'Sin resultados',
        subtitle: 'No se encontraron clubes para esta búsqueda.',
      );
    }

    return Column(
      children: clubs.map((club) {
        final name = club['nombre']?.toString() ?? 'Club';
        final league = _resolveClubLeague(club);
        final country = _resolveCountryFromClub(club);
        final city = _resolveCity(club);
        final short = club['nombre_corto']?.toString() ?? '';
        final logoUrl =
            (club['logo_url'] ?? club['escudo_url'] ?? club['shield_url'] ?? '')
                .toString()
                .trim();
        final activeCount = _convocatorias.where((conv) {
          final clubData = conv['club_data'];
          if (clubData is Map) {
            return _clubRefFromMap(Map<String, dynamic>.from(clubData)) ==
                _clubRefFromMap(club);
          }
          return (conv['club_id']?.toString().trim() ?? '') ==
              _clubRefFromMap(club);
        }).length;
        final subtitle = [
          if (short.isNotEmpty) short,
          if (league.isNotEmpty) league,
          if (city.isNotEmpty) city,
          if (country.isNotEmpty) country,
        ].join(' • ');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openPublicClubProfile(context, club),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 54,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0D3B66).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFE8F0FE),
                          backgroundImage:
                              logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                          child: logoUrl.isNotEmpty
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (league.isNotEmpty)
                          _simpleBadge(league, color: const Color(0xFF0D3B66)),
                        if (city.isNotEmpty)
                          _simpleBadge(city, color: const Color(0xFF1D4ED8)),
                        if (country.isNotEmpty)
                          _simpleBadge(country, color: const Color(0xFF0F766E)),
                        _simpleBadge(
                          activeCount > 0
                              ? '$activeCount convocatorias activas'
                              : 'Sin convocatorias activas',
                          color: activeCount > 0
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF718096),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        title: 'Sin resultados',
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE8F0FE),
                      child: Icon(
                        Icons.campaign_outlined,
                        color: Color(0xFF0D3B66),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conv['titulo']?.toString() ?? 'Convocatoria',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          if (clubName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _openPublicClubProfile(
                                context,
                                conv['club_data'] is Map<String, dynamic>
                                    ? Map<String, dynamic>.from(
                                        conv['club_data'] as Map,
                                      )
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
                          const SizedBox(height: 4),
                          Text(
                            details.isNotEmpty ? details : 'Sin detalles',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildConvocatoriaInsightChips(conv),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: id.isEmpty
                        ? null
                        : () {
                            context.pushNamed(
                              DetallesDeLaConvocatoriaProfesionalWidget
                                  .routeName,
                              queryParameters: {'convocatoriasID': id},
                            );
                          },
                    style: _explorerPrimaryButtonStyle(),
                    icon: const Icon(
                      Icons.visibility_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Ver convocatoria',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
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
    String? tempPlayerState = _scoutPlayerState;
    String? tempPlayerCity = _scoutPlayerCity;
    String? tempPlayerLevel = _scoutPlayerLevel;
    String? tempClubCountry = _scoutClubCountry;
    String? tempClubState = _scoutClubState;
    String? tempClubCity = _scoutClubCity;
    String? tempClubLeague = _scoutClubLeague;
    String? tempConvCountry = _scoutConvocatoriaCountry;
    String? tempConvState = _scoutConvocatoriaState;
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
                      onChanged: (v) => setSheetState(() {
                        tempConvCountry = v;
                        tempConvState = null;
                        tempConvCity = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Provincia/Estado',
                      value: tempConvState,
                      options: LatamTaxonomy.statesForCountry(tempConvCountry),
                      onChanged: (v) => setSheetState(() {
                        tempConvState = v;
                        tempConvCity = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Ciudad',
                      value: tempConvCity,
                      options: LatamTaxonomy.citiesForState(
                          tempConvCountry, tempConvState),
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
                      onChanged: (v) => setSheetState(() {
                        tempClubCountry = v;
                        tempClubState = null;
                        tempClubCity = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Provincia/Estado',
                      value: tempClubState,
                      options: LatamTaxonomy.statesForCountry(tempClubCountry),
                      onChanged: (v) => setSheetState(() {
                        tempClubState = v;
                        tempClubCity = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Ciudad',
                      value: tempClubCity,
                      options: LatamTaxonomy.citiesForState(
                          tempClubCountry, tempClubState),
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
                      onChanged: (v) => setSheetState(() {
                        tempPlayerCountry = v;
                        tempPlayerState = null;
                        tempPlayerCity = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Provincia/Estado',
                      value: tempPlayerState,
                      options:
                          LatamTaxonomy.statesForCountry(tempPlayerCountry),
                      onChanged: (v) => setSheetState(() {
                        tempPlayerState = v;
                        tempPlayerCity = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownFilter(
                      label: 'Ciudad',
                      value: tempPlayerCity,
                      options: LatamTaxonomy.citiesForState(
                          tempPlayerCountry, tempPlayerState),
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
                                tempConvState = null;
                                tempConvCity = null;
                                tempConvCategory = null;
                                tempConvPosition = null;
                              } else if (_scoutTab == _ScoutTab.clubes) {
                                tempClubCountry = null;
                                tempClubState = null;
                                tempClubCity = null;
                                tempClubLeague = null;
                              } else {
                                tempPosition = null;
                                tempCategory = null;
                                tempPlayerCountry = null;
                                tempPlayerState = null;
                                tempPlayerCity = null;
                                tempPlayerLevel = null;
                              }
                            });
                          },
                          child: const Text('Limpiar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (_scoutTab == _ScoutTab.convocatorias) {
                                _scoutConvocatoriaCountry = tempConvCountry;
                                _scoutConvocatoriaState = tempConvState;
                                _scoutConvocatoriaCity = tempConvCity;
                                _scoutConvocatoriaCategory = tempConvCategory;
                                _scoutConvocatoriaPosition = tempConvPosition;
                              } else if (_scoutTab == _ScoutTab.clubes) {
                                _scoutClubCountry = tempClubCountry;
                                _scoutClubState = tempClubState;
                                _scoutClubCity = tempClubCity;
                                _scoutClubLeague = tempClubLeague;
                              } else {
                                _scoutPosition = tempPosition;
                                _scoutCategory = tempCategory;
                                _scoutPlayerCountry = tempPlayerCountry;
                                _scoutPlayerState = tempPlayerState;
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
                      'Compartir listas solo está disponible para staff del club.',
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

  Widget _simpleBadge(
    String label, {
    required Color color,
    double maxWidth = 132,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _subtleBadge(String label) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 116),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: const Color(0xFFA0AEC0),
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
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
