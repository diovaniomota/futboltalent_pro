import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_club_model.dart';
export 'dashboard_club_model.dart';

class DashboardClubWidget extends StatefulWidget {
  const DashboardClubWidget({super.key});

  static String routeName = 'dashboard_club';
  static String routePath = '/dashboardClub';

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

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardClubModel());
    _searchController.addListener(_onSearchChanged);
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
      _currentPlanId != null && _currentUserVerified;

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
      _errorMessage = 'Error al cargar Inicio del Club';
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
    final value = _searchController.text.trim();
    if (value == _searchQuery) return;
    _searchQuery = value;
    _searchHome(value);
  }

  void _setHomeScope(String scope) {
    if (_homeScope == scope) return;
    setState(() {
      _homeScope = scope;
    });
    if (scope == 'jugadores' && _searchQuery.trim().length < 2) {
      if (!mounted) return;
      setState(() {
        _isSearchingPlayers = false;
        _searchPlayers = [];
        _searchClubs = [];
        _searchTryouts = [];
      });
      return;
    }
    _searchHome(_searchQuery);
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
      final response = await SupaFlow.client
          .from('users')
          .select(
              'user_id, name, lastname, username, posicion, city, club, birthday, photo_url, userType')
          .inFilter(
              'userType', ['jugador', 'jogador', 'player', 'athlete', 'atleta'])
          .or('name.ilike.%$query%,lastname.ilike.%$query%,username.ilike.%$query%,posicion.ilike.%$query%,city.ilike.%$query%')
          .limit(60);

      final players = List<Map<String, dynamic>>.from(response);
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
      final clubs = query.length < 2
          ? allClubs.take(24).toList()
          : allClubs.where((club) {
              final name = (club['nombre'] ??
                      club['name'] ??
                      club['club_name'] ??
                      'Club')
                  .toString()
                  .toLowerCase();
              final city = (club['city'] ?? club['ubicacion'] ?? '')
                  .toString()
                  .toLowerCase();
              return name.contains(query) || city.contains(query);
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
      final tryouts = query.length < 2
          ? allTryouts.take(24).toList()
          : allTryouts.where((row) {
              final title = (row['titulo'] ?? row['title'] ?? '')
                  .toString()
                  .toLowerCase();
              final desc = (row['descripcion'] ?? row['description'] ?? '')
                  .toString()
                  .toLowerCase();
              final zone = (row['ubicacion'] ?? row['location'] ?? '')
                  .toString()
                  .toLowerCase();
              return title.contains(query) ||
                  desc.contains(query) ||
                  zone.contains(query);
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
    final suggestedIds = <String>[];

    final applicants = postulaciones
        .map(_postulacionPlayerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    applicants.sort((a, b) {
      final left = _videoCountByPlayerId[a] ?? 0;
      final right = _videoCountByPlayerId[b] ?? 0;
      return right.compareTo(left);
    });

    for (final id in applicants) {
      if (!suggestedIds.contains(id)) suggestedIds.add(id);
    }

    if (suggestedIds.length < 12) {
      try {
        final fallbackUsersResponse = await SupaFlow.client
            .from('users')
            .select()
            .inFilter('userType',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta'])
            .order('created_at', ascending: false)
            .limit(40);

        for (final row in (fallbackUsersResponse as List)) {
          final id = row['user_id']?.toString() ?? '';
          if (id.isEmpty) continue;
          usersMap.putIfAbsent(id, () => Map<String, dynamic>.from(row));
          if (!suggestedIds.contains(id)) {
            suggestedIds.add(id);
          }
          if (suggestedIds.length >= 20) break;
        }
      } catch (_) {}
    }

    _suggestedPlayers = suggestedIds
        .take(12)
        .map((id) {
          return {
            'user_id': id,
            'user_data': usersMap[id],
            'video_data': _latestVideoByPlayerId[id],
          };
        })
        .where((row) => row['user_data'] != null)
        .toList();
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
        return 'Pré-selecionado';
      case 'invitar_prueba':
      case 'convidar_teste':
        return 'Convidar para teste';
      case 'en_prueba':
      case 'em_teste':
        return 'Em teste';
      case 'descartado':
        return 'Descartado';
      case 'contratado':
      case 'acompanhamento':
      case 'acompanamiento':
        return 'Contratado/Acompanhamento';
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
          content: Text('Pipeline atualizado: ${_pipelineLabel(status)}'),
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
                                  'Menu do Club',
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
                                label: 'Início',
                                icon: Icons.home_outlined,
                                selected: true,
                                onTap: () => context
                                    .pushNamed(DashboardClubWidget.routeName),
                              ),
                              _drawerItem(
                                context,
                                label: 'Convocatórias',
                                icon: Icons.campaign_outlined,
                                selected: false,
                                onTap: () => context.pushNamed(
                                    ConvocatoriasClubWidget.routeName),
                              ),
                              _drawerItem(
                                context,
                                label: 'Postulações',
                                icon: Icons.people_outline,
                                selected: false,
                                onTap: () => context
                                    .pushNamed(PostulacionesWidget.routeName),
                              ),
                              _drawerItem(
                                context,
                                label: 'Listas',
                                icon: Icons.list_alt_outlined,
                                selected: false,
                                onTap: () => context
                                    .pushNamed(ListaYNotaWidget.routeName),
                              ),
                              _drawerItem(
                                context,
                                label: 'Configuração',
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SafeArea(
                      child: ListView(
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
                                  'Início',
                                  style: GoogleFonts.inter(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 12, bottom: 14),
                            child: Text(
                              'Gestão de talento de ${_clubName ?? 'tu club'} a partir de convocatórias e pipeline.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF4A5568),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          _buildSearchBar(),
                          const SizedBox(height: 10),
                          _buildHomeScopeTabs(),
                          const SizedBox(height: 16),
                          if (_searchQuery.trim().length >= 2 ||
                              _homeScope != 'jugadores') ...[
                            _buildSectionHeader(
                              title: _homeScope == 'jugadores'
                                  ? 'Resultados de jugadores'
                                  : _homeScope == 'clubes'
                                      ? 'Resultados de clubes'
                                      : 'Resultados de tryouts',
                            ),
                            _buildSearchResultsSection(),
                          ] else ...[
                            _buildSectionHeader(
                              title: 'Necesidades activas',
                              trailing: OutlinedButton.icon(
                                onPressed: () => context.pushNamed(
                                  ConvocatoriasClubWidget.routeName,
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Mis necesidades'),
                              ),
                            ),
                            _buildActiveConvocatoriasSection(),
                            const SizedBox(height: 18),
                            _buildSectionHeader(
                                title: 'Postulaciones recientes'),
                            _buildRecentPostulacionesSection(),
                            const SizedBox(height: 18),
                            _buildSectionHeader(
                                title: 'Candidatos nuevos verificados'),
                            _buildSuggestedPlayersSection(),
                            const SizedBox(height: 18),
                            _buildSectionHeader(
                              title: 'Pipeline',
                            ),
                            _buildPipelineSection(),
                          ],
                        ],
                      ),
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
    final hintText = _homeScope == 'clubes'
        ? 'Buscar club, ciudad...'
        : _homeScope == 'tryouts'
            ? 'Buscar tryout, categoría, zona...'
            : 'Buscar jugador, club, posición, año, ciudad...';
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
      if (_searchClubs.isEmpty) {
        return _buildInlineStatus(
          icon: Icons.shield_outlined,
          title: 'Sem resultados',
          subtitle: 'No se encontraron clubes para esta búsqueda.',
        );
      }
      return Column(
        children: _searchClubs.map(_buildSearchClubCard).toList(),
      );
    }

    if (_homeScope == 'tryouts') {
      if (_searchTryouts.isEmpty) {
        return _buildInlineStatus(
          icon: Icons.campaign_outlined,
          title: 'Sem resultados',
          subtitle: 'No se encontraron tryouts para esta búsqueda.',
        );
      }
      return Column(
        children: _searchTryouts.map(_buildSearchTryoutCard).toList(),
      );
    }

    if (_searchPlayers.isEmpty) {
      return _buildInlineStatus(
        icon: Icons.search_off,
        title: 'Sem resultados',
        subtitle: 'No se encontraron jugadores para esta búsqueda.',
      );
    }

    return Column(
      children: _searchPlayers.map(_buildSearchPlayerCard).toList(),
    );
  }

  Widget _buildSearchPlayerCard(Map<String, dynamic> player) {
    final userId = player['user_id']?.toString() ?? '';
    final name = '${player['name'] ?? ''} ${player['lastname'] ?? ''}'.trim();
    final position = player['posicion']?.toString() ?? 'Sin posición';
    final city = player['city']?.toString() ?? 'Sin ubicación';
    final club = player['club']?.toString() ?? '';
    final latestVideo = player['latest_video'] as Map<String, dynamic>?;
    final hasVideo = (player['video_count'] as int? ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE8F0FE),
            backgroundImage:
                (player['photo_url']?.toString().isNotEmpty ?? false)
                    ? NetworkImage(player['photo_url'])
                    : null,
            child: (player['photo_url']?.toString().isNotEmpty ?? false)
                ? null
                : const Icon(Icons.person, color: Color(0xFF0D3B66)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Jugador',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [position, if (club.isNotEmpty) club, city].join(' • '),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
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
                    OutlinedButton(
                      onPressed:
                          hasVideo ? () => _openPlayerVideo(latestVideo) : null,
                      child: const Text('Ver vídeo'),
                    ),
                  ],
                ),
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
    final city =
        (club['city'] ?? club['ubicacion'] ?? 'Sin ubicación').toString();
    final logo =
        (club['logo_url'] ?? club['photo_url'] ?? club['avatar_url'] ?? '')
            .toString();

    return Container(
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  city,
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
    );
  }

  Widget _buildSearchTryoutCard(Map<String, dynamic> tryout) {
    final title = (tryout['titulo'] ?? tryout['title'] ?? 'Tryout').toString();
    final zone =
        (tryout['ubicacion'] ?? tryout['location'] ?? 'Sin zona').toString();
    final desc = (tryout['descripcion'] ?? tryout['description'] ?? '')
        .toString()
        .trim();
    final minAge = tryout['edad_minima'] ?? tryout['edad_min'];
    final maxAge = tryout['edad_maxima'] ?? tryout['edad_max'];
    final ageLabel = (minAge != null || maxAge != null)
        ? '${minAge ?? '-'}-${maxAge ?? '-'}'
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A202C),
                    height: 1.15,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
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
              _metaChip('Zona: $zone'),
              _metaChip('Categoria: $ageLabel'),
            ],
          ),
        ],
      ),
    );
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
                  label: 'Tryouts',
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
        subtitle: 'Crie sua primeira convocatória no módulo Convocatórias.',
      );
    }

    return Column(
      children: _activeConvocatorias.map((conv) {
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
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _metaChip('Zona: $zone'),
                  _metaChip('Categoria: $category'),
                  _metaChip('Nº postulações: $postulaciones'),
                  _metaChip('Nº jogadores salvos: $saved'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _showCandidatesSheet(conv),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D3B66),
                    ),
                    child: const Text(
                      'Ver candidatos',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () =>
                        context.pushNamed(PostulacionesWidget.routeName),
                    child: const Text('Abrir Postulações'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
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

    return SizedBox(
      height: 298,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recentPostulaciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final post = _recentPostulaciones[index];
          return SizedBox(
            width: 330,
            child: _buildPostulacionCard(post, compact: true),
          );
        },
      ),
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
              if (hasVideo) _metaChip('Tem vídeo'),
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
                    'Adicionar ao pipeline',
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
        icon: Icons.videocam_outlined,
        title: 'Sem resultados',
        subtitle: 'No hay sugerencias por zona/categoría todavía.',
      );
    }

    return SizedBox(
      height: 234,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedPlayers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final row = _suggestedPlayers[index];
          final user = row['user_data'] as Map<String, dynamic>;
          final video = row['video_data'] as Map<String, dynamic>?;
          final userId = row['user_id']?.toString() ?? '';
          final name = '${user['name'] ?? ''} ${user['lastname'] ?? ''}'.trim();
          final category = _categoryFromBirthday(user['birthday']);
          final position = user['posicion']?.toString() ?? 'Sin posición';

          return Container(
            width: 210,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 110,
                    color: const Color(0xFF102A43),
                    child: (video?['thumbnail_url']?.toString().isNotEmpty ??
                            false)
                        ? Image.network(
                            video!['thumbnail_url'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Jugador',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$category • $position',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            'Ver',
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
        subtitle: 'El pipeline aparecerá cuando existan convocatorias activas.',
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
              Text(
                conv['titulo']?.toString() ?? 'Convocatoria',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _pipelineMetric(
                      'Postulados',
                      (stats['postulated'] ?? 0).toString(),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, color: Color(0xFF718096)),
                  ),
                  Expanded(
                    child: _pipelineMetric(
                      'Salvos',
                      (stats['saved'] ?? 0).toString(),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, color: Color(0xFF718096)),
                  ),
                  Expanded(
                    child: _pipelineMetric(
                      'Interesse iniciado',
                      (stats['interest'] ?? 0).toString(),
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

  Widget _pipelineMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
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
