import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
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
  List<Map<String, dynamic>> _savedVideos = [];
  int _userRanking = 0;

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

      // Carregar vídeos do usuário (meus vídeos publicados)
      final videosResponse = await SupaFlow.client
          .from('videos')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

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
              .order('created_at', ascending: false);

          savedVideos = List<Map<String, dynamic>>.from(savedVideosResponse);
        }
      } catch (e) {
        debugPrint('Erro ao carregar vídeos salvos: $e');
      }

      // Calcular ranking do usuário (com tratamento de erro)
      int ranking = 0;
      try {
        final allUsersResponse = await SupaFlow.client
            .from('users')
            .select('user_id')
            .order('created_at', ascending: true);

        final allUsers = List<Map<String, dynamic>>.from(
          allUsersResponse as List,
        );
        for (int i = 0; i < allUsers.length; i++) {
          if (allUsers[i]['user_id'] == uid) {
            ranking = i + 1;
            break;
          }
        }
      } catch (e) {
        debugPrint('Erro ao calcular ranking: $e');
        ranking = 1; // Default
      }

      if (mounted) {
        setState(() {
          _userData = userResponse;
          _videos = List<Map<String, dynamic>>.from(videosResponse);
          _savedVideos = savedVideos;
          _userRanking = ranking;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
    if (xp >= 10000) return 'Leyenda';
    if (xp >= 6000) return 'Elite';
    if (xp >= 3500) return 'Pro';
    if (xp >= 1750) return 'Semi Pro';
    if (xp >= 500) return 'Amateur';
    return 'Principiante';
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
        'unlocked': xpInt >= 500,
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

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFF444444),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF444444),
            fontSize: 14,
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(5),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: _videos.asMap().entries.map((entry) {
          return _VideoCard(
            videoUrl: entry.value['video_url'] ?? '',
            onTap: () => _openVideoFeed(entry.key, _videos),
          );
        }).toList(),
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
                                        debugPrint('🔵 Notificações clicado!');
                                        context.pushNamed('notificaciones');
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
                                          Icons.notifications_rounded,
                                          size: 24,
                                        ),
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
                            style: GoogleFonts.inter(
                              color: const Color(0xFF444444),
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Username e Stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Username e seguidores
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@$username',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF444444),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatNumber(followers)} seguidores',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF444444),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),

                              // Stats: Nivel, Ranking, Puntos
                              Row(
                                children: [
                                  _buildStatColumn(level, 'Nivel'),
                                  const SizedBox(width: 15),
                                  _buildStatColumn(
                                    '#${_userRanking > 0 ? _userRanking : '-'}',
                                    'Ranking',
                                  ),
                                  const SizedBox(width: 15),
                                  _buildStatColumn(xpInt.toString(), 'Puntos'),
                                ],
                              ),
                            ],
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
                              Text(
                                position,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF444444),
                                  fontSize: 14,
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
                              Text(
                                dominantFoot,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF444444),
                                  fontSize: 14,
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
                                Text(
                                  location,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF444444),
                                    fontSize: 14,
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
                      height: 450,
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
