import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/account_deletion_service.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/fluxo_compartilhado/club_identity_utils.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/fluxo_compartilhado/perfil_publico_club/perfil_publico_club_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/fluxo_compartilhado/location_data.dart';
import 'configuracin_model.dart';
export 'configuracin_model.dart';

class ConfiguracinWidget extends StatefulWidget {
  const ConfiguracinWidget({super.key});

  static String routeName = 'Configuracin';
  static String routePath = '/configuracin';

  @override
  State<ConfiguracinWidget> createState() => _ConfiguracinWidgetState();
}

class _ConfiguracinWidgetState extends State<ConfiguracinWidget> {
  late ConfiguracinModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _profileScrollController = ScrollController();
  final _editSectionKey = GlobalKey();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _nombreCortoController = TextEditingController();
  final TextEditingController _paisController = TextEditingController();
  final TextEditingController _estadoController = TextEditingController();
  final TextEditingController _ciudadController = TextEditingController();
  final TextEditingController _ligaController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _sitioWebController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditingClubProfile = false;
  List<String> _states = [];
  List<String> _cities = [];
  bool _isStatesLoading = false;
  bool _isCitiesLoading = false;
  bool _stateFreeText = false;
  bool _cityFreeText = false;
  Map<String, dynamic>? _clubData;
  Map<String, dynamic>? _currentUserData;
  List<Map<String, dynamic>> _staffMembers = [];
  String? _logoUrl;
  String? _bannerUrl;
  String? _clubId;
  String? _currentUserId;
  Set<String> _clubRefs = <String>{};

