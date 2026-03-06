import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/gamification/gamification_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'perfil_jugador_model.dart';
export 'perfil_jugador_model.dart';

class PerfilJugadorWidget extends StatefulWidget {
  const PerfilJugadorWidget({super.key});

  static String routeName = 'perfil_jugador';
  static String routePath = '/perfilJugador';

  @override
  State<PerfilJugadorWidget> createState() => _PerfilJugadorWidgetState();
}

class _PerfilJugadorWidgetState extends State<PerfilJugadorWidget>
    with SingleTickerProviderStateMixin {
  late PerfilJugadorModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _completedChallenges = [];
  List<Map<String, dynamic>> _savedVideos = [];
  List<Map<String, dynamic>> _contactRequests = [];
  int _userRanking = 0;
  int _pendingContactRequests = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PerfilJugadorModel());
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final uid = currentUserUid;
      if (uid.isEmpty) return;

      // Carregar dados do usuário
      final userResponse = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      await GamificationService.recalculateUserProgress(userId: uid);

      Map<String, dynamic>? progressResponse;
      try {
        progressResponse = await SupaFlow.client
            .from('user_progress')
            .select('total_xp, courses_completed, exercises_completed')
            .eq('user_id', uid)
            .maybeSingle();
      } catch (_) {}

      final mergedUserData = <String, dynamic>{
        ...(userResponse ?? <String, dynamic>{}),
        ...(progressResponse ?? <String, dynamic>{}),
      };

      // Carregar vídeos do usuário (meus vídeos publicados)
      final videosResponse = await SupaFlow.client
          .from('videos')
          .select()
          .eq('user_id', uid)
          .eq('is_public', true)
          .order('created_at', ascending: false);
      final videos = List<Map<String, dynamic>>.from(videosResponse);
      final completedChallenges = await _buildCompletedChallenges(videos);

      // Carregar vídeos salvos/curtidos (guardados)
      List<Map<String, dynamic>> savedVideos = [];
      try {
        final likesResponse = await SupaFlow.client
            .from('likes')
            .select('video_id')
            .eq('user_id', uid);

        if ((likesResponse as List).isNotEmpty) {
          final videoIds = (likesResponse).map((l) => l['video_id']).toList();

          final savedVideosResponse = await SupaFlow.client
              .from('videos')
              .select()
              .inFilter('id', videoIds)
              .eq('is_public', true)
              .order('created_at', ascending: false);

          savedVideos = List<Map<String, dynamic>>.from(savedVideosResponse);
        }
      } catch (e) {
        debugPrint('Erro ao carregar vídeos salvos: $e');
      }

      // Calcular ranking do usuário (com tratamento de erro)
      int ranking = await _loadCategoryRanking(uid, mergedUserData);

      final requests = await _loadContactRequests(uid);

      if (mounted) {
        setState(() {
          _userData = mergedUserData;
          _videos = videos;
          _completedChallenges = completedChallenges;
          _savedVideos = savedVideos;
          _contactRequests = requests;
          _pendingContactRequests = requests
              .where((r) => _normalizeContactRequestStatus(r) == 'pending')
              .length;
          _userRanking = ranking;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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

  String _normalizeChallengeTitle(String rawTitle, String fallbackType) {
    final title = rawTitle.trim();
    if (title.isEmpty) {
      return fallbackType == 'course' ? 'Curso' : 'Ejercicio';
    }

    final lower = title.toLowerCase();
    if (lower.startsWith('desafío:')) {
      final normalized = title.substring('desafío:'.length).trim();
      return normalized.isEmpty ? 'Desafío' : normalized;
    }
    if (lower.startsWith('desafio:')) {
      final normalized = title.substring('desafio:'.length).trim();
      return normalized.isEmpty ? 'Desafío' : normalized;
    }
    return title;
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  Future<int> _loadCategoryRanking(
    String uid,
    Map<String, dynamic>? currentUserData,
  ) async {
    try {
      final progressRows = await SupaFlow.client
          .from('user_progress')
          .select('user_id, total_xp')
          .order('total_xp', ascending: false);
      final ordered = List<Map<String, dynamic>>.from(progressRows);
      if (ordered.isEmpty) return 1;

      final myYear = GamificationService.birthYearFromUser(currentUserData);
      if (myYear == null) {
        for (int i = 0; i < ordered.length; i++) {
          if (ordered[i]['user_id']?.toString() == uid) return i + 1;
        }
        return 1;
      }

      final ids = ordered
          .map((r) => r['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isEmpty) return 1;

      final usersRows = await SupaFlow.client
          .from('users')
          .select('user_id, birthday, birth_date')
          .inFilter('user_id', ids);
      final yearByUser = <String, int?>{};
      for (final row in (usersRows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['user_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        yearByUser[id] = GamificationService.birthYearFromUser(map);
      }

      final categoryRows = ordered.where((row) {
        final id = row['user_id']?.toString() ?? '';
        return id.isNotEmpty && yearByUser[id] == myYear;
      }).toList()
        ..sort((a, b) => GamificationService.toInt(
              b['total_xp'],
            ).compareTo(
              GamificationService.toInt(a['total_xp']),
            ));

      for (int i = 0; i < categoryRows.length; i++) {
        if (categoryRows[i]['user_id']?.toString() == uid) return i + 1;
      }
      return 1;
    } catch (e) {
      debugPrint('Erro ao calcular ranking por categoria: $e');
      return 1;
    }
  }

  Future<List<Map<String, dynamic>>> _buildCompletedChallenges(
    List<Map<String, dynamic>> videos,
  ) async {
    final completed = <Map<String, dynamic>>[];
    final courseIds = <String>{};
    final exerciseIds = <String>{};

    for (final video in videos) {
      final description = video['description']?.toString() ?? '';
      final ref = _parseChallengeRef(description);
      if (ref == null) continue;

      final type = ref['type'] ?? '';
      final itemId = ref['id'] ?? '';
      if (type.isEmpty || itemId.isEmpty) continue;

      if (type == 'course') {
        courseIds.add(itemId);
      } else {
        exerciseIds.add(itemId);
      }

      completed.add({
        'video_id': video['id']?.toString(),
        'video_url': video['video_url']?.toString() ?? '',
        'created_at': video['created_at']?.toString() ?? '',
        'item_type': type,
        'item_id': itemId,
        'title': _normalizeChallengeTitle(
          video['title']?.toString() ?? '',
          type,
        ),
        'status': 'Completado',
        'points': null,
      });
    }

    final courseMap = <String, Map<String, dynamic>>{};
    final exerciseMap = <String, Map<String, dynamic>>{};

    if (courseIds.isNotEmpty) {
      try {
        final response = await SupaFlow.client
            .from('courses')
            .select('id, title')
            .inFilter('id', courseIds.toList());
        for (final row in (response as List)) {
          final map = Map<String, dynamic>.from(row);
          final id = map['id']?.toString() ?? '';
          if (id.isNotEmpty) courseMap[id] = map;
        }
      } catch (e) {
        debugPrint('Erro ao carregar cursos dos desafios: $e');
      }
    }

    if (exerciseIds.isNotEmpty) {
      try {
        final response = await SupaFlow.client
            .from('exercises')
            .select('id, title')
            .inFilter('id', exerciseIds.toList());
        for (final row in (response as List)) {
          final map = Map<String, dynamic>.from(row);
          final id = map['id']?.toString() ?? '';
          if (id.isNotEmpty) exerciseMap[id] = map;
        }
      } catch (e) {
        debugPrint('Erro ao carregar exercícios dos desafios: $e');
      }
    }

    for (final challenge in completed) {
      final type = challenge['item_type']?.toString() ?? '';
      final itemId = challenge['item_id']?.toString() ?? '';
      if (itemId.isEmpty) continue;

      final source = type == 'course' ? courseMap[itemId] : exerciseMap[itemId];
      if (source == null) continue;

      final title = source['title']?.toString().trim() ?? '';
      if (title.isNotEmpty) {
        challenge['title'] = title;
      }

      challenge['points'] = GamificationService.challengeCompletedPoints;
    }

    return completed;
  }

  String _normalizeContactRequestStatus(Map<String, dynamic> request) {
    return request['status']?.toString().toLowerCase().trim() ?? 'pending';
  }

  String _contactRequestStatusLabel(Map<String, dynamic> request) {
    final status = _normalizeContactRequestStatus(request);
    switch (status) {
      case 'accepted':
      case 'aceptado':
      case 'aprobado':
        return 'Aprovado';
      case 'rejected':
      case 'rechazado':
      case 'recusado':
        return 'Recusado';
      default:
        return 'Pendente';
    }
  }

  Color _contactRequestStatusColor(Map<String, dynamic> request) {
    final status = _normalizeContactRequestStatus(request);
    switch (status) {
      case 'accepted':
      case 'aceptado':
      case 'aprobado':
        return const Color(0xFF15803D);
      case 'rejected':
      case 'rechazado':
      case 'recusado':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF0D3B66);
    }
  }

  Future<List<Map<String, dynamic>>> _loadContactRequests(
      String playerId) async {
    try {
      final response = await SupaFlow.client
          .from('contact_requests')
          .select()
          .eq('to_user_id', playerId)
          .order('created_at', ascending: false)
          .limit(60);

      final rows = List<Map<String, dynamic>>.from(response);
      if (rows.isEmpty) return [];

      final fromIds = rows
          .map((r) => r['from_user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final usersMap = <String, Map<String, dynamic>>{};
      if (fromIds.isNotEmpty) {
        try {
          final usersRes = await SupaFlow.client
              .from('users')
              .select('user_id, name, lastname, userType, club, photo_url')
              .inFilter('user_id', fromIds);
          for (final row in (usersRes as List)) {
            final map = Map<String, dynamic>.from(row);
            final id = map['user_id']?.toString() ?? '';
            if (id.isNotEmpty) usersMap[id] = map;
          }
        } catch (_) {}
      }

      for (final request in rows) {
        final fromId = request['from_user_id']?.toString() ?? '';
        request['from_user_data'] = usersMap[fromId];
      }

      return rows;
    } catch (_) {
      return [];
    }
  }

  String _formatRequestDate(dynamic rawDate) {
    if (rawDate == null) return '';
    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed == null) return '';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  Future<bool> _updateContactRequestStatus(
    String requestId,
    String status,
  ) async {
    if (requestId.isEmpty || currentUserUid.isEmpty) return false;
    try {
      dynamic updatedRow;
      try {
        updatedRow = await SupaFlow.client
            .from('contact_requests')
            .update({
              'status': status,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', requestId)
            .eq('to_user_id', currentUserUid)
            .select('id')
            .maybeSingle();
      } catch (_) {
        updatedRow = await SupaFlow.client
            .from('contact_requests')
            .update({
              'status': status,
            })
            .eq('id', requestId)
            .eq('to_user_id', currentUserUid)
            .select('id')
            .maybeSingle();
      }

      if (updatedRow == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível atualizar. Verifique permissões no banco.',
              ),
            ),
          );
        }
        return false;
      }

      final refreshed = await _loadContactRequests(currentUserUid);
      if (mounted) {
        setState(() {
          _contactRequests = refreshed;
          _pendingContactRequests = refreshed
              .where((r) => _normalizeContactRequestStatus(r) == 'pending')
              .length;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted'
                  ? 'Solicitação aprovada'
                  : 'Solicitação recusada',
            ),
            backgroundColor: status == 'accepted'
                ? const Color(0xFF15803D)
                : const Color(0xFFB91C1C),
          ),
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar a solicitação'),
          ),
        );
      }
      return false;
    }
  }

  Future<String?> _showRequestDetail(Map<String, dynamic> request) async {
    final requester = request['from_user_data'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final requesterName =
        '${requester['name'] ?? ''} ${requester['lastname'] ?? ''}'.trim();
    final role = requester['userType']?.toString() ?? 'profesional';
    final club = requester['club']?.toString() ?? '';
    final createdAt = _formatRequestDate(request['created_at']);
    final status = _normalizeContactRequestStatus(request);
    final reqId = request['id']?.toString() ?? '';
    final requesterId = request['from_user_id']?.toString() ?? '';

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool actionLoading = false;

        return StatefulBuilder(
          builder: (ctx, setDetailState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Solicitud de contacto',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    requesterName.isNotEmpty ? requesterName : 'Scout',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      role,
                      if (club.isNotEmpty) club,
                      if (createdAt.isNotEmpty) 'Enviada em $createdAt',
                    ].join(' • '),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          _contactRequestStatusColor(request).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _contactRequestStatusLabel(request),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _contactRequestStatusColor(request),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (status == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: actionLoading
                                ? null
                                : () async {
                                    setDetailState(() => actionLoading = true);
                                    final ok =
                                        await _updateContactRequestStatus(
                                      reqId,
                                      'rejected',
                                    );
                                    if (!ctx.mounted) return;
                                    if (ok) {
                                      Navigator.pop(ctx, 'rejected');
                                    } else {
                                      setDetailState(
                                          () => actionLoading = false);
                                    }
                                  },
                            child: actionLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Recusar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: actionLoading
                                ? null
                                : () async {
                                    setDetailState(() => actionLoading = true);
                                    final ok =
                                        await _updateContactRequestStatus(
                                      reqId,
                                      'accepted',
                                    );
                                    if (!ctx.mounted) return;
                                    if (ok) {
                                      Navigator.pop(ctx, 'accepted');
                                    } else {
                                      setDetailState(
                                          () => actionLoading = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D3B66),
                            ),
                            child: const Text(
                              'Aprovar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3B66),
                        ),
                        child: const Text(
                          'Entendido',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  if (requesterId.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: actionLoading
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                context.pushNamed(
                                  'perfil_profesional_solicitar_Contato',
                                  queryParameters: {'userId': requesterId},
                                );
                              },
                        child: const Text('Ver perfil de quem solicitou'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showContactRequestsSheet() async {
    if (currentUserUid.isEmpty) return;

    final refreshed = await _loadContactRequests(currentUserUid);
    if (mounted) {
      setState(() {
        _contactRequests = refreshed;
        _pendingContactRequests = refreshed
            .where((r) => _normalizeContactRequestStatus(r) == 'pending')
            .length;
      });
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        List<Map<String, dynamic>> localRequests =
            List<Map<String, dynamic>>.from(_contactRequests);
        bool isRefreshing = false;

        Future<void> refresh(StateSetter setSheetState) async {
          setSheetState(() => isRefreshing = true);
          final latest = await _loadContactRequests(currentUserUid);
          if (!mounted) return;
          setState(() {
            _contactRequests = latest;
            _pendingContactRequests = latest
                .where((r) => _normalizeContactRequestStatus(r) == 'pending')
                .length;
          });
          setSheetState(() {
            localRequests = latest;
            isRefreshing = false;
          });
        }

        return StatefulBuilder(
          builder: (ctx, setSheetState) => FractionallySizedBox(
            heightFactor: 0.78,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Notificações de contato',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isRefreshing
                              ? null
                              : () => refresh(setSheetState),
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: isRefreshing
                        ? const Center(child: CircularProgressIndicator())
                        : localRequests.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Você ainda não recebeu solicitações de contato.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: localRequests.length,
                                itemBuilder: (_, index) {
                                  final request = localRequests[index];
                                  final from = request['from_user_data']
                                          as Map<String, dynamic>? ??
                                      <String, dynamic>{};
                                  final fromName =
                                      '${from['name'] ?? ''} ${from['lastname'] ?? ''}'
                                          .trim();
                                  final statusLabel =
                                      _contactRequestStatusLabel(request);
                                  final statusColor =
                                      _contactRequestStatusColor(request);
                                  final dateLabel =
                                      _formatRequestDate(request['created_at']);

                                  return InkWell(
                                    onTap: () async {
                                      final updatedStatus =
                                          await _showRequestDetail(request);
                                      if (updatedStatus != null) {
                                        await refresh(setSheetState);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor:
                                                const Color(0xFFEAF2FF),
                                            backgroundImage: (from['photo_url']
                                                        ?.toString()
                                                        .isNotEmpty ??
                                                    false)
                                                ? NetworkImage(
                                                    from['photo_url']
                                                        .toString(),
                                                  )
                                                : null,
                                            child: (from['photo_url']
                                                        ?.toString()
                                                        .isNotEmpty ??
                                                    false)
                                                ? null
                                                : const Icon(
                                                    Icons.person,
                                                    color: Color(0xFF0D3B66),
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fromName.isNotEmpty
                                                      ? fromName
                                                      : 'Scout',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xFF111827),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  dateLabel.isNotEmpty
                                                      ? 'Solicitou contato em $dateLabel'
                                                      : 'Solicitou contato',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color:
                                                        const Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  statusColor.withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
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
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatBirthDate(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return 'No definido';
    try {
      if (birthDate.contains('/')) return birthDate;
      final date = DateTime.parse(birthDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return birthDate;
    }
  }

  String _getLevelName(int xp) {
    return GamificationService.levelNameFromPoints(xp);
  }

  int _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return 0;
    try {
      DateTime birth;
      if (birthDate.contains('/')) {
        final parts = birthDate.split('/');
        birth = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      } else {
        birth = DateTime.parse(birthDate);
      }
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildMedalsRow() {
    final coursesCompleted = _userData?['courses_completed'] ?? 0;
    final exercisesCompleted = _userData?['exercises_completed'] ?? 0;
    final totalXp = _userData?['total_xp'] ?? 0;
    final xpInt =
        totalXp is int ? totalXp : int.tryParse(totalXp.toString()) ?? 0;

    final medals = <Map<String, dynamic>>[
      {
        'unlocked': (coursesCompleted is int ? coursesCompleted : 0) >= 1,
        'icon': Icons.school,
        'color': const Color(0xFF4CAF50),
      },
      {
        'unlocked': (exercisesCompleted is int ? exercisesCompleted : 0) >= 5,
        'icon': Icons.fitness_center,
        'color': const Color(0xFF2196F3),
      },
      {
        'unlocked': xpInt >= 300,
        'icon': Icons.star,
        'color': const Color(0xFFFF9800),
      },
      {
        'unlocked': _videos.length >= 3,
        'icon': Icons.videocam,
        'color': const Color(0xFF9C27B0),
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: medals.map((medal) {
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: medal['unlocked']
                ? Icon(medal['icon'], color: medal['color'], size: 30)
                : const Icon(Icons.lock, color: Colors.grey, size: 30),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatColumn(String value, String label, {bool compact = false}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: compact ? 68 : 76),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontSize: compact ? 13 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic num) {
    final n = num is int ? num : int.tryParse(num.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  // ===== TAB VIDEOS =====
  Widget _buildVideosTab() {
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              color: Colors.grey[400],
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay videos',
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                try {
                  GoRouter.of(context).pushNamed('Crear_Publicacin_de_Video');
                } catch (e) {
                  context.pushNamed('Crear_Publicacin_de_Video');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D3B66),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Subir video',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_completedChallenges.isNotEmpty) ...[
            Text(
              'Desafíos completados',
              style: GoogleFonts.inter(
                color: const Color(0xFF0D3B66),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_completedChallenges.length} desafío(s) finalizado(s)',
              style: GoogleFonts.inter(
                color: const Color(0xFF6B7280),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            ..._completedChallenges.map(_buildCompletedChallengeCard),
            const SizedBox(height: 14),
            Text(
              'Todos os videos',
              style: GoogleFonts.inter(
                color: const Color(0xFF444444),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: _videos.asMap().entries.map((entry) {
              return _VideoCard(
                videoUrl: entry.value['video_url'] ?? '',
                onTap: () => _openVideoFeed(entry.key, _videos),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedChallengeCard(Map<String, dynamic> challenge) {
    final title = challenge['title']?.toString() ?? 'Desafío';
    final status = challenge['status']?.toString() ?? 'Completado';
    final points = _readInt(challenge['points']);
    final createdAt = challenge['created_at']?.toString() ?? '';
    final videoId = challenge['video_id']?.toString() ?? '';
    final fallbackUrl = challenge['video_url']?.toString() ?? '';

    var selectedIndex = -1;
    if (videoId.isNotEmpty) {
      selectedIndex =
          _videos.indexWhere((v) => v['id']?.toString() == videoId.toString());
    }
    if (selectedIndex < 0 && fallbackUrl.isNotEmpty) {
      selectedIndex =
          _videos.indexWhere((v) => v['video_url']?.toString() == fallbackUrl);
    }

    final submittedLabel = () {
      final parsed = DateTime.tryParse(createdAt);
      if (parsed == null) return 'Video enviado';
      return 'Enviado el ${DateFormat('dd/MM/yyyy').format(parsed)}';
    }();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF111827),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 14,
                      color: Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      submittedLabel,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1E3A8A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF166534),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (points != null && points > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+$points pts',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: selectedIndex >= 0
                  ? () => _openVideoFeed(selectedIndex, _videos)
                  : null,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: Text(
                'Ver video enviado',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D3B66),
                side: const BorderSide(color: Color(0xFF0D3B66)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== TAB FICHA COMPLETA =====
  Widget _buildFichaTab() {
    final birthDate =
        _userData?['birth_date'] ?? _userData?['fecha_nacimiento'] ?? '';
    final nationality = _userData?['nationality'] ??
        _userData?['nacionalidad'] ??
        'No definido';
    final height = _userData?['height'] ?? _userData?['altura'] ?? '';
    final weight = _userData?['weight'] ?? _userData?['peso'] ?? '';
    final age = _calculateAge(birthDate.toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información Personal',
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoRow(
            Icons.calendar_month,
            birthDate.toString().isNotEmpty
                ? '${_formatBirthDate(birthDate.toString())} | $age años'
                : 'No definido',
          ),
          _buildInfoRow(Icons.flag, nationality.toString()),
          _buildInfoRow(
            Icons.height,
            height.toString().isNotEmpty ? '$height cm' : 'No definido',
          ),
          _buildInfoRow(
            Icons.fitness_center,
            weight.toString().isNotEmpty ? '$weight kg' : 'No definido',
          ),
          const SizedBox(height: 20),
          Text(
            'Historial Deportivo',
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildHistorySection(),
          const SizedBox(height: 20),
          Text(
            'Estadísticas de Entrenamiento',
            style: GoogleFonts.inter(
              color: const Color(0xFF444444),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildStatCard(
                'Cursos',
                (_userData?['courses_completed'] ?? 0).toString(),
                Icons.school,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                'Ejercicios',
                (_userData?['exercises_completed'] ?? 0).toString(),
                Icons.fitness_center,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                'Videos',
                _videos.length.toString(),
                Icons.videocam,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF444444)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: const Color(0xFF444444)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final clubs = _userData?['clubs'] ?? _userData?['historial_clubes'];

    if (clubs != null && clubs is List && clubs.isNotEmpty) {
      return Column(
        children: clubs.map<Widget>((club) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    club['name'] ?? club['nombre'] ?? 'Club',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  club['period'] ?? club['periodo'] ?? '',
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Text(
      'Agrega tu historial en Editar Perfil',
      style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF0D3B66), size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFF0D3B66),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
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

  // ===== TAB GUARDADOS =====
  Widget _buildGuardadosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '+ Crear una nova coleção',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF444444),
                    fontSize: 14,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF444444),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_savedVideos.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.bookmark_border,
                    color: Colors.grey[400],
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Não há vídeos guardados',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Os vídeos que você gostar aparecerão aqui',
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: _savedVideos.asMap().entries.map((entry) {
                return _VideoCard(
                  videoUrl: entry.value['video_url'] ?? '',
                  onTap: () => _openVideoFeed(entry.key, _savedVideos),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _openVideoFeed(int selectedIndex, List<Map<String, dynamic>> videoList) {
    if (videoList.isEmpty) return;

    final selectedVideo = videoList[selectedIndex];
    final otherVideos = <Map<String, dynamic>>[];

    for (int i = selectedIndex + 1; i < videoList.length; i++) {
      otherVideos.add(videoList[i]);
    }
    for (int i = 0; i < selectedIndex; i++) {
      otherVideos.add(videoList[i]);
    }

    final reorderedVideos = [selectedVideo, ...otherVideos];

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _VideoFeedScreen(videos: reorderedVideos, userId: currentUserUid),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
        ),
      );
    }

    final name = _userData?['name'] ?? 'Usuario';
    final username = _userData?['username'] ?? 'username';
    final photoUrl = _userData?['photo_url'] ?? _userData?['avatar_url'] ?? '';
    final coverUrl =
        _userData?['cover_url'] ?? _userData?['cover_photo_url'] ?? '';
    final totalXp = _userData?['total_xp'] ?? 0;
    final xpInt =
        totalXp is int ? totalXp : int.tryParse(totalXp.toString()) ?? 0;
    final level = _getLevelName(xpInt);
    final position =
        _userData?['position'] ?? _userData?['posicion'] ?? 'Jugador';
    final dominantFoot = _userData?['dominant_foot'] ??
        _userData?['pie_dominante'] ??
        'No definido';
    final location = _userData?['location'] ??
        _userData?['ubicacion'] ??
        _userData?['club'] ??
        '';
    final followers =
        _userData?['followers_count'] ?? _userData?['seguidores'] ?? 0;
    final screenSize = MediaQuery.sizeOf(context);
    final isCompactProfile = screenSize.width < 390;
    final tabViewHeight =
        (screenSize.height * 0.52).clamp(380.0, 560.0).toDouble();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // ===== HEADER COM FOTO DE CAPA =====
                    SizedBox(
                      height: 250,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Foto de capa
                          Container(
                            width: double.infinity,
                            height: 192,
                            decoration: BoxDecoration(color: Colors.grey[300]),
                            child: coverUrl.isNotEmpty
                                ? Image.network(
                                    coverUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/images/517529573247018df7fa574b80864b1d3ab2e6ae.jpg',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(color: Colors.grey[400]),
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/517529573247018df7fa574b80864b1d3ab2e6ae.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(color: Colors.grey[400]),
                                  ),
                          ),

                          // Ícones do topo
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 10,
                            left: 15,
                            right: 15,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Configurações
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    debugPrint('🔵 Configurações clicado!');
                                    context.pushNamed('configuraciones');
                                  },
                                  child: Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9D9D9),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(Icons.settings, size: 24),
                                  ),
                                ),
                                Row(
                                  children: [
                                    // Notificações
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        _showContactRequestsSheet();
                                      },
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 35,
                                            height: 35,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD9D9D9),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                18,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.notifications_rounded,
                                              size: 24,
                                            ),
                                          ),
                                          if (_pendingContactRequests > 0)
                                            Positioned(
                                              right: -3,
                                              top: -3,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFDC2626),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Text(
                                                  _pendingContactRequests > 9
                                                      ? '9+'
                                                      : _pendingContactRequests
                                                          .toString(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Mensagens
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        print(
                                          '🔵 Logout button pressed (Perfil Jugador)',
                                        );
                                        try {
                                          await authManager.signOut();
                                          print('SignOut completed');
                                          if (context.mounted) {
                                            print('Navigating to login');
                                            context.goNamed('login');
                                          }
                                        } catch (e) {
                                          print('Error during logout: $e');
                                        }
                                      },
                                      child: Container(
                                        width: 35,
                                        height: 35,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD9D9D9),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.logout,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Foto de perfil
                          Positioned(
                            top: 140,
                            left: 20,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9D9D9),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: photoUrl.isNotEmpty
                                    ? Image.network(
                                        photoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Image.asset(
                                          'assets/images/codicon_account.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/images/codicon_account.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          // Botão Editar Perfil
                          Positioned(
                            top: 200,
                            right: 15,
                            child: Material(
                              color: const Color(0xFF0D3B66),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  context.pushNamed('editar_perfil');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Editar perfil',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ===== NOME E INFO =====
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF444444),
                              fontSize: isCompactProfile ? 22 : 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Username e Stats
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrowStats = constraints.maxWidth < 390;
                              final userInfo = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@$username',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF444444),
                                      fontSize: isCompactProfile ? 13 : 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatNumber(followers)} seguidores',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF444444),
                                      fontSize: isCompactProfile ? 13 : 14,
                                    ),
                                  ),
                                ],
                              );

                              final stats = Wrap(
                                spacing: isNarrowStats ? 10 : 14,
                                runSpacing: 8,
                                alignment: isNarrowStats
                                    ? WrapAlignment.start
                                    : WrapAlignment.end,
                                children: [
                                  _buildStatColumn(
                                    level,
                                    'Nivel',
                                    compact: isCompactProfile,
                                  ),
                                  _buildStatColumn(
                                    '#${_userRanking > 0 ? _userRanking : '-'}',
                                    'Ranking',
                                    compact: isCompactProfile,
                                  ),
                                  _buildStatColumn(
                                    xpInt.toString(),
                                    'Puntos',
                                    compact: isCompactProfile,
                                  ),
                                ],
                              );

                              if (isNarrowStats) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    userInfo,
                                    const SizedBox(height: 12),
                                    stats,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: userInfo),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: stats,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 25),

                          // Posición
                          Row(
                            children: [
                              const Icon(
                                Icons.shield,
                                color: Color(0xFF444444),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  position,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF444444),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Pie
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_walk,
                                color: Color(0xFF444444),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dominantFoot,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF444444),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Ubicación
                          if (location.toString().isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_pin,
                                  color: Color(0xFF444444),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF444444),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 25),

                          // ===== MEDALLAS Y LOGROS =====
                          Text(
                            'Medallas y Logros',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF444444),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),

                          _buildMedalsRow(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== TAB BAR =====
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: const Color(0xFF0D3B66),
                        unselectedLabelColor: Colors.grey,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        unselectedLabelStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                        indicatorColor: const Color(0xFF0D3B66),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        tabs: const [
                          Tab(text: 'Videos'),
                          Tab(text: 'Ficha completa'),
                          Tab(text: 'Guardados'),
                        ],
                      ),
                    ),

                    // ===== TAB BAR VIEW =====
                    SizedBox(
                      height: tabViewHeight,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildVideosTab(),
                          _buildFichaTab(),
                          _buildGuardadosTab(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
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
}

class _VideoCard extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onTap;

  const _VideoCard({required this.videoUrl, required this.onTap});

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.videoUrl.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller!.initialize();
      _controller!.setVolume(0);
      _controller!.setLooping(true);
      // Removido play() automático para evitar exaustão de MediaCodec em grids com muitos vídeos

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 107,
        height: 143,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _hasError
              ? Container(
                  color: Colors.grey[400],
                  child: const Icon(
                    Icons.videocam_off,
                    color: Colors.white70,
                    size: 30,
                  ),
                )
              : !_isInitialized || _controller == null
                  ? Container(
                      color: Colors.grey[400],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    )
                  : SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _VideoFeedScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final String userId;

  const _VideoFeedScreen({required this.videos, required this.userId});

  @override
  State<_VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<_VideoFeedScreen> {
  late PageController _pageController;
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
            itemCount: widget.videos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return _VideoPlayerItem(
                key: ValueKey(widget.videos[index]['id']),
                videoData: widget.videos[index],
                isCurrentVideo: index == _currentIndex,
                userId: widget.userId,
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
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
}

class _VideoPlayerItem extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final bool isCurrentVideo;
  final String userId;

  const _VideoPlayerItem({
    super.key,
    required this.videoData,
    required this.isCurrentVideo,
    required this.userId,
  });

  @override
  State<_VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<_VideoPlayerItem>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPaused = false;
  bool _isMuted = false;
  bool _showLikeAnimation = false;
  bool _isLiked = false;
  int _likesCount = 0;

  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  late AnimationController _likeAnimController;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _likesCount = widget.videoData['likes_count'] ?? 0;
    _initVideo();
    _checkIfLiked();
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && _isInitialized) {
      if (widget.isCurrentVideo && !_isPaused) {
        _controller?.play();
      } else if (!widget.isCurrentVideo) {
        _controller?.pause();
      }
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      final response = await SupaFlow.client
          .from('likes')
          .select('id')
          .eq('video_id', widget.videoData['id'])
          .eq('user_id', widget.userId)
          .maybeSingle();
      if (mounted) setState(() => _isLiked = response != null);
    } catch (e) {
      debugPrint('Error checking if liked: $e');
    }
  }

  Future<void> _toggleLike() async {
    final prev = _isLiked;
    final prevCount = _likesCount;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount =
          _isLiked ? _likesCount + 1 : (_likesCount > 0 ? _likesCount - 1 : 0);
    });

    try {
      if (_isLiked) {
        await SupaFlow.client.from('likes').insert({
          'user_id': widget.userId,
          'video_id': widget.videoData['id'],
        });
      } else {
        await SupaFlow.client
            .from('likes')
            .delete()
            .eq('user_id', widget.userId)
            .eq('video_id', widget.videoData['id']);
      }
      await SupaFlow.client.from('videos').update(
          {'likes_count': _likesCount}).eq('id', widget.videoData['id']);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = prev;
          _likesCount = prevCount;
        });
      }
    }
  }

  Future<void> _initVideo() async {
    final url = widget.videoData['video_url'] ?? '';
    if (url.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(_isMuted ? 0 : 1);

      if (mounted) {
        setState(() => _isInitialized = true);
        if (widget.isCurrentVideo) _controller!.play();
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onTap(TapUpDetails details) {
    if (_controller == null || !_isInitialized) return;
    final now = DateTime.now();
    final pos = details.globalPosition;

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300 &&
        _lastTapPosition != null &&
        (pos - _lastTapPosition!).distance < 50) {
      _showLikeAnim();
      if (!_isLiked) _toggleLike();
      _lastTapTime = null;
    } else {
      _lastTapTime = now;
      _lastTapPosition = pos;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_lastTapTime == now) _togglePlayPause();
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPaused = true;
      } else {
        _controller!.play();
        _isPaused = false;
      }
    });
  }

  void _showLikeAnim() {
    setState(() => _showLikeAnimation = true);
    _likeAnimController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showLikeAnimation = false);
    });
  }

  String _formatCount(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return c.toString();
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.videoData['title'] ?? '';

    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text('Error al cargar', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTapUp: _onTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 250,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 80,
              bottom: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 120,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Column(
                      children: [
                        Icon(
                          _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          color:
                              _isLiked ? const Color(0xFF0D3B66) : Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCount(_likesCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Column(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '0',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Column(
                    children: [
                      Icon(Icons.share, color: Colors.white, size: 32),
                      SizedBox(height: 4),
                      Text(
                        'Share',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isPaused)
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
            if (_showLikeAnimation)
              Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0, end: 1.5).animate(
                    CurvedAnimation(
                      parent: _likeAnimController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1, end: 0).animate(
                      CurvedAnimation(
                        parent: _likeAnimController,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: const Icon(
                      Icons.thumb_up,
                      color: Color(0xFF0D3B66),
                      size: 100,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
