import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/fluxo_compartilhado/perfil_publico_club/perfil_publico_club_widget.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:provider/provider.dart';
import '../detalles_de_la_convocatoria/detalles_de_la_convocatoria_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'convocatoria_jugador1_model.dart';
export 'convocatoria_jugador1_model.dart';

class ConvocatoriaJugador1Widget extends StatefulWidget {
  const ConvocatoriaJugador1Widget({super.key});

  static String routeName = 'convocatoria_jugador_1';
  static String routePath = '/convocatoriaJugador1';

  @override
  State<ConvocatoriaJugador1Widget> createState() =>
      _ConvocatoriaJugador1WidgetState();
}

class _ConvocatoriaJugador1WidgetState
    extends State<ConvocatoriaJugador1Widget> {
  late ConvocatoriaJugador1Model _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _convocatorias = [];
  List<Map<String, dynamic>> _filteredConvocatorias = [];
  bool _isLoading = true;

  // Filtros
  String? _selectedCategoria;
  String? _selectedUbicacion;
  String? _selectedPosicion;

  // Opciones de filtros
  List<String> _categorias = [];
  List<String> _ubicaciones = [];
  List<String> _posiciones = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConvocatoriaJugador1Model());
    _loadConvocatorias();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> _loadConvocatorias() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await SupaFlow.client
          .from('convocatorias')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final convocatorias = List<Map<String, dynamic>>.from(response);

      for (var conv in convocatorias) {
        final clubId = conv['club_id']?.toString() ?? '';
        if (clubId.isNotEmpty) {
          try {
            var clubResponse = await SupaFlow.client
                .from('clubs')
                .select()
                .eq('id', clubId)
                .maybeSingle();

            clubResponse ??= await SupaFlow.client
                .from('clubs')
                .select()
                .eq('user_id', clubId)
                .maybeSingle();

            clubResponse ??= await SupaFlow.client
                .from('clubs')
                .select()
                .eq('owner_id', clubId)
                .maybeSingle();

            if (clubResponse != null) {
              conv['club_data'] = clubResponse;
            }
          } catch (e) {
            debugPrint('Erro ao buscar clube: $e');
          }
        }
      }

      final activeCountByClub = <String, int>{};
      for (final conv in convocatorias) {
        final clubId = conv['club_id']?.toString().trim() ?? '';
        if (clubId.isEmpty) continue;
        activeCountByClub[clubId] = (activeCountByClub[clubId] ?? 0) + 1;
      }

      for (final conv in convocatorias) {
        final clubId = conv['club_id']?.toString().trim() ?? '';
        conv['active_convocatorias_count'] = activeCountByClub[clubId] ?? 0;
      }

      final categoriasSet = <String>{};
      final ubicacionesSet = <String>{};
      final posicionesSet = <String>{};

      for (var conv in convocatorias) {
        if (conv['categoria'] != null &&
            conv['categoria'].toString().isNotEmpty) {
          categoriasSet.add(conv['categoria'].toString());
        }
        if (conv['ubicacion'] != null &&
            conv['ubicacion'].toString().isNotEmpty) {
          ubicacionesSet.add(conv['ubicacion'].toString());
        }
        if (conv['posicion'] != null &&
            conv['posicion'].toString().isNotEmpty) {
          posicionesSet.add(conv['posicion'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _convocatorias = convocatorias;
          _filteredConvocatorias = convocatorias;
          _categorias = categoriasSet.toList()..sort();
          _ubicaciones = ubicacionesSet.toList()..sort();
          _posiciones = posicionesSet.toList()..sort();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar convocatorias: $e');
      if (mounted) {
        setState(() {
          _convocatorias = [];
          _filteredConvocatorias = [];
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final searchText = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredConvocatorias = _convocatorias.where((conv) {
        if (searchText.isNotEmpty) {
          final titulo = (conv['titulo'] ?? '').toString().toLowerCase();
          final descripcion =
              (conv['descripcion'] ?? '').toString().toLowerCase();
          final clubName = (conv['club_data']?['name'] ??
                  conv['club_data']?['club_name'] ??
                  '')
              .toString()
              .toLowerCase();

          if (!titulo.contains(searchText) &&
              !descripcion.contains(searchText) &&
              !clubName.contains(searchText)) {
            return false;
          }
        }

        if (_selectedCategoria != null && _selectedCategoria!.isNotEmpty) {
          if (conv['categoria'] != _selectedCategoria) return false;
        }

        if (_selectedUbicacion != null && _selectedUbicacion!.isNotEmpty) {
          if (conv['ubicacion'] != _selectedUbicacion) return false;
        }

        if (_selectedPosicion != null && _selectedPosicion!.isNotEmpty) {
          if (conv['posicion'] != _selectedPosicion) return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategoria = null;
      _selectedUbicacion = null;
      _selectedPosicion = null;
      _searchController.clear();
      _filteredConvocatorias = _convocatorias;
    });
  }

  void _navigateToDetail(Map<String, dynamic> convocatoria) {
    final convocatoriaId = convocatoria['id']?.toString() ?? '';
    if (convocatoriaId.isEmpty) return;

    context.pushNamed(
      DetallesDeLaConvocatoriaWidget.routeName,
      queryParameters: {
        'convocatoriaId': serializeParam(convocatoriaId, ParamType.String),
      }.withoutNulls,
    );
  }

  void _openClubProfile(Map<String, dynamic> convocatoria) {
    final clubData = convocatoria['club_data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(convocatoria['club_data'] as Map)
        : <String, dynamic>{
            'id': convocatoria['club_id'],
            'club_name': convocatoria['club_name'],
            'nombre_club': convocatoria['nombre_club'],
          };

    final refs = [
      clubData['id'],
      clubData['owner_id'],
      clubData['user_id'],
      convocatoria['club_id'],
    ];
    String clubRef = '';
    for (final value in refs) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        clubRef = text;
        break;
      }
    }
    if (clubRef.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilPublicoClubWidget(
          clubRef: clubRef,
          initialClubData: clubData,
        ),
      ),
    );
  }

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return null;
  }

  String _resolveClubName(Map<String, dynamic>? clubData) {
    return _firstNonEmpty([
          clubData?['name'],
          clubData?['club_name'],
          clubData?['nombre'],
          clubData?['nombre_corto'],
        ]) ??
        'Club';
  }

  String _resolveClubLogo(Map<String, dynamic>? clubData) {
    return _firstNonEmpty([
          clubData?['photo_url'],
          clubData?['logo_url'],
          clubData?['avatar_url'],
        ]) ??
        '';
  }

  String _resolveClubCountry(Map<String, dynamic>? clubData) {
    return _firstNonEmpty([
          clubData?['pais'],
          clubData?['country'],
          clubData?['country_name'],
        ]) ??
        '';
  }

  String _resolveClubLeague(Map<String, dynamic>? clubData) {
    return _firstNonEmpty([
          clubData?['liga'],
          clubData?['league'],
          clubData?['league_name'],
        ]) ??
        '';
  }

  String _resolveConvocatoriaLocation(Map<String, dynamic> convocatoria) {
    return _firstNonEmpty([
          convocatoria['ubicacion'],
          convocatoria['location'],
          convocatoria['city'],
          convocatoria['ciudad'],
          convocatoria['localidad'],
          (convocatoria['club_data'] as Map?)?['city'],
          (convocatoria['club_data'] as Map?)?['ciudad'],
        ]) ??
        'Sin ubicación';
  }

  String _resolveConvocatoriaMode(Map<String, dynamic> convocatoria) {
    final virtualFlag = convocatoria['is_virtual'] == true ||
        (convocatoria['virtual']?.toString().toLowerCase() == 'true');
    final presentialFlag = convocatoria['is_presencial'] == true ||
        convocatoria['is_in_person'] == true ||
        (convocatoria['presencial']?.toString().toLowerCase() == 'true');
    if (virtualFlag && presentialFlag) return 'Híbrida';
    if (virtualFlag) return 'Virtual';
    if (presentialFlag) return 'Presencial';

    final raw = (_firstNonEmpty([
          convocatoria['modalidad'],
          convocatoria['modality'],
          convocatoria['tipo_modalidad'],
          convocatoria['formato'],
          convocatoria['format'],
          convocatoria['tipo'],
        ]) ??
        'Presencial')
        .toLowerCase();

    if (raw.contains('hibr')) return 'Híbrida';
    if (raw.contains('virtual') ||
        raw.contains('online') ||
        raw.contains('remote') ||
        raw.contains('remot')) {
      return 'Virtual';
    }
    return 'Presencial';
  }

  Color _convocatoriaModeColor(String mode) {
    switch (mode) {
      case 'Virtual':
        return const Color(0xFF0284C7);
      case 'Híbrida':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF15803D);
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
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadConvocatorias,
                color: const Color(0xFF0D3B66),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchField(),
                      const SizedBox(height: 20),
                      _buildFilters(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Resultados',
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D3B66)),
                          ),
                          if (_selectedCategoria != null ||
                              _selectedUbicacion != null ||
                              _selectedPosicion != null ||
                              _searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: _clearFilters,
                              child: Text(
                                'Limpiar filtros',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF0D3B66),
                                    decoration: TextDecoration.underline),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_filteredConvocatorias.length} convocatorias encontradas',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF444444)),
                      ),
                      const SizedBox(height: 20),
                      _buildConvocatoriasList(),
                      const SizedBox(height: 80), // Space for NavBar
                    ],
                  ),
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

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA0AEC0), width: 1),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Buscar convocatorias',
          hintStyle:
              GoogleFonts.inter(color: const Color(0xFF444444), fontSize: 14),
          prefixIcon: const Icon(FontAwesomeIcons.magnifyingGlass,
              size: 18, color: Color(0xFF444444)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  })
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.inter(fontSize: 14),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildDropdownFilter(
              hint: 'Categoría',
              value: _selectedCategoria,
              items: _categorias,
              onChanged: (v) {
                setState(() => _selectedCategoria = v);
                _applyFilters();
              }),
          const SizedBox(width: 15),
          _buildDropdownFilter(
              hint: 'Ubicación',
              value: _selectedUbicacion,
              items: _ubicaciones,
              onChanged: (v) {
                setState(() => _selectedUbicacion = v);
                _applyFilters();
              }),
          const SizedBox(width: 15),
          _buildDropdownFilter(
              hint: 'Posición',
              value: _selectedPosicion,
              items: _posiciones,
              onChanged: (v) {
                setState(() => _selectedPosicion = v);
                _applyFilters();
              }),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(
      {required String hint,
      required String? value,
      required List<String> items,
      required Function(String?) onChanged}) {
    return Container(
      width: 130,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA0AEC0), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF444444))),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF444444), size: 24),
          isExpanded: true,
          style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black),
          items: [
            DropdownMenuItem<String>(
                value: null,
                child: Text(hint,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: const Color(0xFF444444)))),
            ...items.map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item,
                    style: GoogleFonts.inter(fontSize: 14),
                    overflow: TextOverflow.ellipsis))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildConvocatoriasList() {
    if (_isLoading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(color: Color(0xFF0D3B66))));
    }

    if (_filteredConvocatorias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: Column(
            children: [
              const Icon(Icons.search_off, size: 64, color: Color(0xFFA0AEC0)),
              const SizedBox(height: 16),
              Text('No se encontraron convocatorias',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF444444))),
              const SizedBox(height: 8),
              Text('Intenta ajustar los filtros de búsqueda',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: const Color(0xFF888888))),
            ],
          ),
        ),
      );
    }

    return Column(
        children: _filteredConvocatorias
            .map((conv) => _buildConvocatoriaCard(conv))
            .toList());
  }

  Widget _buildConvocatoriaCard(Map<String, dynamic> convocatoria) {
    final clubData = convocatoria['club_data'] as Map<String, dynamic>?;
    final clubName = _resolveClubName(clubData);
    final titulo = convocatoria['titulo'] ?? 'Convocatoria';
    final categoria = convocatoria['categoria']?.toString().trim() ?? '';
    final ubicacion = _resolveConvocatoriaLocation(convocatoria);
    final posicion = convocatoria['posicion']?.toString().trim() ?? '';
    final imagenUrl = convocatoria['imagen_url'] ?? '';
    final clubImageUrl = _resolveClubLogo(clubData);
    final clubLeague = _resolveClubLeague(clubData);
    final clubCountry = _resolveClubCountry(clubData);
    final clubSecondary = clubLeague.isNotEmpty ? clubLeague : clubCountry;
    final mode = _resolveConvocatoriaMode(convocatoria);
    final activeCount = convocatoria['active_convocatorias_count'] as int? ?? 0;

    return GestureDetector(
      onTap: () => _navigateToDetail(convocatoria),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120D3B66),
              blurRadius: 14,
              offset: Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  imagenUrl.isNotEmpty
                      ? Image.network(
                          imagenUrl,
                          width: double.infinity,
                          height: 156,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                        )
                      : _buildPlaceholderImage(),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _convocatoriaModeColor(mode).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        mode,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _convocatoriaModeColor(mode),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openClubProfile(convocatoria),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD9E6F5)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: clubImageUrl.isNotEmpty
                                ? Image.network(
                                    clubImageUrl,
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildClubPlaceholderIcon(),
                                  )
                                : _buildClubPlaceholderIcon(size: 42),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clubName,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0D3B66),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  clubSecondary.isNotEmpty
                                      ? clubSecondary
                                      : 'Club verificado en plataforma',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0FE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              activeCount > 0
                                  ? '$activeCount activas'
                                  : 'Sin activas',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0D3B66),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    titulo,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoTag(
                        Icons.badge_outlined,
                        'Club: $clubName',
                      ),
                      _buildInfoTag(
                        Icons.category_outlined,
                        'Categoría: ${categoria.isNotEmpty ? categoria : 'N/A'}',
                      ),
                      _buildInfoTag(
                        Icons.sports_soccer,
                        'Posición: ${posicion.isNotEmpty ? posicion : 'Todas'}',
                      ),
                      _buildInfoTag(
                        Icons.location_on_outlined,
                        'Ubicación: $ubicacion',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() => Container(
      width: double.infinity,
      height: 156,
      color: const Color(0xFFE0E0E0),
      child: const Center(
          child:
              Icon(Icons.sports_soccer, size: 50, color: Color(0xFF0D3B66))));
  Widget _buildClubPlaceholderIcon({double size = 24}) => Container(
      width: size,
      height: size,
      color: const Color(0xFF0D3B66),
      child: Icon(Icons.shield_outlined, size: size * 0.58, color: Colors.white));
  Widget _buildInfoTag(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: const Color(0xFF0D3B66)),
        const SizedBox(width: 4),
        Text(text,
            style:
                GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0D3B66)))
      ]));
}
