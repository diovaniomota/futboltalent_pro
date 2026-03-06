import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'convocatorias_club_model.dart';
export 'convocatorias_club_model.dart';

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

    // Carregar convocatorias e stats
    if (_clubId != null && _clubId!.isNotEmpty) {
      await _loadConvocatorias();
      await _loadStats();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadConvocatorias() async {
    try {
      final response = await SupaFlow.client
          .from('convocatorias')
          .select()
          .eq('club_id', _clubId!)
          .order('created_at', ascending: false);

      _convocatorias = List<Map<String, dynamic>>.from(response);

      // Carregar contagem de postulações para cada convocatoria
      for (var conv in _convocatorias) {
        try {
          final postulacionesResponse = await SupaFlow.client
              .from('postulaciones')
              .select('id')
              .eq('convocatoria_id', conv['id']);

          conv['postulaciones_count'] = (postulacionesResponse as List).length;
        } catch (e) {
          conv['postulaciones_count'] = 0;
        }
      }
    } catch (e) {
      debugPrint('Error cargando convocatorias: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      // Convocatorias activas
      _convocatoriasActivas = _convocatorias
          .where((c) => c['estado']?.toString().toLowerCase() == 'activa')
          .length;

      // Total postulaciones
      _totalPostulaciones = _convocatorias.fold<int>(
          0, (sum, c) => sum + (c['postulaciones_count'] as int? ?? 0));

      // Promedio por convocatoria
      if (_convocatoriasActivas > 0) {
        _promedioPostulaciones = _totalPostulaciones / _convocatoriasActivas;
      }

      // Total videos (das postulações)
      try {
        final videosResponse = await SupaFlow.client
            .from('postulaciones')
            .select('id, convocatorias!inner(club_id)')
            .eq('convocatorias.club_id', _clubId!);

        _totalVideos = (videosResponse as List).length;
      } catch (e) {
        _totalVideos = 0;
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
                                'Menu do Club',
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
                                  'Início',
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
                                  'Postulaciones',
                                  false,
                                  () async => context.pushNamed(
                                      PostulacionesWidget.routeName)),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.list_alt_outlined,
                                  'Listas',
                                  false,
                                  () async => context
                                      .pushNamed(ListaYNotaWidget.routeName)),
                              const Divider(),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.settings_outlined,
                                  'Configuração',
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
    final fechaCreacion = _formatDate(conv['created_at']);
    final fechaCierre = _formatDate(conv['fecha_cierre']);
    final ejercicios = conv['ejercicios'] as List? ?? [];
    final convId = conv['id'].toString();

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
              _buildInfoColumn('Creada', fechaCreacion),
              _buildInfoColumn('Cierra', fechaCierre),
            ],
          ),

          // Ejercicios
          if (ejercicios.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Ejercicios incluidos:',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF818181),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ejercicios
                  .map<Widget>((e) => _buildExerciseTag(e.toString()))
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
      if (data['fecha_cierre'] != null) {
        try {
          _fechaCierre = DateTime.parse(data['fecha_cierre']);
        } catch (e) {}
      }
    }
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
class _ViewConvocatoriaModal extends StatelessWidget {
  const _ViewConvocatoriaModal({
    Key? key,
    required this.convocatoria,
  }) : super(key: key);

  final Map<String, dynamic> convocatoria;

  @override
  Widget build(BuildContext context) {
    final titulo = convocatoria['titulo'] ?? 'Sin título';
    final posicion = convocatoria['posicion'] ?? '-';
    final descripcion = convocatoria['descripcion'] ?? '-';
    final categoria = convocatoria['categoria'] ?? '-';
    final tipo = convocatoria['tipo'] ?? '-';
    final estado = convocatoria['estado'] ?? 'activa';
    final postulaciones = convocatoria['postulaciones_count'] ?? 0;

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
                  const SizedBox(height: 16),
                  Text('Descripción',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(descripcion,
                      style: GoogleFonts.inter(color: Colors.grey[700])),
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
}
