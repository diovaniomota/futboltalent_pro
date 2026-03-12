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
        await GamificationService.recalculateUserProgress(userId: currentUserUid);
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
      _currentUserProgress = rankingRows.cast<Map<String, dynamic>?>().firstWhere(
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
      _scopeValue = GamificationService.rankingScopeValue(currentUser, newScope);
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
        backgroundColor: Colors.white,
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Ranking',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D3B66),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildSummaryBadge(Icons.bolt, '$currentPoints XP'),
                  _buildSummaryBadge(Icons.workspace_premium, _currentUserLevelName),
                  _buildSummaryBadge(Icons.filter_alt_outlined, _scopeSubtitle()),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceButton(
                      text: 'Categoría',
                      selected: _scope == 'categoria',
                      onTap: () => _changeScope('categoria'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceButton(
                      text: 'País',
                      selected: _scope == 'pais',
                      onTap: () => _changeScope('pais'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceButton(
                      text: 'Posición',
                      selected: _scope == 'posicion',
                      onTap: () => _changeScope('posicion'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceButton(
                      text: 'XP',
                      selected: _sortBy == 'puntos',
                      onTap: () => _changeSortOrder('puntos'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceButton(
                      text: 'Desafíos',
                      selected: _sortBy == 'desafios',
                      onTap: () => _changeSortOrder('desafios'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _rankingData.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRankingData,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _rankingData.length,
                    itemBuilder: (context, index) {
                      final item = _rankingData[index];
                      final position = index + 1;
                      final isCurrentUser = item['user_id'] == currentUserUid;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildRankingItem(item, position, isCurrentUser),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSummaryBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E0EA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF0D3B66), size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D3B66) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF0D3B66) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: selected ? Colors.white : const Color(0xFF334155),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
            color: Color(0xFFA0AEC0),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay jugadores para este ranking',
            style: GoogleFonts.inter(
              color: const Color(0xFF718096),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completa desafíos y sube videos para subir en el Top.',
            style: GoogleFonts.inter(
              color: const Color(0xFFA0AEC0),
              fontSize: 14,
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
            child: const Text(
              'Actualizar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingItem(
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
    final totalChallenges = GamificationService.completedChallengesCount(item);
    final levelName = GamificationService.levelNameFromPoints(totalXp);
    final photoUrl = user['photo_url']?.toString() ?? '';

    Color badgeColor = const Color(0xFFD69E2E);
    if (position == 1) {
      badgeColor = const Color(0xFFFFD700);
    } else if (position == 2) {
      badgeColor = const Color(0xFFC0C0C0);
    } else if (position == 3) {
      badgeColor = const Color(0xFFCD7F32);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFFE8F4FD) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color:
              isCurrentUser ? const Color(0xFF0D3B66) : const Color(0xFFDBE4EE),
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: position <= 3 ? badgeColor : const Color(0xFF0D3B66),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$position',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8F0FE),
            backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isNotEmpty
                ? null
                : Text(
                    userName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Color(0xFF0D3B66)),
                  ),
          ),
          const SizedBox(width: 12),
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
                          color: Colors.black,
                          fontSize: 14,
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
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D3B66),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TÚ',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$userPosition • $userCountry',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildMiniPill('$totalXp XP', const Color(0xFF0D3B66)),
                    _buildMiniPill(levelName, const Color(0xFF1D4ED8)),
                    _buildMiniPill(
                      '$totalChallenges desafíos',
                      const Color(0xFF0F766E),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final uid = item['user_id']?.toString() ?? '';
              if (uid.isEmpty) return;
              context.pushNamed(
                'perfil_profesional_solicitar_Contato',
                queryParameters: {'userId': uid},
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Ver perfil',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D3B66),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
