import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
// import '/flutter_flow/flutter_flow_widgets.dart'; // Unused
// import '/custom_code/widgets/index.dart' as custom_widgets; // Removed
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dashboard_club_model.dart';
export 'dashboard_club_model.dart';

class DashboardClubWidget extends StatefulWidget {
  const DashboardClubWidget({super.key});

  static String routeName = 'dashboard_club';
  static String routePath = '/dashboardClub';

  @override
  State<DashboardClubWidget> createState() => _DashboardClubWidgetState();
}

class _DashboardClubWidgetState extends State<DashboardClubWidget> {
  late DashboardClubModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String? _clubName;

  // Estatísticas
  int _nuevasPostulaciones = 0;
  int _convocatoriasActivas = 0;
  int _totalPostulaciones = 0;
  int _listasCreadas = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardClubModel());
    _loadData();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final clubId = currentUserUid;
    if (clubId.isEmpty) {
      debugPrint('DashboardClubWidget: clubId is empty, skipping load');
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Carregar nome do clube
      final userData = await SupaFlow.client
          .from('users')
          .select('name')
          .eq('user_id', clubId)
          .maybeSingle();

      if (userData != null) {
        _clubName = userData['name'] as String?;
      }

      // Carregar estatísticas usando a função do banco
      try {
        final statsResponse = await SupaFlow.client
            .rpc('get_club_dashboard_stats', params: {'p_club_id': clubId});

        if (statsResponse != null) {
          setState(() {
            _convocatoriasActivas = statsResponse['convocatorias_activas'] ?? 0;
            _totalPostulaciones = statsResponse['total_postulaciones'] ?? 0;
            _nuevasPostulaciones = statsResponse['postulaciones_48h'] ?? 0;
            _listasCreadas = statsResponse['listas_creadas'] ?? 0;
          });
        }
      } catch (e) {
        debugPrint('Função RPC não disponível, usando queries diretas: $e');
        await _loadStatsDirectly(clubId);
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      // Usar valores padrão em caso de erro
      await _loadStatsDirectly(clubId);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatsDirectly(String clubId) async {
    try {
      // Convocatorias ativas
      final convocatorias = await SupaFlow.client
          .from('convocatorias')
          .select('id')
          .eq('club_id', clubId)
          .eq('is_active', true);
      _convocatoriasActivas = (convocatorias as List?)?.length ?? 0;

      // IDs das convocatorias para buscar postulaciones
      final convocatoriaIds =
          (convocatorias as List?)?.map((c) => c['id']).toList() ?? [];

      if (convocatoriaIds.isNotEmpty) {
        // Total de postulaciones
        final postulaciones = await SupaFlow.client
            .from('postulaciones')
            .select('id, created_at')
            .inFilter('convocatoria_id', convocatoriaIds);

        _totalPostulaciones = (postulaciones as List?)?.length ?? 0;

        // Postulaciones nas últimas 48h
        final now = DateTime.now();
        final twoDaysAgo = now.subtract(const Duration(hours: 48));
        _nuevasPostulaciones = (postulaciones as List?)?.where((p) {
              final createdAt = DateTime.tryParse(p['created_at'] ?? '');
              return createdAt != null && createdAt.isAfter(twoDaysAgo);
            }).length ??
            0;
      }

      // Listas criadas
      final listas = await SupaFlow.client
          .from('listas_club')
          .select('id')
          .eq('club_id', clubId);
      _listasCreadas = (listas as List?)?.length ?? 0;
    } catch (e) {
      debugPrint('Erro ao carregar stats diretamente: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Ação: Nova Convocatoria
  void _crearConvocatoria() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CrearConvocatoriaModal(
        clubId: currentUserUid,
        onCreated: () {
          _loadData();
          Navigator.pop(context);
        },
      ),
    );
  }

  // Ação: Nova Nota
  void _crearNota() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CrearNotaModal(
        clubId: currentUserUid,
        onCreated: () {
          Navigator.pop(context);
          _showSnackBar('Nota creada con éxito!');
        },
      ),
    );
  }

  // Ação: Ver Postulantes
  void _verPostulantes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PostulantesModal(clubId: currentUserUid),
    );
  }

  // Ação: Filtrar por Posición
  void _filtrarPorPosicion() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FiltrarPosicionModal(
        onSelect: (posicion) {
          Navigator.pop(context);
          _showSnackBar('Filtrando por: $posicion');
          // Aqui você pode implementar a navegação para uma tela filtrada
        },
      ),
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
        backgroundColor: Colors.white,
        body: Container(
          width: MediaQuery.sizeOf(context).width * 1.0,
          height: MediaQuery.sizeOf(context).height * 1.0,
          color: Colors.white,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header com menu
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: InkWell(
                              onTap: () {
                                _showClubMenu(context);
                              },
                              child: const Icon(Icons.menu, size: 24),
                            ),
                          ),

                          // Título
                          Text(
                            'Inicio',
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bienvenido al panel de control de ${_clubName ?? "FutbolTalent.Pro"}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aquí tienes un resumen de toda la actividad reciente.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Acciones Rápidas
                          _buildAccionesRapidas(),
                          const SizedBox(height: 20),

                          // Stats Row 1
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Nuevas\nPostulaciones',
                                  _nuevasPostulaciones.toString(),
                                  'En las últimas 48h',
                                  Icons.people,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Convocatorias\nActivas',
                                  _convocatoriasActivas.toString(),
                                  'En curso',
                                  Icons.calendar_month,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // Stats Row 2
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Total\nPostulaciones',
                                  _totalPostulaciones.toString(),
                                  'Todas las convocatorias',
                                  Icons.people,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Listas\nCreadas',
                                  _listasCreadas.toString(),
                                  'En curso',
                                  Icons.calendar_month,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ===== DRAWER DO MENU =====
  Widget _buildAccionesRapidas() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF807C7C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acciones Rápidas',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Atajos a las funciones más utilizadas',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          // Row 1: Nueva Convocatoria, Nueva Nota
          Row(
            children: [
              _buildActionButton(
                'Nueva Convocatoria',
                Icons.add,
                const Color(0xFF818181),
                Colors.white,
                _crearConvocatoria,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                'Nueva Nota',
                Icons.add,
                const Color(0xFF818181),
                Colors.white,
                _crearNota,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Ver Postulantes, Filtrar por Posición
          Row(
            children: [
              _buildActionButton(
                'Ver Postulantes',
                Icons.visibility,
                Colors.white,
                Colors.black,
                _verPostulantes,
                outlined: true,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                'Filtrar por Posición',
                Icons.filter_list,
                Colors.white,
                Colors.black,
                _filtrarPorPosicion,
                outlined: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color bgColor,
    Color textColor,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(5),
            border:
                outlined ? Border.all(color: const Color(0xFFB5BECA)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, IconData icon) {
    return Container(
      height: 152,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF928F8F)),
      ),
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
              Icon(icon, size: 16, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEEF2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up,
                        size: 16, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      '+12%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showClubMenu(BuildContext ctx) {
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
                  width: MediaQuery.of(context).size.width * 0.75,
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
                                'Panel del Club',
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
                                  true,
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
                                  'Postulaciones',
                                  false,
                                  () async => context.pushNamed(
                                      PostulacionesWidget.routeName)),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.list_alt_outlined,
                                  'Listas y Notas',
                                  false,
                                  () async => context
                                      .pushNamed(ListaYNotaWidget.routeName)),
                              const Divider(),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.settings_outlined,
                                  'Configuración',
                                  false,
                                  () async => context
                                      .pushNamed(ConfiguracinWidget.routeName)),
                              const SizedBox(height: 16),
                              _buildDrawerItemCallback(
                                  context, Icons.logout, 'Cerrar Sesión', false,
                                  () async {
                                debugPrint(
                                    'Logout: Button pressed in DashboardClub');
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
                                  debugPrint('Logout: Error: $e');
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
        Navigator.pop(context);
        if (!isSelected && onTap != null) {
          await onTap();
        }
      },
    );
  }
}

// ===== MODAL: CRIAR CONVOCATORIA =====
class _CrearConvocatoriaModal extends StatefulWidget {
  final String clubId;
  final VoidCallback onCreated;

  const _CrearConvocatoriaModal({
    required this.clubId,
    required this.onCreated,
  });

  @override
  State<_CrearConvocatoriaModal> createState() =>
      _CrearConvocatoriaModalState();
}

class _CrearConvocatoriaModalState extends State<_CrearConvocatoriaModal> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  String _posicionSeleccionada = 'Delantero';
  final _edadMinController = TextEditingController();
  final _edadMaxController = TextEditingController();
  final _salarioMinController = TextEditingController();
  final _salarioMaxController = TextEditingController();
  final _cierreController = TextEditingController();
  DateTime? _fechaCierre;
  bool _isLoading = false;

  final List<String> _posiciones = [
    'Portero',
    'Defensa',
    'Mediocampista',
    'Delantero',
  ];

  Future<void> _crear() async {
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un título')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupaFlow.client.from('convocatorias').insert({
        'club_id': widget.clubId,
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'posicion': _posicionSeleccionada,
        'edad_minima': int.tryParse(_edadMinController.text),
        'edad_maxima': int.tryParse(_edadMaxController.text),
        'salario_min': double.tryParse(_salarioMinController.text),
        'salario_max': double.tryParse(_salarioMaxController.text),
        'fecha_cierre': _fechaCierre?.toIso8601String(),
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      widget.onCreated();
    } catch (e) {
      debugPrint('Erro ao criar convocatoria: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _fechaCierre = picked;
        _cierreController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nueva Convocatoria',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildTextField('Título', _tituloController),
                const SizedBox(height: 16),
                _buildTextField('Descripción', _descripcionController,
                    maxLines: 3),
                const SizedBox(height: 16),
                Text(
                  'Posición',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _posicionSeleccionada,
                  items: _posiciones
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _posicionSeleccionada = val!),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            'Edad Mínima', _edadMinController,
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildTextField(
                            'Edad Máxima', _edadMaxController,
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            'Salario Mín (\$)', _salarioMinController,
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildTextField(
                            'Salario Máx (\$)', _salarioMaxController,
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: _buildTextField('Fecha de Cierre', _cierreController,
                        suffixIcon: Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _crear,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D3B66),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Crear Convocatoria',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType? keyboardType, IconData? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
          ),
        ),
      ],
    );
  }
}

