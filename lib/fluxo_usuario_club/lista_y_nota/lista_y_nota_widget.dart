import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lista_y_nota_model.dart';
export 'lista_y_nota_model.dart';

class ListaYNotaWidget extends StatefulWidget {
  const ListaYNotaWidget({super.key});

  static String routeName = 'Lista_y_nota';
  static String routePath = '/listaYNota';

  @override
  State<ListaYNotaWidget> createState() => _ListaYNotaWidgetState();
}

class _ListaYNotaWidgetState extends State<ListaYNotaWidget> {
  late ListaYNotaModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String? _clubId;
  String? _clubName;

  List<Map<String, dynamic>> _listas = [];
  Map<String, dynamic>? _selectedLista;
  List<Map<String, dynamic>> _jugadoresEnLista = [];
  List<Map<String, dynamic>> _filteredJugadores = [];

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ListaYNotaModel());
    _searchController.addListener(_filterJugadores);
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============ HELPER METHODS ============
  double _responsive(BuildContext context,
      {required double mobile, double? tablet, double? desktop}) {
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return '-';
    }
  }

  String _getInitials(String? name, String? lastname) {
    String initials = '';
    if (name != null && name.isNotEmpty) initials += name[0].toUpperCase();
    if (lastname != null && lastname.isNotEmpty) {
      initials += lastname[0].toUpperCase();
    }
    return initials.isEmpty ? '?' : initials;
  }

  // ============ DATA LOADING ============
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

    // Carregar listas
    if (_clubId != null && _clubId!.isNotEmpty) {
      try {
        await _loadListas();
      } catch (e) {
        debugPrint('Error cargando listas: $e');
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadListas() async {
    try {
      final response = await SupaFlow.client
          .from('listas_club')
          .select()
          .eq('club_id', _clubId!)
          .order('created_at', ascending: false);
      _listas = List<Map<String, dynamic>>.from(response);

      for (var lista in _listas) {
        try {
          final countResponse = await SupaFlow.client
              .from('listas_jugadores')
              .select('id')
              .eq('lista_id', lista['id']);
          lista['jugadores_count'] = (countResponse as List).length;
        } catch (e) {
          lista['jugadores_count'] = 0;
        }
      }

      // Atualizar _selectedLista com dados frescos
      if (_selectedLista != null) {
        final updated =
            _listas.where((l) => l['id'] == _selectedLista!['id']).toList();
        if (updated.isNotEmpty) {
          _selectedLista = updated.first;
        }
        await _loadJugadoresEnLista(_selectedLista!['id'].toString());
      }
    } catch (e) {
      debugPrint('❌ Error cargando listas: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadJugadoresEnLista(String listaId) async {
    try {
      final response = await SupaFlow.client
          .from('listas_jugadores')
          .select()
          .eq('lista_id', listaId)
          .order('created_at', ascending: false);
      _jugadoresEnLista = List<Map<String, dynamic>>.from(response);

      for (var item in _jugadoresEnLista) {
        try {
          final jugadorResponse = await SupaFlow.client
              .from('users')
              .select(
                  'user_id, name, lastname, posicion, birthday, country_id, photo_url')
              .eq('user_id', item['jugador_id'])
              .maybeSingle();
          if (jugadorResponse != null) item['jugador'] = jugadorResponse;
        } catch (e) {}
      }
      _filteredJugadores = List.from(_jugadoresEnLista);
    } catch (e) {
      debugPrint('❌ Error cargando jugadores: $e');
    }
    if (mounted) setState(() {});
  }

  void _filterJugadores() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredJugadores = List.from(_jugadoresEnLista);
      } else {
        _filteredJugadores = _jugadoresEnLista.where((item) {
          final jugador = item['jugador'] as Map<String, dynamic>?;
          if (jugador == null) return false;
          final name = '${jugador['name'] ?? ''} ${jugador['lastname'] ?? ''}'
              .toLowerCase();
          final posicion = (jugador['posicion'] ?? '').toString().toLowerCase();
          return name.contains(query) || posicion.contains(query);
        }).toList();
      }
    });
  }

  void _selectLista(Map<String, dynamic> lista) async {
    setState(() {
      _selectedLista = lista;
      _isLoading = true;
    });
    await _loadJugadoresEnLista(lista['id'].toString());
    if (mounted) setState(() => _isLoading = false);
  }

  Future<List<Map<String, dynamic>>> _fetchCandidatePlayersForClub() async {
    if (_clubId == null || _clubId!.isEmpty) return [];

    try {
      final convocatoriasResponse = await SupaFlow.client
          .from('convocatorias')
          .select('id')
          .eq('club_id', _clubId!)
          .limit(250);
      final convocatoriaIds = (convocatoriasResponse as List)
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (convocatoriaIds.isEmpty) return [];

      final posts = <Map<String, dynamic>>[];
      Future<void> loadPosts(String table) async {
        try {
          final response = await SupaFlow.client
              .from(table)
              .select('player_id, jugador_id, convocatoria_id')
              .inFilter('convocatoria_id', convocatoriaIds)
              .order('created_at', ascending: false)
              .limit(600);
          posts.addAll(List<Map<String, dynamic>>.from(response));
        } catch (_) {}
      }

      await Future.wait([
        loadPosts('postulaciones'),
        loadPosts('aplicaciones_convocatoria'),
      ]);

      final ids = posts
          .map((row) =>
              row['player_id']?.toString() ??
              row['jugador_id']?.toString() ??
              '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (ids.isEmpty) return [];

      List<Map<String, dynamic>> users;
      try {
        final response = await SupaFlow.client
            .from('users')
            .select(
                'user_id, name, lastname, username, posicion, city, birthday, country_id, photo_url, userType')
            .inFilter('user_id', ids)
            .inFilter('userType',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta']);
        users = List<Map<String, dynamic>>.from(response);
      } catch (_) {
        final response = await SupaFlow.client
            .from('users')
            .select(
                'user_id, name, lastname, username, posicion, city, birthday, country_id, photo_url, usertype')
            .inFilter('user_id', ids)
            .inFilter('usertype',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta']);
        users = List<Map<String, dynamic>>.from(response);
      }

      return users;
    } catch (e) {
      debugPrint('Error candidate players for club lists: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSavedPlayersForClub() async {
    if (_clubId == null || _clubId!.isEmpty) return [];

    try {
      final ids = <String>{};

      try {
        final saved = await SupaFlow.client
            .from('jugadores_guardados')
            .select('jugador_id')
            .eq('scout_id', _clubId!)
            .limit(600);
        for (final row in (saved as List)) {
          final id = row['jugador_id']?.toString() ?? '';
          if (id.isNotEmpty) ids.add(id);
        }
      } catch (_) {}

      try {
        final saved = await SupaFlow.client
            .from('jugadores_guardados')
            .select('jugador_id')
            .eq('club_id', _clubId!)
            .limit(600);
        for (final row in (saved as List)) {
          final id = row['jugador_id']?.toString() ?? '';
          if (id.isNotEmpty) ids.add(id);
        }
      } catch (_) {}

      if (ids.isEmpty) return [];

      List<Map<String, dynamic>> users;
      try {
        final response = await SupaFlow.client
            .from('users')
            .select(
                'user_id, name, lastname, username, posicion, city, birthday, country_id, photo_url, userType')
            .inFilter('user_id', ids.toList())
            .inFilter('userType',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta']);
        users = List<Map<String, dynamic>>.from(response);
      } catch (_) {
        final response = await SupaFlow.client
            .from('users')
            .select(
                'user_id, name, lastname, username, posicion, city, birthday, country_id, photo_url, usertype')
            .inFilter('user_id', ids.toList())
            .inFilter('usertype',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta']);
        users = List<Map<String, dynamic>>.from(response);
      }

      return users;
    } catch (e) {
      debugPrint('Error saved players for club lists: $e');
      return [];
    }
  }

  // ============ MENU & MODALS ============
  void _showClubMenu(BuildContext ctx) {
    Navigator.of(ctx).push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              child: Container(
                width: MediaQuery.of(context).size.width *
                    _responsive(context,
                        mobile: 0.8, tablet: 0.5, desktop: 0.35),
                height: double.infinity,
                color: Colors.white,
                child: SafeArea(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Color(0xFFE0E0E0)))),
                        child: Row(
                          children: [
                            Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                    color: const Color(0xFF0D3B66),
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Icon(Icons.settings,
                                    color: Colors.white, size: 24)),
                            const SizedBox(width: 12),
                            Text('Menú del club',
                                style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D3B66))),
                            const Spacer(),
                            IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _buildDrawerItem(
                                context,
                                Icons.dashboard_outlined,
                                'Dashboard',
                                false,
                                () => context
                                    .pushNamed(DashboardClubWidget.routeName)),
                            _buildDrawerItem(
                                context,
                                Icons.campaign_outlined,
                                'Convocatorias',
                                false,
                                () => context.pushNamed(
                                    ConvocatoriasClubWidget.routeName)),
                            _buildDrawerItem(
                                context,
                                Icons.people_outline,
                                'Jugadores',
                                false,
                                () => context
                                    .pushNamed(PostulacionesWidget.routeName)),
                            _buildDrawerItem(
                                context,
                                Icons.list_alt_outlined,
                                'Scouting',
                                true,
                                () => context
                                    .pushNamed(ListaYNotaWidget.routeName)),
                            const Divider(),
                            _buildDrawerItem(
                                context,
                                Icons.settings_outlined,
                                'Club',
                                false,
                                () => context
                                    .pushNamed(ConfiguracinWidget.routeName)),
                            const Divider(),
                            _buildDrawerItem(
                                context, Icons.logout, 'Cerrar Sesión', false,
                                () async {
                              debugPrint(
                                  'Logout callback triggered in ListaYNota');
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
    ));
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String label,
      bool isSelected, Future Function() onTap) {
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFF0D3B66) : Colors.grey[600]),
      title: Text(label,
          style: GoogleFonts.inter(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? const Color(0xFF0D3B66) : Colors.grey[800])),
      trailing: isSelected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFF0D3B66), shape: BoxShape.circle))
          : null,
      onTap: () async {
        Navigator.of(context, rootNavigator: true).pop();
        if (!isSelected) {
          await Future.delayed(const Duration(milliseconds: 100));
          await onTap();
        }
      },
    );
  }

  // ============ UI BUILDER ============
  @override
  Widget build(BuildContext context) {
    final scale = _scaleFactor(context);
    final padding = _responsive(context, mobile: 16, tablet: 24, desktop: 32);
    final maxContentWidth = _responsive(context,
        mobile: double.infinity, tablet: 800, desktop: 1000);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          child: _isLoading && _listas.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D3B66)))
              : Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(padding),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: maxContentWidth == double.infinity
                                ? double.infinity
                                : maxContentWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(context),
                            if (_clubName != null) ...[
                              const SizedBox(height: 8),
                              Text('Club: $_clubName',
                                  style: GoogleFonts.inter(
                                      fontSize: 14, color: Colors.grey[600])),
                            ],
                            SizedBox(height: 16 * scale),
                            _buildActionButtons(context),
                            SizedBox(height: 24 * scale),
                            if (_isLargeScreen(context))
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      flex: 1,
                                      child: _buildMisListasCard(context)),
                                  SizedBox(width: 24 * scale),
                                  Expanded(
                                      flex: 2,
                                      child: _selectedLista != null
                                          ? _buildSelectedListaCard(context)
                                          : _buildEmptyListaPlaceholder(
                                              context)),
                                ],
                              )
                            else ...[
                              _buildMisListasCard(context),
                              SizedBox(height: 24 * scale),
                              if (_selectedLista != null)
                                _buildSelectedListaCard(context),
                            ],
                            SizedBox(height: 32 * scale),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scale = _scaleFactor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
            onTap: () => _showClubMenu(context),
            child: Icon(Icons.menu, color: Colors.black, size: 24 * scale)),
        SizedBox(height: 16 * scale),
        Text('Listas',
            style: GoogleFonts.inter(
                fontSize:
                    _responsive(context, mobile: 20, tablet: 24, desktop: 28) *
                        scale,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF444444))),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final scale = _scaleFactor(context);
    final width = _responsive(context, mobile: 122, tablet: 140, desktop: 160);
    final height = _responsive(context, mobile: 40, tablet: 44, desktop: 48);
    final fontSize =
        _responsive(context, mobile: 13, tablet: 14, desktop: 15) * scale;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton('+ Nueva Lista', () => _showCreateListaModal(),
            width, height, fontSize),
        SizedBox(width: 12 * scale),
        _buildActionButton('+ Nueva Nota', () => _showAddJugadorModal(), width,
            height, fontSize),
      ],
    );
  }

  Widget _buildActionButton(String text, VoidCallback onTap, double width,
      double height, double fontSize) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            color: const Color(0xFF818181),
            borderRadius: BorderRadius.circular(5)),
        child: Center(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: fontSize, color: Colors.white))),
      ),
    );
  }

  Widget _buildEmptyListaPlaceholder(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(40 * scale),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB5BECA))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.touch_app, size: 48 * scale, color: Colors.grey[400]),
        SizedBox(height: 12 * scale),
        Text('Selecciona una lista para ver los jugadores',
            style: GoogleFonts.inter(
                fontSize: 14 * scale, color: Colors.grey[500]),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildMisListasCard(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB5BECA))),
      padding: EdgeInsets.all(16 * scale),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.list_alt, color: Colors.black, size: 20 * scale),
          SizedBox(width: 8 * scale),
          Text('Mis Listas',
              style: GoogleFonts.inter(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w500,
                  color: Colors.black))
        ]),
        SizedBox(height: 4 * scale),
        Text('${_listas.length} listas creadas',
            style: GoogleFonts.inter(fontSize: 12 * scale, color: Colors.grey)),
        SizedBox(height: 16 * scale),
        if (_listas.isEmpty)
          Center(
              child: Padding(
                  padding: EdgeInsets.all(24 * scale),
                  child: Text('No hay listas creadas',
                      style: GoogleFonts.inter(
                          fontSize: 14 * scale, color: Colors.grey))))
        else
          ..._listas
              .take(_isLargeScreen(context) ? 5 : 3)
              .map((l) => _buildListaItem(context, l)),
        if (_listas.length > (_isLargeScreen(context) ? 5 : 3)) ...[
          SizedBox(height: 12 * scale),
          Center(
              child: GestureDetector(
                  onTap: _showAllListasModal,
                  child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16 * scale, vertical: 6 * scale),
                      decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Ver Más',
                          style: GoogleFonts.inter(
                              fontSize: 10 * scale, color: Colors.black))))),
        ]
      ]),
    );
  }

  Widget _buildListaItem(BuildContext context, Map<String, dynamic> lista) {
    final scale = _scaleFactor(context);
    final isSelected = _selectedLista?['id'] == lista['id'];
    return GestureDetector(
      onTap: () => _selectLista(lista),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 12 * scale),
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFFE8F4FD) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isSelected
                    ? const Color(0xFF0D3B66)
                    : const Color(0xFFB5BECA),
                width: isSelected ? 2 : 1)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(lista['nombre'] ?? 'Sin nombre',
                    style: GoogleFonts.inter(
                        fontSize: 14 * scale,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: Colors.black)),
                Text(lista['descripcion'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12 * scale, color: const Color(0xFF818181))),
              ])),
          Container(
              padding: EdgeInsets.all(8 * scale),
              decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF0D3B66) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12)),
              child: Text((lista['jugadores_count'] ?? 0).toString(),
                  style: GoogleFonts.inter(
                      fontSize: 10 * scale,
                      color: isSelected ? Colors.white : Colors.black))),
        ]),
      ),
    );
  }

  Widget _buildSelectedListaCard(BuildContext context) {
    final scale = _scaleFactor(context);
    final nombre = _selectedLista!['nombre'] ?? 'Sin nombre';
    final descripcion = _selectedLista!['descripcion'] ?? '';
    final count = _selectedLista!['jugadores_count'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB5BECA))),
      padding: EdgeInsets.all(16 * scale),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.group, color: Colors.black, size: 20 * scale),
          SizedBox(width: 8 * scale),
          Expanded(
              child: Text(nombre,
                  style: GoogleFonts.inter(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w500,
                      color: Colors.black)))
        ]),
        SizedBox(height: 8 * scale),
        Row(children: [
          Expanded(
              child: Text('$descripcion • $count jugadores',
                  style: GoogleFonts.inter(
                      fontSize: 12 * scale, color: const Color(0xFFB5BECA)))),
          _buildActionIcon(Icons.edit, () => _showEditListaModal()),
          SizedBox(width: 8 * scale),
          _buildActionIcon(Icons.delete, () => _confirmDeleteLista(),
              color: Colors.red),
        ]),
        SizedBox(height: 16 * scale),
        Container(
          height: 40 * scale,
          decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(10)),
          child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(fontSize: 14 * scale),
              decoration: InputDecoration(
                  hintText: 'Buscar en esta lista...',
                  prefixIcon:
                      Icon(Icons.search, size: 20 * scale, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10 * scale))),
        ),
        SizedBox(height: 16 * scale),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_filteredJugadores.isEmpty)
          Center(
              child: Padding(
                  padding: EdgeInsets.all(24 * scale),
                  child: Text('No hay jugadores',
                      style: GoogleFonts.inter(
                          fontSize: 14 * scale, color: Colors.grey))))
        else
          ..._filteredJugadores.map((item) => _buildJugadorCard(context, item))
      ]),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300)),
            child: Icon(icon, size: 16, color: color ?? Colors.grey)));
  }

  Widget _buildJugadorCard(BuildContext context, Map<String, dynamic> item) {
    final scale = _scaleFactor(context);
    final jugador = item['jugador'] as Map<String, dynamic>?;
    final name =
        '${jugador?['name'] ?? ''} ${jugador?['lastname'] ?? ''}'.trim();
    final position = jugador?['posicion'] ?? '';
    final age = _calculateAge(jugador?['birthday']);
    final photo = jugador?['photo_url'];
    final rating = item['calificacion'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB5BECA))),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
              radius: 20 * scale,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Text(_getInitials(jugador?['name'], jugador?['lastname']))
                  : null),
          SizedBox(width: 12 * scale),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name,
                          style: GoogleFonts.inter(
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w500)),
                      _buildActionIcon(
                          Icons.edit, () => _showEditJugadorModal(item))
                    ]),
                Text('$position • $age años',
                    style: GoogleFonts.inter(
                        fontSize: 12 * scale, color: Colors.grey)),
                Row(
                    children: List.generate(
                        5,
                        (i) => Icon(Icons.circle,
                            size: 10 * scale,
                            color:
                                i < rating ? Colors.amber : Colors.grey[300]))),
              ]))
        ]),
        if (item['nota'] != null && item['nota'].toString().isNotEmpty) ...[
          const Divider(),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8)),
              child: Text(item['nota'],
                  style: GoogleFonts.inter(fontSize: 12 * scale)))
        ]
      ]),
    );
  }

  // ============ MODALS IMPL ============
  void _showCreateListaModal() {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _buildModalContent(ctx, 'Nueva Lista', [
              _buildTextField(ctx, 'Nombre *', nombreCtrl),
              const SizedBox(height: 16),
              _buildTextField(ctx, 'Descripción', descCtrl, maxLines: 3),
            ], () async {
              if (nombreCtrl.text.isEmpty) return;
              final inserted =
                  await SupaFlow.client.from('listas_club').insert({
                'club_id': _clubId,
                'nombre': nombreCtrl.text,
                'descripcion': descCtrl.text,
                'created_at': DateTime.now().toIso8601String()
              }).select();
              Navigator.pop(ctx);
              await _loadListas();
              // Auto-select the newly created list
              if (inserted.isNotEmpty && mounted) {
                final newList =
                    _listas.where((l) => l['id'] == inserted[0]['id']).toList();
                if (newList.isNotEmpty) {
                  _selectLista(newList.first);
                }
              }
            }, 'Crear Lista'));
  }

  void _showEditListaModal() {
    final nombreCtrl = TextEditingController(text: _selectedLista!['nombre']);
    final descCtrl =
        TextEditingController(text: _selectedLista!['descripcion']);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _buildModalContent(ctx, 'Editar Lista', [
              _buildTextField(ctx, 'Nombre *', nombreCtrl),
              const SizedBox(height: 16),
              _buildTextField(ctx, 'Descripción', descCtrl, maxLines: 3),
            ], () async {
              await SupaFlow.client.from('listas_club').update({
                'nombre': nombreCtrl.text,
                'descripcion': descCtrl.text,
                'updated_at': DateTime.now().toIso8601String()
              }).eq('id', _selectedLista!['id']);
              Navigator.pop(ctx);
              _loadListas();
            }, 'Guardar Cambios'));
  }

  void _confirmDeleteLista() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Eliminar Lista'),
                content: const Text('¿Seguro que deseas eliminar esta lista?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () async {
                        await SupaFlow.client
                            .from('listas_club')
                            .delete()
                            .eq('id', _selectedLista!['id']);
                        Navigator.pop(ctx);
                        setState(() => _selectedLista = null);
                        _loadListas();
                      },
                      child: const Text('Eliminar',
                          style: TextStyle(color: Colors.red))),
                ]));
  }

  void _showAddJugadorModal() async {
    if (_selectedLista == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una lista primero')),
      );
      return;
    }

    final candidatePlayers = await _fetchCandidatePlayersForClub();
    final savedPlayers = await _fetchSavedPlayersForClub();

    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    Map<String, dynamic>? selected;
    int rating = 0;
    final notaCtrl = TextEditingController();
    String source = 'candidatos';

    List<Map<String, dynamic>> currentSourcePlayers() {
      if (source == 'guardados') return savedPlayers;
      if (source == 'todos') {
        final map = <String, Map<String, dynamic>>{};
        for (final row in [...candidatePlayers, ...savedPlayers]) {
          final uid = row['user_id']?.toString() ?? '';
          if (uid.isEmpty) continue;
          map[uid] = row;
        }
        return map.values.toList();
      }
      return candidatePlayers;
    }

    void runSearch(StateSetter setStates, String value) {
      final query = value.trim().toLowerCase();
      final base = currentSourcePlayers();

      if (query.length < 2) {
        setStates(() => results = base.take(8).toList());
        return;
      }

      final localResults = base.where((player) {
        final name =
            '${player['name'] ?? ''} ${player['lastname'] ?? ''}'.toLowerCase();
        final username = (player['username'] ?? '').toString().toLowerCase();
        final position = (player['posicion'] ?? '').toString().toLowerCase();
        final city = (player['city'] ?? '').toString().toLowerCase();
        return name.contains(query) ||
            username.contains(query) ||
            position.contains(query) ||
            city.contains(query);
      }).toList();

      setStates(() => results = localResults.take(12).toList());
    }

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setStates) {
              return _buildModalContent(ctx, 'Agregar Jugador', [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Candidatos'),
                      selected: source == 'candidatos',
                      onSelected: (_) {
                        setStates(() {
                          source = 'candidatos';
                        });
                        runSearch(setStates, searchCtrl.text);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Guardados'),
                      selected: source == 'guardados',
                      onSelected: (_) {
                        setStates(() {
                          source = 'guardados';
                        });
                        runSearch(setStates, searchCtrl.text);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: source == 'todos',
                      onSelected: (_) {
                        setStates(() {
                          source = 'todos';
                        });
                        runSearch(setStates, searchCtrl.text);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                        hintText: 'Buscar jugador...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8))),
                    onChanged: (v) => runSearch(setStates, v)),
                if (results.isNotEmpty && selected == null)
                  ...results.map((j) => ListTile(
                        leading: CircleAvatar(
                            backgroundImage: j['photo_url'] != null
                                ? NetworkImage(j['photo_url'])
                                : null),
                        title: Text('${j['name']} ${j['lastname']}'),
                        onTap: () => setStates(() {
                          selected = j;
                          results = [];
                        }),
                      )),
                if (results.isEmpty && selected == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Sem resultados para esta origem de busca.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                if (selected != null)
                  ListTile(
                    leading: CircleAvatar(
                        backgroundImage: selected!['photo_url'] != null
                            ? NetworkImage(selected!['photo_url'])
                            : null),
                    title:
                        Text('${selected!['name']} ${selected!['lastname']}'),
                    trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setStates(() => selected = null)),
                  ),
                const SizedBox(height: 16),
                const Text('Calificación'),
                Row(
                    children: List.generate(
                        5,
                        (i) => IconButton(
                            icon: Icon(Icons.circle,
                                color: i < rating
                                    ? Colors.amber
                                    : Colors.grey[300]),
                            onPressed: () => setStates(() => rating = i + 1)))),
                _buildTextField(ctx, 'Nota', notaCtrl, maxLines: 3),
              ], () async {
                if (selected == null) return;
                await SupaFlow.client.from('listas_jugadores').insert({
                  'lista_id': _selectedLista!['id'],
                  'jugador_id': selected!['user_id'],
                  'calificacion': rating,
                  'nota': notaCtrl.text,
                  'created_at': DateTime.now().toIso8601String()
                });
                Navigator.pop(ctx);
                _loadJugadoresEnLista(_selectedLista!['id'].toString());
                _loadListas();
              }, 'Agregar');
            }));
  }

  void _showEditJugadorModal(Map<String, dynamic> item) {
    int rating = item['calificacion'] ?? 0;
    final notaCtrl = TextEditingController(text: item['nota']);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setStates) {
              return _buildModalContent(ctx, 'Editar Nota', [
                const Text('Calificación'),
                Row(
                    children: List.generate(
                        5,
                        (i) => IconButton(
                            icon: Icon(Icons.circle,
                                color: i < rating
                                    ? Colors.amber
                                    : Colors.grey[300]),
                            onPressed: () => setStates(() => rating = i + 1)))),
                _buildTextField(ctx, 'Nota', notaCtrl, maxLines: 3),
                const SizedBox(height: 10),
                TextButton(
                    child: const Text('Eliminar de lista',
                        style: TextStyle(color: Colors.red)),
                    onPressed: () async {
                      await SupaFlow.client
                          .from('listas_jugadores')
                          .delete()
                          .eq('id', item['id']);
                      Navigator.pop(ctx);
                      _loadJugadoresEnLista(_selectedLista!['id'].toString());
                      _loadListas();
                    })
              ], () async {
                await SupaFlow.client.from('listas_jugadores').update({
                  'calificacion': rating,
                  'nota': notaCtrl.text,
                }).eq('id', item['id']);
                Navigator.pop(ctx);
                _loadJugadoresEnLista(_selectedLista!['id'].toString());
              }, 'Guardar');
            }));
  }

  void _showAllListasModal() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
              height: MediaQuery.of(ctx).size.height * 0.5,
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(children: [
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Todas las Listas',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold))),
                Expanded(
                    child: ListView.builder(
                        itemCount: _listas.length,
                        itemBuilder: (context, i) => ListTile(
                              title: Text(_listas[i]['nombre'] ?? ''),
                              trailing: Text(
                                  _listas[i]['jugadores_count'].toString()),
                              onTap: () {
                                Navigator.pop(ctx);
                                _selectLista(_listas[i]);
                              },
                            )))
              ]),
            ));
  }

  Widget _buildModalContent(BuildContext context, String title,
      List<Widget> children, VoidCallback onSave, String buttonText) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context))
                    ]),
                const Divider(),
                ...children,
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D3B66)),
                        onPressed: onSave,
                        child: Text(buttonText,
                            style: const TextStyle(color: Colors.white))))
              ]))),
    );
  }

  Widget _buildTextField(
      BuildContext context, String label, TextEditingController ctrl,
      {int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 5),
      TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[100],
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
    ]);
  }
}
