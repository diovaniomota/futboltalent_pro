import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
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
  List<Map<String, dynamic>> _rankingData = [];
  Map<String, dynamic>? _currentUserProgress;
  Map<String, dynamic>? _currentUserLevel;
  String _sortBy = 'puntos';

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

  Future<void> _loadRankingData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final response = await SupaFlow.client
          .from('user_progress')
          .select('*, levels:current_level_id (id, name, order_index)')
          .order('total_xp', ascending: false);

      _rankingData = List<Map<String, dynamic>>.from(response);

      for (int i = 0; i < _rankingData.length; i++) {
        final userId = _rankingData[i]['user_id'];
        try {
          final userResponse = await SupaFlow.client
              .from('users')
              .select('user_id, name, posicion, country, photo_url')
              .eq('user_id', userId)
              .maybeSingle();

          if (userResponse != null) {
            _rankingData[i]['users'] = userResponse;
          }
        } catch (e) {
          debugPrint('Error loading user data for $userId: $e');
        }
      }

      for (var item in _rankingData) {
        if (item['user_id'] == currentUserUid) {
          _currentUserProgress = item;
          _currentUserLevel = item['levels'];
          break;
        }
      }

      if (_currentUserProgress == null) {
        try {
          final levelResponse = await SupaFlow.client
              .from('levels')
              .select()
              .eq('id', 1)
              .maybeSingle();
          _currentUserLevel = levelResponse ?? {'name': 'Principiante'};
        } catch (e) {
          _currentUserLevel = {'name': 'Principiante'};
        }
        _currentUserProgress = {
          'total_xp': 0,
          'courses_completed': 0,
          'exercises_completed': 0,
        };
      }

      _sortRanking();
    } catch (e) {
      debugPrint('Error loading ranking: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Error al cargar el ranking: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _sortRanking() {
    if (_sortBy == 'puntos') {
      _rankingData
          .sort((a, b) => (b['total_xp'] ?? 0).compareTo(a['total_xp'] ?? 0));
    } else {
      _rankingData.sort((a, b) {
        int medalsA =
            (a['courses_completed'] ?? 0) + (a['exercises_completed'] ?? 0);
        int medalsB =
            (b['courses_completed'] ?? 0) + (b['exercises_completed'] ?? 0);
        return medalsB.compareTo(medalsA);
      });
    }
  }

  void _changeSortOrder(String newSort) {
    if (mounted) {
      setState(() {
        _sortBy = newSort;
        _sortRanking();
      });
    }
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
          Text(_errorMessage!,
              style: GoogleFonts.inter(color: Colors.red, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRankingData,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66)),
            child:
                const Text('Reintentar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ],
          ),
        ),

        // Título e nível
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
              const SizedBox(height: 4),
              Text(
                _currentUserLevel?['name'] ?? 'Principiante',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D3B66),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Filtros
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterButton('Orden', null, false),
              const SizedBox(width: 12),
              _buildFilterButton('Puntos', 'puntos', _sortBy == 'puntos'),
              const SizedBox(width: 12),
              _buildFilterButton('Medallas', 'medallas', _sortBy == 'medallas'),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Lista de ranking
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
                        padding: const EdgeInsets.only(bottom: 8),
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
            'No hay jugadores en el ranking',
            style: GoogleFonts.inter(
              color: const Color(0xFF718096),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completa cursos y ejercicios para aparecer aquí',
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

  Widget _buildFilterButton(String text, String? sortValue, bool isActive) {
    final bool isClickable = sortValue != null;

    return GestureDetector(
      onTap: isClickable ? () => _changeSortOrder(sortValue) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFF0D3B66) : const Color(0xFFA0AEC0),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: GoogleFonts.inter(
                color: isActive
                    ? const Color(0xFF0D3B66)
                    : const Color(0xFF444444),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isClickable) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                color: isActive
                    ? const Color(0xFF0D3B66)
                    : const Color(0xFF718096),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRankingItem(
      Map<String, dynamic> item, int position, bool isCurrentUser) {
    final user = item['users'] as Map<String, dynamic>?;

    final userName = user?['name'] ?? 'Jugador #$position';
    final userPosition = user?['posicion'] ?? _getRandomPosition(position);
    final userCountry = user?['country'] ?? _getRandomCountry(position);
    final totalXp = item['total_xp'] ?? 0;
    final coursesCompleted = item['courses_completed'] ?? 0;
    final exercisesCompleted = item['exercises_completed'] ?? 0;
    final totalMedals = coursesCompleted + exercisesCompleted;

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
              isCurrentUser ? const Color(0xFF0D3B66) : const Color(0xFFB5BECA),
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
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                    color: position <= 3 ? badgeColor : const Color(0xFFD69E2E),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: position <= 3 ? badgeColor : const Color(0xFFD69E2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sortBy == 'puntos' ? Icons.star : Icons.emoji_events,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  _sortBy == 'puntos' ? '$totalXp' : '$totalMedals',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              context.pushNamed('perfilJugador', queryParameters: {
                'userId': item['user_id'],
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Text(
                'Ver Perfil',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D3B66),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRandomPosition(int index) {
    final positions = ['DEF', 'MID', 'ATK', 'GK', 'DEF', 'MID', 'ATK', 'DEF'];
    return positions[index % positions.length];
  }

  String _getRandomCountry(int index) {
    final countries = [
      'Argentina',
      'Brasil',
      'Colombia',
      'México',
      'Chile',
      'Uruguay',
      'Perú',
      'Ecuador'
    ];
    return countries[index % countries.length];
  }
}
