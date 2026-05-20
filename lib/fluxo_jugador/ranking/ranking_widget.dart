import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/gamification/gamification_service.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'ranking_model.dart';
export 'ranking_model.dart';

class RankingWidget extends StatefulWidget {
  const RankingWidget({super.key});

  static String routeName = 'ranking';
  static String routePath = '/ranking';

  @override
  State<RankingWidget> createState() => _RankingWidgetState();
}

class _RankingWidgetState extends State<RankingWidget> {
  late RankingModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allRankingRows = [];
  List<Map<String, dynamic>> _rankingData = [];
  Map<String, dynamic>? _currentUserProgress;
  String _currentUserLevelName = 'Aficionado';
  String _scope = 'categoria';
  String _sortBy = 'puntos';
  String? _scopeValue;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RankingModel());
    _loadRankingData();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String get _scopeLabel {
    switch (_scope) {
      case 'pais':
        return 'País';
      case 'posicion':
        return 'Posición';
      case 'categoria':
      default:
        return 'Categoría';
    }
  }

  String _normalizeUserType(dynamic value) {
    return FFAppState.normalizeUserType(value?.toString() ?? '');
  }

  Future<void> _loadRankingData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      if (currentUserUid.isNotEmpty) {
        await GamificationService.recalculateUserProgress(
            userId: currentUserUid);
      }

      final progressResponse = await SupaFlow.client
          .from('user_progress')
          .select()
          .order('total_xp', ascending: false);

      final progressRows = List<Map<String, dynamic>>.from(progressResponse);
      final userIds = progressRows
          .map((row) => row['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final usersById = <String, Map<String, dynamic>>{};
      if (userIds.isNotEmpty) {
        try {
          final userResponse = await SupaFlow.client
              .from('users')
              .select(
                  'user_id, name, lastname, username, posicion, position, country, pais, country_name, photo_url, birthday, birth_date, categoria, category, userType, usertype')
              .inFilter('user_id', userIds);
          for (final row in (userResponse as List)) {
            final map = Map<String, dynamic>.from(row as Map);
            final uid = map['user_id']?.toString() ?? '';
            if (uid.isNotEmpty) {
              usersById[uid] = map;
            }
          }
        } catch (e) {
          debugPrint('Error loading ranking users: $e');
        }
      }

      final rankingRows = <Map<String, dynamic>>[];
      for (final row in progressRows) {
        final uid = row['user_id']?.toString() ?? '';
        if (uid.isEmpty) continue;
        final user = usersById[uid];
        final userType =
            _normalizeUserType(user?['userType'] ?? user?['usertype']);
        if (userType.isNotEmpty && userType != 'jugador') {
          continue;
        }
        rankingRows.add({
          ...row,
          'users': user,
        });
      }

      _allRankingRows = rankingRows;
      _currentUserProgress =
          rankingRows.cast<Map<String, dynamic>?>().firstWhere(
                (row) => row?['user_id']?.toString() == currentUserUid,
                orElse: () => null,
              );

      _currentUserProgress ??= {
        'user_id': currentUserUid,
        'total_xp': 0,
        'courses_completed': 0,
        'exercises_completed': 0,
        'users': usersById[currentUserUid],
      };

      final currentPoints =
          GamificationService.toInt(_currentUserProgress?['total_xp']);
      _currentUserLevelName =
          GamificationService.levelNameFromPoints(currentPoints);

      _scopeValue = GamificationService.rankingScopeValue(
        _currentUserProgress?['users'] is Map
            ? Map<String, dynamic>.from(
                _currentUserProgress!['users'] as Map,
              )
            : null,
        _scope,
      );

      _applyRankingFilters();
    } catch (e) {
      debugPrint('Error loading ranking: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Error al cargar el ranking.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyRankingFilters() {
    final filtered = _allRankingRows.where((row) {
      if (_scopeValue == null || _scopeValue!.trim().isEmpty) {
        return true;
      }
      final user = row['users'] is Map<String, dynamic>
          ? row['users'] as Map<String, dynamic>
          : (row['users'] is Map
              ? Map<String, dynamic>.from(row['users'] as Map)
              : null);
      final value = GamificationService.rankingScopeValue(user, _scope) ?? '';
      return value.trim().toLowerCase() == _scopeValue!.trim().toLowerCase();
    }).toList();

    filtered.sort((a, b) {
      if (_sortBy == 'desafios') {
        final completedB = GamificationService.completedChallengesCount(b);
        final completedA = GamificationService.completedChallengesCount(a);
        final byCompleted = completedB.compareTo(completedA);
        if (byCompleted != 0) return byCompleted;
      }

      final xpCompare = GamificationService.toInt(b['total_xp']).compareTo(
        GamificationService.toInt(a['total_xp']),
      );
      if (xpCompare != 0) return xpCompare;

      return GamificationService.completedChallengesCount(b).compareTo(
        GamificationService.completedChallengesCount(a),
      );
    });

    _rankingData = filtered;
  }

  void _changeSortOrder(String newSort) {
    if (!mounted) return;
    setState(() {
      _sortBy = newSort;
      _applyRankingFilters();
    });
  }

  void _changeScope(String newScope) {
    if (!mounted) return;
    final currentUser = _currentUserProgress?['users'] is Map
        ? Map<String, dynamic>.from(_currentUserProgress!['users'] as Map)
        : null;
    setState(() {
      _scope = newScope;
      _scopeValue =
          GamificationService.rankingScopeValue(currentUser, newScope);
      _applyRankingFilters();
    });
  }

  String _scopeSubtitle() {
    if (_scopeValue == null || _scopeValue!.trim().isEmpty) {
      return 'Ranking general';
    }
    return '$_scopeLabel ${_scopeValue!.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF7F9FC),
        body: Stack(
          children: [
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : _buildContent(),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: GoogleFonts.inter(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRankingData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D3B66),
            ),
            child: const Text(
              'Reintentar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final currentPoints = GamificationService.toInt(
      _currentUserProgress?['total_xp'],
    );
    final userRankPos = _rankingData.indexWhere(
      (r) => r['user_id'] == currentUserUid,
    );
    final userChallenges = _currentUserProgress != null
        ? GamificationService.completedChallengesCount(_currentUserProgress!)
        : 0;

    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D3B66),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Ranking',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _scopeSubtitle(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildUserBar(currentPoints, userRankPos, userChallenges),
                ],
              ),
            ),
          ),
        ),
        _buildScopeTabs(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Row(
            children: [
              Expanded(
                child: _miniSortChip(
                  'Ordenar por XP',
                  _sortBy == 'puntos',
                  () => _changeSortOrder('puntos'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniSortChip(
                  'Ordenar por Desafíos',
                  _sortBy == 'desafios',
                  () => _changeSortOrder('desafios'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _rankingData.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFF0D3B66),
                  onRefresh: _loadRankingData,
                  child: CustomScrollView(
                    slivers: [
                      if (_rankingData.length >= 3)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                            child: _buildPodium(),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final startIndex =
                                  _rankingData.length >= 3 ? 3 : 0;
                              final dataIndex = startIndex + i;
                              if (dataIndex >= _rankingData.length) {
                                return null;
                              }
                              final item = _rankingData[dataIndex];
                              final pos = dataIndex + 1;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildListItem(
                                  item,
                                  pos,
                                  item['user_id'] == currentUserUid,
                                ),
                              );
                            },
                            childCount: _rankingData.length >= 3
                                ? _rankingData.length - 3
                                : _rankingData.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildScopeTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE3EC)),
        ),
        child: Row(
          children: [
            _scopeTab('Categoría', 'categoria'),
            _scopeTab('País', 'pais'),
            _scopeTab('Posición', 'posicion'),
          ],
        ),
      ),
    );
  }

  Widget _scopeTab(String label, String value) {
    final selected = _scope == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeScope(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0D3B66) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: selected ? Colors.white : const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniSortChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 36,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF2FB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF0D3B66) : const Color(0xFFDCE3EC),
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color:
                  selected ? const Color(0xFF0D3B66) : const Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodium() {
    if (_rankingData.length < 3) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(child: _podiumPlayer(_rankingData[1], 2)),
        const SizedBox(width: 8),
        Expanded(child: _podiumPlayer(_rankingData[0], 1)),
        const SizedBox(width: 8),
        Expanded(child: _podiumPlayer(_rankingData[2], 3)),
      ],
    );
  }

  Widget _podiumPlayer(Map<String, dynamic> item, int position) {
    final user = item['users'] is Map
        ? Map<String, dynamic>.from(item['users'] as Map)
        : <String, dynamic>{};
    final userName = GamificationService.resolveDisplayName(user);
    final totalXp = GamificationService.toInt(item['total_xp']);
    final photoUrl = user['photo_url']?.toString() ?? '';
    final isMe = item['user_id'] == currentUserUid;

    final badgeColor = position == 1
        ? const Color(0xFFF59E0B)
        : position == 2
            ? const Color(0xFF94A3B8)
            : const Color(0xFFB45309);

    return GestureDetector(
      onTap: () {
        final uid = item['user_id']?.toString() ?? '';
        if (uid.isEmpty) return;
        context.pushNamed(
          'perfil_profesional_solicitar_Contato',
          queryParameters: {'userId': uid},
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe ? const Color(0xFF3B82F6) : const Color(0xFFDCE3EC),
            width: isMe ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$position',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            CircleAvatar(
              radius: position == 1 ? 26 : 21,
              backgroundColor: const Color(0xFFE8F0FE),
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(
                      userName.isNotEmpty
                          ? userName.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF0D3B66),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 7),
            Text(
              userName.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF1F2937),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$totalXp XP',
              style: GoogleFonts.inter(
                color: const Color(0xFF0D3B66),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isMe) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'TÚ',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(
    Map<String, dynamic> item,
    int position,
    bool isCurrentUser,
  ) {
    final user = item['users'] is Map
        ? Map<String, dynamic>.from(item['users'] as Map)
        : <String, dynamic>{};
    final userName = GamificationService.resolveDisplayName(user);
    final userPosition =
        GamificationService.resolveUserPosition(user) ?? 'Sin posición';
    final userCountry =
        GamificationService.resolveUserCountry(user) ?? 'Sin país';
    final totalXp = GamificationService.toInt(item['total_xp']);
    final levelName = GamificationService.levelNameFromPoints(totalXp);
    final photoUrl = user['photo_url']?.toString() ?? '';
    final challenges = GamificationService.completedChallengesCount(item);

    return GestureDetector(
      onTap: () {
        final uid = item['user_id']?.toString() ?? '';
        if (uid.isEmpty) return;
        context.pushNamed(
          'perfil_profesional_solicitar_Contato',
          queryParameters: {'userId': uid},
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: isCurrentUser ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentUser
                ? const Color(0xFF93C5FD)
                : const Color(0xFFDCE3EC),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 58,
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF0D3B66).withOpacity(0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0D3B66).withOpacity(0.09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$position',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D3B66),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE8F0FE),
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(
                      userName.isNotEmpty
                          ? userName.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF0D3B66),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          userName,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF111827),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TÚ',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$userPosition · $userCountry',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _cardTag(levelName, const Color(0xFF0F766E)),
                      _cardTag(
                        '$challenges desafíos',
                        const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$totalXp XP',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0D3B66),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D3B66).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF0D3B66),
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildUserBar(
    int currentPoints,
    int userRankPos,
    int userChallenges,
  ) {
    final rankDisplay = userRankPos >= 0 ? '#${userRankPos + 1}' : '-';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tu posición $rankDisplay · $currentPoints XP · $userChallenges desafíos',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentUserLevelName,
              style: GoogleFonts.inter(
                color: const Color(0xFF0D3B66),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.leaderboard_outlined,
            color: Color(0xFF94A3B8),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay jugadores en este ranking',
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Completa desafíos y sube videos para subir en el Top.',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadRankingData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D3B66),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Actualizar',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
