import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/fluxo_compartilhado/club_application_utils.dart';
import '/fluxo_compartilhado/club_identity_utils.dart';
import '/fluxo_compartilhado/perfil_publico_club/perfil_publico_club_widget.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
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
  List<Map<String, dynamic>> _filteredConvocatorias = [];
  String? _clubId;
  String? _clubName;
  Set<String> _clubRefs = <String>{};
  final _searchController = TextEditingController();
  String _statusFilter = 'todas';

  // Stats
  int _convocatoriasActivas = 0;
  int _totalPostulaciones = 0;
  int _totalVideos = 0;
  double _promedioPostulaciones = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConvocatoriasClubModel());
    _searchController.addListener(_applyFilters);
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredConvocatorias = _convocatorias.where((conv) {
        final titulo = (conv['titulo'] ?? conv['categoria'] ?? '')
            .toString()
            .toLowerCase();
        final posicion = (conv['posicion'] ?? '').toString().toLowerCase();
        final estado = (conv['estado'] ?? '').toString().toLowerCase();
        final matchesQuery =
            q.isEmpty || titulo.contains(q) || posicion.contains(q);
        final matchesStatus = _statusFilter == 'todas' ||
            (_statusFilter == 'activa' && estado == 'activa') ||
            (_statusFilter == 'cerrada' && estado != 'activa');
        return matchesQuery && matchesStatus;
      }).toList();
    });
  }

  void _openCurrentClubPublicProfile(BuildContext context) {
    final clubRef =
        _clubRefs.isNotEmpty ? _clubRefs.first : (_clubId ?? currentUserUid);
    if (clubRef.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilPublicoClubWidget(
          clubRef: clubRef,
        ),
      ),
    );
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
      _applyFilters();
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

  void _confirmDeleteConvocatoria(Map<String, dynamic> conv) {
    final titulo = conv['titulo']?.toString().trim() ?? 'esta convocatoria';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar convocatoria',
            style:
                GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
            '¿Estás seguro de que querés eliminar "$titulo"? Esta acción no se puede deshacer.',
            style: GoogleFonts.inter(
                fontSize: 14, color: const Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteConvocatoria(conv);
            },
            child: Text('Eliminar',
                style: GoogleFonts.inter(
                    color: const Color(0xFFDC2626),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteConvocatoria(Map<String, dynamic> conv) async {
    final id = conv['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    try {
      await SupaFlow.client.from('convocatorias').delete().eq('id', id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Convocatoria eliminada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _closeConvocatoria(Map<String, dynamic> conv) async {
    final id = conv['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    try {
      await SupaFlow.client
          .from('convocatorias')
          .update({'estado': 'cerrada'}).eq('id', id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convocatória fechada'),
            backgroundColor: Color(0xFF6B7280),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fechar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reopenConvocatoria(Map<String, dynamic> conv) async {
    final id = conv['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    try {
      await SupaFlow.client
          .from('convocatorias')
          .update({'estado': 'activa'}).eq('id', id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convocatória reaberta'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reabrir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                                  'Gestión de talento',
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
                                  Icons.search_rounded,
                                  'Explorar jugadores',
                                  false,
                                  () async => context
                                      .pushNamed(ListaYNotaWidget.routeName)),
                              _buildDrawerItemCallback(
                                  context,
                                  Icons.shield_outlined,
                                  'Perfil del club',
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
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D3B66),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _showClubMenu(context),
          ),
          title: Text(
            'Convocatorias',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 26),
              tooltip: 'Nueva convocatoria',
              onPressed: _showCreateConvocatoriaModal,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
              )
            : RefreshIndicator(
                color: const Color(0xFF0D3B66),
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchAndFilter(),
                      _buildStatsStrip(),
                      _buildStatusFilterChips(),
                      _buildConvocatoriasList(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateConvocatoriaModal,
          backgroundColor: const Color(0xFF0D3B66),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'Nueva convocatoria',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: const Color(0xFF0D3B66),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar convocatoria...',
            hintStyle:
                TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 14),
            prefixIcon: Icon(Icons.search,
                color: Colors.white.withOpacity(0.7), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close,
                        color: Colors.white.withOpacity(0.7), size: 18),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsStrip() {
    final total = _convocatorias.length;
    final stats = [
      {
        'icon': Icons.campaign_outlined,
        'label': 'Total',
        'value': total.toString(),
        'color': const Color(0xFF0D3B66)
      },
      {
        'icon': Icons.play_circle_outline,
        'label': 'Activas',
        'value': _convocatoriasActivas.toString(),
        'color': const Color(0xFF16A34A)
      },
      {
        'icon': Icons.people_outline,
        'label': 'Postulaciones',
        'value': _totalPostulaciones.toString(),
        'color': const Color(0xFF7C3AED)
      },
      {
        'icon': Icons.bar_chart,
        'label': 'Promedio',
        'value': _promedioPostulaciones.toStringAsFixed(1),
        'color': const Color(0xFFD97706)
      },
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: stats.map<Widget>((s) {
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                    right: s != stats.last
                        ? const BorderSide(color: Color(0xFFE2E8F0))
                        : BorderSide.none),
              ),
              child: Column(
                children: [
                  Icon(s['icon'] as IconData,
                      color: s['color'] as Color, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    s['value'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C)),
                  ),
                  Text(
                    s['label'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFF718096)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    final options = [
      {'key': 'todas', 'label': 'Todas'},
      {'key': 'activa', 'label': 'Activas'},
      {'key': 'cerrada', 'label': 'Cerradas'},
    ];
    return Container(
      color: const Color(0xFFF7F9FC),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            '${_filteredConvocatorias.length} convocatoria${_filteredConvocatorias.length != 1 ? 's' : ''}',
            style:
                GoogleFonts.inter(fontSize: 13, color: const Color(0xFF718096)),
          ),
          const Spacer(),
          ...options.map((o) {
            final isSelected = _statusFilter == o['key'];
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() => _statusFilter = o['key']!);
                  _applyFilters();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0D3B66) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0D3B66)
                          : const Color(0xFFCBD5E0),
                    ),
                  ),
                  child: Text(
                    o['label']!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color:
                          isSelected ? Colors.white : const Color(0xFF4A5568),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildConvocatoriasList() {
    if (_convocatorias.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0D3B66).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_outlined,
                  size: 40, color: Color(0xFF0D3B66)),
            ),
            const SizedBox(height: 16),
            Text(
              'Crea tu primera convocatoria y empieza a encontrar talentos',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748)),
            ),
          ],
        ),
      );
    }

    if (_filteredConvocatorias.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No hay convocatorias que coincidan con la búsqueda.',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.inter(fontSize: 14, color: const Color(0xFF718096)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: _filteredConvocatorias
            .map((conv) => _buildConvocatoriaCard(conv))
            .toList(),
      ),
    );
  }

  Widget _buildConvocatoriaCard(Map<String, dynamic> conv) {
    final titulo = conv['titulo'] ?? conv['categoria'] ?? 'Sin título';
    final posicion = (conv['posicion'] ?? '').toString();
    final descripcion = (conv['descripcion'] ?? '').toString();
    final estado = conv['estado']?.toString().toLowerCase() ?? 'activa';
    final categoria = (conv['categoria'] ?? conv['tipo'] ?? '').toString();
    final postulaciones = conv['postulaciones_count'] ?? 0;
    final fechaCierre = _formatDate(conv['fecha_cierre']);
    final requiredChallenges =
        _convocatoriaRequiredChallengesFrom(conv['required_challenges']);
    final challengeLabels = requiredChallenges.isNotEmpty
        ? requiredChallenges.map(_convocatoriaChallengeTitle).toList()
        : (conv['ejercicios'] as List? ?? [])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList();

    final isActive = estado == 'activa';
    final accentColor =
        isActive ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored left accent bar
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row + menu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            titulo,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A202C)),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              size: 20, color: Color(0xFF718096)),
                          padding: const EdgeInsets.all(0),
                          onSelected: (value) {
                            if (value == 'ver')
                              _showViewConvocatoriaModal(conv);
                            if (value == 'scouting')
                              context.pushNamed(ListaYNotaWidget.routeName);
                            if (value == 'editar')
                              _showEditConvocatoriaModal(conv);
                            if (value == 'eliminar')
                              _confirmDeleteConvocatoria(conv);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'ver',
                              child: Row(children: [
                                const Icon(Icons.visibility_outlined,
                                    size: 16, color: Color(0xFF0D3B66)),
                                const SizedBox(width: 10),
                                Text('Ver detalles',
                                    style: GoogleFonts.inter(fontSize: 13)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'scouting',
                              child: Row(children: [
                                const Icon(Icons.bookmark_add_outlined,
                                    size: 16, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 10),
                                Text('Adicionar ao scouting',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFF7C3AED))),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'editar',
                              child: Row(children: [
                                const Icon(Icons.edit_outlined,
                                    size: 16, color: Color(0xFF0D3B66)),
                                const SizedBox(width: 10),
                                Text('Editar',
                                    style: GoogleFonts.inter(fontSize: 13)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'eliminar',
                              child: Row(children: [
                                const Icon(Icons.delete_outline,
                                    size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 10),
                                Text('Eliminar',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFFDC2626))),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Meta row: categoria · posicion · status badge
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (categoria.isNotEmpty)
                          _metaChip(categoria, const Color(0xFFEBF4FF),
                              const Color(0xFF3B82F6)),
                        if (posicion.isNotEmpty)
                          _metaChip(posicion, const Color(0xFFF3F4F6),
                              const Color(0xFF6B7280)),
                        _statusBadge(isActive),
                      ],
                    ),
                    if (descripcion.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        descripcion,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF718096),
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Postulações destacadas
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: postulaciones > 0
                            ? const Color(0xFFEDE9FE)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people,
                              size: 14,
                              color: postulaciones > 0
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF9CA3AF)),
                          const SizedBox(width: 5),
                          Text(
                            '$postulaciones jogador${postulaciones != 1 ? 'es' : ''} postulado${postulaciones != 1 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: postulaciones > 0
                                  ? const Color(0xFF6D28D9)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Stats inline
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (fechaCierre != '-')
                          _inlineStat(Icons.calendar_today_outlined,
                              'Cierra $fechaCierre'),
                        if (challengeLabels.isNotEmpty)
                          _inlineStat(Icons.flag_outlined,
                              '${challengeLabels.length} desafio${challengeLabels.length != 1 ? 's' : ''}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick actions row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context
                                .pushNamed(PostulacionesWidget.routeName),
                            icon: const Icon(Icons.people_outline, size: 14),
                            label: Text('Ver postulantes',
                                style: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7C3AED),
                              side: const BorderSide(color: Color(0xFFDDD6FE)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: () => _showEditConvocatoriaModal(conv),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: Text('Editar',
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D3B66),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: () => isActive
                              ? _closeConvocatoria(conv)
                              : _reopenConvocatoria(conv),
                          icon: Icon(
                              isActive
                                  ? Icons.lock_outline
                                  : Icons.lock_open_outlined,
                              size: 14),
                          label: Text(isActive ? 'Fechar' : 'Reabrir',
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isActive
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                            side: BorderSide(
                                color: isActive
                                    ? const Color(0xFFFECACA)
                                    : const Color(0xFFBBF7D0)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
    );
  }

  Widget _statusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isActive ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Activa' : 'Cerrada',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  isActive ? const Color(0xFF15803D) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: const Color(0xFF718096))),
      ],
    );
  }

  Widget _buildExerciseTag(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFD0FF)),
      ),
      child: Text(name,
          style: GoogleFonts.inter(
              fontSize: 10.5, color: const Color(0xFF3730A3))),
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
  bool _isUploadingImage = false;
  bool _isLoadingChallenges = true;
  String? _imagenUrl;
  List<Map<String, dynamic>> _availableChallenges = [];
  List<Map<String, dynamic>> _selectedRequiredChallenges = [];
  bool get _isEditing => widget.existingData != null;

  final List<String> _categorias = canonicalPlayerCategories;
  final List<String> _tipos = ['Abierta', 'Invitación', 'Privada'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.existingData!;
      _tituloController.text = data['titulo'] ?? '';
      _posicionController.text =
          normalizePlayerPosition(data['posicion'] ?? '');
      _descripcionController.text = data['descripcion'] ?? '';
      _edadMinController.text =
          (data['edad_minima'] ?? data['edad_min'])?.toString() ?? '';
      _edadMaxController.text =
          (data['edad_maxima'] ?? data['edad_max'])?.toString() ?? '';
      _categoria = normalizePlayerCategory(data['categoria']) == ''
          ? 'Sub-17'
          : normalizePlayerCategory(data['categoria']);
      _tipo = data['tipo'] ?? 'Abierta';
      _imagenUrl = data['imagen_url']?.toString().trim().isNotEmpty == true
          ? data['imagen_url'].toString().trim()
          : null;
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

    if (_isUploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esperá a que termine la carga de la imagen.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final clubData = await resolveCurrentClubForUser(currentUserUid);
      final normalizedPosition =
          normalizePlayerPosition(_posicionController.text);
      final normalizedCategory = normalizePlayerCategory(_categoria);
      final normalizedCountry = normalizeCountryName(firstNonEmptyClubValue([
        clubData?['pais'],
        clubData?['country'],
        clubData?['country_name'],
      ]));
      final normalizedCity = normalizeCityName(firstNonEmptyClubValue([
        clubData?['city'],
        clubData?['ciudad'],
        clubData?['ubicacion'],
        clubData?['location'],
      ]));
      final normalizedLocation = [
        normalizedCity,
        normalizedCountry,
      ].where((item) => item.isNotEmpty).join(', ');
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
        'posicion': normalizedPosition,
        'descripcion': _descripcionController.text.trim(),
        'imagen_url':
            _imagenUrl?.trim().isNotEmpty == true ? _imagenUrl!.trim() : null,
        'categoria': normalizedCategory,
        'tipo': _tipo,
        'pais': normalizedCountry,
        'ciudad': normalizedCity,
        'ubicacion': normalizedLocation,
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
        if (!_isEditing) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF16A34A), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡Convocatoria creada!',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Tu convocatoria ya está publicada. Los jugadores pueden postularse ahora.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF4A5568),
                  height: 1.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cerrar',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF718096),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pushNamed(DashboardClubWidget.routeName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Explorar jugadores',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Convocatoria actualizada'),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  Future<void> _pickAndUploadCoverImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 900,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await image.readAsBytes();
      final safeClubId =
          widget.clubId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName =
          'convocatoria_cover_${safeClubId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await SupaFlow.client.storage.from('Fotos').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl =
          SupaFlow.client.storage.from('Fotos').getPublicUrl(fileName);

      if (!mounted) return;
      setState(() {
        _imagenUrl = publicUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagen de capa cargada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
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
                      'Ej: Mediocampistas Sub-17 para temporada 2026'),
                  const SizedBox(height: 16),
                  _buildCoverImageField(),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    'Posición buscada',
                    canonicalPlayerPositions.contains(
                      _posicionController.text.trim(),
                    )
                        ? _posicionController.text.trim()
                        : null,
                    canonicalPlayerPositions,
                    (value) => setState(
                      () => _posicionController.text = value ?? '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Descripción', _descripcionController,
                      'Ej: Buscamos jugadores con buen manejo de balón, visión de juego y experiencia en competiciones regionales...',
                      maxLines: 3),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Una buena descripción atrae jugadores más relevantes para tu club.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

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

  Widget _buildDropdown(String label, String? value, List<String> items,
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

  Widget _buildCoverImageField() {
    final hasImage = _imagenUrl?.trim().isNotEmpty == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagen de capa',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imagenUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
                  ),
                )
              : _buildCoverPlaceholder(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: (_isUploadingImage || _isSaving)
                  ? null
                  : _pickAndUploadCoverImage,
              icon: _isUploadingImage
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(
                _isUploadingImage
                    ? 'Cargando...'
                    : hasImage
                        ? 'Cambiar imagen'
                        : 'Subir imagen',
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: (_isUploadingImage || _isSaving)
                    ? null
                    : () => setState(() => _imagenUrl = null),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Color(0xFFDC2626)),
                label: const Text(
                  'Quitar',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCoverPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: Colors.grey[500], size: 28),
          const SizedBox(height: 6),
          Text(
            'Sin imagen de capa',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
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
        for (final row
            in List<Map<String, dynamic>>.from(usersResponse as List)) {
          final id = row['user_id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            usersById[id] = row;
          }
        }
      }

      final requiredChallenges = _convocatoriaRequiredChallengesFrom(
          convocatoria['required_challenges']);
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
              .select(
                  'id, user_id, title, thumbnail_url, video_url, created_at')
              .eq('is_public', true)
              .inFilter('user_id', playerIds)
              .order('created_at', ascending: false)
              .limit(400);

          for (final video
              in List<Map<String, dynamic>>.from(videosResponse as List)) {
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
    final attemptVideos = List<Map<String, dynamic>>.from(
        candidate['attempt_videos'] ?? const []);
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
                      onPressed:
                          videoUrl.isEmpty ? null : () => _openVideo(videoUrl),
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
                  onPressed: playerId.isEmpty
                      ? null
                      : () => _openPlayerProfile(playerId),
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
