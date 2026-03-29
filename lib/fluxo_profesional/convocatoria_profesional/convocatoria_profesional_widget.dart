import '/backend/supabase/supabase.dart';
import '/flutter_flow/app_modals.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'convocatoria_profesional_model.dart';
export 'convocatoria_profesional_model.dart';
import '/fluxo_profesional/detalles_de_la_convocatoria_profesional/detalles_de_la_convocatoria_profesional_widget.dart';
import 'package:provider/provider.dart';

class ConvocatoriaProfesionalWidget extends StatefulWidget {
  const ConvocatoriaProfesionalWidget({super.key});

  static String routeName = 'convocatoria_profesional';
  static String routePath = '/convocatoria_profesional';

  @override
  State<ConvocatoriaProfesionalWidget> createState() =>
      _ConvocatoriaProfesionalWidgetState();
}

class _ConvocatoriaProfesionalWidgetState
    extends State<ConvocatoriaProfesionalWidget> {
  late ConvocatoriaProfesionalModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _convocatorias = [];
  List<Map<String, dynamic>> _filteredConvocatorias = [];
  bool _isLoading = true;

  String? _selectedCategoria;
  String? _selectedUbicacion;
  String? _selectedPosicion;
  List<String> _categorias = [];
  List<String> _ubicaciones = [];
  List<String> _posiciones = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConvocatoriaProfesionalModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadConvocatorias();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadConvocatorias() async {
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
                .from('users')
                .select()
                .eq('user_id', clubId)
                .maybeSingle();
            if (clubResponse != null) conv['club_data'] = clubResponse;
          } catch (e) {}
        }
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
    final search = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredConvocatorias = _convocatorias.where((conv) {
        if (search.isNotEmpty) {
          final t = (conv['titulo'] ?? '').toString().toLowerCase();
          final d = (conv['descripcion'] ?? '').toString().toLowerCase();
          final cn = (conv['club_data']?['name'] ??
                  conv['club_data']?['club_name'] ??
                  '')
              .toString()
              .toLowerCase();
          if (!t.contains(search) &&
              !d.contains(search) &&
              !cn.contains(search)) {
            return false;
          }
        }
        if (_selectedCategoria != null &&
            conv['categoria'] != _selectedCategoria) {
          return false;
        }
        if (_selectedUbicacion != null &&
            conv['ubicacion'] != _selectedUbicacion) {
          return false;
        }
        if (_selectedPosicion != null &&
            conv['posicion'] != _selectedPosicion) {
          return false;
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

  void _navigateToDetail(String id) {
    context.pushNamed(DetallesDeLaConvocatoriaProfesionalWidget.routeName,
        queryParameters: {
          'convocatoriasID': serializeParam(id, ParamType.String)
        }.withoutNulls);
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    final convocatoriasEnabled = FFAppState().isFeatureEnabled('convocatorias');
    final hasConvocatoriasAccess =
        FFAppState().canAccessFeature('convocatorias');
    if (!convocatoriasEnabled) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Convocatorias desactivadas temporalmente.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0D3B66),
              ),
            ),
          ),
        ),
      );
    }
    if (!hasConvocatoriasAccess) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PlanPaywallCard(
              title: 'Convocatórias no Plano Pro',
              message:
                  'Esse acesso fica disponível apenas no Plano Pro. Com o modo piloto ligado, o bloqueio deixa de valer.',
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Stack(
          children: [
            Container(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height * 0.92,
              color: Colors.white,
              child: SafeArea(
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
                                Text('Resultados',
                                    style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0D3B66))),
                                if (_selectedCategoria != null ||
                                    _selectedUbicacion != null ||
                                    _selectedPosicion != null ||
                                    _searchController.text.isNotEmpty)
                                  GestureDetector(
                                      onTap: _clearFilters,
                                      child: Text('Limpiar filtros',
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: const Color(0xFF0D3B66),
                                              decoration:
                                                  TextDecoration.underline)))
                              ]),
                          const SizedBox(height: 10),
                          Text(
                              '${_filteredConvocatorias.length} convocatorias encontradas',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF444444))),
                          const SizedBox(height: 20),
                          _buildConvocatoriasList(),
                        ]),
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
          border: Border.all(color: const Color(0xFFA0AEC0))),
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
                    onPressed: _clearFilters)
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        style: GoogleFonts.inter(fontSize: 14),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _buildDropdown('Categoría', _selectedCategoria, _categorias, (v) {
            setState(() => _selectedCategoria = v);
            _applyFilters();
          }),
          const SizedBox(width: 15),
          _buildDropdown('Ubicación', _selectedUbicacion, _ubicaciones, (v) {
            setState(() => _selectedUbicacion = v);
            _applyFilters();
          }),
          const SizedBox(width: 15),
          _buildDropdown('Posición', _selectedPosicion, _posiciones, (v) {
            setState(() => _selectedPosicion = v);
            _applyFilters();
          }),
        ]));
  }

  Widget _buildDropdown(String hint, String? value, List<String> items,
      Function(String?) onChanged) {
    return Container(
      width: 130,
      height: 38,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA0AEC0))),
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
          DropdownMenuItem(
              value: null,
              child: Text(hint,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: const Color(0xFF444444)))),
          ...items.map((i) => DropdownMenuItem(
              value: i,
              child: Text(i,
                  style: GoogleFonts.inter(fontSize: 14),
                  overflow: TextOverflow.ellipsis)))
        ],
        onChanged: onChanged,
      )),
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
              child: Column(children: [
                const Icon(Icons.search_off,
                    size: 64, color: Color(0xFFA0AEC0)),
                const SizedBox(height: 16),
                Text('No se encontraron convocatorias',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF444444))),
              ])));
    }
    return Column(
        children: _filteredConvocatorias.map((c) => _buildCard(c)).toList());
  }

  Widget _buildCard(Map<String, dynamic> c) {
    final club = c['club_data'];
    final clubName = club?['name'] ?? club?['club_name'] ?? 'Club';
    final img = c['imagen_url'] ?? '';
    final clubImg = club?['photo_url'] ?? club?['logo_url'] ?? '';
    String date = '';
    if (c['fecha_inicio'] != null) {
      try {
        final d = DateTime.parse(c['fecha_inicio']);
        date = '${d.day}/${d.month}/${d.year}';
        if (c['fecha_fin'] != null) {
          final e = DateTime.parse(c['fecha_fin']);
          date += ' - ${e.day}/${e.month}/${e.year}';
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _navigateToDetail(c['id']?.toString() ?? ''),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: img.isNotEmpty
                  ? Image.network(img,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder()),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (clubImg.isNotEmpty) ...[
                        ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(clubImg,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    width: 24,
                                    height: 24,
                                    color: const Color(0xFF0D3B66),
                                    child: const Icon(Icons.sports_soccer,
                                        size: 16, color: Colors.white)))),
                        const SizedBox(width: 8)
                      ],
                      Expanded(
                          child: Text(clubName,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D3B66)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 6),
                    Text(c['titulo'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0D3B66)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (c['descripcion'] != null) ...[
                      const SizedBox(height: 4),
                      Text(c['descripcion'],
                          style: GoogleFonts.inter(
                              fontSize: 12, color: const Color(0xFF666666)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)
                    ],
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (c['categoria'] != null)
                        _tag(Icons.category_outlined, c['categoria']),
                      if (c['posicion'] != null)
                        _tag(Icons.sports_soccer, c['posicion']),
                      if (c['ubicacion'] != null)
                        _tag(Icons.location_on_outlined, c['ubicacion']),
                    ]),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: Color(0xFF888888)),
                        const SizedBox(width: 4),
                        Text(date,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF888888)))
                      ])
                    ]
                  ]))
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
      width: double.infinity,
      height: 140,
      color: const Color(0xFFE0E0E0),
      child: const Center(
          child:
              Icon(Icons.sports_soccer, size: 50, color: Color(0xFF0D3B66))));
  Widget _tag(IconData i, String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 14, color: const Color(0xFF0D3B66)),
        const SizedBox(width: 4),
        Text(t,
            style:
                GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0D3B66)))
      ]));
}
