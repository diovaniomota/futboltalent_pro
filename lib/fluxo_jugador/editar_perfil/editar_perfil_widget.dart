import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/profile_history_utils.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'editar_perfil_model.dart';
export 'editar_perfil_model.dart';

class EditarPerfilWidget extends StatefulWidget {
  const EditarPerfilWidget({super.key});

  static String routeName = 'editar_perfil';
  static String routePath = '/editarPerfil';

  @override
  State<EditarPerfilWidget> createState() => _EditarPerfilWidgetState();
}

class _EditarPerfilWidgetState extends State<EditarPerfilWidget> {
  late EditarPerfilModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Controllers para os campos de texto
  TextEditingController? _nomeController;
  TextEditingController? _usernameController;
  TextEditingController? _birthdayController;
  TextEditingController? _countryController;
  TextEditingController? _stateController;
  TextEditingController? _cityController;
  TextEditingController? _posicaoController;
  TextEditingController? _categoryController;
  TextEditingController? _pieDominanteController;
  TextEditingController? _clubController;
  TextEditingController? _experienceController;
  TextEditingController? _heightController;
  TextEditingController? _weightController;
  TextEditingController? _lugarController;
  TextEditingController? _bioController;
  TextEditingController? _phoneController;
  TextEditingController? _professionalUrlController;
  TextEditingController? _dniController;
  TextEditingController? _collaborationsController;

  // Focus nodes
  FocusNode? _nomeFocusNode;
  FocusNode? _usernameFocusNode;

  // Estado
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isUploadingCover = false;
  Map<String, dynamic>? _userData;
  String? _errorMessage;
  String _currentUserType = 'jugador';
  bool _hasPlayerRecord = false;
  bool _hasScoutRecord = false;
  List<Map<String, dynamic>> _countries = [];
  String? _selectedCountryId;
  List<String> _states = [];
  String? _selectedState;
  bool _isStatesLoading = false;
  List<String> _cities = [];
  String? _selectedCity;
  bool _isCitiesLoading = false;

  // Opção selecionada (club ou sin club)
  String? _selectedPlayerStatus;
  DateTime? _selectedBirthday;
  final List<TextEditingController> _historyClubControllers = [];
  final List<TextEditingController> _historyPositionControllers = [];
  final List<TextEditingController> _historyNoteControllers = [];
  final List<String?> _historyStartYears = [];
  final List<String?> _historyEndYears = [];
  final List<bool> _historyCurrentFlags = [];

  static const List<String> _playerStatusOptions = [
    'Buscando club',
    'Federado',
    'En prueba',
    'En inferiores',
  ];

