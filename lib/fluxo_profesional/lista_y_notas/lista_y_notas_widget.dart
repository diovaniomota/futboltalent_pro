import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/app_modals.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
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
  List<Map<String, dynamic>> _jugadoresGuardados = [];
  bool _isLoadingGuardados = false;
  bool _showGuardados = false;
  bool _isClubStaff = false;
  int? _currentPlanId;
  bool _currentUserVerified = true;
  bool _isSearchingGlobalPlayers = false;
  List<Map<String, dynamic>> _globalSearchResults = [];
  String? _globalSearchError;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ListaYNotasModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _currentUserId = currentUserUid;
    _initData();
    _searchController.addListener(_filterJugadores);
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.removeListener(_filterJugadores);
    _searchDebounce?.cancel();
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

  bool get _canUseSensitiveActions =>
      FFAppState().unlockSensitiveActions ||
      (_currentPlanId != null && _currentUserVerified);

  bool _resolveVerification(Map<String, dynamic>? user,
      {required bool defaultIfMissing}) {
    if (user == null) return defaultIfMissing;
    final hasInfo = user.containsKey('is_verified') ||
        user.containsKey('verification_status');
    if (!hasInfo) return defaultIfMissing;

    final direct = user['is_verified'];
    if (direct is bool) return direct;

    final status = user['verification_status']?.toString().toLowerCase() ?? '';
    return status == 'verified' ||
        status == 'verificado' ||
        status == 'aprovado' ||
        status == 'aprobado';
  }

  Future<void> _initData() async {
    await _loadViewerCapabilities();
    await Future.wait([
      _loadListas(),
      _loadJugadoresGuardados(),
    ]);
  }

  Future<void> _loadViewerCapabilities() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    try {
      final user = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', _currentUserId!)
          .maybeSingle();
      if (user != null) {
        _currentPlanId = user['plan_id'] as int?;
        _currentUserVerified = _resolveVerification(
          user,
          defaultIfMissing: true,
        );
      }
    } catch (_) {
      _currentPlanId = null;
      _currentUserVerified = true;
    }

    try {
      final response = await SupaFlow.client
          .from('club_staff')
          .select('id')
          .eq('user_id', _currentUserId!)
          .limit(1);
      _isClubStaff = (response as List).isNotEmpty;
    } catch (_) {
      _isClubStaff = false;
    }

    if (mounted) setState(() {});
  }

  void _showUpsellDialog() {
    showBlockedActionDialog(
      context,
      title: 'Acción bloqueada',
      message:
          'Para acciones sensibles necesitas cuenta verificada y plan activo.',
      confirmLabel: 'Entendido',
    );
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

    _searchDebounce?.cancel();
    if (query.length < 2) {
      final suggestions = _suggestedPlayersFromGuardados();
      setState(() {
        _isSearchingGlobalPlayers = false;
        _globalSearchResults = suggestions;
        _globalSearchError = suggestions.isEmpty
            ? 'Escribí al menos 2 letras para buscar más jugadores.'
            : null;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _searchPlayersToAdd(query);
    });
  }

  List<Map<String, dynamic>> _suggestedPlayersFromGuardados() {
    final existingIds = _jugadoresEnLista
        .map((item) => item['jugador_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final dedup = <String, Map<String, dynamic>>{};
    for (final g in _jugadoresGuardados) {
      final data = (g['jugador_data'] as Map<String, dynamic>?) ?? {};
      final uid = (g['jugador_id']?.toString().trim().isNotEmpty ?? false)
          ? g['jugador_id'].toString().trim()
          : (data['user_id']?.toString().trim() ?? '');
      if (uid.isEmpty || existingIds.contains(uid)) continue;
      dedup[uid] = {
        ...data,
        'user_id': uid,
      };
    }
    return dedup.values.take(8).toList();
  }

  Future<void> _searchPlayersToAdd(String query) async {
    if (_selectedLista == null) return;
    setState(() {
      _isSearchingGlobalPlayers = true;
      _globalSearchError = null;
    });
    try {
      dynamic res;
      try {
        res = await SupaFlow.client
            .from('users')
            .select(
                'user_id, name, lastname, username, posicion, photo_url, city')
            .inFilter('userType',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta'])
            .or('name.ilike.%$query%,lastname.ilike.%$query%,username.ilike.%$query%,posicion.ilike.%$query%,city.ilike.%$query%')
            .limit(12);
      } catch (_) {
        res = await SupaFlow.client
            .from('users')
            .select(
                'user_id, name, lastname, username, posicion, photo_url, city')
            .inFilter('usertype',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta'])
            .or('name.ilike.%$query%,lastname.ilike.%$query%,username.ilike.%$query%,posicion.ilike.%$query%,city.ilike.%$query%')
            .limit(12);
      }

      final existingIds = _jugadoresEnLista
          .map((item) => item['jugador_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final candidates = List<Map<String, dynamic>>.from(res).where((player) {
        final uid = player['user_id']?.toString() ?? '';
        return uid.isNotEmpty && !existingIds.contains(uid);
      }).toList();

      if (!mounted) return;
      setState(() {
        _globalSearchResults = candidates;
        _isSearchingGlobalPlayers = false;
        if (candidates.isEmpty) {
          _globalSearchError = 'No se encontraron jugadores para agregar.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearchingGlobalPlayers = false;
        _globalSearchResults = [];
        _globalSearchError = 'No se pudo buscar jugadores.';
      });
    }
  }

  Future<void> _addPlayerDirectFromSearch(Map<String, dynamic> player) async {
    if (!_canUseSensitiveActions) {
      _showUpsellDialog();
      return;
    }
    if (_selectedLista == null) return;

    final listaId = _selectedLista!['id']?.toString() ?? '';
    final jugadorId = player['user_id']?.toString() ?? '';
    if (listaId.isEmpty || jugadorId.isEmpty) return;

    try {
      final existing = await SupaFlow.client
          .from('listas_jugadores')
          .select('id')
          .eq('lista_id', listaId)
          .eq('jugador_id', jugadorId)
          .maybeSingle();
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jugador ya está en esta lista')),
          );
        }
        return;
      }

      await SupaFlow.client.from('listas_jugadores').insert({
        'lista_id': listaId,
        'jugador_id': jugadorId,
        'nota': '',
        'calificacion': 3,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${(player['name'] ?? 'Jugador').toString()} agregado a la lista'),
          backgroundColor: Colors.green[700],
        ),
      );
      _searchController.clear();
      await _loadJugadoresEnLista();
      await _loadListas();
    } catch (e) {
      final raw = e.toString().toLowerCase();
      var message = 'No se pudo agregar el jugador a la lista.';
      if (raw.contains('23503') || raw.contains('foreign key constraint')) {
        message =
            'La lista seleccionada no está disponible. Actualizá tus listas y volvé a intentar.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
        ));
      }
    }
  }

  Future<void> _loadListas() async {
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await SupaFlow.client
          .from('listas')
          .select()
          .eq('profesional_id', _currentUserId!)
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
            if (convResponse != null &&
                convResponse['profesional_id'] != null) {
              final clubResponse = await SupaFlow.client
                  .from('users')
                  .select('name, photo_url')
                  .eq('user_id', convResponse['profesional_id'])
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
          if (_searchController.text.trim().length < 2) {
            final suggestions = _suggestedPlayersFromGuardados();
            _globalSearchResults = suggestions;
            _globalSearchError = suggestions.isEmpty
                ? 'Escribí al menos 2 letras para buscar más jugadores.'
                : null;
          } else {
            _globalSearchResults = [];
            _globalSearchError = null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingJugadores = false);
    }
  }

  Future<void> _loadJugadoresGuardados() async {
    if (_currentUserId == null) return;
    setState(() => _isLoadingGuardados = true);
    try {
      final response = await SupaFlow.client
          .from('jugadores_guardados')
          .select()
          .eq('scout_id', _currentUserId!)
          .order('created_at', ascending: false);
      final guardados = List<Map<String, dynamic>>.from(response);
      for (var g in guardados) {
        if (g['jugador_id'] != null) {
          try {
            final jugadorResponse = await SupaFlow.client
                .from('users')
                .select('user_id, name, lastname, posicion, photo_url, city')
                .eq('user_id', g['jugador_id'])
                .maybeSingle();
            g['jugador_data'] = jugadorResponse;
          } catch (_) {}
        }
      }
      if (mounted) {
        setState(() {
          _jugadoresGuardados = guardados;
          _isLoadingGuardados = false;
          if (_selectedLista != null &&
              _searchController.text.trim().length < 2) {
            final suggestions = _suggestedPlayersFromGuardados();
            _globalSearchResults = suggestions;
            _globalSearchError = suggestions.isEmpty
                ? 'Escribí al menos 2 letras para buscar más jugadores.'
                : null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando guardados: $e');
      if (mounted) setState(() => _isLoadingGuardados = false);
    }
  }

  Future<void> _editarNotaGuardado(Map<String, dynamic> guardado) async {
    final notaCtrl = TextEditingController(text: guardado['nota'] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nota del Jugador'),
        content: TextField(
          controller: notaCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Escribe una nota...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, notaCtrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        await SupaFlow.client.from('jugadores_guardados').update({
          'nota': result,
          'updated_at': DateTime.now().toIso8601String()
        }).eq('id', guardado['id']);
        await _loadJugadoresGuardados();
      } catch (_) {}
    }
  }

  Future<void> _removeGuardado(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Jugador'),
        content: const Text('¿Quitar este jugador de guardados?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await SupaFlow.client.from('jugadores_guardados').delete().eq('id', id);
        await _loadJugadoresGuardados();
      } catch (_) {}
    }
  }

  Future<void> _addGuardadoToList(Map<String, dynamic> guardado) async {
    if (!_canUseSensitiveActions) {
      _showUpsellDialog();
      return;
    }

    if (_listas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea una lista primero')),
      );
      return;
    }
    final selectedLista = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar Lista'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _listas
                .map((l) => ListTile(
                      title: Text(l['nombre'] ?? 'Lista'),
                      onTap: () => Navigator.pop(ctx, l),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (selectedLista != null) {
      try {
        final existing = await SupaFlow.client
            .from('listas_jugadores')
            .select('id')
            .eq('lista_id', selectedLista['id'])
            .eq('jugador_id', guardado['jugador_id'])
            .maybeSingle();
        if (existing != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Jugador ya está en esta lista')),
            );
          }
          return;
        }
        await SupaFlow.client.from('listas_jugadores').insert({
          'lista_id': selectedLista['id'],
          'jugador_id': guardado['jugador_id'],
          'nota': guardado['nota'] ?? '',
          'calificacion': 3,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jugador agregado a la lista'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadListas();
        if (_selectedLista?['id'] == selectedLista['id']) {
          await _loadJugadoresEnLista();
        }
      } catch (e) {
        final raw = e.toString().toLowerCase();
        var message = 'No se pudo agregar el jugador a la lista.';
        if (raw.contains('listas_jugadores_lista_id_fkey') ||
            raw.contains('foreign key constraint') ||
            raw.contains('23503')) {
          message =
              'La lista seleccionada no está disponible. Actualizá tus listas y volvé a intentar.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: Colors.red[700],
          ));
        }
      }
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
        try {
          await SupaFlow.client.from('listas').insert({
            'profesional_id': _currentUserId,
            'nombre': result.trim(),
            'is_private': true,
          });
        } catch (_) {
          await SupaFlow.client.from('listas').insert({
            'profesional_id': _currentUserId,
            'nombre': result.trim(),
          });
        }
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
            .from('listas')
            .delete()
            .eq('id', _selectedLista!['id']);
        setState(() => _selectedLista = null);
        await _loadListas();
      } catch (e) {}
    }
  }

  Future<void> _createNewNota() async {
    if (!_canUseSensitiveActions) {
      _showUpsellDialog();
      return;
    }

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

  void _shareSelectedLista() {
    if (!_isClubStaff || _selectedLista == null) return;

    final listName = _selectedLista!['nombre']?.toString() ?? 'Lista';
    final items = _jugadoresEnLista
        .map((item) {
          final jugador = item['jugador_data'] as Map<String, dynamic>?;
          final name =
              '${jugador?['name'] ?? ''} ${jugador?['lastname'] ?? ''}'.trim();
          final pos = jugador?['posicion']?.toString() ?? '';
          final note = item['nota']?.toString() ?? '';
          final parts = [
            if (name.isNotEmpty) name,
            if (pos.isNotEmpty) pos,
            if (note.isNotEmpty) 'Nota: $note',
          ];
          return parts.join(' • ');
        })
        .where((line) => line.isNotEmpty)
        .toList();

    final text = StringBuffer()
      ..writeln('Lista: $listName')
      ..writeln('Scout: ${_currentUserId ?? ''}')
      ..writeln('')
      ..writeln(items.isEmpty ? 'Sin jugadores aún.' : items.join('\n'));

    Share.share(text.toString());
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
                          Text('Cuaderno de Campo',
                              style: GoogleFonts.inter(
                                  fontSize: 24 * scale,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4 * scale),
                          Text(
                            'Decisión de jugadores',
                            style: GoogleFonts.inter(
                              fontSize: 13 * scale,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          // Toggle Mis Listas / Guardados
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _showGuardados = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_showGuardados
                                          ? const Color(0xFF0D3B66)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text('Listas',
                                          style: TextStyle(
                                            color: !_showGuardados
                                                ? Colors.white
                                                : Colors.grey[700],
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14 * scale,
                                          )),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _showGuardados = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _showGuardados
                                          ? const Color(0xFF0D3B66)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text('Guardados',
                                          style: TextStyle(
                                            color: _showGuardados
                                                ? Colors.white
                                                : Colors.grey[700],
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14 * scale,
                                          )),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                          SizedBox(height: 16 * scale),
                          if (!_showGuardados) ...[
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildActionButton(context, '+ Nueva Lista',
                                      _createNewLista),
                                  SizedBox(width: 12 * scale),
                                  _buildActionButton(
                                      context, '+ Decisión', _createNewNota),
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
                                            : _buildEmptyDetailSection(
                                                context)),
                                  ])
                            else ...[
                              _buildMisListasSection(context),
                              SizedBox(height: 24 * scale),
                              if (_selectedLista != null)
                                _buildDetalleListaSection(context),
                            ],
                          ] else
                            _buildGuardadosSection(context),
                          const SizedBox(height: 100),
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

  Widget _buildGuardadosSection(BuildContext context) {
    final scale = _scaleFactor(context);
    if (_isLoadingGuardados) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ));
    }
    if (_jugadoresGuardados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(children: [
            Icon(Icons.bookmark_border, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No tienes jugadores guardados',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text('Guarda jugadores desde su perfil para verlos aquí',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_jugadoresGuardados.length} jugador(es) guardado(s)',
            style: TextStyle(color: Colors.grey[600], fontSize: 13 * scale)),
        SizedBox(height: 12 * scale),
        ..._jugadoresGuardados.map((g) => _buildGuardadoCard(context, g)),
      ],
    );
  }

  Widget _buildGuardadoCard(
      BuildContext context, Map<String, dynamic> guardado) {
    final j = guardado['jugador_data'] as Map<String, dynamic>?;
    final name = '${j?['name'] ?? ''} ${j?['lastname'] ?? ''}'.trim();
    final posicion = j?['posicion'] ?? '';
    final city = j?['city'] ?? '';
    final nota = guardado['nota'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: j?['photo_url'] != null &&
                      j!['photo_url'].toString().isNotEmpty
                  ? NetworkImage(j['photo_url'])
                  : null,
              backgroundColor: const Color(0xFF0D3B66),
              child: (j?['photo_url'] == null ||
                      j!['photo_url'].toString().isEmpty)
                  ? Text(_getInitials(name.isNotEmpty ? name : 'J'),
                      style: const TextStyle(color: Colors.white, fontSize: 14))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isNotEmpty ? name : 'Jugador',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  if (posicion.isNotEmpty || city.isNotEmpty)
                    Text(
                        [posicion, city].where((s) => s.isNotEmpty).join(' - '),
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) {
                switch (value) {
                  case 'nota':
                    _editarNotaGuardado(guardado);
                    break;
                  case 'lista':
                    _addGuardadoToList(guardado);
                    break;
                  case 'perfil':
                    if (guardado['jugador_id'] != null) {
                      context.pushNamed('perfil_profesional_solicitar_Contato',
                          queryParameters: {'userId': guardado['jugador_id']});
                    }
                    break;
                  case 'eliminar':
                    _removeGuardado(guardado['id']);
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'nota', child: Text('Editar Nota')),
                PopupMenuItem(value: 'lista', child: Text('Agregar a Lista')),
                PopupMenuItem(value: 'perfil', child: Text('Ver Perfil')),
                PopupMenuItem(
                    value: 'eliminar',
                    child:
                        Text('Eliminar', style: TextStyle(color: Colors.red))),
              ],
            ),
          ]),
          if (nota.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 56),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(children: [
                  Icon(Icons.note, size: 14, color: Colors.amber[700]),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(nota,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[800]))),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D3B66),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
        const Text('Listas', style: TextStyle(fontWeight: FontWeight.bold)),
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
            if (_isClubStaff)
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: _shareSelectedLista,
                tooltip: 'Compartir lista',
              ),
            IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: _deleteLista),
          ]),
        ]),
        if (!_isClubStaff)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Compartir solo está habilitado para staff de club.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        const Divider(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Lista seleccionada. Podés agregar jugadores directamente acá.',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            OutlinedButton.icon(
              onPressed: _createNewNota,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Agregar jugador'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D3B66),
                side: const BorderSide(color: Color(0xFF0D3B66)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar en esta lista...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Agregar jugador a la lista',
                onPressed: _createNewNota,
                icon: const Icon(Icons.person_add_alt_1),
              ),
            )),
        const SizedBox(height: 10),
        if (_isSearchingGlobalPlayers ||
            _globalSearchResults.isNotEmpty ||
            _globalSearchError != null) ...[
          if (_isSearchingGlobalPlayers)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_globalSearchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE1E8F5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _searchController.text.trim().length >= 2
                        ? 'Resultados para agregar'
                        : 'Sugeridos para agregar',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._globalSearchResults.map((player) {
                    final fullName =
                        '${player['name'] ?? ''} ${player['lastname'] ?? ''}'
                            .trim();
                    final subtitle = [
                      player['posicion']?.toString() ?? '',
                      player['city']?.toString() ?? '',
                    ].where((s) => s.isNotEmpty).join(' • ');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundImage: player['photo_url'] != null &&
                                  player['photo_url']
                                      .toString()
                                      .trim()
                                      .isNotEmpty
                              ? NetworkImage(player['photo_url'])
                              : null,
                          backgroundColor: const Color(0xFF0D3B66),
                          child: (player['photo_url'] == null ||
                                  player['photo_url'].toString().trim().isEmpty)
                              ? Text(
                                  (fullName.isNotEmpty ? fullName[0] : 'J')
                                      .toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(
                          fullName.isNotEmpty ? fullName : 'Jugador',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: subtitle.isNotEmpty
                            ? Text(
                                subtitle,
                                style: const TextStyle(fontSize: 11),
                              )
                            : null,
                        trailing: TextButton(
                          onPressed: () => _addPlayerDirectFromSearch(player),
                          child: const Text('Agregar'),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          if (_globalSearchResults.isEmpty &&
              _globalSearchError != null &&
              !_isSearchingGlobalPlayers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _globalSearchError!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
        ],
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
  String? _errorMsg;
  int _rating = 3;

  String _resolveSaveError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('listas_jugadores_lista_id_fkey') ||
        raw.contains('foreign key constraint') ||
        raw.contains('23503')) {
      return 'No se pudo vincular esta lista. Reabrí Cuaderno de Campo o creá una lista nueva e intentá otra vez.';
    }
    if (raw.contains('duplicate key') ||
        raw.contains('already') ||
        raw.contains('unique')) {
      return 'Este jugador ya está en la lista.';
    }
    return 'No se pudo guardar. Intentá nuevamente.';
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() {
        _results = [];
        _errorMsg = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _errorMsg = null;
    });
    try {
      dynamic res;
      try {
        res = await SupaFlow.client
            .from('users')
            .select('user_id, name, lastname, posicion, photo_url, city')
            .inFilter('userType',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta'])
            .or('name.ilike.%$q%,lastname.ilike.%$q%')
            .limit(10);
      } catch (_) {
        res = await SupaFlow.client
            .from('users')
            .select('user_id, name, lastname, posicion, photo_url, city')
            .inFilter('usertype',
                ['jugador', 'jogador', 'player', 'athlete', 'atleta'])
            .or('name.ilike.%$q%,lastname.ilike.%$q%')
            .limit(10);
      }
      if (mounted) {
        setState(() {
          _results = List.from(res);
          if (_results.isEmpty) _errorMsg = 'No se encontraron jugadores';
        });
      }
    } catch (e) {
      debugPrint('Error buscando jugadores: $e');
      if (mounted) {
        setState(() => _errorMsg = 'Error en la búsqueda');
      }
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _save() async {
    if (_selected == null) return;
    try {
      // Check if already in list
      final existing = await SupaFlow.client
          .from('listas_jugadores')
          .select('id')
          .eq('lista_id', widget.listaId)
          .eq('jugador_id', _selected!['user_id'])
          .maybeSingle();
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Jugador ya está en esta lista')));
        }
        return;
      }
      await SupaFlow.client.from('listas_jugadores').insert({
        'lista_id': widget.listaId,
        'jugador_id': _selected!['user_id'],
        'nota': _notaCtrl.text,
        'calificacion': _rating
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_resolveSaveError(e)),
          backgroundColor: Colors.red[700],
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text('Agregar Jugador',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
            controller: _searchCtrl,
            onChanged: _search,
            autofocus: true,
            decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _results = [];
                                _errorMsg = null;
                              });
                            })
                        : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)))),
        if (_errorMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_errorMsg!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
        if (_results.isNotEmpty && _selected == null)
          Expanded(
              child: ListView(
                  children: _results.map((r) {
            final fullName = '${r['name'] ?? ''} ${r['lastname'] ?? ''}'.trim();
            final pos = r['posicion'] ?? '';
            final city = r['city'] ?? '';
            final subtitle = [pos, city].where((s) => s.isNotEmpty).join(' - ');
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: r['photo_url'] != null &&
                        r['photo_url'].toString().isNotEmpty
                    ? NetworkImage(r['photo_url'])
                    : null,
                backgroundColor: const Color(0xFF0D3B66),
                child: (r['photo_url'] == null ||
                        r['photo_url'].toString().isEmpty)
                    ? Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'J',
                        style: const TextStyle(color: Colors.white))
                    : null,
              ),
              title: Text(fullName.isNotEmpty ? fullName : 'Jugador'),
              subtitle: subtitle.isNotEmpty
                  ? Text(subtitle, style: const TextStyle(fontSize: 12))
                  : null,
              onTap: () => setState(() => _selected = r),
            );
          }).toList())),
        if (_selected != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0D3B66)),
            ),
            child: Row(children: [
              const Icon(Icons.person, color: Color(0xFF0D3B66)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      '${_selected!['name'] ?? ''} ${_selected!['lastname'] ?? ''}'
                          .trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selected = null)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                5,
                (index) => GestureDetector(
                      onTap: () => setState(() => _rating = index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFFDC700),
                            size: 28),
                      ),
                    )),
          ),
          const SizedBox(height: 8),
          TextField(
              controller: _notaCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                  hintText: 'Nota sobre el jugador...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Guardar',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ]
      ]),
    );
  }
}