  int _convocatoriasActivas = 0;
  int _maxConvocatorias = 20;
  int _staffCount = 0;
  int _maxStaff = 10;
  String _selectedProfileTab = 'convocatorias';
  List<Map<String, dynamic>> _clubConvocatoriasPreview = [];
  List<Map<String, dynamic>> _countries = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConfiguracinModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadCountries();
    _loadData();
  }

  @override
  void dispose() {
    _model.dispose();
    _nombreController.dispose();
    _nombreCortoController.dispose();
    _paisController.dispose();
    _estadoController.dispose();
    _ciudadController.dispose();
    _ligaController.dispose();
    _descripcionController.dispose();
    _sitioWebController.dispose();
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '15/11/2025';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return '15/11/2025';
    }
  }

  String _firstNonEmptyText(Iterable<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return fallback;
  }

  Map<String, dynamic> _mergeClubWithUserFallback(
    Map<String, dynamic>? club,
    Map<String, dynamic>? user,
  ) {
    final merged = <String, dynamic>{...?club};

    merged['id'] = _firstNonEmptyText([
      club?['id'],
    ]);
    merged['owner_id'] = _firstNonEmptyText([
      club?['owner_id'],
      user?['user_id'],
      _currentUserId,
    ]);
    merged['user_id'] = _firstNonEmptyText([
      club?['user_id'],
      user?['user_id'],
      _currentUserId,
    ]);
    merged['nombre'] = _firstNonEmptyText([
      club?['nombre'],
      club?['name'],
      club?['club_name'],
      user?['club_name'],
      user?['name'],
      'Mi Club',
    ]);
    merged['nombre_corto'] = _firstNonEmptyText([
      club?['nombre_corto'],
      user?['nombre_corto'],
      user?['short_name'],
    ]);
    merged['pais'] = _firstNonEmptyText([
      club?['pais'],
      club?['country'],
      user?['pais'],
      user?['country'],
      user?['country_name'],
    ]);
    merged['estado'] = _firstNonEmptyText([
      club?['estado'],
      club?['state'],
      user?['state'],
      user?['estado'],
    ]);
    merged['ciudad'] = _firstNonEmptyText([
      club?['ciudad'],
      club?['city'],
      user?['city'],
      user?['ciudad'],
    ]);
    merged['liga'] = _firstNonEmptyText([
      club?['liga'],
      user?['liga'],
      user?['league'],
      user?['organization'],
    ]);
    merged['descripcion'] = _firstNonEmptyText([
      club?['descripcion'],
      club?['description'],
      user?['descripcion'],
      user?['bio'],
      user?['description'],
    ]);
    merged['sitio_web'] = _firstNonEmptyText([
      club?['sitio_web'],
      club?['website'],
      user?['sitio_web'],
      user?['website'],
      user?['web'],
    ]);
    merged['logo_url'] = _firstNonEmptyText([
      club?['logo_url'],
      user?['logo_url'],
      user?['photo_url'],
      user?['avatar_url'],
    ]);

    return merged;
  }

  void _populateClubControllers(Map<String, dynamic>? clubData) {
    _nombreController.text = _firstNonEmptyText([
      clubData?['nombre'],
      clubData?['name'],
    ]);
    _nombreCortoController.text = _firstNonEmptyText([
      clubData?['nombre_corto'],
    ]);
    _paisController.text = normalizeCountryName(_firstNonEmptyText([
      clubData?['pais'],
      clubData?['country'],
    ]));
    _estadoController.text = _firstNonEmptyText([
      clubData?['state'],
      clubData?['estado'],
    ]);
    _ciudadController.text = _firstNonEmptyText([
      clubData?['city'],
      clubData?['ciudad'],
    ]);
    _states = [];
    _cities = [];
    _stateFreeText = false;
    _cityFreeText = false;
    _ligaController.text = normalizeLeagueName(_firstNonEmptyText([
      clubData?['liga'],
      clubData?['league'],
    ]));
    _descripcionController.text = _firstNonEmptyText([
      clubData?['descripcion'],
      clubData?['bio'],
      clubData?['description'],
    ]);
    _sitioWebController.text = _firstNonEmptyText([
      clubData?['sitio_web'],
      clubData?['website'],
      clubData?['web'],
    ]);
    final logoUrl = _firstNonEmptyText([
      clubData?['logo_url'],
      clubData?['photo_url'],
      clubData?['avatar_url'],
    ]);
    _logoUrl = logoUrl.isEmpty ? null : logoUrl;
    final bannerUrl = _firstNonEmptyText([
      clubData?['cover_url'],
      clubData?['banner_url'],
    ]);
    _bannerUrl = bannerUrl.isEmpty ? null : bannerUrl;
  }

  // ============ DATA LOADING ============
  Future<void> _loadCountries() async {
    try {
      final response =
          await SupaFlow.client.from('countrys').select().order('name');
      final countryList = List<Map<String, dynamic>>.from(response ?? []);
      // Sort manually to guarantee alphabetical order (A-Z)
      countryList.sort((a, b) {
        final nameA = (a['name']?.toString() ?? '').trim().toLowerCase();
        final nameB = (b['name']?.toString() ?? '').trim().toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() => _countries = countryList);
      }
    } catch (e) {
      debugPrint('Error cargando países: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUserId = currentUserUid;

      if (_currentUserId == null || _currentUserId!.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      try {
        _currentUserData = await SupaFlow.client
            .from('users')
            .select()
            .eq('user_id', _currentUserId!)
            .maybeSingle();
      } catch (_) {
        _currentUserData = null;
      }

      _clubRefs = await resolveClubRefsForUser(_currentUserId!);
      var clubResponse = await resolveCurrentClubForUser(_currentUserId!);

      // Se não encontrou, criar um club básico para este usuário
      if (clubResponse == null) {
        try {
          final userName = await SupaFlow.client
              .from('users')
              .select('name')
              .eq('user_id', _currentUserId!)
              .maybeSingle();
          final defaultName = userName?['name'] ?? 'Mi Club';

          await SupaFlow.client.from('clubs').insert({
            'nombre': 'Club de $defaultName',
            'owner_id': _currentUserId,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          clubResponse = await resolveCurrentClubForUser(_currentUserId!);
          _clubRefs = await resolveClubRefsForUser(_currentUserId!);
        } catch (e) {
          debugPrint('Error creando club: $e');
        }
      }

      final mergedClub =
          _mergeClubWithUserFallback(clubResponse, _currentUserData);
      if (mergedClub.isNotEmpty) {
        _clubData = mergedClub;
        _clubId = _firstNonEmptyText([
          mergedClub['id'],
        ]);
        _populateClubControllers(mergedClub);

        // Pre-load states/cities for existing country
        final existingCountry = _paisController.text.trim();
        if (existingCountry.isNotEmpty) {
          _loadStates(existingCountry);
        }

        await _loadStats();
        // Staff usa o ID real do club na tabela clubs
        if (_clubId != null && _clubId!.isNotEmpty) {
          await _loadStaff(_clubId!);
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStaff(String clubId) async {
    try {
      final response = await SupaFlow.client
          .from('club_staff')
          .select('*, users!club_staff_user_id_fkey(*)')
          .eq('club_id', clubId)
          .order('created_at', ascending: true);
      _staffMembers = List<Map<String, dynamic>>.from(response);
      _staffCount = _staffMembers.length;
    } catch (e) {
      debugPrint('Error cargando staff con join: $e');
      // Fallback: buscar staff sem join
      try {
        final staffResponse = await SupaFlow.client
            .from('club_staff')
            .select()
            .eq('club_id', clubId);
        _staffMembers = List<Map<String, dynamic>>.from(staffResponse);
        _staffCount = _staffMembers.length;
      } catch (e2) {
        debugPrint('Error cargando staff fallback: $e2');
        _staffMembers = [];
        _staffCount = 0;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    try {
      if (_clubRefs.isEmpty &&
          _currentUserId != null &&
          _currentUserId!.isNotEmpty) {
        _clubRefs = await resolveClubRefsForUser(_currentUserId!);
      }
      if (_clubRefs.isEmpty &&
          _currentUserId != null &&
          _currentUserId!.isNotEmpty) {
        _clubRefs = {_currentUserId!};
      }

      final convocatoriasResponse = _clubRefs.length == 1
          ? await SupaFlow.client
              .from('convocatorias')
              .select('id, titulo, categoria, posicion, ubicacion, created_at')
              .eq('club_id', _clubRefs.first)
              .eq('is_active', true)
              .order('created_at', ascending: false)
          : await SupaFlow.client
              .from('convocatorias')
              .select('id, titulo, categoria, posicion, ubicacion, created_at')
              .inFilter('club_id', _clubRefs.toList())
              .eq('is_active', true);

      // Limites vêm do registro do club (usa _clubData que já foi carregado)
      if (mounted) {
        setState(() {
          final convocatorias =
              List<Map<String, dynamic>>.from(convocatoriasResponse as List);
          _convocatoriasActivas = convocatorias.length;
          _clubConvocatoriasPreview = convocatorias.take(6).toList();
          if (_clubData != null) {
            _maxConvocatorias = _clubData!['max_convocatorias'] ?? 20;
            _maxStaff = _clubData!['max_staff'] ?? 10;
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando stats: $e');
    }
  }

  Future<void> _loadStates(String countryName) async {
    final trimmedCountry = countryName.trim();
    if (trimmedCountry.isEmpty) return;
    final apiName = locationToApiCountryName(trimmedCountry);
    final currentState = _estadoController.text.trim();
    final hardcoded = getHardcodedStates(apiName);
    if (mounted) {
      setState(() {
        _isStatesLoading = true;
        _states = [];
        _stateFreeText = false;
      });
    }
    final stateSet = <String>{};
    var loadedFromApi = false;
    try {
      final response = await http
          .post(
            Uri.parse('https://countriesnow.space/api/v0.1/countries/states'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiName}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final statesList = data['data']?['states'] as List?;
        if (statesList != null && statesList.isNotEmpty) {
          loadedFromApi = true;
          stateSet.addAll(statesList
              .map((s) => (s as Map<String, dynamic>)['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty));
        }
      }
    } catch (_) {}
    if (!loadedFromApi) {
      stateSet.addAll(hardcoded);
    }
    final states = stateSet.toList()..sort();
    if (mounted) {
      setState(() {
        _isStatesLoading = false;
        _states = states;
        _stateFreeText = states.isEmpty;
      });
    }
    if (currentState.isNotEmpty) {
      await _loadCitiesByState(trimmedCountry, currentState);
    }
  }

  String _normalizeLocationToken(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<List<String>> _resolveApiStateCandidates(
      String apiCountryName, String selectedState) async {
    final targetRaw = selectedState.trim();
    final target = _normalizeLocationToken(targetRaw);
    if (target.isEmpty) return [];

    final exact = <String>[];
    final contains = <String>[];

    try {
      final response = await http
          .post(
            Uri.parse('https://countriesnow.space/api/v0.1/countries/states'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiCountryName}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final statesList = data['data']?['states'] as List?;
        if (statesList != null && statesList.isNotEmpty) {
          for (final raw in statesList) {
            final name =
                (raw as Map<String, dynamic>)['name']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            final normalized = _normalizeLocationToken(name);
            if (normalized == target) {
              exact.add(name);
              continue;
            }
            if (normalized.contains(target) || target.contains(normalized)) {
              contains.add(name);
            }
          }
        }
      }
    } catch (_) {}

    final ordered = <String>[];
    ordered.add(targetRaw);
    ordered.addAll(exact);
    ordered.addAll(contains);
    final seen = <String>{};
    final unique = <String>[];
    for (final name in ordered) {
      final key = name.trim().toLowerCase();
      if (name.trim().isEmpty || !seen.add(key)) continue;
      unique.add(name);
    }
    return unique;
  }

  Future<List<String>> _fetchCitiesForState(
      String apiCountryName, String stateName) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                'https://countriesnow.space/api/v0.1/countries/state/cities'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiCountryName, 'state': stateName}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['error'] == true) return const [];
      final citiesList = data['data'] as List?;
      if (citiesList == null || citiesList.isEmpty) return const [];

      return citiesList
          .map((item) {
            if (item is Map<String, dynamic>) {
              return (item['name'] ?? item['city'] ?? '').toString().trim();
            }
            return item?.toString().trim() ?? '';
          })
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadCitiesDirectly(String apiCountryName) async {
    final citySet = <String>{...getHardcodedCitiesForCountry(apiCountryName)};
    if (mounted) {
      setState(() {
        _isCitiesLoading = true;
        _cities = [];
        _cityFreeText = false;
      });
    }
    try {
      final response = await http
          .post(
            Uri.parse('https://countriesnow.space/api/v0.1/countries/cities'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiCountryName}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final citiesList = data['data'] as List?;
        if (citiesList != null && citiesList.isNotEmpty) {
          citySet.addAll(citiesList.map((item) {
            if (item is Map<String, dynamic>) {
              return (item['name'] ?? item['city'] ?? '').toString().trim();
            }
            return item?.toString().trim() ?? '';
          }).where((n) => n.isNotEmpty));
        }
      }
    } catch (_) {}
    final cities = citySet.toList()..sort();
    if (mounted) {
      setState(() {
        _isCitiesLoading = false;
        _cities = cities;
        _cityFreeText = cities.isEmpty;
      });
    }
  }

  Future<void> _loadCitiesByState(String countryName, String stateName) async {
    final trimmedCountry = countryName.trim();
    final trimmedState = stateName.trim();
    if (trimmedCountry.isEmpty || trimmedState.isEmpty) return;
    final apiName = locationToApiCountryName(trimmedCountry);
    final citySet = <String>{};
    if (mounted) {
      setState(() {
        _isCitiesLoading = true;
        _cities = [];
        _cityFreeText = false;
      });
    }
    final candidates = await _resolveApiStateCandidates(apiName, trimmedState);
    for (final candidate in candidates) {
      final fetched = await _fetchCitiesForState(apiName, candidate);
      if (fetched.isNotEmpty) {
        citySet.addAll(fetched);
      }
    }

    if (citySet.isNotEmpty) {
      final cities = citySet.toList()..sort();
      if (mounted) {
        setState(() {
          _isCitiesLoading = false;
          _cities = cities;
          _cityFreeText = false;
        });
      }
      return;
    }

    citySet.addAll(getHardcodedCities(apiName, trimmedState));
    if (citySet.isNotEmpty) {
      final cities = citySet.toList()..sort();
      if (mounted) {
        setState(() {
          _isCitiesLoading = false;
          _cities = cities;
          _cityFreeText = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isCitiesLoading = false;
        _cities = [];
        _cityFreeText = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_clubData == null) return;
    setState(() => _isSaving = true);
    try {
      final updatedAt = DateTime.now().toIso8601String();
      final normalizedCountry =
          normalizeCountryName(_paisController.text.trim());
      final normalizedLeague = normalizeLeagueName(_ligaController.text.trim());

      if (normalizedCountry.isEmpty) {
        throw 'Debes indicar una ubicación real (País).';
      }
      if (_clubLogoUrl() == null) {
        throw 'Debes cargar el escudo del club antes de guardar.';
      }
      if (_clubCoverUrl() == null) {
        throw 'Debes cargar banner/portada del club antes de guardar.';
      }

      final payload = {
        'nombre': _nombreController.text.trim(),
        'nombre_corto': _nombreCortoController.text.trim(),
        'pais': normalizedCountry,
        'estado': _estadoController.text.trim(),
        'ciudad': _ciudadController.text.trim(),
        'liga': normalizedLeague,
        'descripcion': _descripcionController.text.trim(),
        'sitio_web': _sitioWebController.text.trim(),
        'updated_at': updatedAt,
      };
      final currentClubId = _clubData?['id']?.toString().trim() ?? '';

      Map<String, dynamic>? persistedClub;
      if (currentClubId.isNotEmpty) {
        await SupaFlow.client
            .from('clubs')
            .update(payload)
            .eq('id', currentClubId);
        persistedClub = {
          ...?_clubData,
          ...payload,
          'id': currentClubId,
        };
      } else {
        final inserted = await SupaFlow.client
            .from('clubs')
            .insert({
              ...payload,
              'owner_id': _firstNonEmptyText([
                _clubData?['owner_id'],
                _currentUserId,
              ]),
              'user_id': _firstNonEmptyText([
                _clubData?['user_id'],
                _currentUserId,
              ]),
              'is_active': true,
              'created_at': updatedAt,
            })
            .select()
            .maybeSingle();
        persistedClub = inserted == null
            ? {
                ...?_clubData,
                ...payload,
              }
            : Map<String, dynamic>.from(inserted);
        _clubRefs = await resolveClubRefsForUser(_currentUserId ?? '');
      }

      _clubData = _mergeClubWithUserFallback(persistedClub, _currentUserData);
      _clubId = _firstNonEmptyText([_clubData?['id']]);
      _populateClubControllers(_clubData);
      await _loadStats();
      if (_clubId != null && _clubId!.isNotEmpty) {
        await _loadStaff(_clubId!);
      }
      if (mounted) {
        setState(() {
          _isEditingClubProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cambios guardados'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos guardar los cambios. Verifica tu conexión e intenta de nuevo.'),
            backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _deleteBanner() async {
    setState(() {
      _isSaving = true;
    });
    try {
      final previousUrls = <String>{
        (_bannerUrl ?? '').trim(),
        (_clubData?['cover_url'] ?? '').toString().trim(),
        (_clubData?['banner_url'] ?? '').toString().trim(),
      }..removeWhere((url) => url.isEmpty);
      if (_clubData?['id'] != null) {
        await SupaFlow.client.from('clubs').update({
          'banner_url': null,
          'cover_url': null,
        }).eq('id', _clubData!['id']);
      }
      for (final url in previousUrls) {
        final storagePath = _storagePathFromPublicUrl(url, 'Fotos');
        if (storagePath == null || storagePath.isEmpty) continue;
        try {
          await SupaFlow.client.storage.from('Fotos').remove([storagePath]);
        } catch (storageError) {
          debugPrint('No se pudo remover el banner del storage: $storageError');
        }
      }
      setState(() {
        _bannerUrl = null;
        if (_clubData != null) {
          _clubData!['banner_url'] = null;
          _clubData!['cover_url'] = null;
        }
        if (_currentUserData != null) {
          _currentUserData!['cover_url'] = null;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner eliminado')),
        );
      }
    } catch (e) {
      debugPrint('Error al eliminar banner: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No pudimos eliminar el banner. Verifica tu conexión e intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _uploadLogo() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 500,
          maxHeight: 500,
          imageQuality: 85);
      if (image == null || _clubData == null) return;
      setState(() => _isSaving = true);
      final bytes = await image.readAsBytes();
      final fileName =
          'club_${_clubData!['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupaFlow.client.storage.from('logos clubs').uploadBinary(
          fileName, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final publicUrl =
          SupaFlow.client.storage.from('logos clubs').getPublicUrl(fileName);
      await SupaFlow.client
          .from('clubs')
          .update({'logo_url': publicUrl}).eq('id', _clubData!['id']);
      setState(() {
        _logoUrl = publicUrl;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Logo actualizado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos subir el logo. Verifica tu conexión e intenta con una imagen más pequeña.'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _uploadBanner() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 900,
          imageQuality: 85);
      if (image == null || _clubData == null) return;
      setState(() => _isSaving = true);
      final bytes = await image.readAsBytes();
      final fileName =
          'club_banner_${_clubData!['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupaFlow.client.storage.from('Fotos').uploadBinary(fileName, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final publicUrl =
          SupaFlow.client.storage.from('Fotos').getPublicUrl(fileName);
      await SupaFlow.client.from('clubs').update(
        {
          'cover_url': publicUrl,
          'banner_url': publicUrl,
        },
      ).eq('id', _clubData!['id']);
      setState(() {
        _bannerUrl = publicUrl;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Banner actualizado'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos subir el banner. Verifica tu conexión e intenta con una imagen más pequeña.'),
            backgroundColor: Colors.red));
      }
    }
  }

  // ============ DIALOGS ============
  void _showInviteDialog() {
    final usernameCtrl = TextEditingController();
    final cargoCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Invitar Nuevo Miembro'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'nombre_usuario',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: cargoCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Cargo',
                          hintText: 'Director Deportivo',
                          border: OutlineInputBorder())),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _inviteStaff(usernameCtrl.text, cargoCtrl.text);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3B66)),
                      child: const Text('Invitar',
                          style: TextStyle(color: Colors.white))),
                ]));
  }

  Future<void> _inviteStaff(String username, String cargo) async {
    if (username.trim().isEmpty || _clubData == null) return;
    if (_staffCount >= _maxStaff) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Límite de staff alcanzado'),
            backgroundColor: Colors.orange));
      }
      return;
    }
    setState(() => _isSaving = true);
    try {
      final userResponse = await SupaFlow.client
          .from('users')
          .select('user_id, name')
          .eq('username', username.trim())
          .maybeSingle();
      if (userResponse == null) throw 'Usuario no encontrado con ese username';
      final targetId = userResponse['user_id'];

      final existing = await SupaFlow.client
          .from('club_staff')
          .select('id')
          .eq('club_id', _clubData!['id'])
          .eq('user_id', targetId)
          .maybeSingle();
      if (existing != null) throw 'Este usuario ya es parte del staff';

      await SupaFlow.client.from('club_staff').insert({
        'club_id': _clubData!['id'],
        'user_id': targetId,
        'cargo': cargo.trim().isEmpty ? 'Staff' : cargo.trim(),
        'is_admin': false,
        'created_at': DateTime.now().toIso8601String()
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${userResponse['name']} añadido al staff'),
            backgroundColor: Colors.green));
        await _loadStaff(_clubData!['id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos invitar a este miembro. Verifica los datos e intenta de nuevo.'),
            backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    final userData = staff['users'] ?? staff;
    final staffName = userData['name'] ?? 'Miembro';
    final cargoCtrl = TextEditingController(text: staff['cargo'] ?? '');
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Editar Staff'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staffName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                          controller: cargoCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Cargo',
                              border: OutlineInputBorder())),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  TextButton(
                      child: const Text('Eliminar',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _removeStaffMember(staff['id']);
                      }),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3B66)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _updateStaffRole(staff['id'], cargoCtrl.text);
                      },
                      child: const Text('Guardar',
                          style: TextStyle(color: Colors.white)))
                ]));
  }

  Future<void> _updateStaffRole(String staffId, String newCargo) async {
    setState(() => _isSaving = true);
    try {
      await SupaFlow.client.from('club_staff').update({
        'cargo': newCargo.trim(),
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', staffId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cargo actualizado'), backgroundColor: Colors.green));
        if (_clubData != null) await _loadStaff(_clubData!['id']);
      }
    } catch (e) {
      debugPrint('Error actualizando cargo: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _removeStaffMember(String staffId) async {
    setState(() => _isSaving = true);
    try {
      await SupaFlow.client.from('club_staff').delete().eq('id', staffId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Miembro eliminado'), backgroundColor: Colors.green));
        if (_clubData != null) await _loadStaff(_clubData!['id']);
      }
    } catch (e) {
      debugPrint('Error eliminando staff: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // ============ MENU ============
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
                  child: Column(children: [
                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Color(0xFFE0E0E0)))),
                        child: Row(children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: const Color(0xFF0D3B66),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.shield_outlined,
                                  color: Colors.white)),
                          const SizedBox(width: 12),
                          const Text('Menú del club',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D3B66))),
                          const Spacer(),
                          IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context))
                        ])),
                    Expanded(
                        child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: [
                          _buildDrawerItem(
                              context,
                              Icons.dashboard_outlined,
                              'Gestión de talento',
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
                              'Postulaciones',
                              false,
                              () => context
                                  .pushNamed(PostulacionesWidget.routeName)),
                          _buildDrawerItem(
                              context,
                              Icons.search_rounded,
                              'Explorar jugadores',
                              false,
                              () => context
                                  .pushNamed(ListaYNotaWidget.routeName)),
                          _buildDrawerItem(
                              context,
                              Icons.shield_outlined,
                              'Perfil del club',
                              true,
                              () => context
                                  .pushNamed(ConfiguracinWidget.routeName)),
                          const Divider(),
                          _buildDrawerItem(
                              context, Icons.logout, 'Cerrar Sesión', false,
                              () async {
                            debugPrint(
                                'Logout callback triggered in Configuracion');
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
                          _buildDrawerItem(
                              context,
                              Icons.delete_forever_outlined,
                              'Eliminar mi cuenta',
                              false, () async {
                            await AccountDeletionService
                                .showDeleteAccountDialog(context: ctx);
                          })
                        ]))
                  ]),
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

  String _clubDisplayName() => _firstNonEmptyText([
        _nombreController.text.trim(),
        _clubData?['nombre'],
        _clubData?['name'],
        _clubData?['club_name'],
      ], fallback: 'Mi Club');

  String _clubDescriptionText() => _firstNonEmptyText([
        _descripcionController.text.trim(),
        _clubData?['descripcion'],
        _clubData?['description'],
        _currentUserData?['bio'],
      ], fallback: 'Completá la descripción para presentar tu club.');

  String _clubWebsiteText() => _firstNonEmptyText([
        _sitioWebController.text.trim(),
        _clubData?['sitio_web'],
        _clubData?['website'],
      ]);

  String _clubLeagueText() => normalizeLeagueName(_firstNonEmptyText([
        _ligaController.text.trim(),
        _clubData?['liga'],
        _clubData?['league'],
      ]));

  String _clubCountryText() => normalizeCountryName(_firstNonEmptyText([
        _paisController.text.trim(),
        _clubData?['pais'],
        _clubData?['country'],
      ]));

  String? _clubCoverUrl() {
    final cover = _firstNonEmptyText([
      _bannerUrl,
      _clubData?['cover_url'],
      _clubData?['banner_url'],
      _currentUserData?['cover_url'],
    ]);
    return cover.isEmpty ? null : cover;
  }

  String? _storagePathFromPublicUrl(String? rawUrl, String bucketName) {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final publicIndex = segments.indexOf('public');
    final bucketIndex = publicIndex + 1;
    if (publicIndex == -1 ||
        bucketIndex >= segments.length ||
        segments[bucketIndex] != bucketName) {
      return null;
    }
    final objectSegments = segments.skip(bucketIndex + 1).toList();
    if (objectSegments.isEmpty) return null;
    return objectSegments.map(Uri.decodeComponent).join('/');
  }

  String? _clubLogoUrl() {
    final logo = _firstNonEmptyText([
      _logoUrl,
      _clubData?['logo_url'],
      _clubData?['photo_url'],
      _clubData?['avatar_url'],
    ]);
    return logo.isEmpty ? null : logo;
  }

  bool _isVerifiedClubProfile() {
    final values = [
      _clubData?['is_verified'],
      _currentUserData?['is_verified'],
    ];
    for (final value in values) {
      if (value is bool) return value;
      final text = value?.toString().trim().toLowerCase() ?? '';
      if (text == 'true') return true;
    }

    final status = _firstNonEmptyText([
      _clubData?['verification_status'],
      _currentUserData?['verification_status'],
    ]).toLowerCase();
    return status == 'verified' ||
        status == 'verificado' ||
        status == 'approved' ||
        status == 'aprobado';
  }

  Widget _buildProfileTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _showClubMenu(context),
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
        ),
        Expanded(
          child: Text(
            'Perfil',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            final willEdit = !_isEditingClubProfile;
            setState(() => _isEditingClubProfile = willEdit);
            if (willEdit) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ctx = _editSectionKey.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(ctx,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut);
                }
              });
            }
          },
          icon: Icon(
            _isEditingClubProfile
                ? Icons.close_rounded
                : Icons.settings_outlined,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMetricCard({
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF151B28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF20293A)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileActionButton({
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final style = primary
        ? ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1473E6),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2A3240),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );

    return Expanded(
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: style,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTabs() {
    final tabs = const [
      ('convocatorias', 'Convocatorias'),
      ('cursos', 'Cursos'),
      ('fichajes', 'Fichajes'),
      ('sobre', 'Sobre Nosotros'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((entry) {
          final selected = _selectedProfileTab == entry.$1;
          return GestureDetector(
            onTap: () => setState(() => _selectedProfileTab = entry.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 22),
              padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color:
                        selected ? const Color(0xFF1473E6) : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                entry.$2,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF8B96A8),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDarkClubPanel({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C111B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1B2331)),
      ),
      child: child,
    );
  }

  Widget _buildOwnConvocatoriaTile(Map<String, dynamic> convocatoria) {
    final title = _firstNonEmptyText([
      convocatoria['titulo'],
      convocatoria['title'],
    ], fallback: 'Convocatoria');
    final subtitle = [
      convocatoria['categoria']?.toString() ?? '',
      convocatoria['posicion']?.toString() ?? '',
      convocatoria['ubicacion']?.toString() ?? '',
    ].where((item) => item.trim().isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF3D8F2E),
                  Color(0xFF1C4D1A),
                ],
              ),
            ),
            child: const Icon(
              Icons.sports_soccer_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnProfileTabContent() {
    switch (_selectedProfileTab) {
      case 'cursos':
        return _buildDarkClubPanel(
          child: Text(
            'Todavía no hay cursos publicados para este club.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: const Color(0xFF94A3B8),
            ),
          ),
        );
      case 'fichajes':
        return _buildDarkClubPanel(
          child: _staffMembers.isEmpty
              ? Text(
                  'No hay staff cargado por ahora.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                  ),
                )
              : Column(
                  children: _staffMembers.take(4).map((member) {
                    final user = member['users'];
                    final name = _firstNonEmptyText([
                      user?['name'],
                      member['cargo'],
                    ], fallback: 'Miembro');
                    final role = _firstNonEmptyText([
                      member['cargo'],
                      'Staff',
                    ]);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1E293B),
                        child: Text(
                          name.isNotEmpty ? name.substring(0, 1) : '?',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        role,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        );
      case 'sobre':
        return _buildDarkClubPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _clubDescriptionText(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              if (_clubWebsiteText().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _clubWebsiteText(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF60A5FA),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                [
                  _clubCountryText(),
                  _clubLeagueText(),
                ].where((item) => item.isNotEmpty).join(' • '),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        );
      default:
        if (_clubConvocatoriasPreview.isEmpty) {
          return _buildDarkClubPanel(
            child: Text(
              'Aún no tenés convocatorias activas.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
              ),
            ),
          );
        }
        return Column(
          children:
              _clubConvocatoriasPreview.map(_buildOwnConvocatoriaTile).toList(),
        );
    }
  }

  // ============ UI BUILDER ============
  @override
  Widget build(BuildContext context) {
    final scale = _scaleFactor(context);
    final horizontalPadding =
        _responsive(context, mobile: 16, tablet: 24, desktop: 32);
    final maxContentWidth = _responsive(
      context,
      mobile: double.infinity,
      tablet: 760,
      desktop: 840,
    );
    final coverUrl = _clubCoverUrl();
    final logoUrl = _clubLogoUrl();
    final verified = _isVerifiedClubProfile();
    final clubName = _clubDisplayName();
    final description = _clubDescriptionText();
    final planLabel = (_clubData?['subscription_plan'] ?? 'free')
        .toString()
        .trim()
        .toUpperCase();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFF050913),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1473E6)),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxContentWidth == double.infinity
                            ? double.infinity
                            : maxContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileTopBar(context),
                          const SizedBox(height: 16),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 208,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  color: const Color(0xFF0E1624),
                                  image: coverUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(coverUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: coverUrl == null
                                    ? Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0xFF294B78),
                                              Color(0xFF0D1726),
                                            ],
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: -52,
                                child: Center(
                                  child: Container(
                                    width: 108,
                                    height: 108,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF173E4E),
                                      border: Border.all(
                                        color: const Color(0xFF0A111E),
                                        width: 5,
                                      ),
                                      image: logoUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(logoUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: logoUrl == null
                                        ? const Icon(
                                            Icons.shield_rounded,
                                            color: Colors.white,
                                            size: 46,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 70),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    clubName,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 22 * scale,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (verified) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 22,
                                    color: Color(0xFF1D9BF0),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              verified ? 'Club Verificado' : 'Perfil del club',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 540),
                              child: Text(
                                description,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              _buildProfileMetricCard(
                                value: '$_convocatoriasActivas',
                                label: 'Convocatorias',
                              ),
                              const SizedBox(width: 12),
                              _buildProfileMetricCard(
                                value: '$_staffCount',
                                label: 'Staff',
                              ),
                              const SizedBox(width: 12),
                              _buildProfileMetricCard(
                                value: planLabel,
                                label: 'Plan',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildProfileTabs(),
                          const SizedBox(height: 18),
                          _buildOwnProfileTabContent(),
                          if (_isEditingClubProfile) ...[
                            const SizedBox(height: 20),
                            Container(
                              key: _editSectionKey,
                              child: _buildClubInfoSection(context),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _populateClubControllers(_clubData);
                                        _isEditingClubProfile = false;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E293B),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text('Cancelar',
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _saveChanges(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D3B66),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text('Guardar',
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
          onTap: () => _showClubMenu(context),
          child: Icon(Icons.menu, color: Colors.black, size: 24 * scale)),
      SizedBox(height: 16 * scale),
      Text('Mi perfil',
          style: GoogleFonts.inter(
              fontSize: 24 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black)),
      SizedBox(height: 8 * scale),
      Text('Gestiona el perfil de tu club',
          style:
              GoogleFonts.inter(fontSize: 14 * scale, color: Colors.grey[700])),
    ]);
  }

  Widget _buildPrimaryActionLabel(
    String text,
    BuildContext context, {
    Color color = Colors.white,
  }) {
    final scale = _scaleFactor(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: GoogleFonts.inter(
          fontSize: 15 * scale,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildClubProfileSummarySection(BuildContext context) {
    final scale = _scaleFactor(context);
    final clubName = _nombreController.text.trim().isNotEmpty
        ? _nombreController.text.trim()
        : (_clubData?['nombre']?.toString().trim().isNotEmpty ?? false)
            ? _clubData!['nombre'].toString().trim()
            : 'Mi Club';
    final country = normalizeCountryName(_paisController.text.trim());
    final league = normalizeLeagueName(_ligaController.text.trim());
    final description = _descripcionController.text.trim();
    final site = _sitioWebController.text.trim();
    final planLabel =
        'Plan ${(_clubData?['subscription_plan'] ?? 'free').toString().trim().toLowerCase()}';

    Widget infoTile({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 13 * scale,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7ECF2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40 * scale,
              height: 40 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(icon, size: 18 * scale, color: const Color(0xFF5B6B82)),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13 * scale,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    value.isEmpty
                        ? 'Completá este campo para mejorar tu perfil'
                        : value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15 * scale,
                      color: value.isEmpty
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                      fontWeight:
                          value.isEmpty ? FontWeight.w500 : FontWeight.w700,
                      fontStyle:
                          value.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EBF1)),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74 * scale,
                height: 74 * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFF173E73),
                  borderRadius: BorderRadius.circular(20),
                  image: _logoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_logoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _logoUrl == null
                    ? Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 34 * scale,
                      )
                    : null,
              ),
              SizedBox(width: 14 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfil del club',
                      style: GoogleFonts.inter(
                        fontSize: 12 * scale,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      clubName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 20 * scale,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10 * scale),
                    Wrap(
                      spacing: 8 * scale,
                      runSpacing: 8 * scale,
                      children: [
                        _buildInfoChip(planLabel, scale),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          infoTile(
            icon: Icons.public_rounded,
            label: 'País',
            value: country,
          ),
          SizedBox(height: 10 * scale),
          infoTile(
            icon: Icons.emoji_events_outlined,
            label: 'Liga',
            value: league,
          ),
          SizedBox(height: 10 * scale),
          infoTile(
            icon: Icons.language_rounded,
            label: 'Sitio web',
            value: site,
          ),
          SizedBox(height: 10 * scale),
          infoTile(
            icon: Icons.description_outlined,
            label: 'Descripción',
            value: description,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE6EBF1)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.5 * scale,
          color: const Color(0xFF334155),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _openCurrentClubPublicProfile(BuildContext context) {
    final clubRef = (_clubData?['id']?.toString().trim().isNotEmpty ?? false)
        ? _clubData!['id'].toString().trim()
        : (_clubData?['owner_id']?.toString().trim().isNotEmpty ?? false)
            ? _clubData!['owner_id'].toString().trim()
            : _currentUserId ?? '';
    if (clubRef.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilPublicoClubWidget(
          clubRef: clubRef,
          initialClubData: _clubData,
        ),
      ),
    );
  }

  Widget _buildPublicProfileButton(BuildContext context, double scale) {
    return OutlinedButton(
      onPressed: () => _openCurrentClubPublicProfile(context),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF0D3B66)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 12 * scale,
        ),
      ),
      child: _buildPrimaryActionLabel(
        'Perfil público',
        context,
        color: const Color(0xFF0D3B66),
      ),
    );
  }

  Widget _buildEditClubButton(BuildContext context, double scale) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D3B66),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 12 * scale,
        ),
      ),
      onPressed: () {
        setState(() => _isEditingClubProfile = true);
        final country = _paisController.text.trim();
        if (country.isNotEmpty) {
          _loadStates(country);
        }
      },
      icon: const Icon(Icons.edit_outlined),
      label: _buildPrimaryActionLabel(
        'Editar perfil',
        context,
      ),
    );
  }

  Widget _buildCancelEditClubButton(BuildContext context, double scale) {
    return OutlinedButton(
      onPressed: _isSaving
          ? null
          : () {
              setState(() {
                _isEditingClubProfile = false;
                _populateClubControllers(_clubData);
              });
            },
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF0D3B66)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 12 * scale,
        ),
      ),
      child: _buildPrimaryActionLabel(
        'Cancelar edición',
        context,
        color: const Color(0xFF0D3B66),
      ),
    );
  }

  Widget _buildSaveClubButton(BuildContext context, double scale) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D3B66),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 12 * scale,
        ),
      ),
      onPressed: _isSaving ? null : _saveChanges,
      child: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.2,
              ),
            )
          : _buildPrimaryActionLabel(
              'Guardar cambios',
              context,
            ),
    );
  }

  Widget _buildClubInfoSection(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.edit_outlined),
          const SizedBox(width: 8),
          Text('Editar perfil',
              style:
                  TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500))
        ]),
        SizedBox(height: 16 * scale),
        _buildLogoUpload(context),
        SizedBox(height: 16 * scale),
        _buildBannerUpload(context),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Nombre', _nombreController),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Nombre Corto', _nombreCortoController),
        SizedBox(height: 16 * scale),
        // País dropdown
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('País', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 5),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _countries.any((c) =>
                        normalizeCountryName(c['name']) ==
                        _paisController.text.trim())
                    ? _paisController.text.trim()
                    : null,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Selecciona un país'),
                ),
                items: (_countries.toList()
                      ..sort((a, b) {
                        final nameA =
                            (a['name']?.toString() ?? '').trim().toLowerCase();
                        final nameB =
                            (b['name']?.toString() ?? '').trim().toLowerCase();
                        return nameA.compareTo(nameB);
                      }))
                    .map((c) {
                  final name = normalizeCountryName(c['name'] ?? '');
                  return DropdownMenuItem(
                    value: name,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(name.trim()),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _paisController.text = v;
                    _estadoController.text = '';
                    _ciudadController.text = '';
                    _states = [];
                    _cities = [];
                    _stateFreeText = false;
                    _cityFreeText = false;
                  });
                  _loadStates(v);
                },
              ),
            ),
          ),
        ]),
        SizedBox(height: 16 * scale),
        // Estado
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Estado / Provincia', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 5),
          if (_isStatesLoading)
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (_states.isNotEmpty && !_stateFreeText)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _states.contains(_estadoController.text)
                      ? _estadoController.text
                      : null,
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Selecciona el estado'),
                  ),
                  items: _states
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(s))))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _estadoController.text = v;
                      _ciudadController.text = '';
                      _cities = [];
                    });
                    _loadCitiesByState(_paisController.text.trim(), v);
                  },
                ),
              ),
            )
          else
            TextField(
              controller: _estadoController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[100],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ]),
        SizedBox(height: 16 * scale),
        // Ciudad
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ciudad', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 5),
          // Só mostra o campo cidade se um estado foi selecionado
          if (_estadoController.text.isEmpty)
            const SizedBox.shrink()
          else if (_isCitiesLoading)
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (_cities.isNotEmpty && !_cityFreeText)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _cities.contains(_ciudadController.text)
                      ? _ciudadController.text
                      : null,
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Selecciona la ciudad'),
                  ),
                  items: _cities
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(c))))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _ciudadController.text = v);
                  },
                ),
              ),
            )
          else
            const SizedBox.shrink(),
        ]),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Liga', _ligaController),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Descripción', _descripcionController,
            maxLines: 4,
            hint:
                'Ej: Club formador con más de 10 años de experiencia, enfocado en el desarrollo de jugadores juveniles...'),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Sitio Web', _sitioWebController),
      ]),
    );
  }

  Widget _buildLogoUpload(BuildContext context) {
    final scale = _scaleFactor(context);
    return GestureDetector(
        onTap: _uploadLogo,
        child: Row(children: [
          Container(
              width: 60 * scale,
              height: 60 * scale,
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: _logoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_logoUrl!), fit: BoxFit.cover)
                      : null),
              child: _logoUrl == null
                  ? const Icon(Icons.upload, color: Colors.grey)
                  : null),
          SizedBox(width: 12 * scale),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Escudo del Club',
                style: TextStyle(fontWeight: FontWeight.w500)),
            Text('Foto de perfil (cuadrada)',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Toca para subir',
                style: TextStyle(fontSize: 11, color: Colors.grey))
          ])
        ]));
  }

  Widget _buildBannerUpload(BuildContext context) {
    final scale = _scaleFactor(context);
    final bannerUrl = _clubCoverUrl();
    return GestureDetector(
      onTap: _uploadBanner,
      child: Row(
        children: [
          Container(
            width: 100 * scale,
            height: 60 * scale,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              image: bannerUrl != null
                  ? DecorationImage(
                      image: NetworkImage(bannerUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: bannerUrl == null
                ? const Icon(Icons.image_outlined, color: Colors.grey)
                : null,
          ),
          SizedBox(width: 12 * scale),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Banner del Club',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                Text('Imagen de portada (horizontal)',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text('Toca para subir',
                    style: TextStyle(fontSize: 11, color: Colors.grey))
              ],
            ),
          ),
          if (bannerUrl != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteBanner,
              tooltip: 'Eliminar banner',
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      BuildContext context, String label, TextEditingController ctrl,
      {int maxLines = 1, String? hint, ValueChanged<String>? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.grey[700])),
      const SizedBox(height: 5),
      TextField(
          controller: ctrl,
          onChanged: onChanged,
          maxLines: maxLines,
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: Colors.grey[100],
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
    ]);
  }

  Widget _buildStaffSection(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6EBF1)),
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Gestión del Staff',
          style: GoogleFonts.inter(
            fontSize: 16 * scale,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 10 * scale),
        if (_staffMembers.isEmpty)
          Text(
            'No hay staff',
            style: GoogleFonts.inter(
              fontSize: 14 * scale,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ..._staffMembers.take(3).map((s) {
          final userData = s['users'];
          final name = userData?['name'] ?? 'Miembro';
          return Padding(
            padding: EdgeInsets.only(bottom: 10 * scale),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18 * scale,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2 * scale),
                      Text(
                        s['cargo'] ?? 'Staff',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12 * scale,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditStaffDialog(s),
                  icon: const Icon(Icons.more_vert_rounded),
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: 8 * scale),
        OutlinedButton(
          onPressed: _showInviteDialog,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 12 * scale,
            ),
            side: const BorderSide(color: Color(0xFFE1E8F0)),
            backgroundColor: const Color(0xFFF8FBFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Invitar Miembro',
            style: GoogleFonts.inter(
              fontSize: 14 * scale,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4AA3DF),
            ),
          ),
        )
      ]),
    );
  }

  Widget _buildAccountStatusSection(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE6EBF1)),
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Estado de la Cuenta',
            style: GoogleFonts.inter(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 10 * scale),
          _buildStatusRow(
              context, 'Plan', _clubData?['subscription_plan'] ?? 'Básico'),
          _buildStatusRow(context, 'Convocatorias',
              '$_convocatoriasActivas/$_maxConvocatorias'),
          _buildStatusRow(context, 'Staff', '$_staffCount/$_maxStaff'),
          _buildStatusRow(
              context, 'Miembro desde', _formatDate(_clubData?['created_at'])),
        ]));
  }

  Widget _buildStatusRow(BuildContext context, String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          )
        ]));
  }
}
