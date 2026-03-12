import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
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

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _convocatorias = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _recommendedChallenges = [];

  final Map<String, int> _videoCountByUserId = {};
  final Map<String, Map<String, dynamic>> _latestVideoByUserId = {};
  final Map<int, String> _countryNameById = {};

  _ScoutTab _scoutTab = _ScoutTab.jugadores;
  String? _scoutPosition;
  String? _scoutCategory;
  String? _scoutLocation;
  bool _scoutOnlyVerified = false;
  bool _scoutWithVideo = false;

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
      ]);
      await _loadNextChallenge();
      _decorateUserData();
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
      _convocatorias = List<Map<String, dynamic>>.from(response);
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

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
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
            '${u['name'] ?? ''} ${u['lastname'] ?? ''} ${u['posicion'] ?? ''} ${u['city'] ?? ''} ${u['club'] ?? ''}'
                .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    if (_scoutPosition != null) {
      filtered = filtered.where((u) =>
          (u['posicion']?.toString().trim().toLowerCase() ?? '') ==
          _scoutPosition!.toLowerCase());
    }

    if (_scoutLocation != null) {
      filtered = filtered.where((u) =>
          (u['city']?.toString().trim().toLowerCase() ?? '') ==
          _scoutLocation!.toLowerCase());
    }

    if (_scoutCategory != null) {
      filtered = filtered
          .where((u) => _categoryFromBirthday(u['birthday']) == _scoutCategory);
    }

    if (_scoutOnlyVerified) {
      filtered = filtered.where(_isVerified);
    }

    if (_scoutWithVideo) {
      filtered = filtered.where((u) =>
          (_videoCountByUserId[u['user_id']?.toString() ?? ''] ?? 0) > 0);
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _scoutFilteredClubs {
    Iterable<Map<String, dynamic>> filtered = _clubs;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((club) {
        final text =
            '${club['nombre'] ?? ''} ${club['nombre_corto'] ?? ''} ${club['pais'] ?? ''} ${club['liga'] ?? ''}'
                .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    return filtered.toList();
  }

  List<Map<String, dynamic>> get _scoutFilteredConvocatorias {
    Iterable<Map<String, dynamic>> filtered = _convocatorias;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((conv) {
        final text =
            '${conv['titulo'] ?? ''} ${conv['posicion'] ?? ''} ${conv['ubicacion'] ?? ''}'
                .toLowerCase();
        return text.contains(_searchQuery);
      });
    }

    if (_scoutPosition != null) {
      filtered = filtered.where((conv) =>
          (conv['posicion']?.toString().trim().toLowerCase() ?? '') ==
          _scoutPosition!.toLowerCase());
    }

    if (_scoutLocation != null) {
      filtered = filtered.where((conv) =>
          (conv['ubicacion']?.toString().trim().toLowerCase() ?? '') ==
          _scoutLocation!.toLowerCase());
    }

    return filtered.toList();
  }

  Future<void> _savePlayerForScout(Map<String, dynamic> player) async {
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
    if (playerId.isEmpty) return;

    try {
      final existing = await SupaFlow.client
          .from('jugadores_guardados')
          .select('id')
          .eq('scout_id', currentUserUid)
          .eq('jugador_id', playerId)
          .maybeSingle();

      if (existing != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este jugador ya está guardado')),
        );
        return;
      }

      await SupaFlow.client.from('jugadores_guardados').insert({
        'scout_id': currentUserUid,
        'jugador_id': playerId,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jugador guardado con éxito'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el jugador')),
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

    final videos = _videos
        .where((v) => (v['user_id']?.toString() ?? '') == playerId)
        .toList();

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

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;

    if (userType == 'club') {
      return const DashboardClubWidget();
    }

    return GestureDetector(
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
    final promoted = _convocatorias
        .where((conv) {
          if (_searchQuery.isEmpty) return true;
          final text =
              '${conv['titulo'] ?? ''} ${conv['posicion'] ?? ''} ${conv['ubicacion'] ?? ''}'
                  .toLowerCase();
          return text.contains(_searchQuery);
        })
        .take(6)
        .toList();
    final recommendedChallenges = _recommendedChallenges
        .where((challenge) {
          if (_searchQuery.isEmpty) return true;
          final text =
              '${challenge['title'] ?? ''} ${challenge['category'] ?? challenge['categoria'] ?? ''} ${challenge['difficulty'] ?? challenge['dificultad'] ?? ''}'
                  .toLowerCase();
          return text.contains(_searchQuery);
        })
        .take(8)
        .toList();

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
            const SizedBox(height: 14),
            _buildSearchBar(
              hint: 'Buscar desafíos, convocatorias, clubes o usuarios...',
            ),
            const SizedBox(height: 14),
            _buildQuickActionsJugador(),
            const SizedBox(height: 14),
            if (_nextChallenge != null) _buildNextChallengeCard(),
            if (_nextChallenge != null) const SizedBox(height: 14),
            _buildSectionTitle('Para vos hoy'),
            _buildRecommendedChallengesRow(recommendedChallenges),
            const SizedBox(height: 14),
            _buildSectionTitle('Convocatorias recomendadas'),
            _buildPromotedConvocatorias(promoted),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScoutExplorer() {
    final positionOptions =
        _extractUniqueStrings(_players.map((u) => u['posicion']));
    final categoryOptions = _extractUniqueStrings(
      _players.map((u) => _categoryFromBirthday(u['birthday'])),
    );
    final locationOptions =
        _extractUniqueStrings(_players.map((u) => u['city']));

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
                  icon: const Icon(Icons.bookmarks_outlined),
                  label: const Text('Minhas listas'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSearchBar(
                    hint: 'Buscar jugador, club, posición, año, ciudad...',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openScoutFilters(
                    positionOptions: positionOptions,
                    categoryOptions: categoryOptions,
                    locationOptions: locationOptions,
                  ),
                  icon: const Icon(Icons.tune),
                  label: const Text('Filtros'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildScoutTabBar(),
            const SizedBox(height: 14),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6DEE8)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Color(0xFFA0AEC0)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  icon: const Icon(Icons.clear, color: Color(0xFFA0AEC0)),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
        style: GoogleFonts.inter(fontSize: 14),
      ),
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
          icon: Icons.emoji_events_outlined,
          title: 'Desafíos',
          onTap: () => context.pushNamed(CursosEjerciciosWidget.routeName),
        ),
        _quickActionCard(
          icon: Icons.campaign_outlined,
          title: 'Convocatorias',
          onTap: () => context.pushNamed(ConvocatoriaJugador1Widget.routeName),
        ),
        _quickActionCard(
          icon: Icons.shield_outlined,
          title: 'Clubes',
          onTap: _openClubShortcuts,
        ),
        _quickActionCard(
          icon: Icons.verified_user_outlined,
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF0D3B66), size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(0xFF2D3748),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
          const Icon(Icons.flag_outlined, color: Color(0xFF0D3B66)),
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
          ElevatedButton(
            onPressed: () =>
                context.pushNamed(CursosEjerciciosWidget.routeName),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D3B66),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: const Text(
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
                      child: imageUrl.startsWith('http')
                          ? null
                          : const Icon(
                              Icons.sports_score_outlined,
                              color: Color(0xFF0D3B66),
                              size: 36,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A202C),
        ),
      ),
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
      children: convocatorias
          .map(
            (conv) => Container(
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
                subtitle: Text(
                  '${conv['posicion'] ?? 'Sin posición'} • ${conv['ubicacion'] ?? 'Sin ubicación'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            ),
          )
          .toList(),
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
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0D3B66) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0D3B66)
                    : const Color(0xFFD6DEE8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? Colors.white : const Color(0xFF4A5568)),
                const SizedBox(width: 6),
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
          icon: Icons.people_outline,
        ),
        const SizedBox(width: 8),
        tab(
          tab: _ScoutTab.clubes,
          label: 'Clubes',
          icon: Icons.shield_outlined,
        ),
        const SizedBox(width: 8),
        tab(
          tab: _ScoutTab.convocatorias,
          label: 'Convocatorias',
          icon: Icons.campaign_outlined,
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
        final hasVideo = (_videoCountByUserId[uid] ?? 0) > 0;
        final category = _categoryFromBirthday(player['birthday']);
        final year = _birthYear(player['birthday']);
        final totalXp = GamificationService.toInt(player['total_xp']);
        final levelName =
            player['level_name']?.toString() ?? GamificationService.levelNameFromPoints(totalXp);
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
                    child: OutlinedButton.icon(
                      onPressed: () => _savePlayerForScout(player),
                      icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                      label: const Text('Salvar lista'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          hasVideo ? () => _openPlayerVideos(player) : null,
                      icon: const Icon(Icons.play_circle_outline, size: 16),
                      label: const Text('Ver vídeo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (uid.isEmpty) return;
                        context.pushNamed(
                          'perfil_profesional_solicitar_Contato',
                          queryParameters: {'userId': uid},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D3B66),
                      ),
                      icon: const Icon(Icons.person_outline,
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
            subtitle: Text(
              '${conv['posicion'] ?? 'Sin posición'} • ${conv['ubicacion'] ?? 'Sin ubicación'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: ElevatedButton(
              onPressed: id.isEmpty
                  ? null
                  : () {
                      context.pushNamed(
                        DetallesDeLaConvocatoriaProfesionalWidget.routeName,
                        queryParameters: {'convocatoriasID': id},
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66),
              ),
              child: const Text('Ver', style: TextStyle(color: Colors.white)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openScoutFilters({
    required List<String> positionOptions,
    required List<String> categoryOptions,
    required List<String> locationOptions,
  }) async {
    String? tempPosition = _scoutPosition;
    String? tempCategory = _scoutCategory;
    String? tempLocation = _scoutLocation;
    bool tempOnlyVerified = _scoutOnlyVerified;
    bool tempWithVideo = _scoutWithVideo;

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
                    'Filtros Scout V1',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDropdownFilter(
                    label: 'Posición',
                    value: tempPosition,
                    options: positionOptions,
                    onChanged: (v) => setSheetState(() => tempPosition = v),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdownFilter(
                    label: 'Ano/Faixa etária',
                    value: tempCategory,
                    options: categoryOptions,
                    onChanged: (v) => setSheetState(() => tempCategory = v),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdownFilter(
                    label: 'Localización',
                    value: tempLocation,
                    options: locationOptions,
                    onChanged: (v) => setSheetState(() => tempLocation = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: tempOnlyVerified,
                    onChanged: (v) => setSheetState(() => tempOnlyVerified = v),
                    title: const Text('Apenas verificados'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: tempWithVideo,
                    onChanged: (v) => setSheetState(() => tempWithVideo = v),
                    title: const Text('Tem vídeo'),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              tempPosition = null;
                              tempCategory = null;
                              tempLocation = null;
                              tempOnlyVerified = false;
                              tempWithVideo = false;
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
                              _scoutPosition = tempPosition;
                              _scoutCategory = tempCategory;
                              _scoutLocation = tempLocation;
                              _scoutOnlyVerified = tempOnlyVerified;
                              _scoutWithVideo = tempWithVideo;
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
                  if (!_isClubStaff)
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6DEE8)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Color(0xFFA0AEC0)),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    controller.clear();
                    onClear();
                  },
                  icon: const Icon(Icons.clear, color: Color(0xFFA0AEC0)),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
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
