import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/fluxo_compartilhado/club_application_utils.dart';
import '/fluxo_compartilhado/club_identity_utils.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'convocatorias_club_model.dart';
export 'convocatorias_club_model.dart';

List<Map<String, dynamic>> _convocatoriaRequiredChallengesFrom(dynamic raw) {
  dynamic source = raw;
  if (source is String) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return const [];
    try {
      source = jsonDecode(trimmed);
    } catch (_) {
      return const [];
    }
  }

  if (source is! List) return const [];

  final result = <Map<String, dynamic>>[];
  final seen = <String>{};

  for (final entry in source) {
    final map = entry is Map<String, dynamic>
        ? Map<String, dynamic>.from(entry)
        : entry is Map
            ? Map<String, dynamic>.from(entry)
            : null;
    if (map == null) continue;

    final id = map['id']?.toString().trim() ?? '';
    final type = map['type']?.toString().trim().toLowerCase() ?? '';
    if (id.isEmpty || (type != 'course' && type != 'exercise')) continue;

    final key = '$type:$id';
    if (!seen.add(key)) continue;

    result.add({
      ...map,
      'id': id,
      'type': type,
      'title': map['title']?.toString().trim() ?? '',
    });
  }

  return result;
}

String _convocatoriaChallengeTitle(Map<String, dynamic> challenge) {
  final title = challenge['title']?.toString().trim() ?? '';
  if (title.isNotEmpty) return title;
  return challenge['type'] == 'course' ? 'Curso' : 'Desafío';
}

class ConvocatoriasClubWidget extends StatefulWidget {
  const ConvocatoriasClubWidget({super.key});

  static String routeName = 'convocatorias_club';
  static String routePath = '/convocatoriasClub';

  @override
  State<ConvocatoriasClubWidget> createState() =>
      _ConvocatoriasClubWidgetState();
}

class _ConvocatoriasClubWidgetState extends State<ConvocatoriasClubWidget> {
  late ConvocatoriasClubModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  List<Map<String, dynamic>> _convocatorias = [];
  String? _clubId;
  String? _clubName;
  Set<String> _clubRefs = <String>{};

  // Stats
  int _convocatoriasActivas = 0;
  int _totalPostulaciones = 0;
  int _totalVideos = 0;
  double _promedioPostulaciones = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConvocatoriasClubModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _resolveClubContext();

