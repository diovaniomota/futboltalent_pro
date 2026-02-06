import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'cursos_ejercicios_model.dart';
export 'cursos_ejercicios_model.dart';

class CursosEjerciciosWidget extends StatefulWidget {
  const CursosEjerciciosWidget({super.key});

  static String routeName = 'cursos_ejercicios';
  static String routePath = '/cursosEjercicios';

  @override
  State<CursosEjerciciosWidget> createState() => _CursosEjerciciosWidgetState();
}

class _CursosEjerciciosWidgetState extends State<CursosEjerciciosWidget> {
  late CursosEjerciciosModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // State
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'Todos';
  int _currentPage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.92);

  // Data
  Map<String, dynamic>? _userProgress;
  Map<String, dynamic>? _currentLevel;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  Map<String, String> _userCourseStatus = {};
  Map<String, String> _userExerciseStatus = {};

  final List<String> _filters = [
    'Todos',
    'Cursos',
    'Ejercicios',
    'Completados'
  ];

  final List<String> _placeholderImages = [
    'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=800',
    'https://images.unsplash.com/photo-1553778263-73a83bab9b0c?w=800',
    'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800',
    'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?w=800',
    'https://images.unsplash.com/photo-1517466787929-bc90951d0974?w=800',
    'https://images.unsplash.com/photo-1560272564-c83b66b1ad12?w=800',
  ];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CursosEjerciciosModel());
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    _pageController.dispose();
    super.dispose();
  }

  double _responsive(BuildContext context,
      {required double mobile, double? tablet, double? desktop}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return desktop ?? tablet ?? mobile;
    if (width >= 600) return tablet ?? mobile;
    return mobile;
  }

  double _scaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 320) return 0.8;
    if (width < 360) return 0.9;
    if (width >= 1024) return 1.1;
    return 1.0;
  }

  bool _isLargeScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await Future.wait([
        _loadUserProgress(),
        _loadCourses(),
        _loadExercises(),
      ]);

      _combineAndFilterItems();
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _errorMessage = 'Error al cargar datos');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserProgress() async {
    try {
      final progressResponse = await SupaFlow.client
          .from('user_progress')
          .select()
          .eq('user_id', currentUserUid)
          .maybeSingle();

      if (progressResponse != null) {
        _userProgress = progressResponse;
        if (_userProgress!['current_level_id'] != null) {
          final levelResponse = await SupaFlow.client
              .from('levels')
              .select()
              .eq('id', _userProgress!['current_level_id'])
              .maybeSingle();
          _currentLevel = levelResponse;
        }
      } else {
        await SupaFlow.client.from('user_progress').insert({
          'user_id': currentUserUid,
          'total_xp': 0,
          'current_level_id': 1,
          'courses_completed': 0,
          'exercises_completed': 0
        });
        _userProgress = {
          'total_xp': 0,
          'current_level_id': 1,
          'courses_completed': 0,
          'exercises_completed': 0
        };
        final levelResponse = await SupaFlow.client
            .from('levels')
            .select()
            .eq('id', 1)
            .maybeSingle();
        _currentLevel = levelResponse;
      }
    } catch (e) {
      debugPrint('Error loading user progress: $e');
    }
  }

  Future<void> _loadCourses() async {
    try {
      final coursesResponse = await SupaFlow.client
          .from('courses')
          .select()
          .eq('is_active', true)
          .order('order_index');
      _courses = List<Map<String, dynamic>>.from(coursesResponse);
      final userCoursesResponse = await SupaFlow.client
          .from('user_courses')
          .select('course_id, status')
          .eq('user_id', currentUserUid);
      for (var uc in (userCoursesResponse)) {
        _userCourseStatus[uc['course_id'].toString()] = uc['status'];
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
  }

  Future<void> _loadExercises() async {
    try {
      final exercisesResponse = await SupaFlow.client
          .from('exercises')
          .select()
          .eq('is_active', true)
          .order('order_index');
      _exercises = List<Map<String, dynamic>>.from(exercisesResponse);
      final userExercisesResponse = await SupaFlow.client
          .from('user_exercises')
          .select('exercise_id, status')
          .eq('user_id', currentUserUid);
      for (var ue in (userExercisesResponse)) {
        _userExerciseStatus[ue['exercise_id'].toString()] = ue['status'];
      }
    } catch (e) {
      debugPrint('Error loading exercises: $e');
    }
  }

  void _combineAndFilterItems() {
    _allItems = [];
    for (int i = 0; i < _courses.length; i++) {
      final course = _courses[i];
      _allItems.add({
        ...course,
        'type': 'course',
        'status': _userCourseStatus[course['id'].toString()] ?? 'not_started',
        'placeholder_image': _placeholderImages[i % _placeholderImages.length]
      });
    }
    for (int i = 0; i < _exercises.length; i++) {
      final exercise = _exercises[i];
      _allItems.add({
        ...exercise,
        'type': 'exercise',
        'status':
            _userExerciseStatus[exercise['id'].toString()] ?? 'not_started',
        'placeholder_image':
            _placeholderImages[(i + 3) % _placeholderImages.length]
      });
    }
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      switch (_selectedFilter) {
        case 'Cursos':
          _filteredItems =
              _allItems.where((item) => item['type'] == 'course').toList();
          break;
        case 'Ejercicios':
          _filteredItems =
              _allItems.where((item) => item['type'] == 'exercise').toList();
          break;
        case 'Completados':
          _filteredItems =
              _allItems.where((item) => item['status'] == 'completed').toList();
          break;
        default:
          _filteredItems = List.from(_allItems);
      }
      _currentPage = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    });
  }

  void _onFilterSelected(String filter) {
    setState(() => _selectedFilter = filter);
    _applyFilter();
  }

  Future<void> _onItemTap(Map<String, dynamic> item) async {
    final isCourse = item['type'] == 'course';
    final status = item['status'] ?? 'not_started';
    final itemId = item['id'].toString();

    if (status == 'not_started') {
      try {
        if (isCourse) {
          final existing = await SupaFlow.client
              .from('user_courses')
              .select('id')
              .eq('user_id', currentUserUid)
              .eq('course_id', itemId)
              .maybeSingle();
          if (existing != null) {
            await SupaFlow.client
                .from('user_courses')
                .update({
                  'status': 'in_progress',
                  'started_at': DateTime.now().toIso8601String()
                })
                .eq('user_id', currentUserUid)
                .eq('course_id', itemId);
          } else {
            await SupaFlow.client.from('user_courses').insert({
              'user_id': currentUserUid,
              'course_id': itemId,
              'status': 'in_progress',
              'started_at': DateTime.now().toIso8601String()
            });
          }
          _userCourseStatus[itemId] = 'in_progress';
        } else {
          final existing = await SupaFlow.client
              .from('user_exercises')
              .select('id')
              .eq('user_id', currentUserUid)
              .eq('exercise_id', itemId)
              .maybeSingle();
          if (existing != null) {
            await SupaFlow.client
                .from('user_exercises')
                .update({'status': 'in_progress'})
                .eq('user_id', currentUserUid)
                .eq('exercise_id', itemId);
          } else {
            await SupaFlow.client.from('user_exercises').insert({
              'user_id': currentUserUid,
              'exercise_id': itemId,
              'status': 'in_progress'
            });
          }
          _userExerciseStatus[itemId] = 'in_progress';
        }
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
    _showVideoModal(item);
  }

  void _showVideoModal(Map<String, dynamic> item) {
    final scale = _scaleFactor(context);
    final videoUrl = item['video_url']?.toString() ?? '';
    final title =
        item['title'] ?? (item['type'] == 'course' ? 'Curso' : 'Ejercicio');
    final xpReward = item['xp_reward'] ?? (item['type'] == 'course' ? 100 : 50);
    final isCourse = item['type'] == 'course';
    final itemId = item['id'].toString();
    final imageUrl = item['thumbnail_url'] ??
        item['image_url'] ??
        item['placeholder_image'] ??
        '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            Container(
                margin: EdgeInsets.only(top: 12 * scale),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: Stack(
                children: [
                  if (imageUrl.isNotEmpty)
                    Positioned.fill(
                        child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24)),
                            child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                color: Colors.black.withOpacity(0.4),
                                colorBlendMode: BlendMode.darken))),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(20 * scale),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                              alignment: Alignment.topRight,
                              child: GestureDetector(
                                  onTap: () => Navigator.pop(ctx),
                                  child: Container(
                                      padding: EdgeInsets.all(8 * scale),
                                      decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Icon(Icons.close,
                                          color: Colors.white,
                                          size: 24 * scale)))),
                          const Spacer(),
                          Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12 * scale, vertical: 6 * scale),
                              decoration: BoxDecoration(
                                  color: isCourse
                                      ? const Color(0xFF0D3B66)
                                      : const Color(0xFF48BB78),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(isCourse ? 'CURSO' : 'EJERCICIO',
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12 * scale,
                                      fontWeight: FontWeight.w600))),
                          SizedBox(height: 12 * scale),
                          Text(title,
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 28 * scale,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 8 * scale),
                          Row(children: [
                            Icon(Icons.bolt,
                                color: const Color(0xFFFFD700),
                                size: 20 * scale),
                            SizedBox(width: 4 * scale),
                            Text('+$xpReward XP',
                                style: GoogleFonts.inter(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 16 * scale,
                                    fontWeight: FontWeight.w600))
                          ]),
                          SizedBox(height: 24 * scale),
                          if (videoUrl.isNotEmpty)
                            GestureDetector(
                                onTap: () async {
                                  await launchURL(videoUrl);
                                },
                                child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 16 * scale),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.play_circle_filled,
                                              color: const Color(0xFF0D3B66),
                                              size: 28 * scale),
                                          SizedBox(width: 12 * scale),
                                          Text('Ver Video',
                                              style: GoogleFonts.inter(
                                                  color:
                                                      const Color(0xFF0D3B66),
                                                  fontSize: 18 * scale,
                                                  fontWeight: FontWeight.w600))
                                        ]))),
                          SizedBox(height: 12 * scale),
                          _CompletarButton(
                              itemId: itemId,
                              isCourse: isCourse,
                              userId: currentUserUid,
                              xpReward: xpReward,
                              onComplete: () {
                                Navigator.pop(ctx);
                                _loadData();
                              }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    final scale = _scaleFactor(context);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D3B66)))
            : _errorMessage != null
                ? _buildErrorState(context)
                : Stack(
                    children: [
                      SafeArea(
                        child: Column(
                          children: [
                            _buildHeader(context),
                            SizedBox(height: 16 * scale),
                            _buildFilters(context),
                            SizedBox(height: 20 * scale),
                            Expanded(
                              child: _filteredItems.isEmpty
                                  ? _buildEmptyState(context)
                                  : _isLargeScreen(context)
                                      ? _buildGridView(context)
                                      : _buildCarousel(context),
                            ),
                            if (!_isLargeScreen(context) &&
                                _filteredItems.isNotEmpty)
                              _buildPageIndicators(context),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                      Align(
                        alignment: const AlignmentDirectional(0.0, 1.0),
                        child: userType == 'jugador'
                            ? wrapWithModel(
                                model: _model.navBarJudadorModel,
                                updateCallback: () => safeSetState(() {}),
                                child: const NavBarJudadorWidget(),
                              )
                            : (userType == 'profesional'
                                ? wrapWithModel(
                                    model: _model.navBarProfesionalModel,
                                    updateCallback: () => safeSetState(() {}),
                                    child: const NavBarProfesionalWidget(),
                                  )
                                : const SizedBox.shrink()),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final scale = _scaleFactor(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48 * scale),
          SizedBox(height: 16 * scale),
          Text(_errorMessage!,
              style:
                  GoogleFonts.inter(color: Colors.red, fontSize: 16 * scale)),
          SizedBox(height: 16 * scale),
          ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66)),
              child: Text('Reintentar',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 14 * scale))),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scale = _scaleFactor(context);
    final totalXp = _userProgress?['total_xp'] ?? 0;
    final levelName = _currentLevel?['name'] ?? 'Principiante';
    final horizontalPadding =
        _responsive(context, mobile: 16, tablet: 24, desktop: 32);

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: 12 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mi Progreso',
                  style: GoogleFonts.inter(
                      fontSize: 14 * scale, color: Colors.grey[600])),
              SizedBox(height: 4 * scale),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale, vertical: 4 * scale),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF0D3B66), Color(0xFF1E5A8A)]),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Icon(Icons.bolt,
                          color: const Color(0xFFFFD700), size: 16 * scale),
                      SizedBox(width: 4 * scale),
                      Text('$totalXp XP',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.bold))
                    ]),
                  ),
                  SizedBox(width: 8 * scale),
                  Text(levelName,
                      style: GoogleFonts.inter(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D3B66))),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => context.pushNamed('ranking'),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale, vertical: 10 * scale),
              decoration: BoxDecoration(
                  color: const Color(0xFF0D3B66),
                  borderRadius: BorderRadius.circular(25)),
              child: Row(children: [
                Icon(Icons.leaderboard, color: Colors.white, size: 18 * scale),
                SizedBox(width: 6 * scale),
                Text('Ranking',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w600))
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final scale = _scaleFactor(context);
    final horizontalPadding =
        _responsive(context, mobile: 16, tablet: 24, desktop: 32);

    return SizedBox(
      height: 40 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 10 * scale),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => _onFilterSelected(filter),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 20 * scale, vertical: 10 * scale),
              decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF0D3B66) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0D3B66)
                          : Colors.grey[300]!,
                      width: 1.5)),
              child: Text(filter,
                  style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontSize: 14 * scale,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scale = _scaleFactor(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined,
              size: 64 * scale, color: Colors.grey[400]),
          SizedBox(height: 16 * scale),
          Text(
              _selectedFilter == 'Completados'
                  ? 'No has completado ningún contenido aún'
                  : 'No hay contenido disponible',
              style: GoogleFonts.inter(
                  fontSize: 16 * scale, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCarousel(BuildContext context) {
    final scale = _scaleFactor(context);
    return PageView.builder(
      controller: _pageController,
      itemCount: _filteredItems.length,
      onPageChanged: (index) => setState(() => _currentPage = index),
      itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          child: _buildCard(context, _filteredItems[index])),
    );
  }

  Widget _buildGridView(BuildContext context) {
    final scale = _scaleFactor(context);
    final horizontalPadding =
        _responsive(context, mobile: 16, tablet: 24, desktop: 32);

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16 * scale,
          mainAxisSpacing: 16 * scale,
          childAspectRatio: 0.75),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) =>
          _buildCard(context, _filteredItems[index]),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> item) {
    final scale = _scaleFactor(context);
    final isCourse = item['type'] == 'course';
    final status = item['status'] ?? 'not_started';
    final isCompleted = status == 'completed';
    final title = item['title'] ?? (isCourse ? 'Curso' : 'Ejercicio');
    final xpReward = item['xp_reward'] ?? (isCourse ? 100 : 50);
    final imageUrl = item['thumbnail_url'] ??
        item['image_url'] ??
        item['placeholder_image'] ??
        '';

    String statusText = isCompleted
        ? '✓ Completado'
        : (status == 'in_progress' ? 'Continuar' : 'Empezar ahora');

    return GestureDetector(
      onTap: () => _onItemTap(item),
      child: Container(
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey[300]),
                    errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF0D3B66),
                        child: const Icon(Icons.play_circle_outline,
                            color: Colors.white54, size: 80)))
              else
                Container(
                    color: const Color(0xFF0D3B66),
                    child: const Icon(Icons.play_circle_outline,
                        color: Colors.white54, size: 80)),
              Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8)
                  ],
                          stops: const [
                    0.3,
                    0.6,
                    1.0
                  ]))),
              if (isCompleted)
                Positioned(
                    top: 16 * scale,
                    right: 16 * scale,
                    child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12 * scale, vertical: 6 * scale),
                        decoration: BoxDecoration(
                            color: const Color(0xFF48BB78),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle,
                              color: Colors.white, size: 14 * scale),
                          SizedBox(width: 4 * scale),
                          Text('Completado',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w600))
                        ]))),
              Positioned(
                  top: 16 * scale,
                  left: 16 * scale,
                  child: Container(
                      width: 40 * scale,
                      height: 40 * scale,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8)
                          ]),
                      child: Icon(
                          isCourse ? Icons.school : Icons.fitness_center,
                          color: const Color(0xFF0D3B66),
                          size: 22 * scale))),
              Positioned(
                  bottom: 24 * scale,
                  left: 20 * scale,
                  right: 20 * scale,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: _responsive(context,
                                        mobile: 24, tablet: 26, desktop: 28) *
                                    scale,
                                fontWeight: FontWeight.bold,
                                height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        SizedBox(height: 8 * scale),
                        Row(children: [
                          Text(statusText,
                              style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10 * scale, vertical: 4 * scale),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Icon(Icons.bolt,
                                    color: const Color(0xFFFFD700),
                                    size: 14 * scale),
                                SizedBox(width: 2 * scale),
                                Text('+$xpReward XP',
                                    style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12 * scale,
                                        fontWeight: FontWeight.w600))
                              ]))
                        ])
                      ])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators(BuildContext context) {
    final scale = _scaleFactor(context);
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 16 * scale),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                _filteredItems.length,
                (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                    width: _currentPage == index ? 24 * scale : 8 * scale,
                    height: 8 * scale,
                    decoration: BoxDecoration(
                        color: _currentPage == index
                            ? const Color(0xFF0D3B66)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))))));
  }
}

