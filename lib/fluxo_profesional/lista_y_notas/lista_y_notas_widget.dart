import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/fluxo_compartilhado/scouting_metadata_utils.dart';
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

  String _normalizeId(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static const List<String> _scoutingStates = ScoutingMetadataUtils.states;

  String _scoutingStateLabel(String state) =>
      ScoutingMetadataUtils.labelFromState(state);

  String _scoutingStateFromItem(Map<String, dynamic> item) =>
      ScoutingMetadataUtils.stateFromItem(item);

  int _ratingFromScoutingState(String state) =>
      ScoutingMetadataUtils.ratingFromState(state);

  List<String> _parseScoutingTags(dynamic raw) =>
      ScoutingMetadataUtils.parseTags(raw);

  Color _scoutingStateColor(String state) {
    switch (state) {
      case 'descubierto':
        return const Color(0xFF2563EB);
      case 'en_acompanamiento':
        return const Color(0xFFF59E0B);
      case 'prioridad':
        return const Color(0xFF0F766E);
      case 'descartado':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildStatePill(String state) {
    final color = _scoutingStateColor(state);
    final background = () {
      switch (state) {
        case 'descubierto':
          return const Color(0xFFEFF6FF);
        case 'en_acompanamiento':
          return const Color(0xFFFFF7ED);
        case 'prioridad':
          return const Color(0xFFECFDF3);
        case 'descartado':
          return const Color(0xFFFEF2F2);
        default:
          return color.withOpacity(0.12);
      }
    }();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        _scoutingStateLabel(state),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  bool get _canUseSensitiveActions =>
      FFAppState().canUseSensitiveActions ||
      ((_currentPlanId ?? 0) >= 2 && _currentUserVerified);

  Future<bool> _ensureSensitiveAccess() async {
    await _loadViewerCapabilities();
    if (_canUseSensitiveActions) {
      return true;
    }

    if (mounted) {
      _showUpsellDialog();
    }
    return false;
  }

  Future<void> _initData() async {
    await _loadViewerCapabilities();
    await Future.wait([
      _loadListas(),
      _loadJugadoresGuardados(),
    ]);
  }

  Future<void> _refreshData() async {
    await _loadViewerCapabilities();
    await Future.wait([
      _loadListas(),
      _loadJugadoresGuardados(),
    ]);
    if (_selectedLista != null) {
      await _loadJugadoresEnLista();
    }
  }

  Future<void> _loadViewerCapabilities() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    try {
      await FFAppState().refreshCurrentUserAccess();
      final appState = FFAppState();
      _currentPlanId = appState.currentPlanId;
      _currentUserVerified = appState.currentUserVerified;
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

  String _normalizeForMatch(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  List<String> _contextPositionTokens() {
    final listName = (_selectedLista?['nombre']?.toString() ?? '').trim();
    if (listName.isEmpty) return const [];
    final normalized = _normalizeForMatch(listName);

    const tokenGroups = <String, List<String>>{
      'arquero': ['arquero', 'portero', 'goalkeeper', 'goleiro'],
      'defensa': ['defensa', 'defensor', 'zaguero', 'lateral', 'center back'],
      'mediocampo': ['mediocampo', 'mediocampista', 'volante', 'medio'],
      'delantero': ['delantero', 'atacante', 'punta', 'extremo', 'forward'],
    };

    final matches = <String>{};
    tokenGroups.forEach((_, tokens) {
      for (final token in tokens) {
        if (normalized.contains(token)) {
          matches.addAll(tokens);
          break;
        }
      }
    });
    return matches.toList();
  }

  bool _matchesSuggestionContext(Map<String, dynamic> player) {
    final tokens = _contextPositionTokens();
    if (tokens.isEmpty) return true;
    final position = _normalizeForMatch(
      (player['posicion'] ?? player['position'] ?? '').toString(),
    );
    if (position.isEmpty) return false;
    return tokens.any(position.contains);
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

    final all = dedup.values.toList();
    final contextual = all.where(_matchesSuggestionContext).toList();
    if (contextual.isNotEmpty) {
      return contextual.take(8).toList();
    }
    return all.take(8).toList();
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
    if (!await _ensureSensitiveAccess()) {
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
        'calificacion': 1,
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
      final mergedByPlayerId = <String, Map<String, dynamic>>{};

      for (final row in List<Map<String, dynamic>>.from(response)) {
        final jugadorId = _normalizeId(row['jugador_id']);
        final rowId = _normalizeId(row['id']);
        if (jugadorId.isEmpty || rowId.isEmpty) continue;
        mergedByPlayerId[jugadorId] = {
          ...row,
          'source_table': 'jugadores_guardados',
          'source_row_id': rowId,
          'id': 'jugadores_guardados:$rowId',
        };
      }

      final listasResponse = await SupaFlow.client
          .from('listas')
          .select('id')
          .eq('profesional_id', _currentUserId!);
      final listaIds = (listasResponse as List)
          .map((item) => _normalizeId((item as Map)['id']))
          .where((id) => id.isNotEmpty)
          .toList();

      if (listaIds.isNotEmpty) {
        final listasJugadoresResponse = await SupaFlow.client
            .from('listas_jugadores')
            .select('id, lista_id, jugador_id, nota, created_at, updated_at')
            .inFilter('lista_id', listaIds)
            .order('created_at', ascending: false);

        for (final row
            in List<Map<String, dynamic>>.from(listasJugadoresResponse)) {
          final jugadorId = _normalizeId(row['jugador_id']);
          final rowId = _normalizeId(row['id']);
          if (jugadorId.isEmpty || rowId.isEmpty) continue;

          mergedByPlayerId.putIfAbsent(
            jugadorId,
            () => {
              ...row,
              'scout_id': _currentUserId,
              'source_table': 'listas_jugadores',
              'source_row_id': rowId,
              'id': 'listas_jugadores:$rowId',
            },
          );
        }
      }

      if (mergedByPlayerId.isNotEmpty) {
        final usersResponse = await SupaFlow.client
            .from('users')
            .select('user_id, name, lastname, posicion, photo_url, city')
            .inFilter('user_id', mergedByPlayerId.keys.toList());

        final usersById = <String, Map<String, dynamic>>{};
        for (final user in List<Map<String, dynamic>>.from(usersResponse)) {
          final userId = _normalizeId(user['user_id']);
          if (userId.isEmpty) continue;
          usersById[userId] = user;
        }

        mergedByPlayerId.forEach((jugadorId, row) {
          row['jugador_data'] = usersById[jugadorId];
        });
      }

      final guardados = mergedByPlayerId.values.toList();
      DateTime safeCreatedAt(Map<String, dynamic> item) {
        final raw = item['created_at']?.toString();
        return DateTime.tryParse(raw ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }

      guardados.sort(
        (a, b) => safeCreatedAt(b).compareTo(safeCreatedAt(a)),
      );

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
        final sourceTable =
            guardado['source_table']?.toString() ?? 'jugadores_guardados';
        final rowId = _normalizeId(guardado['source_row_id'] ?? guardado['id']);
        if (rowId.isEmpty) return;

        await SupaFlow.client.from(sourceTable).update({
          'nota': result,
          'updated_at': DateTime.now().toIso8601String()
        }).eq('id', rowId);
        await _loadJugadoresGuardados();
      } catch (_) {}
    }
  }

  Future<void> _removeGuardado(Map<String, dynamic> guardado) async {
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
        final sourceTable =
            guardado['source_table']?.toString() ?? 'jugadores_guardados';
        final rowId = _normalizeId(guardado['source_row_id'] ?? guardado['id']);
        if (rowId.isEmpty) return;

        await SupaFlow.client.from(sourceTable).delete().eq('id', rowId);
        await _loadJugadoresGuardados();
      } catch (_) {}
    }
  }

  Future<void> _addGuardadoToList(Map<String, dynamic> guardado) async {
    if (!await _ensureSensitiveAccess()) {
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
          'calificacion': 1,
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
              .showSnackBar(const SnackBar(content: Text('No pudimos crear la lista. Verifica tu conexión e intenta de nuevo.'), backgroundColor: Colors.red));
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
    if (!await _ensureSensitiveAccess()) {
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
    final tagsController = TextEditingController(
      text: _parseScoutingTags(jugadorEnLista['scouting_tags']).join(', '),
    );
    String scoutingState = _scoutingStateFromItem(jugadorEnLista);

    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
                    title: const Text('Editar seguimiento'),
                    content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Estado',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _scoutingStates.map((state) {
                            final isSelected = scoutingState == state;
                            final color = _scoutingStateColor(state);
                            return ChoiceChip(
                              label: Text(_scoutingStateLabel(state)),
                              selected: isSelected,
                              selectedColor: color.withOpacity(0.16),
                              side: BorderSide(
                                color: isSelected
                                    ? color
                                    : const Color(0xFFD0D7DE),
                              ),
                              labelStyle: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? color
                                    : const Color(0xFF475569),
                              ),
                              onSelected: (_) =>
                                  setDialogState(() => scoutingState = state),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                            controller: tagsController,
                            decoration: const InputDecoration(
                                hintText: 'Etiquetas (separadas por coma)',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 10),
                        TextField(
                            controller: notaController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                hintText: 'Notas',
                                border: OutlineInputBorder())),
                      ]),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                          onPressed: () {
                            final tags = tagsController.text
                                .split(',')
                                .map((tag) => tag.trim())
                                .where((tag) => tag.isNotEmpty)
                                .toSet()
                                .toList();
                            Navigator.pop(ctx, {
                              'notas': notaController.text,
                              'state': scoutingState,
                              'tags': tags,
                            });
                          },
                          child: const Text('Guardar')),
                    ])));

    if (result != null) {
      try {
        final state = (result['state']?.toString().trim().isNotEmpty ?? false)
            ? result['state'].toString().trim()
            : 'descubierto';
        final tags = List<String>.from((result['tags'] as List?) ?? const []);
        final payload = {
          'nota': result['notas'],
          'scouting_state': state,
          'scouting_tags': tags,
          // Keep legacy field in sync for backward compatibility.
          'calificacion': _ratingFromScoutingState(state),
          'updated_at': DateTime.now().toIso8601String(),
        };

        try {
          await SupaFlow.client
              .from('listas_jugadores')
              .update(payload)
              .eq('id', jugadorEnLista['id']);
        } catch (_) {
          // Fallback when migrations have not been applied yet.
          await SupaFlow.client.from('listas_jugadores').update({
            'nota': result['notas'],
            'calificacion': _ratingFromScoutingState(state),
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', jugadorEnLista['id']);
        }
        if (mounted) {
          setState(() {
            for (final item in _jugadoresEnLista) {
              if (item['id']?.toString() == jugadorEnLista['id']?.toString()) {
                item['nota'] = result['notas'];
                item['scouting_state'] = state;
                item['scouting_tags'] = tags;
                item['calificacion'] = _ratingFromScoutingState(state);
                item['updated_at'] = DateTime.now().toIso8601String();
              }
            }
            for (final item in _filteredJugadores) {
              if (item['id']?.toString() == jugadorEnLista['id']?.toString()) {
                item['nota'] = result['notas'];
                item['scouting_state'] = state;
                item['scouting_tags'] = tags;
                item['calificacion'] = _ratingFromScoutingState(state);
                item['updated_at'] = DateTime.now().toIso8601String();
              }
            }
          });
        }
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
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(padding),
                          child: Column(children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Mi scouting',
                                  style: GoogleFonts.inter(
                                      fontSize: 24 * scale,
                                      fontWeight: FontWeight.bold)),
                            ),
                            SizedBox(height: 6 * scale),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Gestioná y evaluá talento de forma profesional',
                                style: GoogleFonts.inter(
                                  fontSize: 13 * scale,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(height: 16 * scale),
                            // Toggle de secciones internas de Mi scouting
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
                                  ]),
                              SizedBox(height: 24 * scale),
                              if (_isLargeScreen(context))
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          flex: 2,
                                          child:
                                              _buildMisListasSection(context)),
                                      SizedBox(width: 24 * scale),
                                      Expanded(
                                          flex: 3,
                                          child: _selectedLista != null
                                              ? _buildDetalleListaSection(
                                                  context)
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
            Text('No hay guardados todavía',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text(
                'Los jugadores que guardás desde Feed o Explorer entran aquí para clasificarlos en listas.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_jugadoresGuardados.length} jugador(es) en guardados',
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
                    _removeGuardado(guardado);
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
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Crea listas para hacer seguimiento de jugadores',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _createNewLista,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Crear primera lista',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )
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
      child: const Center(
        child: Text(
          'Crea listas para organizar jugadores y seguir su estado.',
          textAlign: TextAlign.center,
        ),
      ),
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
        const Divider(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
        Text(
          '${_filteredJugadores.length} jugador(es) en esta lista',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
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
        else if (_filteredJugadores.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Todavía no hay jugadores en esta lista. Agregalos desde la búsqueda o desde Guardados.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ..._filteredJugadores.map((j) => _buildJugadorCard(context, j)),
      ]),
    );
  }

  Widget _buildJugadorCard(BuildContext context, Map<String, dynamic> item) {
    final j = item['jugador_data'];
    final name = '${j?['name'] ?? ''} ${j?['lastname'] ?? ''}'.trim();
    final position = j?['posicion']?.toString().trim() ?? '';
    final city = j?['city']?.toString().trim() ?? '';
    final note = item['nota']?.toString().trim() ?? '';
    final scoutingState = _scoutingStateFromItem(item);
    final customTags = _parseScoutingTags(item['scouting_tags']);
    final userId = item['jugador_id']?.toString().trim() ?? '';

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
                backgroundImage: j?['photo_url'] != null
                    ? NetworkImage(j!['photo_url'])
                    : null,
                backgroundColor: const Color(0xFF0D3B66),
                child: j?['photo_url'] == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'J',
                        style: const TextStyle(color: Colors.white),
                      )
                    : null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : 'Jugador',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (position.isNotEmpty || city.isNotEmpty)
                    Text(
                      [position, city].where((s) => s.isNotEmpty).join(' • '),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  if (customTags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: customTags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: const Color(0xFFC5D7F2)),
                              ),
                              child: Text(
                                '#$tag',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D3B66),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            _buildStatePill(scoutingState),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _editarNotaJugador(item),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Evaluar jugador'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D3B66),
                  side: const BorderSide(color: Color(0xFF0D3B66)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: userId.isEmpty
                    ? null
                    : () => context.pushNamed(
                          'perfil_profesional_solicitar_Contato',
                          queryParameters: {'userId': userId},
                        ),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Ver perfil'),
              ),
            ],
          ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  note,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
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
  final _tagsCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];
  Map<String, dynamic>? _selected;
  bool _searching = false;
  bool _saving = false;
  String? _errorMsg;
  String _scoutingState = 'descubierto';

  String _normalizeId(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static const List<String> _scoutingStates = [
    'descubierto',
    'en_acompanamiento',
    'prioridad',
    'descartado',
  ];

  String _scoutingStateLabel(String state) {
    switch (state) {
      case 'descubierto':
        return 'Descubierto';
      case 'en_acompanamiento':
        return 'En acompañamiento';
      case 'prioridad':
        return 'Prioridad';
      case 'descartado':
        return 'Descartado';
      default:
        return 'Descubierto';
    }
  }

  int _ratingFromScoutingState(String state) {
    switch (state) {
      case 'descubierto':
        return 1;
      case 'en_acompanamiento':
        return 2;
      case 'prioridad':
        return 4;
      case 'descartado':
        return 5;
      default:
        return 1;
    }
  }

  Color _scoutingStateColor(String state) {
    switch (state) {
      case 'descubierto':
        return const Color(0xFF2563EB);
      case 'en_acompanamiento':
        return const Color(0xFFF59E0B);
      case 'prioridad':
        return const Color(0xFF0F766E);
      case 'descartado':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _resolveSaveError(Object error) {
    final raw = error.toString().toLowerCase();
    debugPrint('_AddJugadorModal._save error: $error');
    if (raw.contains('listas_jugadores_lista_id_fkey') ||
        raw.contains('foreign key constraint') ||
        raw.contains('23503')) {
      return 'No se pudo vincular esta lista. Reabrí Mi scouting o creá una lista nueva e intentá otra vez.';
    }
    if (raw.contains('duplicate key') ||
        raw.contains('already exists') ||
        raw.contains('unique')) {
      return 'Este jugador ya está en la lista.';
    }
    if (raw.contains('row-level security') ||
        raw.contains('42501') ||
        raw.contains('permission denied') ||
        raw.contains('forbidden')) {
      return 'Sin permiso para modificar esta lista. Verificá que sea tuya e intentá de nuevo.';
    }
    if (raw.contains('jwt') ||
        raw.contains('not authenticated') ||
        raw.contains('invalid token') ||
        raw.contains('401')) {
      return 'Tu sesión expiró. Cerrá sesión e ingresá de nuevo.';
    }
    if (raw.contains('pgrst116') ||
        raw.contains('multiple') ||
        raw.contains('json object requested')) {
      return 'Este jugador ya está en la lista.';
    }
    return 'No se pudo guardar. Intentá nuevamente.';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notaCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
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
          _results = List<Map<String, dynamic>>.from(
            (res as List).map((item) => Map<String, dynamic>.from(item as Map)),
          );
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
    if (_saving) return;

    final selected = _selected;
    final listaId = _normalizeId(widget.listaId);

    if (selected == null) {
      setState(() {
        _errorMsg = 'Seleccioná un jugador antes de guardar.';
      });
      return;
    }

    final jugadorId = _normalizeId(selected['user_id']);
    if (jugadorId.isEmpty) {
      setState(() {
        _errorMsg = 'El jugador seleccionado no es válido.';
      });
      return;
    }

    if (listaId.isEmpty) {
      setState(() {
        _errorMsg = 'La lista seleccionada no es válida.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      // Check if player is already in the list (use limit(1) to avoid
      // maybeSingle() throwing on duplicate DB rows)
      final existingRows = await SupaFlow.client
          .from('listas_jugadores')
          .select('id')
          .eq('lista_id', listaId)
          .eq('jugador_id', jugadorId)
          .limit(1);
      if (existingRows.isNotEmpty) {
        if (mounted) {
          setState(() {
            _errorMsg = 'Este jugador ya está en la lista.';
          });
        }
        return;
      }
      final tags = _tagsCtrl.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();
      try {
        await SupaFlow.client.from('listas_jugadores').insert({
          'lista_id': listaId,
          'jugador_id': jugadorId,
          'nota': _notaCtrl.text.trim(),
          'calificacion': _ratingFromScoutingState(_scoutingState),
          'scouting_state': _scoutingState,
          'scouting_tags': tags,
        });
      } catch (_) {
        await SupaFlow.client.from('listas_jugadores').insert({
          'lista_id': listaId,
          'jugador_id': jugadorId,
          'nota': _notaCtrl.text.trim(),
          'calificacion': _ratingFromScoutingState(_scoutingState),
        });
      }
      if (mounted) Navigator.pop(context, <String, dynamic>{'saved': true});
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = _resolveSaveError(e);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_resolveSaveError(e)),
          backgroundColor: Colors.red[700],
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                  style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ),
          if (_results.isNotEmpty && _selected == null)
            Expanded(
                child: ListView(
                    children: _results.map((r) {
              final fullName =
                  '${r['name'] ?? ''} ${r['lastname'] ?? ''}'.trim();
              final pos = r['posicion'] ?? '';
              final city = r['city'] ?? '';
              final subtitle =
                  [pos, city].where((s) => s.isNotEmpty).join(' - ');
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Estado',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _scoutingStates.map((state) {
                final isSelected = _scoutingState == state;
                final color = _scoutingStateColor(state);
                return ChoiceChip(
                  label: Text(_scoutingStateLabel(state)),
                  selected: isSelected,
                  selectedColor: color.withOpacity(0.16),
                  side: BorderSide(
                    color: isSelected ? color : const Color(0xFFD0D7DE),
                  ),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : const Color(0xFF475569),
                  ),
                  onSelected: (_) => setState(() => _scoutingState = state),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: _tagsCtrl,
                decoration: InputDecoration(
                    hintText: 'Etiquetas (separadas por coma)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)))),
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
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Guardar',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