    // Carregar convocatorias e stats
    if (_clubId != null && _clubId!.isNotEmpty) {
      await _loadConvocatorias();
      await _loadStats();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveClubContext() async {
    final authUid = currentUserUid;
    _clubRefs = await resolveClubRefsForUser(authUid);
    if (_clubRefs.isEmpty && authUid.isNotEmpty) {
      _clubRefs = {authUid};
    }

    final club = await resolveCurrentClubForUser(authUid);
    _clubId = club?['id']?.toString().trim().isNotEmpty == true
        ? club!['id'].toString().trim()
        : (authUid.isNotEmpty ? authUid : null);
    _clubName = club?['nombre']?.toString();
  }

  Future<List<Map<String, dynamic>>> _loadClubConvocatoriasRows({
    String columns = '*',
  }) async {
    if (_clubRefs.isEmpty) return [];

    final response = _clubRefs.length == 1
        ? await SupaFlow.client
            .from('convocatorias')
            .select(columns)
            .eq('club_id', _clubRefs.first)
            .order('created_at', ascending: false)
        : await SupaFlow.client
            .from('convocatorias')
            .select(columns)
            .inFilter('club_id', _clubRefs.toList())
            .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> _loadConvocatorias() async {
    try {
      _convocatorias = await _loadClubConvocatoriasRows();
      final convocatoriaIds = _convocatorias
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final applications = await fetchClubApplicationsForConvocatorias(
        convocatoriaIds: convocatoriaIds,
        limitPerTable: 800,
      );
      final countByConvocatoria = <String, int>{};
      for (final application in applications) {
        final convocatoriaId =
            application['convocatoria_id']?.toString().trim() ?? '';
        if (convocatoriaId.isEmpty) continue;
        countByConvocatoria[convocatoriaId] =
            (countByConvocatoria[convocatoriaId] ?? 0) + 1;
      }

      for (final conv in _convocatorias) {
        final convocatoriaId = conv['id']?.toString().trim() ?? '';
        conv['postulaciones_count'] = countByConvocatoria[convocatoriaId] ?? 0;
      }
    } catch (e) {
      debugPrint('Error cargando convocatorias: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final convocatoriaIds = _convocatorias
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final applications = await fetchClubApplicationsForConvocatorias(
        convocatoriaIds: convocatoriaIds,
        limitPerTable: 800,
      );

      // Convocatorias activas
      _convocatoriasActivas = _convocatorias
          .where((c) => c['estado']?.toString().toLowerCase() == 'activa')
          .length;

      // Total postulaciones
      _totalPostulaciones = applications.length;

      // Promedio por convocatoria
      if (_convocatoriasActivas > 0) {
        _promedioPostulaciones = _totalPostulaciones / _convocatoriasActivas;
      }

      final playerIds = applications
          .map(clubApplicationPlayerId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (playerIds.isEmpty) {
        _totalVideos = 0;
      } else {
        try {
          final videosResponse = await SupaFlow.client
              .from('videos')
              .select('id')
              .eq('is_public', true)
              .inFilter('user_id', playerIds);
          _totalVideos = (videosResponse as List).length;
        } catch (_) {
          _totalVideos = 0;
        }
      }
    } catch (e) {
      debugPrint('Error cargando stats: $e');
    }
  }

  void _showCreateConvocatoriaModal() {
    // Modal para criar nova convocatoria
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateConvocatoriaModal(
        clubId: _clubId!,
        onCreated: () {
          _loadData();
        },
      ),
    );
  }

  void _showViewConvocatoriaModal(Map<String, dynamic> conv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ViewConvocatoriaModal(convocatoria: conv),
    );
  }

  void _showEditConvocatoriaModal(Map<String, dynamic> conv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateConvocatoriaModal(
        clubId: _clubId!,
        existingData: conv,
        onCreated: () {
          _loadData();
        },
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return '-';
    }
  }

  void _showClubMenu(BuildContext ctx) {
    final drawerWidth = 0.75; // Or responsive

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
                  width: MediaQuery.of(context).size.width * drawerWidth,
                  height: double.infinity,
                  color: Colors.white,
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Color(0xFFE0E0E0))),
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
                                child: const Icon(Icons.settings,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Menú del club',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D3B66),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),

                        // Menu Items
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: [
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.dashboard_outlined,
                                  'Dashboard',
                                  false,
                                  () async => context.pushNamed(
                                      DashboardClubWidget.routeName)),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.campaign_outlined,
                                  'Convocatorias',
                                  true,
                                  () async => context.pushNamed(
                                      ConvocatoriasClubWidget.routeName)),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.people_outline,
                                  'Jugadores',
                                  false,
                                  () async => context.pushNamed(
                                      PostulacionesWidget.routeName)),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.list_alt_outlined,
                                  'Scouting',
                                  false,
                                  () async => context
                                      .pushNamed(ListaYNotaWidget.routeName)),
                              const Divider(),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.settings_outlined,
                                  'Club',
                                  false,
                                  () async => context
                                      .pushNamed(ConfiguracinWidget.routeName)),
                              const Divider(),
                              _buildDrawerItemCallback(
                                  context, Icons.logout, 'Cerrar Sesión', false,
                                  () async {
                                debugPrint(
                                    'Logout callback triggered in ConvocatoriasClub');
                                try {
                                  await authManager.signOut();
                                  debugPrint(
                                      'Logout: SignOut successful, navigating with stable context');
                                  if (ctx.mounted) {
                                    ctx.goNamed('login');
                                  } else {
                                    debugPrint(
                                        'Logout: Stable context not mounted');
                                  }
                                } catch (e) {
                                  debugPrint('Error logout: $e');
                                  if (ctx.mounted) {
                                    ctx.goNamed('login');
                                  }
                                }
                              }),
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

  Widget _buildDrawerItemCallback(BuildContext context, IconData icon,
      String label, bool isSelected, Future Function()? onTap) {
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFF0D3B66) : Colors.grey[600]),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? const Color(0xFF0D3B66) : Colors.grey[800],
        ),
      ),
      trailing: isSelected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFF0D3B66), shape: BoxShape.circle),
            )
          : null,
      onTap: () async {
        Navigator.of(context, rootNavigator: true).pop();
        if (!isSelected && onTap != null) {
          await Future.delayed(const Duration(milliseconds: 100));
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
        body: SafeArea(
          top: true,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
                )
              : Container(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 1.0,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildHeader(),
                        if (_clubName != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Club: $_clubName',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Botón Nueva Convocatoria
                        _buildNewButton(),
                        const SizedBox(height: 24),

                        // Stats Cards
                        _buildStatsRow1(),
                        const SizedBox(height: 16),
                        _buildStatsRow2(),
                        const SizedBox(height: 24),

                        // Lista de Convocatorias
                        _buildConvocatoriasList(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _showClubMenu(context),
              child: const Icon(Icons.menu, color: Colors.black, size: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Convocatorias',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Crea y gestiona las convocatorias para diferentes categorías y posiciones.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildNewButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _showCreateConvocatoriaModal,
        icon: const Icon(Icons.add, size: 18, color: Colors.white),
        label: Text(
          'Nueva Convocatoria',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF818181),
          minimumSize: const Size(200, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildStatsRow1() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Convocatorias\nActivas',
            value: _convocatoriasActivas.toString(),
            icon: Icons.people,
            subtitle: 'En curso',
            trend: '+12%',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Promedio por\nConvocatoria',
            value: _promedioPostulaciones.toStringAsFixed(0),
            icon: Icons.calendar_month,
            subtitle: 'Postulaciones',
            trend: '+8%',
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow2() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total\nPostulaciones',
            value: _totalPostulaciones.toString(),
            icon: Icons.people,
            subtitle: 'Todas las convocatorias',
            trend: '+15%',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Total videos\nSubidos',
            value: _totalVideos.toString(),
            icon: Icons.videocam,
            subtitle: 'En convocatorias',
            trend: '+20%',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required String subtitle,
    String? trend,
  }) {
    return Container(
      height: 152,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF928F8F), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              Icon(icon, color: Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEEF2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_up,
                          color: Colors.black, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        trend,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildConvocatoriasList() {
    if (_convocatorias.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay convocatorias',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu primera convocatoria para\nempezar a recibir postulaciones',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children:
          _convocatorias.map((conv) => _buildConvocatoriaCard(conv)).toList(),
    );
  }

  Widget _buildConvocatoriaCard(Map<String, dynamic> conv) {
    final titulo = conv['titulo'] ?? conv['categoria'] ?? 'Sin título';
    final posicion = conv['posicion'] ?? '';
    final descripcion = conv['descripcion'] ?? '';
    final estado = conv['estado']?.toString().toLowerCase() ?? 'activa';
    final categoria = conv['tipo'] ?? conv['categoria'] ?? 'Abierta';
    final postulaciones = conv['postulaciones_count'] ?? 0;
    final fechaCierre = _formatDate(conv['fecha_cierre']);
    final requiredChallenges =
        _convocatoriaRequiredChallengesFrom(conv['required_challenges']);
    final challengeLabels = requiredChallenges.isNotEmpty
        ? requiredChallenges.map(_convocatoriaChallengeTitle).toList()
        : (conv['ejercicios'] as List? ?? [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF928F8F)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con título y botones
          Row(
            children: [
              Text(
                titulo,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              _buildSmallButton('Ver', Icons.visibility, () {
                _showViewConvocatoriaModal(conv);
              }),
              const SizedBox(width: 8),
              _buildSmallButton('Editar', FontAwesomeIcons.edit, () {
                _showEditConvocatoriaModal(conv);
              }),
            ],
          ),
          const SizedBox(height: 8),

          // Posición y Estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                posicion.isNotEmpty ? posicion : 'Sin posición',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: estado == 'activa' ? Colors.black : Colors.grey,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  estado == 'activa' ? 'Activa' : 'Cerrada',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          // Descripción
          if (descripcion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              descripcion,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFB5BECA),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),

          // Stats Row 1
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn('Categoría', categoria),
              _buildInfoColumn('Postulaciones', postulaciones.toString()),
            ],
          ),
          const SizedBox(height: 12),

          // Stats Row 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn(
                  'Desafíos req.', challengeLabels.length.toString()),
              _buildInfoColumn('Cierra', fechaCierre),
            ],
          ),

          // Desafíos requeridos
          if (challengeLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Desafíos requeridos:',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF818181),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: challengeLabels
                  .map<Widget>((challenge) => _buildExerciseTag(challenge))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFB5BECA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.black),
            const SizedBox(width: 4),
            Text(
              text,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF818181),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseTag(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF818181)),
      ),
      child: Text(
        name,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

// ===== MODAL CRIAR/EDITAR CONVOCATORIA =====
class _CreateConvocatoriaModal extends StatefulWidget {
  const _CreateConvocatoriaModal({
    Key? key,
    required this.clubId,
    this.existingData,
    required this.onCreated,
  }) : super(key: key);

  final String clubId;
  final Map<String, dynamic>? existingData;
  final VoidCallback onCreated;

  @override
  State<_CreateConvocatoriaModal> createState() =>
      _CreateConvocatoriaModalState();
}

class _CreateConvocatoriaModalState extends State<_CreateConvocatoriaModal> {
  final _tituloController = TextEditingController();
  final _posicionController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _edadMinController = TextEditingController();
  final _edadMaxController = TextEditingController();

  String _categoria = 'Sub-17';
  String _tipo = 'Abierta';
  DateTime _fechaCierre = DateTime.now().add(const Duration(days: 30));
  bool _isSaving = false;
  bool _isLoadingChallenges = true;
  List<Map<String, dynamic>> _availableChallenges = [];
  List<Map<String, dynamic>> _selectedRequiredChallenges = [];
  bool get _isEditing => widget.existingData != null;

  final List<String> _categorias = [
    'Sub-13',
    'Sub-15',
    'Sub-17',
    'Sub-20',
    'Primera División'
  ];
  final List<String> _tipos = ['Abierta', 'Invitación', 'Privada'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.existingData!;
      _tituloController.text = data['titulo'] ?? '';
      _posicionController.text = data['posicion'] ?? '';
      _descripcionController.text = data['descripcion'] ?? '';
      _edadMinController.text =
          (data['edad_minima'] ?? data['edad_min'])?.toString() ?? '';
      _edadMaxController.text =
          (data['edad_maxima'] ?? data['edad_max'])?.toString() ?? '';
      _categoria = data['categoria'] ?? 'Sub-17';
      _tipo = data['tipo'] ?? 'Abierta';
      _selectedRequiredChallenges =
          _convocatoriaRequiredChallengesFrom(data['required_challenges']);
      if (data['fecha_cierre'] != null) {
        try {
          _fechaCierre = DateTime.parse(data['fecha_cierre']);
        } catch (e) {}
      }
    }
    _loadAvailableChallenges();
  }

  Future<void> _loadAvailableChallenges() async {
    final available = <Map<String, dynamic>>[];

    try {
      final courses = await SupaFlow.client
          .from('courses')
          .select('id, title, is_active, order_index')
          .eq('is_active', true)
          .order('order_index');
      for (final row in List<Map<String, dynamic>>.from(courses as List)) {
        final id = row['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        available.add({
          'id': id,
          'type': 'course',
          'title': row['title']?.toString().trim() ?? 'Curso',
        });
      }
    } catch (e) {
      debugPrint('Error cargando cursos para convocatoria: $e');
    }

    try {
      final exercises = await SupaFlow.client
          .from('exercises')
          .select('id, title, is_active, order_index')
          .eq('is_active', true)
          .order('order_index');
      for (final row in List<Map<String, dynamic>>.from(exercises as List)) {
        final id = row['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        available.add({
          'id': id,
          'type': 'exercise',
          'title': row['title']?.toString().trim() ?? 'Desafío',
        });
      }
    } catch (e) {
      debugPrint('Error cargando ejercicios para convocatoria: $e');
    }

    final titleByKey = <String, String>{
      for (final item in available)
        '${item['type']}:${item['id']}': item['title']?.toString().trim() ?? '',
    };

    final mergedSelection = _selectedRequiredChallenges
        .map((item) {
          final key = '${item['type']}:${item['id']}';
          final title = item['title']?.toString().trim() ?? '';
          return {
            ...item,
            'title': title.isNotEmpty ? title : (titleByKey[key] ?? ''),
          };
        })
        .where((item) => ((item['id']?.toString() ?? '').trim().isNotEmpty))
        .toList();

    if (!mounted) return;
    setState(() {
      _availableChallenges = available;
      _selectedRequiredChallenges = mergedSelection;
      _isLoadingChallenges = false;
    });
  }

  String _challengeKey(Map<String, dynamic> challenge) {
    final type = challenge['type']?.toString().trim().toLowerCase() ?? '';
    final id = challenge['id']?.toString().trim() ?? '';
    return '$type:$id';
  }

  bool _isRequiredChallengeSelected(Map<String, dynamic> challenge) {
    final key = _challengeKey(challenge);
    return _selectedRequiredChallenges
        .any((item) => _challengeKey(item) == key);
  }

  void _toggleRequiredChallenge(Map<String, dynamic> challenge) {
    final key = _challengeKey(challenge);
    setState(() {
      final existingIndex = _selectedRequiredChallenges
          .indexWhere((item) => _challengeKey(item) == key);
      if (existingIndex >= 0) {
        _selectedRequiredChallenges.removeAt(existingIndex);
      } else {
        _selectedRequiredChallenges.add({
          'id': challenge['id'],
          'type': challenge['type'],
          'title': challenge['title'],
          if (challenge['points'] != null) 'points': challenge['points'],
        });
      }
    });
  }

  Future<void> _save() async {
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El título es requerido'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final requiredChallengesPayload = _selectedRequiredChallenges
          .map((item) => {
                'id': item['id']?.toString().trim(),
                'type': item['type']?.toString().trim().toLowerCase(),
                'title': item['title']?.toString().trim(),
                if (item['points'] != null) 'points': item['points'],
              })
          .where((item) =>
              (item['id']?.toString().isNotEmpty ?? false) &&
              ((item['type'] == 'course') || (item['type'] == 'exercise')))
          .toList();

      final data = {
        'club_id': widget.clubId,
        'titulo': _tituloController.text.trim(),
        'posicion': _posicionController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'categoria': _categoria,
        'tipo': _tipo,
        'edad_minima': int.tryParse(_edadMinController.text) ?? 0,
        'edad_maxima': int.tryParse(_edadMaxController.text) ?? 99,
        'fecha_cierre': _fechaCierre.toIso8601String(),
        'estado': 'activa',
        'required_challenges': requiredChallengesPayload,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isEditing) {
        await SupaFlow.client
            .from('convocatorias')
            .update(data)
            .eq('id', widget.existingData!['id']);
      } else {
        data['created_at'] = DateTime.now().toIso8601String();
        await SupaFlow.client.from('convocatorias').insert(data);
      }

      widget.onCreated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Convocatoria actualizada'
                : 'Convocatoria creada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando convocatoria: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaCierre,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _fechaCierre = picked);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _posicionController.dispose();
    _descripcionController.dispose();
    _edadMinController.dispose();
    _edadMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Editar Convocatoria' : 'Nueva Convocatoria',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D3B66),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey[200]),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('Título *', _tituloController,
                      'Ej: Sub-17 Mediocampistas'),
                  const SizedBox(height: 16),
                  _buildTextField('Posición', _posicionController,
                      'Ej: Mediocampista, Delantero'),
                  const SizedBox(height: 16),
                  _buildTextField('Descripción', _descripcionController,
                      'Describe los requisitos de la convocatoria...',
                      maxLines: 3),
                  const SizedBox(height: 16),

                  // Categoría y Tipo
                  Row(
                    children: [
                      Expanded(
                          child: _buildDropdown(
                              'Categoría',
                              _categoria,
                              _categorias,
                              (v) => setState(() => _categoria = v!))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildDropdown('Tipo', _tipo, _tipos,
                              (v) => setState(() => _tipo = v!))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Edad mínima y máxima
                  Row(
                    children: [
                      Expanded(
                          child: _buildTextField(
                              'Edad Mínima', _edadMinController, '13',
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildTextField(
                              'Edad Máxima', _edadMaxController, '17',
                              keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fecha de cierre
                  Text('Fecha de Cierre',
                      style:
                          GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_fechaCierre.day}/${_fechaCierre.month}/${_fechaCierre.year}',
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                          const Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Desafíos requeridos',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'El jugador deberá completar todos estos desafíos antes de enviar su postulación.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingChallenges)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(
                          color: Color(0xFF0D3B66),
                        ),
                      ),
                    )
                  else if (_availableChallenges.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'No hay desafíos activos disponibles para vincular.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableChallenges.map((challenge) {
                        final selected =
                            _isRequiredChallengeSelected(challenge);
                        final typeLabel =
                            challenge['type'] == 'course' ? 'Curso' : 'Desafío';
                        return FilterChip(
                          selected: selected,
                          onSelected: (_) =>
                              _toggleRequiredChallenge(challenge),
                          label: Text(
                            '$typeLabel · ${challenge['title']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          selectedColor:
                              const Color(0xFF0D3B66).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF0D3B66),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? const Color(0xFF0D3B66)
                                : const Color(0xFF444444),
                          ),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF0D3B66)
                                : const Color(0xFFCBD5E0),
                          ),
                          backgroundColor: Colors.white,
                        );
                      }).toList(),
                    ),
                  if (_selectedRequiredChallenges.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${_selectedRequiredChallenges.length} desafío(s) requerido(s)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Botón Guardar
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isEditing ? 'Guardar Cambios' : 'Crear Convocatoria',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, String hint,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ===== MODAL VER CONVOCATORIA =====
class _ViewConvocatoriaModal extends StatefulWidget {
  const _ViewConvocatoriaModal({
    Key? key,
    required this.convocatoria,
  }) : super(key: key);

  final Map<String, dynamic> convocatoria;

  @override
  State<_ViewConvocatoriaModal> createState() => _ViewConvocatoriaModalState();
}

class _ViewConvocatoriaModalState extends State<_ViewConvocatoriaModal> {
  bool _isLoadingCandidates = true;
  String? _loadError;
  List<Map<String, dynamic>> _candidates = [];

  Map<String, dynamic> get convocatoria => widget.convocatoria;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  String _playerId(Map<String, dynamic> row) => clubApplicationPlayerId(row);

  String _statusLabel(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'aceptado':
      case 'aceptada':
        return 'Aceptado';
      case 'rechazado':
      case 'rechazada':
        return 'Rechazado';
      case 'revisado':
      case 'revisada':
        return 'Revisado';
      default:
        return 'Nuevo';
    }
  }

  Color _statusColor(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'aceptado':
      case 'aceptada':
        return const Color(0xFF16A34A);
      case 'rechazado':
      case 'rechazada':
        return const Color(0xFFDC2626);
      case 'revisado':
      case 'revisada':
        return const Color(0xFF475569);
      default:
        return const Color(0xFF0D3B66);
    }
  }

  int _calculateAge(dynamic birthDate) {
    final parsed = DateTime.tryParse(birthDate?.toString() ?? '');
    if (parsed == null) return 0;
    final now = DateTime.now();
    var age = now.year - parsed.year;
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      age--;
    }
    return age;
  }

  DateTime _submittedAt(Map<String, dynamic> row) {
    final parsed = DateTime.tryParse(row['submitted_at']?.toString() ?? '');
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _updateCandidateStatus(
    Map<String, dynamic> candidate,
    String newStatus,
  ) async {
    final rowId = candidate['id']?.toString().trim() ?? '';
    if (rowId.isEmpty) return;

    final sourceTable =
        candidate['_source_table']?.toString() == 'aplicaciones_convocatoria'
            ? 'aplicaciones_convocatoria'
            : 'postulaciones';

    try {
      await SupaFlow.client.from(sourceTable).update({
        'estado': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', rowId);

      if (!mounted) return;
      setState(() {
        for (final row in _candidates) {
          if ((row['id']?.toString().trim() ?? '') == rowId &&
              (row['_source_table']?.toString() ?? 'postulaciones') ==
                  sourceTable) {
            row['estado'] = newStatus;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado a ${_statusLabel(newStatus)}'),
          backgroundColor: const Color(0xFF0D3B66),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el estado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCandidateStatusMenu(Map<String, dynamic> candidate) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Cambiar estado',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            ...[
              {'value': 'pendiente', 'label': 'Nuevo'},
              {'value': 'revisado', 'label': 'Revisado'},
              {'value': 'aceptado', 'label': 'Aceptado'},
              {'value': 'rechazado', 'label': 'Rechazado'},
            ].map((entry) {
              final value = entry['value']!;
              final label = entry['label']!;
              return ListTile(
                onTap: () {
                  Navigator.pop(ctx);
                  _updateCandidateStatus(candidate, value);
                },
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _statusColor(value),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                title: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCandidates() async {
    final convocatoriaId = convocatoria['id']?.toString().trim() ?? '';
    if (convocatoriaId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingCandidates = false;
        _candidates = [];
      });
      return;
    }

    setState(() {
      _isLoadingCandidates = true;
      _loadError = null;
    });

    try {
      final applications = await fetchClubApplicationsForConvocatorias(
        convocatoriaIds: [convocatoriaId],
        limitPerTable: 240,
      );
      final playerIds = applications
          .map(_playerId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final usersById = <String, Map<String, dynamic>>{};
      if (playerIds.isNotEmpty) {
        final usersResponse = await SupaFlow.client
            .from('users')
            .select()
            .inFilter('user_id', playerIds);
        for (final row in List<Map<String, dynamic>>.from(usersResponse as List)) {
          final id = row['user_id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            usersById[id] = row;
          }
        }
      }

      final requiredChallenges =
          _convocatoriaRequiredChallengesFrom(convocatoria['required_challenges']);
      final attemptByKey = <String, Map<String, dynamic>>{};

      Future<void> loadAttemptsForType(String type, List<String> ids) async {
        if (playerIds.isEmpty || ids.isEmpty) return;
        try {
          final attemptsResponse = await SupaFlow.client
              .from('user_challenge_attempts')
              .select(
                'id, user_id, item_id, item_type, video_url, status, submitted_at, video_id',
              )
              .eq('item_type', type)
              .inFilter('user_id', playerIds)
              .inFilter('item_id', ids);
          for (final row
              in List<Map<String, dynamic>>.from(attemptsResponse as List)) {
            final userId = row['user_id']?.toString().trim() ?? '';
            final itemId = row['item_id']?.toString().trim() ?? '';
            if (userId.isEmpty || itemId.isEmpty) continue;
            attemptByKey['$userId::$type:$itemId'] = row;
          }
        } catch (_) {}
      }

      final requiredCourseIds = requiredChallenges
          .where((item) => item['type'] == 'course')
          .map((item) => item['id']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final requiredExerciseIds = requiredChallenges
          .where((item) => item['type'] == 'exercise')
          .map((item) => item['id']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      await Future.wait([
        loadAttemptsForType('course', requiredCourseIds),
        loadAttemptsForType('exercise', requiredExerciseIds),
      ]);

      final publicVideoByPlayer = <String, Map<String, dynamic>>{};
      if (playerIds.isNotEmpty) {
        try {
          final videosResponse = await SupaFlow.client
              .from('videos')
              .select('id, user_id, title, thumbnail_url, video_url, created_at')
              .eq('is_public', true)
              .inFilter('user_id', playerIds)
              .order('created_at', ascending: false)
              .limit(400);

          for (final video in List<Map<String, dynamic>>.from(videosResponse as List)) {
            final userId = video['user_id']?.toString().trim() ?? '';
            if (userId.isEmpty) continue;
            publicVideoByPlayer.putIfAbsent(userId, () => video);
          }
        } catch (_) {}
      }

      final candidates = applications.map((application) {
        final playerId = _playerId(application);
        final attemptVideos = requiredChallenges
            .map((challenge) {
              final type = challenge['type']?.toString().trim() ?? '';
              final id = challenge['id']?.toString().trim() ?? '';
              final attempt = attemptByKey['$playerId::$type:$id'];
              if (attempt == null) return null;
              return {
                ...attempt,
                'challenge_title': _convocatoriaChallengeTitle(challenge),
                'challenge_type': type,
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList()
          ..sort((a, b) => _submittedAt(b).compareTo(_submittedAt(a)));

        return {
          ...application,
          'jugador': usersById[playerId],
          'attempt_videos': attemptVideos,
          'required_videos_total': requiredChallenges.length,
          'latest_public_video': publicVideoByPlayer[playerId],
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _isLoadingCandidates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoadingCandidates = false;
      });
    }
  }

  Future<void> _openVideo(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    try {
      await launchURL(cleanUrl);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el video.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openPlayerProfile(String playerId) {
    if (playerId.trim().isEmpty) return;
    Navigator.of(context).pop();
    context.pushNamed(
      'perfil_profesional_solicitar_Contato',
      queryParameters: {'userId': playerId},
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> candidate) {
    final jugador = candidate['jugador'] as Map<String, dynamic>?;
    final name = jugador?['name']?.toString().trim() ?? '';
    final lastname = jugador?['lastname']?.toString().trim() ?? '';
    final playerId = _playerId(candidate);
    final fullName = '$name $lastname'.trim().isEmpty
        ? 'Jugador sin nombre'
        : '$name $lastname'.trim();
    final position = jugador?['posicion']?.toString().trim() ?? '';
    final city = jugador?['city']?.toString().trim() ?? '';
    final age = _calculateAge(jugador?['birthday'] ?? jugador?['birth_date']);
    final status = candidate['estado']?.toString().trim() ?? 'pendiente';
    final attemptVideos =
        List<Map<String, dynamic>>.from(candidate['attempt_videos'] ?? const []);
    final latestPublicVideo =
        candidate['latest_public_video'] as Map<String, dynamic>?;
    final primaryVideoUrl = attemptVideos.isNotEmpty
        ? attemptVideos.first['video_url']?.toString() ?? ''
        : latestPublicVideo?['video_url']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (position.isNotEmpty) position,
                        if (age > 0) '$age años',
                        if (city.isNotEmpty) city,
                      ].join(' • ').isEmpty
                          ? 'Perfil pendiente de completar'
                          : [
                              if (position.isNotEmpty) position,
                              if (age > 0) '$age años',
                              if (city.isNotEmpty) city,
                            ].join(' • '),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: InkWell(
                  onTap: () => _showCandidateStatusMenu(candidate),
                  borderRadius: BorderRadius.circular(999),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _statusLabel(status),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              candidate['required_videos_total'] == 0
                  ? 'Esta convocatoria no tiene desafíos requeridos. Se muestra como apoyo el último video público del jugador.'
                  : '${attemptVideos.length}/${candidate['required_videos_total']} desafíos requeridos con video encontrado.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          if (attemptVideos.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...attemptVideos.map((attempt) {
              final challengeTitle =
                  attempt['challenge_title']?.toString().trim() ?? 'Desafío';
              final submittedAt = DateTime.tryParse(
                attempt['submitted_at']?.toString() ?? '',
              );
              final videoUrl = attempt['video_url']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD6DEE8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challengeTitle,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            submittedAt != null
                                ? 'Enviado el ${submittedAt.day.toString().padLeft(2, '0')}/${submittedAt.month.toString().padLeft(2, '0')}/${submittedAt.year}'
                                : 'Video enviado',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: videoUrl.isEmpty ? null : () => _openVideo(videoUrl),
                      child: const Text('Ver video'),
                    ),
                  ],
                ),
              );
            }),
          ] else if (latestPublicVideo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6DEE8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'No se encontró video de desafío asociado. Se muestra el último video público disponible.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _openVideo(
                      latestPublicVideo['video_url']?.toString() ?? '',
                    ),
                    child: const Text('Ver video'),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Todavía no hay video visible para este jugador dentro de esta convocatoria.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 160,
                child: OutlinedButton(
                  onPressed:
                      playerId.isEmpty ? null : () => _openPlayerProfile(playerId),
                  child: const Text('Ver perfil'),
                ),
              ),
              SizedBox(
                width: 160,
                child: ElevatedButton(
                  onPressed: primaryVideoUrl.trim().isEmpty
                      ? null
                      : () => _openVideo(primaryVideoUrl),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                  ),
                  child: const Text(
                    'Abrir video',
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

  @override
  Widget build(BuildContext context) {
    final titulo = convocatoria['titulo'] ?? 'Sin título';
    final posicion = convocatoria['posicion'] ?? '-';
    final descripcion = convocatoria['descripcion'] ?? '-';
    final categoria = convocatoria['categoria'] ?? '-';
    final tipo = convocatoria['tipo'] ?? '-';
    final estado = convocatoria['estado'] ?? 'activa';
    final postulaciones = convocatoria['postulaciones_count'] ?? 0;
    final requiredChallenges = _convocatoriaRequiredChallengesFrom(
        convocatoria['required_challenges']);
    final challengeLabels = requiredChallenges.isNotEmpty
        ? requiredChallenges.map(_convocatoriaChallengeTitle).toList()
        : (convocatoria['ejercicios'] as List? ?? [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detalles de Convocatoria',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D3B66),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Título', titulo),
                  _buildDetailRow('Posición', posicion),
                  _buildDetailRow('Categoría', categoria),
                  _buildDetailRow('Tipo', tipo),
                  _buildDetailRow('Estado', estado),
                  _buildDetailRow('Postulaciones', postulaciones.toString()),
                  _buildDetailRow(
                    'Desafíos requeridos',
                    challengeLabels.length.toString(),
                  ),
                  const SizedBox(height: 16),
                  Text('Descripción',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(descripcion,
                      style: GoogleFonts.inter(color: Colors.grey[700])),
                  if (challengeLabels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Lista de desafíos requeridos',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: challengeLabels
                          .map((challenge) => _buildChallengeTag(challenge))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Postulantes y videos',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Se muestran las solicitudes consolidadas de la convocatoria y, cuando existen, los videos asociados a sus desafíos requeridos.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingCandidates)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: Color(0xFF0D3B66),
                        ),
                      ),
                    )
                  else if (_loadError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        'No se pudieron cargar los postulantes: $_loadError',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                    )
                  else if (_candidates.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Todavía no hay postulaciones para esta convocatoria.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    )
                  else
                    ..._candidates.map(_buildCandidateCard),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.grey[600])),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildChallengeTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6DEE8)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0D3B66),
        ),
      ),
    );
  }
}