class _CompletarButton extends StatefulWidget {
  final String itemId;
  final bool isCourse;
  final String userId;
  final int xpReward;
  final VoidCallback onComplete;
  const _CompletarButton(
      {required this.itemId,
      required this.isCourse,
      required this.userId,
      required this.xpReward,
      required this.onComplete});
  @override
  State<_CompletarButton> createState() => _CompletarButtonState();
}

class _CompletarButtonState extends State<_CompletarButton> {
  bool _isLoading = false;
  Future<void> _markAsCompleted() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isCourse) {
        final existing = await SupaFlow.client
            .from('user_courses')
            .select('id, status')
            .eq('user_id', widget.userId)
            .eq('course_id', widget.itemId)
            .maybeSingle();
        if (existing != null && existing['status'] == 'completed') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Este curso ya fue completado'),
              backgroundColor: Colors.orange));
          widget.onComplete();
          return;
        }
        if (existing != null) {
          await SupaFlow.client
              .from('user_courses')
              .update({
                'status': 'completed',
                'completed_at': DateTime.now().toIso8601String(),
                'progress_percent': 100,
                'xp_earned': widget.xpReward
              })
              .eq('user_id', widget.userId)
              .eq('course_id', widget.itemId);
        } else {
          await SupaFlow.client.from('user_courses').insert({
            'user_id': widget.userId,
            'course_id': widget.itemId,
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'progress_percent': 100,
            'xp_earned': widget.xpReward
          });
        }
        await _updateUserProgress(isExercise: false);
      } else {
        final existing = await SupaFlow.client
            .from('user_exercises')
            .select('id, status')
            .eq('user_id', widget.userId)
            .eq('exercise_id', widget.itemId)
            .maybeSingle();
        if (existing != null && existing['status'] == 'completed') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Este ejercicio ya fue completado'),
              backgroundColor: Colors.orange));
          widget.onComplete();
          return;
        }
        if (existing != null) {
          await SupaFlow.client
              .from('user_exercises')
              .update({
                'status': 'completed',
                'last_completed_at': DateTime.now().toIso8601String(),
                'total_xp_earned': widget.xpReward
              })
              .eq('user_id', widget.userId)
              .eq('exercise_id', widget.itemId);
        } else {
          await SupaFlow.client.from('user_exercises').insert({
            'user_id': widget.userId,
            'exercise_id': widget.itemId,
            'status': 'completed',
            'last_completed_at': DateTime.now().toIso8601String(),
            'total_xp_earned': widget.xpReward
          });
        }
        await _updateUserProgress(isExercise: true);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isCourse
              ? '¡Curso completado! +${widget.xpReward} XP'
              : '¡Ejercicio completado! +${widget.xpReward} XP'),
          backgroundColor: const Color(0xFF48BB78)));
      widget.onComplete();
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserProgress({required bool isExercise}) async {
    try {
      final currentProgress = await SupaFlow.client
          .from('user_progress')
          .select()
          .eq('user_id', widget.userId)
          .maybeSingle();
      if (currentProgress != null) {
        final newXp = (currentProgress['total_xp'] ?? 0) + widget.xpReward;
        final newCoursesCompleted = isExercise
            ? (currentProgress['courses_completed'] ?? 0)
            : (currentProgress['courses_completed'] ?? 0) + 1;
        final newExercisesCompleted = isExercise
            ? (currentProgress['exercises_completed'] ?? 0) + 1
            : (currentProgress['exercises_completed'] ?? 0);
        int newLevelId = 1;
        if (newXp >= 10000)
          newLevelId = 6;
        else if (newXp >= 6000)
          newLevelId = 5;
        else if (newXp >= 3500)
          newLevelId = 4;
        else if (newXp >= 1750)
          newLevelId = 3;
        else if (newXp >= 500) newLevelId = 2;
        await SupaFlow.client.from('user_progress').update({
          'total_xp': newXp,
          'courses_completed': newCoursesCompleted,
          'exercises_completed': newExercisesCompleted,
          'current_level_id': newLevelId,
          'last_activity_date': DateTime.now().toIso8601String().split('T')[0],
          'updated_at': DateTime.now().toIso8601String()
        }).eq('user_id', widget.userId);
      } else {
        int newLevelId = widget.xpReward >= 500 ? 2 : 1;
        await SupaFlow.client.from('user_progress').insert({
          'user_id': widget.userId,
          'total_xp': widget.xpReward,
          'courses_completed': isExercise ? 0 : 1,
          'exercises_completed': isExercise ? 1 : 0,
          'current_level_id': newLevelId,
          'last_activity_date': DateTime.now().toIso8601String().split('T')[0]
        });
      }
    } catch (e) {
      debugPrint('Error updating user progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        onPressed: _isLoading ? null : _markAsCompleted,
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF48BB78),
            disabledBackgroundColor: Colors.grey,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text('Marcar como Completado',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)));
  }
}
