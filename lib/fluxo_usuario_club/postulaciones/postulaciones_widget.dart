import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_theme.dart';
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

    _clubId = currentUserUid;

    // Carregar nome do club (não bloqueia o resto se falhar)
    try {
      final clubResponse = await SupaFlow.client
          .from('clubs')
          .select('nombre')
          .eq('owner_id', _clubId!)
          .maybeSingle();
      if (clubResponse != null && clubResponse['nombre'] != null) {
        _clubName = clubResponse['nombre'];
      }
    } catch (e) {
      debugPrint('Club name not found: $e');
    }

    // Carregar stats e postulaciones
    if (_clubId != null && _clubId!.isNotEmpty) {
      await _loadStats();
      await _loadPostulacionesRecientes();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final convocatoriasResponse = await SupaFlow.client
          .from('convocatorias')
          .select('id, estado')
          .eq('club_id', _clubId!);

      final convocatorias =
          List<Map<String, dynamic>>.from(convocatoriasResponse);

      _convocatoriasActivas = convocatorias
          .where((c) => c['estado']?.toString().toLowerCase() == 'activa')
          .length;

      int totalPostulaciones = 0;
      for (var conv in convocatorias) {
        try {
          final postResponse = await SupaFlow.client
              .from('postulaciones')
              .select('id')
              .eq('convocatoria_id', conv['id']);

          totalPostulaciones += (postResponse as List).length;
        } catch (e) {}
      }
      _totalPostulaciones = totalPostulaciones;

      if (_convocatoriasActivas > 0) {
        _promedioPostulaciones = _totalPostulaciones / _convocatoriasActivas;
      }

      _totalVideos = 0;
    } catch (e) {
      debugPrint('❌ Error cargando stats: $e');
    }
  }

  Future<void> _loadPostulacionesRecientes() async {
    try {
      final convocatoriasResponse = await SupaFlow.client
          .from('convocatorias')
          .select('id')
          .eq('club_id', _clubId!);

      final convocatoriaIds = (convocatoriasResponse as List)
          .map((c) => c['id'].toString())
          .toList();

      if (convocatoriaIds.isEmpty) {
        _postulacionesRecientes = [];
        return;
      }

      final postulacionesResponse = await SupaFlow.client
          .from('postulaciones')
          .select()
          .inFilter('convocatoria_id', convocatoriaIds)
          .order('created_at', ascending: false)
          .limit(10);

      _postulacionesRecientes =
          List<Map<String, dynamic>>.from(postulacionesResponse);

      for (var post in _postulacionesRecientes) {
        try {
          final jugadorResponse = await SupaFlow.client
              .from('users')
              .select(
                  'user_id, name, lastname, posicion, birthday, city, photo_url')
              .eq('user_id', post['jugador_id'])
              .maybeSingle();

          if (jugadorResponse != null) {
            post['jugador'] = jugadorResponse;
          }
        } catch (e) {
          debugPrint('Error cargando jugador: $e');
        }
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

  Future<void> _updatePostulacionStatus(
      String postulacionId, String newStatus) async {
    try {
      await SupaFlow.client.from('postulaciones').update({
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
                      return SingleChildScrollView(
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
    final padding = _responsive(context, mobile: 14, tablet: 18, desktop: 22);
    final titleSize =
        _responsive(context, mobile: 14, tablet: 16, desktop: 18) * scale;
    final subtitleSize =
        _responsive(context, mobile: 12, tablet: 13, desktop: 14) * scale;
    final borderRadius =
        _responsive(context, mobile: 14, tablet: 16, desktop: 18);

    return Container(
      width: double.infinity,
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
          // Header
          Text(
            'Postulaciones Recientes',
            style: GoogleFonts.inter(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            'Últimos jugadores que se han postulado',
            style: GoogleFonts.inter(
              fontSize: subtitleSize,
              color: Colors.orange[400],
            ),
          ),
          SizedBox(height: 16 * scale),

          // Lista de postulaciones
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
    final fullName =
        '$name ${lastname.isNotEmpty ? lastname[0] + '.' : ''}'.trim();
    final position = jugador?['posicion'] ?? '';
    final country = jugador?['city'] ?? '';
    final age = _calculateAge(jugador?['birthday']);
    final estado = postulacion['estado']?.toString() ?? 'pendiente';
    final jugadorId = jugador?['user_id']?.toString() ?? '';
    final postulacionId = postulacion['id'].toString();

    final isRevisado = estado.toLowerCase() == 'revisado' ||
        estado.toLowerCase() == 'revisada';

    final padding = _responsive(context, mobile: 12, tablet: 16, desktop: 18);
    final nameFontSize =
        _responsive(context, mobile: 13, tablet: 14, desktop: 15) * scale;
    final detailFontSize =
        _responsive(context, mobile: 11, tablet: 12, desktop: 13) * scale;
    final buttonFontSize =
        _responsive(context, mobile: 11, tablet: 12, desktop: 13) * scale;
    final borderRadius =
        _responsive(context, mobile: 10, tablet: 12, desktop: 14);

    // Layout responsivo para item
    final isWideScreen = _isMediumScreen(context);

    return Container(
      margin: EdgeInsets.only(bottom: 10 * scale),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: isWideScreen
          ? _buildWidePostulacionLayout(
              context,
              fullName,
              position,
              age,
              country,
              estado,
              isRevisado,
              jugadorId,
              postulacionId,
              postulacion,
              nameFontSize,
              detailFontSize,
              buttonFontSize,
              scale)
          : _buildCompactPostulacionLayout(
              context,
              fullName,
              position,
              age,
              country,
              estado,
              isRevisado,
              jugadorId,
              postulacionId,
              postulacion,
              nameFontSize,
              detailFontSize,
              buttonFontSize,
              scale),
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
          onTap: () => _showStatusMenu(postulacionId, estado),
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
        Row(
          children: [
            // Status badge
            GestureDetector(
              onTap: () => _showStatusMenu(postulacionId, estado),
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
        ),
      ],
    );
  }

  void _showStatusMenu(String postulacionId, String currentStatus) {
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
                'pendiente', 'Nuevo', Colors.black, postulacionId),
            _buildStatusOption(
                'revisado', 'Revisado', const Color(0xFF6B7280), postulacionId),
            _buildStatusOption(
                'aceptado', 'Aceptado', const Color(0xFF22C55E), postulacionId),
            _buildStatusOption('rechazado', 'Rechazado',
                const Color(0xFFEF4444), postulacionId),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
      String status, String label, Color color, String postulacionId) {
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
        _updatePostulacionStatus(postulacionId, status);
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
                        _updatePostulacionStatus(
                            postulacion['id'].toString(), 'rechazado');
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
                        _updatePostulacionStatus(
                            postulacion['id'].toString(), 'aceptado');
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
