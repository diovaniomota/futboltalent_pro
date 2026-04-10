import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/fluxo_compartilhado/club_application_utils.dart';
import '/fluxo_compartilhado/club_identity_utils.dart';
import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:google_fonts/google_fonts.dart';
import 'postulaciones_model.dart';
export 'postulaciones_model.dart';

class PostulacionesWidget extends StatefulWidget {
  const PostulacionesWidget({super.key});

  static String routeName = 'postulaciones';
  static String routePath = '/postulaciones';

  @override
  State<PostulacionesWidget> createState() => _PostulacionesWidgetState();
}

class _PostulacionesWidgetState extends State<PostulacionesWidget> {
  late PostulacionesModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String? _clubId;
  Set<String> _clubRefs = <String>{};

  // Stats
  int _convocatoriasActivas = 0;
  int _totalPostulaciones = 0;
  int _totalVideos = 0;
  double _promedioPostulaciones = 0;

  // Postulaciones recientes
  List<Map<String, dynamic>> _postulacionesRecientes = [];
  String? _clubName;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PostulacionesModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // ============ RESPONSIVE HELPERS ============
  double _responsive(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return desktop ?? tablet ?? mobile;
    if (width >= 600) return tablet ?? mobile;
    return mobile;
  }

  bool _isMediumScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;
  bool _isLargeScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  double _scaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 320) return 0.8;
    if (width < 360) return 0.9;
    if (width >= 1024) return 1.1;
    return 1.0;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _resolveClubContext();

    // Carregar stats e postulaciones
    if (_clubId != null && _clubId!.isNotEmpty) {
      await _loadStats();
      await _loadPostulacionesRecientes();
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

  Future<List<Map<String, dynamic>>> _loadConvocatoriasRows() async {
    if (_clubRefs.isEmpty) return [];

    final response = _clubRefs.length == 1
        ? await SupaFlow.client
            .from('convocatorias')
            .select('id, estado, titulo, categoria, posicion, pais, ubicacion')
            .eq('club_id', _clubRefs.first)
        : await SupaFlow.client
            .from('convocatorias')
            .select('id, estado, titulo, categoria, posicion, pais, ubicacion')
            .inFilter('club_id', _clubRefs.toList());

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> _loadStats() async {
    try {
      final convocatorias = await _loadConvocatoriasRows();
      final convocatoriaIds = convocatorias
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      _convocatoriasActivas = convocatorias
          .where((c) => c['estado']?.toString().toLowerCase() == 'activa')
          .length;
      final postulaciones = await fetchClubApplicationsForConvocatorias(
        convocatoriaIds: convocatoriaIds,
        limitPerTable: 800,
      );
      _totalPostulaciones = postulaciones.length;

      if (_convocatoriasActivas > 0) {
        _promedioPostulaciones = _totalPostulaciones / _convocatoriasActivas;
      }

      final playerIds = postulaciones
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
      debugPrint('❌ Error cargando stats: $e');
    }
  }

  Future<void> _loadPostulacionesRecientes() async {
    try {
      final convocatorias = await _loadConvocatoriasRows();
      final convocatoriaIds = convocatorias
          .map((c) => c['id'].toString())
          .toList();
      final convocatoriasById = <String, Map<String, dynamic>>{};
      for (final row in convocatorias) {
        final id = row['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          convocatoriasById[id] = row;
        }
      }

      if (convocatoriaIds.isEmpty) {
        _postulacionesRecientes = [];
        return;
      }

      final postulaciones = await fetchClubApplicationsForConvocatorias(
        convocatoriaIds: convocatoriaIds,
        limitPerTable: 40,
      );
      _postulacionesRecientes = postulaciones.take(10).toList();

      final playerIds = _postulacionesRecientes
          .map(clubApplicationPlayerId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (playerIds.isEmpty) return;

      final jugadoresResponse = await SupaFlow.client
          .from('users')
          .select()
          .inFilter('user_id', playerIds);

      final jugadoresById = <String, Map<String, dynamic>>{};
      for (final row in List<Map<String, dynamic>>.from(jugadoresResponse as List)) {
        final id = row['user_id']?.toString() ?? '';
        if (id.isNotEmpty) {
          jugadoresById[id] = row;
        }
      }

      for (final post in _postulacionesRecientes) {
        final playerId = clubApplicationPlayerId(post);
        if (playerId.isNotEmpty && jugadoresById.containsKey(playerId)) {
          post['jugador'] = jugadoresById[playerId];
        }
        final convocatoriaId = post['convocatoria_id']?.toString().trim() ?? '';
        if (convocatoriaId.isNotEmpty && convocatoriasById.containsKey(convocatoriaId)) {
          post['convocatoria'] = convocatoriasById[convocatoriaId];
          post['convocatoria_titulo'] =
              convocatoriasById[convocatoriaId]?['titulo'];
        }
      }

      final latestVideoByPlayer = <String, Map<String, dynamic>>{};
      if (playerIds.isNotEmpty) {
        try {
          final videosResponse = await SupaFlow.client
              .from('videos')
              .select('id, user_id, title, thumbnail_url, video_url, created_at')
              .eq('is_public', true)
              .inFilter('user_id', playerIds)
              .order('created_at', ascending: false)
              .limit(200);

          for (final row in List<Map<String, dynamic>>.from(videosResponse as List)) {
            final playerId = row['user_id']?.toString().trim() ?? '';
            if (playerId.isEmpty) continue;
            latestVideoByPlayer.putIfAbsent(playerId, () => row);
          }
        } catch (_) {}
      }

      for (final post in _postulacionesRecientes) {
        final playerId = clubApplicationPlayerId(post);
        post['latest_video'] = latestVideoByPlayer[playerId];
        post['has_video'] = latestVideoByPlayer[playerId] != null;
      }
    } catch (e) {
      debugPrint('❌ Error cargando postulaciones: $e');
    }
  }

  int _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return 0;
    try {
      final birth = DateTime.parse(birthDate);
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

  String _playerInitials(Map<String, dynamic>? jugador) {
    final name = jugador?['name']?.toString().trim() ?? '';
    final lastname = jugador?['lastname']?.toString().trim() ?? '';
    String initials = '';
    if (name.isNotEmpty) initials += name[0].toUpperCase();
    if (lastname.isNotEmpty) initials += lastname[0].toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  Future<void> _updatePostulacionStatus(
      Map<String, dynamic> postulacion, String newStatus) async {
    final postulacionId = postulacion['id']?.toString() ?? '';
    if (postulacionId.isEmpty) return;
    final sourceTable =
        postulacion['_source_table']?.toString() == 'aplicaciones_convocatoria'
            ? 'aplicaciones_convocatoria'
            : 'postulaciones';
    try {
      await SupaFlow.client.from(sourceTable).update({
        'estado': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', postulacionId);

      await _loadPostulacionesRecientes();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Estado actualizado a: ${_getStatusLabel(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getStatusLabel(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
      case 'nuevo':
        return 'Nuevo';
      case 'revisado':
      case 'revisada':
        return 'Revisado';
      case 'aceptado':
      case 'aceptada':
        return 'Aceptado';
      case 'rechazado':
      case 'rechazada':
        return 'Rechazado';
      default:
        return 'Nuevo';
    }
  }

  ({Color background, Color foreground, IconData icon}) _statusVisuals(
      String estado) {
    switch (estado.toLowerCase()) {
      case 'revisado':
      case 'revisada':
        return (
          background: const Color(0xFFEFF6FF),
          foreground: const Color(0xFF1D4ED8),
          icon: Icons.visibility_rounded,
        );
      case 'aceptado':
      case 'aceitada':
        return (
          background: const Color(0xFFDCFCE7),
          foreground: const Color(0xFF166534),
          icon: Icons.check_circle_rounded,
        );
      case 'rechazado':
      case 'rechazada':
        return (
          background: const Color(0xFFFEE2E2),
          foreground: const Color(0xFFB91C1C),
          icon: Icons.close_rounded,
        );
      case 'pendiente':
      case 'nuevo':
      default:
        return (
          background: const Color(0xFF111827),
          foreground: Colors.white,
          icon: Icons.fiber_new_rounded,
        );
    }
  }

  Widget _buildStatusBadge(String estado, {double scale = 1}) {
    final palette = _statusVisuals(estado);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(palette.icon, size: 14 * scale, color: palette.foreground),
          SizedBox(width: 6 * scale),
          Text(
            _getStatusLabel(estado),
            style: GoogleFonts.inter(
              fontSize: 11.5 * scale,
              fontWeight: FontWeight.w700,
              color: palette.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostulacionActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool primary = false,
  }) {
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: primary ? Colors.white : const Color(0xFF0D3B66),
      ),
    );

    if (primary) {
      return SizedBox(
        height: 42,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF0D3B66),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(icon, size: 16),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: labelWidget,
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0D3B66),
          side: const BorderSide(color: Color(0xFFDCE3EC)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: labelWidget,
        ),
      ),
    );
  }

  Future<void> _openVideo(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return;
    try {
      await launchURL(url);
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

  void _showClubMenu(BuildContext ctx) {
    final drawerWidth =
        _responsive(context, mobile: 0.8, tablet: 0.5, desktop: 0.35);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        pageBuilder: (modalCtx, animation, secondaryAnimation) {
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
                  width: MediaQuery.of(ctx).size.width * drawerWidth,
                  height: double.infinity,
                  color: Colors.white,
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.all(_responsive(ctx,
                              mobile: 16, tablet: 20, desktop: 24)),
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Color(0xFFE0E0E0))),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: _responsive(ctx,
                                    mobile: 36, tablet: 40, desktop: 44),
                                height: _responsive(ctx,
                                    mobile: 36, tablet: 40, desktop: 44),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D3B66),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(Icons.settings,
                                    color: Colors.white,
                                    size: _responsive(ctx,
                                        mobile: 20, tablet: 24, desktop: 26)),
                              ),
                              SizedBox(
                                  width: _responsive(ctx,
                                      mobile: 10, tablet: 12, desktop: 14)),
                              Expanded(
                                child: Text(
                                  'Menú del club',
                                  style: GoogleFonts.inter(
                                    fontSize: _responsive(ctx,
                                        mobile: 16, tablet: 18, desktop: 20),
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D3B66),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
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
                                  context, // Use parent context for navigation
                                  Icons.dashboard_outlined,
                                  'Dashboard',
                                  false,
                                  () async => context.pushNamed(
                                      DashboardClubWidget.routeName)),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.campaign_outlined,
                                  'Convocatorias',
                                  false,
                                  () async => context.pushNamed(
                                      ConvocatoriasClubWidget.routeName)),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.people_outline,
                                  'Jugadores',
                                  true,
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
                                    'Logout callback triggered in Postulaciones');
                                try {
                                  await authManager.signOut();
                                  if (ctx.mounted) {
                                    ctx.goNamed('login');
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
    final scale = _scaleFactor(context);

    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFF0D3B66) : Colors.grey[600],
          size: 22 * scale),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14 * scale,
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
        // Find the Navigator of the Drawer (which has opaque false) and pop it
        Navigator.of(context, rootNavigator: true).pop();
        if (!isSelected && onTap != null) {
          // Small delay to ensure drawer is closing
          await Future.delayed(const Duration(milliseconds: 100));
          await onTap();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFactor(context);
    final padding = _responsive(context, mobile: 16, tablet: 24, desktop: 32);
    final maxContentWidth = _responsive(context,
        mobile: double.infinity, tablet: 800, desktop: 1000);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
                )
              : Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.white,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return RefreshIndicator(
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxContentWidth == double.infinity
                                    ? constraints.maxWidth
                                    : maxContentWidth,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(padding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Menu icon
                                    GestureDetector(
                                      onTap: () => _showClubMenu(context),
                                      child: Icon(Icons.menu,
                                          color: Colors.black, size: 24 * scale),
                                    ),
                                    SizedBox(height: 20 * scale),

                                    // Título
                                    Text(
                                      'Jugadores',
                                      style: GoogleFonts.inter(
                                        fontSize: _responsive(context,
                                                mobile: 24,
                                                tablet: 28,
                                                desktop: 32) *
                                            scale,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
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
                                    SizedBox(height: 20 * scale),

                                    // Stats - Layout responsivo
                                    _buildResponsiveStats(context),
                                    SizedBox(height: 24 * scale),

                                    // Postulaciones Recientes
                                    _buildPostulacionesRecientes(context),
                                    SizedBox(height: 32 * scale),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildResponsiveStats(BuildContext context) {
    final scale = _scaleFactor(context);
    final spacing = _responsive(context, mobile: 12, tablet: 16, desktop: 20);

    // Em telas grandes, mostrar 4 cards em uma linha
    if (_isLargeScreen(context)) {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context: context,
              title: 'Convocatorias\nActivas',
              value: _convocatoriasActivas.toString(),
              icon: Icons.groups_outlined,
              subtitle: 'En curso',
              trend: '+18%',
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: _buildStatCard(
              context: context,
              title: 'Promedio por\nConvocatoria',
              value: _promedioPostulaciones.toStringAsFixed(0),
              icon: Icons.calendar_today_outlined,
              subtitle: 'En curso',
              trend: '+15%',
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: _buildStatCard(
              context: context,
              title: 'Total\nPostulaciones',
              value: _totalPostulaciones.toString(),
              icon: Icons.groups_outlined,
              subtitle: 'Todas las convocatorias',
              trend: '+25%',
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: _buildStatCard(
              context: context,
              title: 'Total videos\nSubidos',
              value: _totalVideos.toString(),
              icon: Icons.videocam_outlined,
              subtitle: 'En curso',
              trend: '+3%',
            ),
          ),
        ],
      );
    }

    // Em telas médias e pequenas, mostrar 2x2
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                title: 'Convocatorias\nActivas',
                value: _convocatoriasActivas.toString(),
                icon: Icons.groups_outlined,
                subtitle: 'En curso',
                trend: '+18%',
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _buildStatCard(
                context: context,
                title: 'Promedio por\nConvocatoria',
                value: _promedioPostulaciones.toStringAsFixed(0),
                icon: Icons.calendar_today_outlined,
                subtitle: 'En curso',
                trend: '+15%',
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                title: 'Total\nPostulaciones',
                value: _totalPostulaciones.toString(),
                icon: Icons.groups_outlined,
                subtitle: 'Todas las convocatorias\nactivas',
                trend: '+25%',
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _buildStatCard(
                context: context,
                title: 'Total videos\nSubidos',
                value: _totalVideos.toString(),
                icon: Icons.videocam_outlined,
                subtitle: 'En curso',
                trend: '+3%',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required String subtitle,
    String? trend,
  }) {
    final scale = _scaleFactor(context);
    final padding = _responsive(context, mobile: 14, tablet: 16, desktop: 20);
    final titleSize =
        _responsive(context, mobile: 11, tablet: 12, desktop: 13) * scale;
    final valueSize =
        _responsive(context, mobile: 26, tablet: 30, desktop: 34) * scale;
    final subtitleSize =
        _responsive(context, mobile: 10, tablet: 11, desktop: 12) * scale;
    final iconSize =
        _responsive(context, mobile: 18, tablet: 20, desktop: 22) * scale;
    final borderRadius =
        _responsive(context, mobile: 12, tablet: 14, desktop: 16);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
              Icon(icon, color: Colors.grey[400], size: iconSize),
            ],
          ),
          SizedBox(height: 10 * scale),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: valueSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              if (trend != null) ...[
                SizedBox(width: 6 * scale),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6 * scale,
                    vertical: 3 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: Colors.green[600],
                        size: 12 * scale,
                      ),
                      SizedBox(width: 2 * scale),
                      Text(
                        trend,
                        style: GoogleFonts.inter(
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: subtitleSize,
              color: Colors.grey[500],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostulacionesRecientes(BuildContext context) {
    final scale = _scaleFactor(context);
    final padding = _responsive(context, mobile: 16, tablet: 20, desktop: 24);
    final titleSize =
        _responsive(context, mobile: 18, tablet: 20, desktop: 22) * scale;
    final subtitleSize =
        _responsive(context, mobile: 12, tablet: 13, desktop: 14) * scale;
    final borderRadius =
        _responsive(context, mobile: 18, tablet: 20, desktop: 22);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x120D3B66),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38 * scale,
                height: 38 * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: const Color(0xFF0D3B66),
                  size: 20 * scale,
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Postulaciones recientes',
                      style: GoogleFonts.inter(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3 * scale),
                    Text(
                      'Últimos jugadores que se han postulado',
                      style: GoogleFonts.inter(
                        fontSize: subtitleSize,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),

          if (_postulacionesRecientes.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32 * scale),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 48 * scale, color: Colors.grey[300]),
                    SizedBox(height: 8 * scale),
                    Text(
                      'No hay postulaciones recientes',
                      style: GoogleFonts.inter(
                        fontSize: 14 * scale,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._postulacionesRecientes
                .map((post) => _buildPostulacionItem(context, post))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildPostulacionItem(
      BuildContext context, Map<String, dynamic> postulacion) {
    final scale = _scaleFactor(context);
    final jugador = postulacion['jugador'] as Map<String, dynamic>?;
    final name = jugador?['name'] ?? '';
    final lastname = jugador?['lastname'] ?? '';
    final fullName = '$name ${lastname.isNotEmpty ? lastname[0] + '.' : ''}'.trim();
    final position = (jugador?['posicion'] ?? '').toString().trim();
    final country = (jugador?['city'] ?? '').toString().trim();
    final age = _calculateAge(jugador?['birthday']);
    final estado = postulacion['estado']?.toString() ?? 'pendiente';
    final jugadorId = jugador?['user_id']?.toString() ?? '';
    final latestVideo = postulacion['latest_video'] as Map<String, dynamic>?;
    final latestVideoUrl = latestVideo?['video_url']?.toString().trim() ?? '';
    final latestVideoThumb =
        latestVideo?['thumbnail_url']?.toString().trim() ?? '';
    final hasVideo = latestVideoUrl.isNotEmpty || postulacion['has_video'] == true;
    final convocatoria = postulacion['convocatoria'] as Map<String, dynamic>?;
    final convocatoriaTitle = (postulacion['convocatoria_titulo'] ??
            convocatoria?['titulo'] ??
            'Convocatoria')
        .toString()
        .trim();
    final metaParts = <String>[
      if (age > 0) '$age años',
      if (position.isNotEmpty) position,
      if (country.isNotEmpty) country,
    ];
    final photoUrl = jugador?['photo_url']?.toString().trim() ?? '';
    final borderRadius =
        _responsive(context, mobile: 16, tablet: 18, desktop: 20);

    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D3B66),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26 * scale,
                    backgroundColor: const Color(0xFFE8F0FE),
                    backgroundImage: latestVideoThumb.isNotEmpty
                        ? NetworkImage(latestVideoThumb)
                        : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null),
                    child: latestVideoThumb.isEmpty && photoUrl.isEmpty
                        ? Text(
                            _playerInitials(jugador),
                            style: GoogleFonts.inter(
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D3B66),
                            ),
                          )
                        : null,
                  ),
                  if (hasVideo)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20 * scale,
                        height: 20 * scale,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 14 * scale,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : 'Jugador',
                      style: GoogleFonts.inter(
                        fontSize: 15 * scale,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (metaParts.isNotEmpty) ...[
                      SizedBox(height: 4 * scale),
                      Text(
                        metaParts.join(' • '),
                        style: GoogleFonts.inter(
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 8 * scale),
                    Row(
                      children: [
                        Flexible(
                          child: _buildStatusBadge(estado, scale: scale),
                        ),
                        SizedBox(width: 8 * scale),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: PopupMenuButton<String>(
                            splashRadius: 18,
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              size: 20 * scale,
                              color: const Color(0xFF475569),
                            ),
                            onSelected: (value) =>
                                _updatePostulacionStatus(postulacion, value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'pendiente', child: Text('Nuevo')),
                              PopupMenuItem(value: 'revisado', child: Text('Revisado')),
                              PopupMenuItem(value: 'aceptado', child: Text('Aceptado')),
                              PopupMenuItem(value: 'rechazado', child: Text('Rechazado')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 10 * scale,
              vertical: 9 * scale,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 16 * scale,
                  color: const Color(0xFF0D3B66),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    convocatoriaTitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5 * scale,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10 * scale),
          Row(
            children: [
              Expanded(
                child: _buildPostulacionActionButton(
                  context: context,
                  label: 'Ver perfil',
                  icon: Icons.person_outline_rounded,
                  onPressed: () {
                    if (jugadorId.isNotEmpty) {
                      context.pushNamed(
                        'perfil_profesional_solicitar_Contato',
                        queryParameters: {'userId': jugadorId},
                      );
                    } else {
                      _showPlayerDetail(postulacion);
                    }
                  },
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: _buildPostulacionActionButton(
                  context: context,
                  label: 'Ver video',
                  icon: Icons.play_circle_outline_rounded,
                  onPressed:
                      hasVideo ? () => _openVideo(latestVideoUrl) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWidePostulacionLayout(
    BuildContext context,
    String fullName,
    String position,
    int age,
    String country,
    String estado,
    bool isRevisado,
    String jugadorId,
    String postulacionId,
    Map<String, dynamic> postulacion,
    double nameFontSize,
    double detailFontSize,
    double buttonFontSize,
    double scale,
  ) {
    final latestVideoUrl =
        postulacion['latest_video']?['video_url']?.toString().trim() ?? '';
    final hasVideo = latestVideoUrl.isNotEmpty || postulacion['has_video'] == true;

    return Row(
      children: [
        // Info del jugador
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName.isNotEmpty ? fullName : 'Sin nombre',
                style: GoogleFonts.inter(
                  fontSize: nameFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                '$position • $age años • $country',
                style: GoogleFonts.inter(
                  fontSize: detailFontSize,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),

        // Status badge
        GestureDetector(
          onTap: () => _showStatusMenu(postulacion, estado),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 8 * scale,
            ),
            decoration: BoxDecoration(
              color: isRevisado ? const Color(0xFF6B7280) : Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getStatusLabel(estado),
              style: GoogleFonts.inter(
                fontSize: buttonFontSize,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(width: 8 * scale),

        if (hasVideo) ...[
          GestureDetector(
            onTap: latestVideoUrl.isEmpty ? null : () => _openVideo(latestVideoUrl),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 8 * scale,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ver video',
                style: GoogleFonts.inter(
                  fontSize: buttonFontSize,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0D3B66),
                ),
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
        ],

        // Ver Perfil button
        GestureDetector(
          onTap: () {
            if (jugadorId.isNotEmpty) {
              context.pushNamed('perfil_profesional_solicitar_Contato',
                  queryParameters: {'userId': jugadorId});
            } else {
              _showPlayerDetail(postulacion);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 8 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Text(
              'Ver Perfil',
              style: GoogleFonts.inter(
                fontSize: buttonFontSize,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactPostulacionLayout(
    BuildContext context,
    String fullName,
    String position,
    int age,
    String country,
    String estado,
    bool isRevisado,
    String jugadorId,
    String postulacionId,
    Map<String, dynamic> postulacion,
    double nameFontSize,
    double detailFontSize,
    double buttonFontSize,
    double scale,
  ) {
    final latestVideoUrl =
        postulacion['latest_video']?['video_url']?.toString().trim() ?? '';
    final hasVideo = latestVideoUrl.isNotEmpty || postulacion['has_video'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info del jugador
        Text(
          fullName.isNotEmpty ? fullName : 'Sin nombre',
          style: GoogleFonts.inter(
            fontSize: nameFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          '$position • $age años • $country',
          style: GoogleFonts.inter(
            fontSize: detailFontSize,
            color: Colors.grey[500],
          ),
        ),
        SizedBox(height: 12 * scale),

        // Botões
        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: [
            // Status badge
            GestureDetector(
              onTap: () => _showStatusMenu(postulacion, estado),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14 * scale,
                  vertical: 8 * scale,
                ),
                decoration: BoxDecoration(
                  color: isRevisado ? const Color(0xFF6B7280) : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusLabel(estado),
                  style: GoogleFonts.inter(
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Ver Perfil button
            GestureDetector(
              onTap: () {
                if (jugadorId.isNotEmpty) {
                  context.pushNamed('perfil_profesional_solicitar_Contato',
                      queryParameters: {'userId': jugadorId});
                } else {
                  _showPlayerDetail(postulacion);
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale,
                  vertical: 8 * scale,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: Text(
                  'Ver Perfil',
                  style: GoogleFonts.inter(
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            if (hasVideo)
              GestureDetector(
                onTap:
                    latestVideoUrl.isEmpty ? null : () => _openVideo(latestVideoUrl),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12 * scale,
                    vertical: 8 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ver video',
                    style: GoogleFonts.inter(
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showStatusMenu(
      Map<String, dynamic> postulacion, String currentStatus) {
    final scale = _scaleFactor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20 * scale),
            Text(
              'Cambiar Estado',
              style: GoogleFonts.inter(
                fontSize: 18 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20 * scale),
            _buildStatusOption(
                'pendiente', 'Nuevo', Colors.black, postulacion),
            _buildStatusOption(
                'revisado', 'Revisado', const Color(0xFF6B7280), postulacion),
            _buildStatusOption(
                'aceptado', 'Aceptado', const Color(0xFF22C55E), postulacion),
            _buildStatusOption('rechazado', 'Rechazado',
                const Color(0xFFEF4444), postulacion),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
      String status, String label, Color color, Map<String, dynamic> postulacion) {
    final scale = _scaleFactor(context);

    return ListTile(
      leading: Container(
        width: 24 * scale,
        height: 24 * scale,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      title: Text(label,
          style: GoogleFonts.inter(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w500,
          )),
      onTap: () {
        Navigator.pop(context);
        _updatePostulacionStatus(postulacion, status);
      },
    );
  }

  void _showPlayerDetail(Map<String, dynamic> postulacion) {
    final scale = _scaleFactor(context);
    final jugador = postulacion['jugador'] as Map<String, dynamic>?;
    final name = jugador?['name'] ?? '';
    final lastname = jugador?['lastname'] ?? '';
    final fullName = '$name $lastname'.trim();
    final position = jugador?['posicion'] ?? '';
    final country = jugador?['city'] ?? '';
    final age = _calculateAge(jugador?['birthday']);
    final photoUrl = jugador?['photo_url'];
    final mensaje = postulacion['mensaje'] ?? '';
    final latestVideoUrl =
        postulacion['latest_video']?['video_url']?.toString().trim() ?? '';

    String initials = '';
    if (name.isNotEmpty) initials += name[0].toUpperCase();
    if (lastname.isNotEmpty) initials += lastname[0].toUpperCase();

    final modalHeight =
        _responsive(context, mobile: 0.6, tablet: 0.5, desktop: 0.45);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * modalHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12 * scale),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detalle del Jugador',
                    style: GoogleFonts.inter(
                      fontSize: _responsive(context,
                              mobile: 16, tablet: 18, desktop: 20) *
                          scale,
                      fontWeight: FontWeight.bold,
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
                padding: EdgeInsets.all(16 * scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Player info
                    Row(
                      children: [
                        Container(
                          width: _responsive(context,
                                  mobile: 50, tablet: 60, desktop: 70) *
                              scale,
                          height: _responsive(context,
                                  mobile: 50, tablet: 60, desktop: 70) *
                              scale,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECECF0),
                            borderRadius: BorderRadius.circular(30 * scale),
                            image: photoUrl != null && photoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(photoUrl),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: photoUrl == null || photoUrl.isEmpty
                              ? Center(
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.inter(
                                      fontSize: 18 * scale,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: 16 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: GoogleFonts.inter(
                                  fontSize: _responsive(context,
                                          mobile: 16, tablet: 18, desktop: 20) *
                                      scale,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$position • $age años',
                                style: GoogleFonts.inter(
                                  fontSize: 14 * scale,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                country,
                                style: GoogleFonts.inter(
                                  fontSize: 14 * scale,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Mensaje
                    if (mensaje.isNotEmpty) ...[
                      SizedBox(height: 24 * scale),
                      Text(
                        'Mensaje del jugador',
                        style: GoogleFonts.inter(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12 * scale),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          mensaje,
                          style: GoogleFonts.inter(fontSize: 14 * scale),
                        ),
                      ),
                    ],
                    if (latestVideoUrl.isNotEmpty) ...[
                      SizedBox(height: 24 * scale),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openVideo(latestVideoUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D3B66),
                            padding: EdgeInsets.symmetric(vertical: 14 * scale),
                          ),
                          icon: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Ver video enviado',
                            style: GoogleFonts.inter(
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Botones de acción
            Container(
              padding: EdgeInsets.fromLTRB(16 * scale, 12 * scale, 16 * scale,
                  MediaQuery.of(context).padding.bottom + 16 * scale),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updatePostulacionStatus(postulacion, 'rechazado');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 14 * scale),
                      ),
                      child: Text('Rechazar',
                          style: GoogleFonts.inter(
                            fontSize: 14 * scale,
                            color: Colors.red,
                          )),
                    ),
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updatePostulacionStatus(postulacion, 'aceptado');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 14 * scale),
                      ),
                      child: Text('Aceptar',
                          style: GoogleFonts.inter(
                            fontSize: 14 * scale,
                            color: Colors.white,
                          )),
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
}
