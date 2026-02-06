import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lista_y_notas_model.dart';
export 'lista_y_notas_model.dart';
import 'package:provider/provider.dart';

class ListaYNotasWidget extends StatefulWidget {
  const ListaYNotasWidget({super.key});

  static String routeName = 'Lista_y_notas';
  static String routePath = '/listaYNotas';

  @override
  State<ListaYNotasWidget> createState() => _ListaYNotasWidgetState();
}

class _ListaYNotasWidgetState extends State<ListaYNotasWidget> {
  late ListaYNotasModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _listas = [];
  Map<String, dynamic>? _selectedLista;
  List<Map<String, dynamic>> _jugadoresEnLista = [];
  List<Map<String, dynamic>> _filteredJugadores = [];
  bool _isLoading = true;
  bool _isLoadingJugadores = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ListaYNotasModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _currentUserId = currentUserUid;
    _loadListas();
    _searchController.addListener(_filterJugadores);
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.removeListener(_filterJugadores);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ============ HELPERS ============
  double _responsive(BuildContext context,
      {required double mobile, double? tablet, double? desktop}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return desktop ?? tablet ?? mobile;
    if (width >= 600) return tablet ?? mobile;
    return mobile;
  }

  bool _isLargeScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  double _scaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 320) return 0.8;
    if (width < 360) return 0.9;
    if (width >= 1024) return 1.1;
    return 1.0;
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final words = name.split(' ');
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  // ============ LOGIC ============
  void _filterJugadores() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredJugadores = _jugadoresEnLista;
      } else {
        _filteredJugadores = _jugadoresEnLista.where((j) {
          final jugadorData = j['jugador_data'] as Map<String, dynamic>?;
          final nombre = (jugadorData?['name'] ?? jugadorData?['nombre'] ?? '')
              .toString()
              .toLowerCase();
          final posicion =
              (jugadorData?['posicion'] ?? '').toString().toLowerCase();
          return nombre.contains(query) || posicion.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadListas() async {
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await SupaFlow.client
          .from('listas_club')
          .select()
          .eq('club_id', _currentUserId!)
          .order('created_at', ascending: false);
      final listas = List<Map<String, dynamic>>.from(response);

      for (var lista in listas) {
        try {
          final countResponse = await SupaFlow.client
              .from('listas_jugadores')
              .select('id')
              .eq('lista_id', lista['id']);
          lista['jugadores_count'] = (countResponse as List).length;
        } catch (e) {
          lista['jugadores_count'] = 0;
        }

        if (lista['convocatoria_id'] != null) {
          try {
            final convResponse = await SupaFlow.client
                .from('convocatorias')
                .select('titulo, club_id')
                .eq('id', lista['convocatoria_id'])
                .maybeSingle();
            lista['convocatoria_data'] = convResponse;
            if (convResponse != null && convResponse['club_id'] != null) {
              final clubResponse = await SupaFlow.client
                  .from('users')
                  .select('name, photo_url')
                  .eq('user_id', convResponse['club_id'])
                  .maybeSingle();
              lista['club_data'] = clubResponse;
            }
          } catch (e) {}
        }
      }

      if (mounted) {
        setState(() {
          _listas = listas;
          _isLoading = false;
          if (_listas.isNotEmpty && _selectedLista == null) {
            _selectedLista = _listas.first;
            _loadJugadoresEnLista();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadJugadoresEnLista() async {
    if (_selectedLista == null) return;
    setState(() => _isLoadingJugadores = true);
    try {
      final response = await SupaFlow.client
          .from('listas_jugadores')
          .select()
          .eq('lista_id', _selectedLista!['id'])
          .order('created_at', ascending: false);
      final jugadores = List<Map<String, dynamic>>.from(response);

      for (var j in jugadores) {
        if (j['jugador_id'] != null) {
          try {
            final jugadorResponse = await SupaFlow.client
                .from('users')
                .select()
                .eq('user_id', j['jugador_id'])
                .maybeSingle();
            j['jugador_data'] = jugadorResponse;
          } catch (e) {}
        }
      }
      if (mounted) {
        setState(() {
          _jugadoresEnLista = jugadores;
          _filteredJugadores = jugadores;
          _isLoadingJugadores = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingJugadores = false);
    }
  }

  Future<void> _createNewLista() async {
    final nombreController = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Nueva Lista'),
                content: TextField(
                    controller: nombreController,
                    decoration:
                        const InputDecoration(hintText: 'Nombre de la lista'),
                    autofocus: true),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(ctx, nombreController.text),
                      child: const Text('Crear')),
                ]));

    if (result != null && result.trim().isNotEmpty && _currentUserId != null) {
      try {
        await SupaFlow.client
            .from('listas_club')
            .insert({'club_id': _currentUserId, 'nombre': result.trim()});
        await _loadListas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteLista() async {
    if (_selectedLista == null) return;
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Eliminar Lista'),
                content: const Text('¿Seguro que deseas eliminarla?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Eliminar')),
                ]));

    if (confirm == true) {
      try {
        await SupaFlow.client
            .from('listas_club')
            .delete()
            .eq('id', _selectedLista!['id']);
        setState(() => _selectedLista = null);
        await _loadListas();
      } catch (e) {}
    }
  }

  Future<void> _createNewNota() async {
    if (_selectedLista == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una lista primero')));
      return;
    }
    final listaId = _selectedLista!['id']?.toString() ?? '';
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddJugadorModal(listaId: listaId),
    );
    if (result != null) {
      await _loadJugadoresEnLista();
      await _loadListas();
    }
  }

  Future<void> _editarNotaJugador(Map<String, dynamic> jugadorEnLista) async {
    final notaController =
        TextEditingController(text: jugadorEnLista['nota'] ?? '');
    int rating = jugadorEnLista['calificacion'] ?? 0;

    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
                    title: const Text('Editar Nota'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                              5,
                              (index) => GestureDetector(
                                    onTap: () => setDialogState(
                                        () => rating = index + 1),
                                    child: Icon(
                                        index < rating
                                            ? Icons.circle
                                            : Icons.circle_outlined,
                                        color: const Color(0xFFFDC700)),
                                  ))),
                      const SizedBox(height: 10),
                      TextField(
                          controller: notaController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              hintText: 'Notas', border: OutlineInputBorder())),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx,
                              {'notas': notaController.text, 'rating': rating}),
                          child: const Text('Guardar')),
                    ])));

    if (result != null) {
      try {
        await SupaFlow.client.from('listas_jugadores').update({
          'nota': result['notas'],
          'calificacion': result['rating']
        }).eq('id', jugadorEnLista['id']);
        await _loadJugadoresEnLista();
      } catch (e) {}
    }
  }

  // ============ UI ============
  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    final scale = _scaleFactor(context);
    final padding = _responsive(context, mobile: 16, tablet: 24, desktop: 32);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Stack(
          children: [
            SafeArea(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 1.0,
                height: MediaQuery.sizeOf(context).height * 1.0,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(padding),
                        child: Column(children: [
                          Text('Listas y Notas',
                              style: GoogleFonts.inter(
                                  fontSize: 24 * scale,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 16 * scale),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                    context, '+ Nueva Lista', _createNewLista),
                                SizedBox(width: 12 * scale),
                                _buildActionButton(
                                    context, '+ Nueva Nota', _createNewNota),
                              ]),
                          SizedBox(height: 24 * scale),
                          if (_isLargeScreen(context))
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      flex: 2,
                                      child: _buildMisListasSection(context)),
                                  SizedBox(width: 24 * scale),
                                  Expanded(
                                      flex: 3,
                                      child: _selectedLista != null
                                          ? _buildDetalleListaSection(context)
                                          : _buildEmptyDetailSection(context)),
                                ])
                          else ...[
                            _buildMisListasSection(context),
                            SizedBox(height: 24 * scale),
                            if (_selectedLista != null)
                              _buildDetalleListaSection(context),
                          ],
                          const SizedBox(height: 100), // Espaço para a NavBar
                        ]),
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

  Widget _buildActionButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF818181),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildMisListasSection(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mis Listas', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_listas.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20), child: Text('No hay listas'))
        else
          ..._listas.map((l) => _buildListaCard(context, l)),
      ]),
    );
  }

  Widget _buildListaCard(BuildContext context, Map<String, dynamic> lista) {
    final isSelected = _selectedLista?['id'] == lista['id'];
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLista = lista);
        _loadJugadoresEnLista();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F0FE) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    isSelected ? const Color(0xFF0D3B66) : Colors.grey[300]!)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(lista['nombre'] ?? 'Lista',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Creada: ${_formatDate(lista['created_at'])}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ])),
          Text('${lista['jugadores_count'] ?? 0}'),
        ]),
      ),
    );
  }

  Widget _buildEmptyDetailSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!)),
      child: const Center(child: Text('Selecciona una lista')),
    );
  }

  Widget _buildDetalleListaSection(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_selectedLista!['nombre'] ?? 'Lista',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: _deleteLista),
          ]),
        ]),
        const Divider(),
        TextField(
            controller: _searchController,
            decoration: const InputDecoration(
                hintText: 'Buscar jugador...', prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 10),
        if (_isLoadingJugadores)
          const Center(child: CircularProgressIndicator())
        else
          ..._filteredJugadores.map((j) => _buildJugadorCard(context, j)),
      ]),
    );
  }

  Widget _buildJugadorCard(BuildContext context, Map<String, dynamic> item) {
    final j = item['jugador_data'];
    final name = '${j?['name'] ?? ''} ${j?['lastname'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
              backgroundImage: j?['photo_url'] != null
                  ? NetworkImage(j!['photo_url'])
                  : null,
              child: j?['photo_url'] == null
                  ? Text(name.isNotEmpty ? name[0] : 'J')
                  : null),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name.isNotEmpty ? name : 'Jugador',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          TextButton(
              onPressed: () => _editarNotaJugador(item),
              child: const Text('Editar')),
        ]),
        if (item['nota'] != null)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(item['nota'], style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}