  List<String> get _historyYearOptions {
    final currentYear = DateTime.now().year;
    return List<String>.generate(
      currentYear - 1970 + 1,
      (index) => (currentYear - index).toString(),
    );
  }

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // URLs das fotos (para atualizar localmente antes de salvar)
  String? _photoUrl;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditarPerfilModel());
    _nomeFocusNode = FocusNode();
    _usernameFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCountries();
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _nomeController?.dispose();
    _usernameController?.dispose();
    _birthdayController?.dispose();
    _countryController?.dispose();
    _stateController?.dispose();
    _cityController?.dispose();
    _posicaoController?.dispose();
    _categoryController?.dispose();
    _pieDominanteController?.dispose();
    _clubController?.dispose();
    _experienceController?.dispose();
    _heightController?.dispose();
    _weightController?.dispose();
    _lugarController?.dispose();
    _bioController?.dispose();
    _phoneController?.dispose();
    _professionalUrlController?.dispose();
    _dniController?.dispose();
    _collaborationsController?.dispose();
    for (final controller in _historyClubControllers) {
      controller.dispose();
    }
    for (final controller in _historyPositionControllers) {
      controller.dispose();
    }
    for (final controller in _historyNoteControllers) {
      controller.dispose();
    }
    _nomeFocusNode?.dispose();
    _usernameFocusNode?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final uid = currentUserUid;
      if (uid.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Usuario no autenticado';
        });
        return;
      }

      final response = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response == null) {
        _errorMessage = 'Usuario no encontrado';
        return;
      }

      final merged = <String, dynamic>{...response};
      final userType =
          (response['userType']?.toString().trim().toLowerCase() ?? 'jugador')
              .replaceAll('jogador', 'jugador');
      _currentUserType = userType;
      _hasPlayerRecord = false;
      _hasScoutRecord = false;

      if (userType == 'jugador') {
        try {
          final playerResponse = await SupaFlow.client
              .from('players')
              .select()
              .eq('id', uid)
              .maybeSingle();
          if (playerResponse != null) {
            merged.addAll(Map<String, dynamic>.from(playerResponse));
            _hasPlayerRecord = true;
          }
        } catch (_) {}
      } else if (userType == 'profesional') {
        try {
          final scoutResponse = await SupaFlow.client
              .from('scouts')
              .select()
              .eq('id', uid)
              .maybeSingle();
          if (scoutResponse != null) {
            // Merge only non-empty scout values to avoid wiping users fields
            // like city/state when scout columns are null.
            final scoutMap = Map<String, dynamic>.from(scoutResponse);
            for (final entry in scoutMap.entries) {
              final value = entry.value;
              if (value == null) continue;
              if (value is String && value.trim().isEmpty) continue;
              merged[entry.key] = value;
            }
            if ((merged['bio']?.toString().trim().isEmpty ?? true) &&
                (scoutResponse['biography']?.toString().trim().isNotEmpty ??
                    false)) {
              merged['bio'] = scoutResponse['biography'];
            }
            _hasScoutRecord = true;
          }
        } catch (_) {}
      }

      _userData = merged;
      final normalizedHistory =
          _parseHistoryItems(merged['historial_clubes'] ?? merged['clubs']);
      final currentHistoryClub =
          currentClubFromProfileHistory(normalizedHistory) ??
              merged['club']?.toString().trim() ??
              '';
      _nomeController =
          TextEditingController(text: merged['name']?.toString() ?? '');
      _usernameController =
          TextEditingController(text: merged['username']?.toString() ?? '');
      _birthdayController = TextEditingController(
          text: _formatDateForInput(merged['birthday'] ??
              merged['birth_date'] ??
              merged['fecha_nacimiento']));
      _countryController = TextEditingController(
        text: normalizeCountryName(
          _firstNonEmptyValue([
                merged['country'],
                merged['pais'],
                merged['country_name'],
              ]) ??
              '',
        ),
      );
      _stateController = TextEditingController(
        text: normalizeStateName(
          _firstNonEmptyValue([
                merged['state'],
                merged['estado'],
                merged['province'],
                merged['provincia'],
                merged['region'],
              ]) ??
              '',
        ),
      );
      _cityController = TextEditingController(
        text: normalizeCityName(merged['city']?.toString() ?? ''),
      );
      _posicaoController = TextEditingController(
        text: normalizePlayerPosition(
          _firstNonEmptyValue([merged['posicion'], merged['position']]) ?? '',
        ),
      );
      _categoryController = TextEditingController(
        text: normalizePlayerCategory(
          _firstNonEmptyValue([merged['categoria'], merged['category']]) ?? '',
          birthday: merged['birthday'] ?? merged['birth_date'],
        ),
      );
      _pieDominanteController = TextEditingController(
        text: normalizeDominantFoot(
          _firstNonEmptyValue(
                [merged['dominant_foot'], merged['pie_dominante']],
              ) ??
              '',
        ),
      );
      _clubController = TextEditingController(text: currentHistoryClub);
      _experienceController =
          TextEditingController(text: _stringValue(merged['experience']));
      _heightController =
          TextEditingController(text: _stringValue(merged['altura']));
      _weightController =
          TextEditingController(text: _stringValue(merged['peso']));
      _lugarController =
          TextEditingController(text: merged['lugar']?.toString() ?? '');
      _bioController = TextEditingController(
        text: _firstNonEmptyValue(
                [merged['bio'], merged['descripcion'], merged['biography']]) ??
            '',
      );
      _phoneController =
          TextEditingController(text: merged['telephone']?.toString() ?? '');
      _professionalUrlController = TextEditingController(
          text: merged['url_profesional']?.toString() ?? '');
      _dniController = TextEditingController(text: _stringValue(merged['dni']));
      _collaborationsController = TextEditingController(
        text: _parseCollaborations(merged['colaboraciones']).join(', '),
      );
      _selectedPlayerStatus = _normalizePlayerStatus(merged['player_status']);
      _selectedBirthday = _parseDate(
        merged['birthday'] ??
            merged['birth_date'] ??
            merged['fecha_nacimiento'],
      );
      _photoUrl = merged['photo_url']?.toString();
      _coverUrl = merged['cover_url']?.toString();
      _setHistoryControllers(normalizedHistory);
      _selectedCountryId = merged['country_id']?.toString();
      _applySelectedCountryByName(_countryController?.text,
          updateController: false);
      _selectedState = _stateController?.text.trim().isNotEmpty == true
          ? _stateController?.text.trim()
          : null;
      _selectedCity = _cityController?.text.trim().isNotEmpty == true
          ? _cityController?.text.trim()
          : null;
      await _initializeLocationDropdowns();
      _refreshDerivedPlayerCategory();
    } catch (e) {
      debugPrint('Error al cargar usuario: $e');
      _errorMessage = 'Error al cargar datos';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCountries() async {
    try {
      final response = await SupaFlow.client
          .from('countrys')
          .select('id, name')
          .order('name');
      if (!mounted) return;
      setState(() {
        _countries = List<Map<String, dynamic>>.from(response as List);
        _applySelectedCountryByName(
          _countryController?.text,
          updateController: false,
        );
      });
    } catch (e) {
      debugPrint('Error al cargar países: $e');
    }
  }

  String _toApiCountryName(String name) {
    const map = {
      'España': 'Spain',
      'Espana': 'Spain',
      'México': 'Mexico',
      'Mexico': 'Mexico',
      'Brasil': 'Brazil',
      'Alemania': 'Germany',
      'Francia': 'France',
      'Italia': 'Italy',
      'Países Bajos': 'Netherlands',
      'Paises Bajos': 'Netherlands',
      'Holanda': 'Netherlands',
      'Bélgica': 'Belgium',
      'Belgica': 'Belgium',
      'Suiza': 'Switzerland',
      'Suecia': 'Sweden',
      'Noruega': 'Norway',
      'Dinamarca': 'Denmark',
      'Finlandia': 'Finland',
      'Polonia': 'Poland',
      'Grecia': 'Greece',
      'Turquía': 'Turkey',
      'Turquia': 'Turkey',
      'Rusia': 'Russia',
      'Ucrania': 'Ukraine',
      'Rumania': 'Romania',
      'Rumanía': 'Romania',
      'Hungría': 'Hungary',
      'Hungria': 'Hungary',
      'República Checa': 'Czech Republic',
      'Republica Checa': 'Czech Republic',
      'Croacia': 'Croatia',
      'Reino Unido': 'United Kingdom',
      'Irlanda': 'Ireland',
      'Estados Unidos': 'United States',
      'EE.UU.': 'United States',
      'EEUU': 'United States',
      'Canadá': 'Canada',
      'Canada': 'Canada',
      'Colombia': 'Colombia',
      'Venezuela': 'Venezuela',
      'Chile': 'Chile',
      'Perú': 'Peru',
      'Peru': 'Peru',
      'Ecuador': 'Ecuador',
      'Bolivia': 'Bolivia',
      'Paraguay': 'Paraguay',
      'Uruguay': 'Uruguay',
      'Costa Rica': 'Costa Rica',
      'Guatemala': 'Guatemala',
      'Honduras': 'Honduras',
      'El Salvador': 'El Salvador',
      'Nicaragua': 'Nicaragua',
      'Panamá': 'Panama',
      'Panama': 'Panama',
      'Cuba': 'Cuba',
      'República Dominicana': 'Dominican Republic',
      'Republica Dominicana': 'Dominican Republic',
      'Puerto Rico': 'Puerto Rico',
      'Marruecos': 'Morocco',
      'Argelia': 'Algeria',
      'Túnez': 'Tunisia',
      'Tunez': 'Tunisia',
      'Egipto': 'Egypt',
      'Nigeria': 'Nigeria',
      'Ghana': 'Ghana',
      'Senegal': 'Senegal',
      'Costa de Marfil': "Côte d'Ivoire",
      'Camerún': 'Cameroon',
      'Camerun': 'Cameroon',
      'Sudáfrica': 'South Africa',
      'Sudafrica': 'South Africa',
      'Japón': 'Japan',
      'Japon': 'Japan',
      'Corea del Sur': 'South Korea',
      'Arabia Saudita': 'Saudi Arabia',
      'Emiratos Árabes': 'United Arab Emirates',
    };
    return map[name] ?? name;
  }

  Future<void> _initializeLocationDropdowns() async {
    final country = normalizeCountryName(_countryController?.text);
    if (country.isEmpty) return;
    await _loadStates(
      country,
      preferredState: normalizeStateName(_stateController?.text),
      preferredCity: normalizeCityName(_cityController?.text),
    );
  }

  Future<void> _loadStates(
    String countryName, {
    String? preferredState,
    String? preferredCity,
  }) async {
    if (countryName.isEmpty) return;

    final apiName = _toApiCountryName(countryName);
    final preferredStateText = normalizeStateName(preferredState);
    final preferredCityText = normalizeCityName(preferredCity);
    setState(() {
      _isStatesLoading = true;
      _states = [];
      _cities = [];
      _isCitiesLoading = false;
    });

    try {
      final response = await http.post(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/states'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': apiName}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] == false && data['data'] is Map) {
          final statesRaw = data['data']['states'];
          if (statesRaw is List) {
            final stateList = statesRaw
                .map((item) => (item['name'] ?? '').toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
              ..sort();

            if (!mounted) return;
            setState(() => _states = stateList);
          }
        }
      }

      if (_states.isEmpty) {
        if (preferredStateText.isNotEmpty) {
          setState(() {
            _selectedState = preferredStateText;
            _stateController?.text = preferredStateText;
            _states = [preferredStateText];
          });
        }
        await _loadCitiesDirectly(apiName, preferredCity: preferredCityText);
        return;
      }

      final normalizedPreferred = preferredStateText;
      final matchedState = _states.cast<String?>().firstWhere(
            (state) =>
                normalizeLookupKey(state) ==
                normalizeLookupKey(normalizedPreferred),
            orElse: () => null,
          );

      final selectedState = matchedState ??
          (normalizedPreferred.isNotEmpty ? normalizedPreferred : null);

      if (!mounted) return;
      setState(() {
        if (selectedState != null &&
            !_states.any((s) =>
                normalizeLookupKey(s) == normalizeLookupKey(selectedState))) {
          _states = [selectedState, ..._states];
        }
        _selectedState = selectedState;
        _stateController?.text = selectedState ?? '';
      });

      if (selectedState != null) {
        await _loadCitiesByState(
          countryName,
          selectedState,
          preferredCity: preferredCityText,
        );
      }
    } catch (e) {
      debugPrint('Error al cargar estados: $e');
      if (preferredStateText.isNotEmpty && mounted) {
        setState(() {
          _selectedState = preferredStateText;
          _stateController?.text = preferredStateText;
          _states = [preferredStateText];
        });
      }
      await _loadCitiesDirectly(apiName, preferredCity: preferredCityText);
    } finally {
      if (mounted) {
        setState(() => _isStatesLoading = false);
      }
    }
  }

  Future<void> _loadCitiesDirectly(
    String apiCountryName, {
    String? preferredCity,
  }) async {
    final preferredCityText = normalizeCityName(preferredCity);
    setState(() {
      _isCitiesLoading = true;
      _cities = [];
    });

    try {
      final response = await http.post(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/cities'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': apiCountryName}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] == false && data['data'] is List) {
          final cityList = (data['data'] as List)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
            ..sort();

          final normalizedPreferred = preferredCityText;
          final matchedCity = cityList.cast<String?>().firstWhere(
                (city) =>
                    normalizeLookupKey(city) ==
                    normalizeLookupKey(normalizedPreferred),
                orElse: () => null,
              );

          final selectedCity = matchedCity ??
              (normalizedPreferred.isNotEmpty ? normalizedPreferred : null);

          if (!mounted) return;
          setState(() {
            if (selectedCity != null &&
                !cityList.any((c) =>
                    normalizeLookupKey(c) ==
                    normalizeLookupKey(selectedCity))) {
              cityList.insert(0, selectedCity);
            }
            _cities = cityList;
            _selectedCity = selectedCity;
            _cityController?.text = selectedCity ?? '';
          });
        }
      }
      if (_cities.isEmpty && preferredCityText.isNotEmpty && mounted) {
        setState(() {
          _cities = [preferredCityText];
          _selectedCity = preferredCityText;
          _cityController?.text = preferredCityText;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar ciudades: $e');
      if (preferredCityText.isNotEmpty && mounted) {
        setState(() {
          _cities = [preferredCityText];
          _selectedCity = preferredCityText;
          _cityController?.text = preferredCityText;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCitiesLoading = false);
      }
    }
  }

  Future<void> _loadCitiesByState(
    String countryName,
    String stateName, {
    String? preferredCity,
  }) async {
    if (countryName.isEmpty || stateName.isEmpty) return;

    final preferredCityText = normalizeCityName(preferredCity);

    setState(() {
      _isCitiesLoading = true;
      _cities = [];
    });

    final apiName = _toApiCountryName(countryName);

    try {
      final response = await http.post(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/state/cities'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': apiName, 'state': stateName}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] == false && data['data'] is List) {
          final cityList = (data['data'] as List)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
            ..sort();

          final normalizedPreferred = preferredCityText;
          final matchedCity = cityList.cast<String?>().firstWhere(
                (city) =>
                    normalizeLookupKey(city) ==
                    normalizeLookupKey(normalizedPreferred),
                orElse: () => null,
              );

          final selectedCity = matchedCity ??
              (normalizedPreferred.isNotEmpty ? normalizedPreferred : null);

          if (!mounted) return;
          setState(() {
            if (selectedCity != null &&
                !cityList.any((c) =>
                    normalizeLookupKey(c) ==
                    normalizeLookupKey(selectedCity))) {
              cityList.insert(0, selectedCity);
            }
            _cities = cityList;
            _selectedCity = selectedCity;
            _cityController?.text = selectedCity ?? '';
          });
        }
      }

      if (_cities.isEmpty) {
        await _loadCitiesDirectly(apiName, preferredCity: preferredCityText);
      }
    } catch (e) {
      debugPrint('Error al cargar ciudades por estado: $e');
      await _loadCitiesDirectly(apiName, preferredCity: preferredCityText);
    } finally {
      if (mounted) {
        setState(() => _isCitiesLoading = false);
      }
    }
  }

  // Mostrar opções para selecionar foto
  void _showPhotoOptions({required bool isProfilePhoto}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isProfilePhoto
                      ? 'Cambiar Foto de Perfil'
                      : 'Cambiar Foto de Portada',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B66).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF0D3B66),
                    ),
                  ),
                  title: Text(
                    'Tomar Foto',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Usar la cámara',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera,
                        isProfilePhoto: isProfilePhoto);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B66).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF0D3B66),
                    ),
                  ),
                  title: Text(
                    'Elegir de la Galería',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Seleccionar una foto existente',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery,
                        isProfilePhoto: isProfilePhoto);
                  },
                ),
                if (isProfilePhoto &&
                    _photoUrl != null &&
                    _photoUrl!.isNotEmpty)
                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                    ),
                    title: Text(
                      'Eliminar Foto',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: Text(
                      'Quitar la foto actual',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deletePhoto(isProfilePhoto: isProfilePhoto);
                    },
                  ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A202C),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Selecionar imagem
  Future<void> _pickImage(ImageSource source,
      {required bool isProfilePhoto}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: isProfilePhoto ? 500 : 1200,
        maxHeight: isProfilePhoto ? 500 : 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _uploadImage(pickedFile, isProfilePhoto: isProfilePhoto);
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Upload da imagem para Supabase Storage
  Future<void> _uploadImage(XFile imageFile,
      {required bool isProfilePhoto}) async {
    try {
      setState(() {
        if (isProfilePhoto) {
          _isUploadingPhoto = true;
        } else {
          _isUploadingCover = true;
        }
      });

      final uid = currentUserUid;
      // Gerar nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = imageFile.path.split('.').last;
      final fileName = isProfilePhoto
          ? 'profile_${uid}_$timestamp.$fileExtension'
          : 'cover_${uid}_$timestamp.$fileExtension';

      final storagePath = 'users/$uid/$fileName';

      // Ler bytes da imagem
      final bytes = await imageFile.readAsBytes();

      // Descobrir MIME type
      final mimeType = _contentTypeFromPath(imageFile.path);

      // Upload para Supabase Storage no bucket "Fotos"
      await SupaFlow.client.storage.from('Fotos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      // Obter URL pública
      final publicUrl =
          SupaFlow.client.storage.from('Fotos').getPublicUrl(storagePath);

      // Atualizar no banco de dados
      final updateData =
          isProfilePhoto ? {'photo_url': publicUrl} : {'cover_url': publicUrl};

      await SupaFlow.client.from('users').update(updateData).eq('user_id', uid);

      // Atualizar estado local
      setState(() {
        if (isProfilePhoto) {
          _photoUrl = publicUrl;
          _userData?['photo_url'] = publicUrl;
        } else {
          _coverUrl = publicUrl;
          _userData?['cover_url'] = publicUrl;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isProfilePhoto
                ? 'Foto de perfil actualizada'
                : 'Foto de portada actualizada'),
            backgroundColor: const Color(0xFF0D3B66),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al subir imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isProfilePhoto) {
            _isUploadingPhoto = false;
          } else {
            _isUploadingCover = false;
          }
        });
      }
    }
  }

  // Deletar foto
  Future<void> _deletePhoto({required bool isProfilePhoto}) async {
    try {
      setState(() {
        if (isProfilePhoto) {
          _isUploadingPhoto = true;
        } else {
          _isUploadingCover = true;
        }
      });

      final uid = currentUserUid;
      final updateData =
          isProfilePhoto ? {'photo_url': null} : {'cover_url': null};

      await SupaFlow.client.from('users').update(updateData).eq('user_id', uid);

      setState(() {
        if (isProfilePhoto) {
          _photoUrl = null;
          _userData?['photo_url'] = null;
        } else {
          _coverUrl = null;
          _userData?['cover_url'] = null;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isProfilePhoto
                ? 'Foto de perfil eliminada'
                : 'Foto de portada eliminada'),
            backgroundColor: const Color(0xFF0D3B66),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al eliminar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isProfilePhoto) {
            _isUploadingPhoto = false;
          } else {
            _isUploadingCover = false;
          }
        });
      }
    }
  }

  Future<void> _updateTableWithSchemaFallback({
    required String table,
    required String matchColumn,
    required String matchValue,
    required Map<String, dynamic> payload,
  }) async {
    final mutablePayload = Map<String, dynamic>.from(payload);

    for (var attempt = 0; attempt < 12; attempt++) {
      try {
        await SupaFlow.client
            .from(table)
            .update(mutablePayload)
            .eq(matchColumn, matchValue);
        return;
      } catch (e) {
        final message = e.toString();
        final regexSingle =
            RegExp("Could not find the '([^']+)' column of '$table'");
        final regexDouble =
            RegExp('Could not find the \"([^\"]+)\" column of \"$table\"');
        final singleMatch = regexSingle.firstMatch(message);
        final doubleMatch = regexDouble.firstMatch(message);
        final missingColumn =
            (singleMatch?.group(1) ?? doubleMatch?.group(1))?.trim();

        if (missingColumn == null || missingColumn.isEmpty) {
          rethrow;
        }

        if (!mutablePayload.containsKey(missingColumn)) {
          rethrow;
        }

        mutablePayload.remove(missingColumn);
        if (mutablePayload.isEmpty) {
          rethrow;
        }
      }
    }

    throw Exception(
        'No se pudo actualizar $table por incompatibilidad de schema');
  }

  Future<void> _saveChanges() async {
    try {
      setState(() => _isSaving = true);
      final uid = currentUserUid;
      final historyItems = _collectHistoryItems();
      final currentClubName =
          currentClubFromProfileHistory(historyItems)?.trim() ?? '';
      final hasCurrentHistory =
          historyItems.any((item) => item['is_current'] == true);

      for (final item in historyItems) {
        final name = item['name']?.toString().trim() ?? '';
        final startYear = parseHistoryYear(item['start_year']);
        final endYear = parseHistoryYear(item['end_year']);
        final isCurrent = item['is_current'] == true;

        if (name.isNotEmpty && startYear == null) {
          throw Exception(
            'Cada etapa del historial debe tener un año de inicio válido.',
          );
        }

        if (!isCurrent && name.isNotEmpty && endYear == null) {
          throw Exception(
            'Cada etapa finalizada debe tener un año de fin válido.',
          );
        }

        if (startYear != null && endYear != null && endYear < startYear) {
          throw Exception(
            'El año de fin no puede ser menor que el año de inicio.',
          );
        }
      }

      final country = normalizeCountryName(_countryController?.text);
      final state = normalizeStateName(_stateController?.text);
      final city = normalizeCityName(_cityController?.text);
      _applySelectedCountryByName(country, updateController: false);
      final normalizedPosition =
          normalizePlayerPosition(_posicaoController?.text);
      final normalizedCategory = normalizePlayerCategory(
        _categoryController?.text,
        birthday:
            _selectedBirthday?.toIso8601String() ?? _birthdayController?.text,
      );
      final normalizedFoot =
          normalizeDominantFoot(_pieDominanteController?.text);

      final userPayload = <String, dynamic>{
        'name': _nomeController?.text.trim() ?? '',
        'username': _usernameController?.text.trim() ?? '',
        'city': city,
        'country': country,
        'pais': country,
        'country_id': _selectedCountryId != null
            ? int.tryParse(_selectedCountryId!)
            : null,
        'birthday': _selectedBirthday?.toIso8601String(),
        'birth_date': _selectedBirthday?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (state.isNotEmpty) {
        userPayload['state'] = state;
        userPayload['province'] = state;
        userPayload['region'] = state;
      }

      if (_currentUserType == 'profesional') {
        userPayload.addAll({
          'bio': _bioController?.text.trim() ?? '',
          'descripcion': _bioController?.text.trim() ?? '',
          'colaboraciones':
              _collaborationsController?.text.trim().isEmpty == true
                  ? null
                  : _collaborationsController?.text.trim(),
        });
      } else {
        userPayload.addAll({
          'posicion': normalizedPosition,
          'position': normalizedPosition,
          'categoria': normalizedCategory,
          'category': normalizedCategory,
          'pie_dominante': normalizedFoot,
          'juega_en_club': hasCurrentHistory,
          'player_status': _selectedPlayerStatus,
          'historial_clubes': historyItems,
          'club_actual': currentClubName.isEmpty ? null : currentClubName,
          'lugar': currentClubName.isEmpty ? null : currentClubName,
        });
      }

      await _updateTableWithSchemaFallback(
        table: 'users',
        matchColumn: 'user_id',
        matchValue: uid,
        payload: userPayload,
      );

      if (_currentUserType == 'profesional') {
        final scoutPayload = <String, dynamic>{
          'biography': _bioController?.text.trim() ?? '',
          'telephone': _phoneController?.text.trim() ?? '',
          'club': _clubController?.text.trim() ?? '',
          'url_profesional': _professionalUrlController?.text.trim() ?? '',
          'dni': _tryParseInt(_dniController?.text),
          'city': city,
          'country': country,
          if (state.isNotEmpty) 'state': state,
          if (state.isNotEmpty) 'province': state,
          if (state.isNotEmpty) 'region': state,
        };

        if (_hasScoutRecord) {
          await _updateTableWithSchemaFallback(
            table: 'scouts',
            matchColumn: 'id',
            matchValue: uid,
            payload: scoutPayload,
          );
        } else {
          final scoutInsertPayload = <String, dynamic>{
            'biography': _bioController?.text.trim() ?? '',
            'telephone': _phoneController?.text.trim() ?? '',
            'club': _clubController?.text.trim() ?? '',
            'url_profesional': _professionalUrlController?.text.trim() ?? '',
            'dni': _tryParseInt(_dniController?.text),
          };
          await SupaFlow.client.from('scouts').insert({
            'id': uid,
            'created_at': DateTime.now().toIso8601String(),
            ...scoutInsertPayload,
          });
          _hasScoutRecord = true;
        }
      } else {
        final playerPayload = <String, dynamic>{
          'dominant_foot': normalizedFoot,
          'club': currentClubName,
          'experience': _tryParseInt(_experienceController?.text),
          'altura': _tryParseDouble(_heightController?.text),
          'peso': _tryParseDouble(_weightController?.text),
        };

        if (_hasPlayerRecord) {
          await SupaFlow.client
              .from('players')
              .update(playerPayload)
              .eq('id', uid);
        } else {
          await SupaFlow.client.from('players').insert({
            'id': uid,
            'created_at': DateTime.now().toIso8601String(),
            ...playerPayload,
          });
          _hasPlayerRecord = true;
        }
      }

      _clubController?.text = currentClubName;
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _currentUserType == 'profesional'
                  ? 'Perfil profesional actualizado correctamente'
                  : 'Cambios guardados correctamente',
            ),
            backgroundColor: const Color(0xFF0D3B66),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _buildInputDecoration(String hintText, {Widget? suffixIcon}) {
    return InputDecoration(
      isDense: false,
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF718096),
        fontSize: 16,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color(0xFF0D3B66),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
    );
  }

  String? _normalizePlayerStatus(dynamic rawValue) {
    final raw = rawValue?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    switch (raw.toLowerCase()) {
      case 'buscando club':
        return 'Buscando club';
      case 'federado':
        return 'Federado';
      case 'en prueba':
        return 'En prueba';
      case 'en inferiores':
        return 'En inferiores';
      default:
        return null;
    }
  }

  String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  List<String> get _countryOptions => _countries
      .map((country) => normalizeCountryName(country['name']))
      .where((country) => country.isNotEmpty)
      .toList();

  void _applySelectedCountryByName(
    String? countryName, {
    bool updateController = true,
  }) {
    final normalized = normalizeCountryName(countryName);
    if (normalized.isEmpty) {
      _selectedCountryId = null;
      if (updateController) {
        _countryController?.text = '';
      }
      return;
    }

    final match = _countries.cast<Map<String, dynamic>?>().firstWhere(
          (country) =>
              normalizeLookupKey(country?['name']) ==
              normalizeLookupKey(normalized),
          orElse: () => null,
        );

    _selectedCountryId = match?['id']?.toString();
    if (updateController) {
      _countryController?.text =
          normalizeCountryName(match?['name']?.toString() ?? normalized);
    }
  }

  void _refreshDerivedPlayerCategory() {
    final derivedCategory = normalizePlayerCategory(
      _categoryController?.text,
      birthday:
          _selectedBirthday?.toIso8601String() ?? _birthdayController?.text,
    );
    if (derivedCategory.isNotEmpty) {
      _categoryController?.text = derivedCategory;
    }
  }

  String? _firstNonEmptyValue(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  String _contentTypeFromPath(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  DateTime? _parseDate(dynamic rawValue) {
    final raw = rawValue?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _formatDateForInput(dynamic rawValue) {
    final parsed = _parseDate(rawValue);
    if (parsed == null) return '';
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  int? _tryParseInt(String? rawValue) {
    final cleaned = rawValue?.trim() ?? '';
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  double? _tryParseDouble(String? rawValue) {
    final cleaned = (rawValue ?? '').trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  List<String> _parseCollaborations(dynamic rawValue) {
    if (rawValue is List) {
      return rawValue
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final text = rawValue?.toString().trim() ?? '';
    if (text.isEmpty) return [];

    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _parseHistoryItems(dynamic rawValue) {
    return normalizeProfileHistory(rawValue);
  }

  void _disposeHistoryControllers() {
    for (final controller in _historyClubControllers) {
      controller.dispose();
    }
    for (final controller in _historyPositionControllers) {
      controller.dispose();
    }
    for (final controller in _historyNoteControllers) {
      controller.dispose();
    }
    _historyClubControllers.clear();
    _historyPositionControllers.clear();
    _historyNoteControllers.clear();
    _historyStartYears.clear();
    _historyEndYears.clear();
    _historyCurrentFlags.clear();
  }

  void _setHistoryControllers(List<Map<String, dynamic>> items) {
    _disposeHistoryControllers();
    for (final item in items) {
      _historyClubControllers.add(
        TextEditingController(text: item['name'] ?? ''),
      );
      _historyPositionControllers.add(
        TextEditingController(
          text: normalizePlayerPosition(item['position'] ?? ''),
        ),
      );
      _historyNoteControllers.add(
        TextEditingController(text: item['note'] ?? ''),
      );
      _historyStartYears.add(
        parseHistoryYear(item['start_year'])?.toString(),
      );
      _historyEndYears.add(
        parseHistoryYear(item['end_year'])?.toString(),
      );
      _historyCurrentFlags.add(item['is_current'] == true);
    }
  }

  List<Map<String, dynamic>> _collectHistoryItems() {
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < _historyClubControllers.length; i++) {
      final name = _historyClubControllers[i].text.trim();
      final position =
          normalizePlayerPosition(_historyPositionControllers[i].text);
      final note = _historyNoteControllers[i].text.trim();
      final startYear =
          _historyStartYears.length > i ? _historyStartYears[i] : null;
      final endYear = _historyEndYears.length > i ? _historyEndYears[i] : null;
      final isCurrent =
          _historyCurrentFlags.length > i && _historyCurrentFlags[i] == true;
      if (name.isEmpty &&
          (startYear == null || startYear.isEmpty) &&
          (endYear == null || endYear.isEmpty)) {
        continue;
      }
      items.add({
        'name': name,
        'position': position,
        'note': note,
        'start_year': parseHistoryYear(startYear),
        'end_year': isCurrent ? null : parseHistoryYear(endYear),
        'is_current': isCurrent,
        'period': formatProfileHistoryPeriod({
          'start_year': parseHistoryYear(startYear),
          'end_year': isCurrent ? null : parseHistoryYear(endYear),
          'is_current': isCurrent,
        }),
      });
    }
    return items;
  }

  Future<void> _pickBirthday() async {
    final initialDate = _selectedBirthday ?? DateTime(2008, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      helpText: 'Selecciona tu fecha de nacimiento',
    );

    if (picked == null) return;

    setState(() {
      _selectedBirthday = picked;
      _birthdayController?.text = _formatDateForInput(picked.toIso8601String());
      _refreshDerivedPlayerCategory();
    });
  }

  void _addHistoryItem() {
    setState(() {
      _historyClubControllers.add(TextEditingController());
      _historyPositionControllers.add(TextEditingController());
      _historyNoteControllers.add(TextEditingController());
      _historyStartYears.add(null);
      _historyEndYears.add(null);
      _historyCurrentFlags.add(false);
    });
  }

  void _removeHistoryItem(int index) {
    if (index < 0 || index >= _historyClubControllers.length) return;
    setState(() {
      _historyClubControllers.removeAt(index).dispose();
      _historyPositionControllers.removeAt(index).dispose();
      _historyNoteControllers.removeAt(index).dispose();
      _historyStartYears.removeAt(index);
      _historyEndYears.removeAt(index);
      _historyCurrentFlags.removeAt(index);
    });
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController? controller,
    required FocusNode? focusNode,
    required String hintText,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            readOnly: readOnly,
            onTap: onTap,
            obscureText: false,
            keyboardType: keyboardType,
            maxLines: maxLines,
            textCapitalization: textCapitalization,
            decoration: _buildInputDecoration(hintText, suffixIcon: suffixIcon),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF1A202C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hintText,
    required String? value,
    required ValueChanged<String?> onChanged,
    required List<String> options,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue:
                value != null && options.contains(value) ? value : null,
            onChanged: onChanged,
            isExpanded: true,
            decoration: _buildInputDecoration(
              hintText,
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF718096),
              ),
            ),
            hint: Text(
              hintText,
              style: GoogleFonts.inter(
                color: const Color(0xFF718096),
                fontSize: 16,
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF1A202C),
            ),
            dropdownColor: Colors.white,
            icon: const SizedBox.shrink(),
            items: options
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(top: 28.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
              fontSize: 17,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryYearDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          decoration: _buildInputDecoration(
            enabled ? 'Selecciona un año' : 'Presente',
          ),
          hint: Text(
            enabled ? 'Selecciona un año' : 'Presente',
            style: GoogleFonts.inter(
              color: const Color(0xFF718096),
              fontSize: 16,
            ),
          ),
          items: _historyYearOptions
              .map(
                (year) => DropdownMenuItem<String>(
                  value: year,
                  child: Text(year),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildHistoryEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_historyClubControllers.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Todavía no agregaste clubes o etapas de formación. Sumá tu recorrido para reforzar tu perfil.',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ...List.generate(_historyClubControllers.length, (index) {
          return Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Etapa ${index + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _removeHistoryItem(index),
                      splashRadius: 20,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                _buildTextField(
                  label: 'Club / academia',
                  controller: _historyClubControllers[index],
                  focusNode: null,
                  hintText: 'Academia Norte FC',
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildHistoryYearDropdown(
                        label: 'Año de inicio',
                        value: _historyStartYears[index],
                        onChanged: (value) {
                          setState(() => _historyStartYears[index] = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHistoryYearDropdown(
                        label: 'Año de fin',
                        value: _historyCurrentFlags[index]
                            ? null
                            : _historyEndYears[index],
                        enabled: !_historyCurrentFlags[index],
                        onChanged: (value) {
                          setState(() => _historyEndYears[index] = value);
                        },
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: _historyCurrentFlags[index],
                  onChanged: (value) {
                    setState(() {
                      final current = value == true;
                      _historyCurrentFlags[index] = current;
                      if (current) {
                        _historyEndYears[index] = null;
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Continúo jugando aquí',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                _buildDropdownField(
                  label: 'Posición',
                  hintText: 'Selecciona una posición',
                  value: canonicalPlayerPositions.contains(
                    _historyPositionControllers[index].text.trim(),
                  )
                      ? _historyPositionControllers[index].text.trim()
                      : null,
                  onChanged: (value) {
                    setState(() {
                      _historyPositionControllers[index].text = value ?? '';
                    });
                  },
                  options: canonicalPlayerPositions,
                ),
                _buildTextField(
                  label: 'Nota opcional',
                  controller: _historyNoteControllers[index],
                  focusNode: null,
                  hintText: 'Fui capitán, ganamos el torneo...',
                  maxLines: 2,
                ),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 14.0),
          child: OutlinedButton.icon(
            onPressed: _addHistoryItem,
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Agregar etapa'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D3B66),
              side: const BorderSide(color: Color(0xFF0D3B66)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Identidad del jugador',
          subtitle:
              'Completá tu ficha con datos reales para que scouts y clubes entiendan rápido tu perfil.',
        ),
        _buildTextField(
            label: 'Nombre',
            controller: _nomeController,
            focusNode: _nomeFocusNode,
            hintText: 'Nombre'),
        _buildTextField(
            label: 'Nombre de usuario',
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            hintText: 'usuario',
            textCapitalization: TextCapitalization.none),
        _buildTextField(
            label: 'Fecha de nacimiento',
            controller: _birthdayController,
            focusNode: null,
            hintText: 'YYYY-MM-DD',
            readOnly: true,
            onTap: _pickBirthday,
            suffixIcon: const Icon(Icons.calendar_today_outlined,
                size: 18, color: Color(0xFF718096))),
        _buildDropdownField(
            label: 'País / nacionalidad',
            hintText: 'Selecciona tu país',
            value: _countryOptions.contains(_countryController?.text.trim())
                ? _countryController?.text.trim()
                : null,
            onChanged: (value) {
              final country = normalizeCountryName(value);
              setState(() => _applySelectedCountryByName(country));
              _loadStates(country);
            },
            options: _countryOptions),
        _buildDropdownField(
            label: 'Estado / provincia',
            hintText: _isStatesLoading
                ? 'Cargando estados...'
                : 'Selecciona tu estado',
            value: _states.contains(_selectedState) ? _selectedState : null,
            onChanged: _isStatesLoading
                ? (_) {}
                : (value) {
                    setState(() {
                      _selectedState = value;
                      _stateController?.text = value ?? '';
                    });
                    final country =
                        normalizeCountryName(_countryController?.text);
                    if (country.isNotEmpty &&
                        value != null &&
                        value.isNotEmpty) {
                      _loadCitiesByState(country, value);
                    }
                  },
            options: _states),
        _buildDropdownField(
            label: 'Ciudad',
            hintText: _isCitiesLoading
                ? 'Cargando ciudades...'
                : 'Selecciona tu ciudad',
            value: _cities.contains(_selectedCity) ? _selectedCity : null,
            onChanged: _isCitiesLoading
                ? (_) {}
                : (value) {
                    setState(() {
                      _selectedCity = value;
                      _cityController?.text = value ?? '';
                    });
                  },
            options: _cities),
        _buildDropdownField(
            label: 'Posición principal',
            hintText: 'Selecciona tu posición',
            value: canonicalPlayerPositions
                    .contains(_posicaoController?.text.trim())
                ? _posicaoController?.text.trim()
                : null,
            onChanged: (value) {
              setState(() => _posicaoController?.text = value ?? '');
            },
            options: canonicalPlayerPositions),
        _buildTextField(
            label: 'Categoría',
            controller: _categoryController,
            focusNode: null,
            hintText: 'Se calcula por edad',
            readOnly: true),
        _buildDropdownField(
            label: 'Status del jugador',
            hintText: 'Selecciona tu momento actual',
            value: _selectedPlayerStatus,
            onChanged: (value) {
              setState(() => _selectedPlayerStatus = value);
            },
            options: _playerStatusOptions),
        _buildSectionTitle(
          'Ficha deportiva',
          subtitle:
              'Mostrá tu contexto actual, tu físico y la experiencia que ya acumulaste.',
        ),
        _buildDropdownField(
            label: 'Pie dominante',
            hintText: 'Selecciona tu pie dominante',
            value: canonicalDominantFeet
                    .contains(_pieDominanteController?.text.trim())
                ? _pieDominanteController?.text.trim()
                : null,
            onChanged: (value) {
              setState(() => _pieDominanteController?.text = value ?? '');
            },
            options: canonicalDominantFeet),
        _buildTextField(
            label: 'Altura (cm)',
            controller: _heightController,
            focusNode: null,
            hintText: '181',
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        _buildTextField(
            label: 'Peso (kg)',
            controller: _weightController,
            focusNode: null,
            hintText: '75',
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        _buildTextField(
            label: 'Años de experiencia',
            controller: _experienceController,
            focusNode: null,
            hintText: '6',
            keyboardType: TextInputType.number),
        _buildSectionTitle(
          'Historial deportivo',
          subtitle:
              'Usá años válidos para cada etapa. Si seguís jugando ahí, marcá la opción de presente. El club actual se toma desde este historial.',
        ),
        _buildHistoryEditor(),
      ],
    );
  }

  Widget _buildProfessionalForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Identidad profesional',
          subtitle:
              'Ordená tu perfil para que clubes y jugadores entiendan tu rol dentro del scouting.',
        ),
        _buildTextField(
            label: 'Nombre',
            controller: _nomeController,
            focusNode: _nomeFocusNode,
            hintText: 'Nombre'),
        _buildTextField(
            label: 'Nombre de usuario',
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            hintText: 'usuario',
            textCapitalization: TextCapitalization.none),
        _buildDropdownField(
            label: 'País',
            hintText: 'Selecciona tu país',
            value: _countryOptions.contains(_countryController?.text.trim())
                ? _countryController?.text.trim()
                : null,
            onChanged: (value) {
              final country = normalizeCountryName(value);
              setState(() => _applySelectedCountryByName(country));
              _loadStates(country);
            },
            options: _countryOptions),
        _buildDropdownField(
            label: 'Estado / provincia',
            hintText: _isStatesLoading
                ? 'Cargando estados...'
                : 'Selecciona tu estado',
            value: _states.contains(_selectedState) ? _selectedState : null,
            onChanged: _isStatesLoading
                ? (_) {}
                : (value) {
                    setState(() {
                      _selectedState = value;
                      _stateController?.text = value ?? '';
                    });
                    final country =
                        normalizeCountryName(_countryController?.text);
                    if (country.isNotEmpty &&
                        value != null &&
                        value.isNotEmpty) {
                      _loadCitiesByState(country, value);
                    }
                  },
            options: _states),
        _buildDropdownField(
            label: 'Ciudad',
            hintText: _isCitiesLoading
                ? 'Cargando ciudades...'
                : 'Selecciona tu ciudad',
            value: _cities.contains(_selectedCity) ? _selectedCity : null,
            onChanged: _isCitiesLoading
                ? (_) {}
                : (value) {
                    setState(() {
                      _selectedCity = value;
                      _cityController?.text = value ?? '';
                    });
                  },
            options: _cities),
        _buildTextField(
            label: 'Fecha de nacimiento',
            controller: _birthdayController,
            focusNode: null,
            hintText: 'YYYY-MM-DD',
            readOnly: true,
            onTap: _pickBirthday,
            suffixIcon: const Icon(Icons.calendar_today_outlined,
                size: 18, color: Color(0xFF718096))),
        _buildSectionTitle(
          'Perfil profesional',
          subtitle: 'Completá tus datos de contacto y tu enfoque de scouting.',
        ),
        _buildTextField(
            label: 'Club / organización',
            controller: _clubController,
            focusNode: null,
            hintText: 'Rede Iberica de Scouts'),
        _buildTextField(
            label: 'Teléfono',
            controller: _phoneController,
            focusNode: null,
            hintText: '+351910000201',
            keyboardType: TextInputType.phone),
        _buildTextField(
            label: 'Link profesional',
            controller: _professionalUrlController,
            focusNode: null,
            hintText: 'https://...',
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none),
        _buildTextField(
            label: 'DNI / documento',
            controller: _dniController,
            focusNode: null,
            hintText: '2201201',
            keyboardType: TextInputType.number),
        _buildTextField(
            label: 'Biografía profesional',
            controller: _bioController,
            focusNode: null,
            hintText:
                'Contá tu experiencia, foco de scouting y tipo de talento que seguís.',
            maxLines: 4),
        _buildTextField(
            label: 'Colaboraciones destacadas',
            controller: _collaborationsController,
            focusNode: null,
            hintText: 'Separá por coma: Club A, Torneo B, Red Scout C',
            maxLines: 2),
      ],
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: Color(0xFF718096),
            ),
            const SizedBox(height: 8),
            Text(
              'Agregar portada',
              style: GoogleFonts.inter(
                color: const Color(0xFF718096),
                fontSize: 14,
              ),
            ),
          ],
        ),
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF1A202C),
              size: 24,
            ),
            onPressed: () {
              context.safePop();
            },
          ),
          centerTitle: true,
          title: Text(
            'Editar Perfil',
            style: GoogleFonts.inter(
              color: const Color(0xFF1A202C),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D3B66)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66),
              ),
              child: const Text('Reintentar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header com imagem de capa e foto de perfil
          SizedBox(
            height: 220,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Imagem de capa (clicável)
                GestureDetector(
                  onTap: () => _showPhotoOptions(isProfilePhoto: false),
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFE2E8F0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _coverUrl != null && _coverUrl!.isNotEmpty
                              ? Image.network(
                                  _coverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildCoverPlaceholder();
                                  },
                                )
                              : _buildCoverPlaceholder(),
                          if (_isUploadingCover)
                            Container(
                              color: Colors.black.withOpacity(0.5),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                                color: Color(0xFF718096),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Foto de perfil com ícone de edição (clicável)
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _showPhotoOptions(isProfilePhoto: true),
                        child: Stack(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                              ),
                              child: ClipOval(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _photoUrl != null && _photoUrl!.isNotEmpty
                                        ? Image.network(
                                            _photoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person_outline,
                                                size: 50,
                                                color: Color(0xFF718096),
                                              );
                                            },
                                          )
                                        : const Icon(
                                            Icons.person_outline,
                                            size: 50,
                                            color: Color(0xFF718096),
                                          ),
                                    if (_isUploadingPhoto)
                                      Container(
                                        color: Colors.black.withOpacity(0.5),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D3B66),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Botão "Cambiar Foto de Perfil"
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: GestureDetector(
              onTap: () => _showPhotoOptions(isProfilePhoto: true),
              child: Text(
                'Cambiar Foto de Perfil',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D3B66),
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // Formulário
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _currentUserType == 'profesional'
                    ? _buildProfessionalForm()
                    : _buildPlayerForm(),
                Padding(
                  padding: const EdgeInsets.only(top: 32.0, bottom: 40.0),
                  child: GestureDetector(
                    onTap: _isSaving ? null : _saveChanges,
                    child: Container(
                      width: double.infinity,
                      height: 56.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D3B66),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _currentUserType == 'profesional'
                                    ? 'Guardar perfil profesional'
                                    : 'Guardar cambios',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