// ===== MODAL: CRIAR NOTA =====
class _CrearNotaModal extends StatefulWidget {
  final String clubId;
  final VoidCallback onCreated;

  const _CrearNotaModal({
    required this.clubId,
    required this.onCreated,
  });

  @override
  State<_CrearNotaModal> createState() => _CrearNotaModalState();
}

class _CrearNotaModalState extends State<_CrearNotaModal> {
  final _tituloController = TextEditingController();
  final _contenidoController = TextEditingController();
  bool _isLoading = false;

  Future<void> _crear() async {
    if (_tituloController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await SupaFlow.client.from('notas_club').insert({
        'club_id': widget.clubId,
        'titulo': _tituloController.text.trim(),
        'contenido': _contenidoController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      widget.onCreated();
    } catch (e) {
      debugPrint('Erro nota: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nueva Nota',
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contenidoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Contenido',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _crear,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Nota'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== MODAL: VER POSTULANTES (Exemplo simplificado) =====
class _PostulantesModal extends StatefulWidget {
  final String clubId;
  const _PostulantesModal({required this.clubId});

  @override
  State<_PostulantesModal> createState() => _PostulantesModalState();
}

class _PostulantesModalState extends State<_PostulantesModal> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Text(
          'Lista de Postulantes Aqui\n(Implementar listagem)',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.grey),
        ),
      ),
    );
  }
}

// ===== MODAL: FILTRAR POSICIÓN =====
class _FiltrarPosicionModal extends StatelessWidget {
  final Function(String) onSelect;

  const _FiltrarPosicionModal({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final opciones = [
      'Portero',
      'Defensa Central',
      'Lateral Izquierdo',
      'Lateral Derecho',
      'Mediocentro',
      'Mediapunta',
      'Extremo',
      'Delantero Centro'
    ];

    return Container(
      height: 400,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Seleccionar Posición',
              style:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: opciones.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(opciones[index]),
                  onTap: () => onSelect(opciones[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