class _AddJugadorModal extends StatefulWidget {
  final String listaId;
  const _AddJugadorModal({required this.listaId});
  @override
  State<_AddJugadorModal> createState() => _AddJugadorModalState();
}

class _AddJugadorModalState extends State<_AddJugadorModal> {
  final _searchCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  List _results = [];
  Map? _selected;
  bool _searching = false;

  Future<void> _search(String q) async {
    if (q.length < 2) return;
    setState(() => _searching = true);
    try {
      final res = await SupaFlow.client
          .from('users')
          .select()
          .or('name.ilike.%$q%,lastname.ilike.%$q%')
          .eq('userType', 'jugador')
          .limit(10);
      setState(() => _results = List.from(res));
    } catch (e) {}
    setState(() => _searching = false);
  }

  Future<void> _save() async {
    if (_selected == null) return;
    try {
      await SupaFlow.client.from('listas_jugadores').insert({
        'lista_id': widget.listaId,
        'jugador_id': _selected!['user_id'],
        'nota': _notaCtrl.text,
        'calificacion': 3
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override // Re-added build method
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Text('Agregar Jugador',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(
            controller: _searchCtrl,
            onChanged: _search,
            decoration: InputDecoration(
                hintText: 'Buscar...',
                suffixIcon:
                    _searching ? const Icon(Icons.hourglass_empty) : null)),
        if (_results.isNotEmpty && _selected == null)
          Expanded(
              child: ListView(
                  children: _results
                      .map((r) => ListTile(
                          title: Text(r['name'] ?? ''),
                          onTap: () => setState(() => _selected = r)))
                      .toList())),
        if (_selected != null) ...[
          ListTile(
              title: Text(_selected!['name']),
              trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selected = null))),
          TextField(
              controller: _notaCtrl,
              decoration: const InputDecoration(hintText: 'Nota')),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _save, child: const Text('Guardar'))
        ]
      ]),
    );
  }
}
