import 'dart:async';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/geo_selection_bottom_sheet.dart';
import '/fluxo_compartilhado/location_data.dart' as location_data;
import '/fluxo_compartilhado/profile_history_utils.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  TextEditingController? _currentRoleController;
  TextEditingController? _workZoneController;
  TextEditingController? _interestCategoriesController;
  TextEditingController? _interestPositionsController;

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
  String? _selectedOrganizationType;
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
  DateTime? _registeredBirthday;
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

  static const double _minPlayerHeightCm = 110;
  static const double _maxPlayerHeightCm = 230;
  static const double _minPlayerWeightKg = 25;
  static const double _maxPlayerWeightKg = 180;
  static const int _minPlayerExperienceYears = 0;
  static const int _maxPlayerExperienceYears = 40;

  static const List<String> _organizationTypeOptions = [
    'Organización / club',
    'Independiente',
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
  bool _isFormattingPhone = false;

  static const Map<String, String> _latamCountryDialCode = {
    'Argentina': '54',
    'Bolivia': '591',
    'Brasil': '55',
    'Brazil': '55',
    'Chile': '56',
    'Colombia': '57',
    'Costa Rica': '506',
    'Cuba': '53',
    'Ecuador': '593',
    'El Salvador': '503',
    'Guatemala': '502',
    'Honduras': '504',
    'México': '52',
    'Mexico': '52',
    'Nicaragua': '505',
    'Panamá': '507',
    'Panama': '507',
    'Paraguay': '595',
    'Perú': '51',
    'Peru': '51',
    'República Dominicana': '1',
    'Republica Dominicana': '1',
    'Puerto Rico': '1',
    'Uruguay': '598',
    'Venezuela': '58',
  };

  static const List<String> _latamDialCodes = [
    '598',
    '595',
    '593',
    '591',
    '590',
    '587',
    '58',
    '57',
    '56',
    '55',
    '54',
    '53',
    '52',
    '51',
    '507',
    '506',
    '505',
    '504',
    '503',
    '502',
    '1',
  ];

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
    _currentRoleController?.dispose();
    _workZoneController?.dispose();
    _interestCategoriesController?.dispose();
    _interestPositionsController?.dispose();
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
        text: normalizeCityName(
          _firstNonEmptyValue([
                merged['city'],
                merged['ciudad'],
                merged['localidad'],
              ]) ??
              '',
        ),
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
      _clubController = TextEditingController(
        text: _firstNonEmptyValue([
              merged['club'],
              merged['organization'],
              merged['organizacion'],
              currentHistoryClub,
            ]) ??
            '',
      );
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
      _phoneController?.text = _formatLatamPhone(_phoneController?.text ?? '');
      _phoneController?.addListener(_handlePhoneInputChange);
      _professionalUrlController = TextEditingController(
          text: merged['url_profesional']?.toString() ?? '');
      _dniController = TextEditingController(text: _stringValue(merged['dni']));
      _collaborationsController = TextEditingController(
        text: _parseCollaborations(merged['colaboraciones']).join(', '),
      );
      _currentRoleController = TextEditingController(
        text: _firstNonEmptyValue([
              merged['current_role'],
              merged['rol_actual'],
              merged['role'],
            ]) ??
            '',
      );
      _workZoneController = TextEditingController(
        text: _firstNonEmptyValue([
              merged['work_zone'],
              merged['zona_trabajo'],
              merged['work_area'],
            ]) ??
            '',
      );
      _interestCategoriesController = TextEditingController(
        text: _firstNonEmptyValue([
              merged['interest_categories'],
              merged['categorias_interes'],
            ]) ??
            '',
      );
      _interestPositionsController = TextEditingController(
        text: _firstNonEmptyValue([
              merged['interest_positions'],
              merged['posiciones_interes'],
            ]) ??
            '',
      );
      final organizationRaw = _firstNonEmptyValue([
            merged['organization_type'],
            merged['tipo_organizacion'],
          ]) ??
          '';
      final normalizedOrg = organizationRaw.toLowerCase();
      _selectedOrganizationType = normalizedOrg.contains('independ')
          ? 'Independiente'
          : _organizationTypeOptions.first;
      _selectedPlayerStatus = _normalizePlayerStatus(merged['player_status']);
      _registeredBirthday = _parseDate(
        merged['birthday'] ??
            merged['birth_date'] ??
            merged['fecha_nacimiento'],
      );
      _selectedBirthday = _registeredBirthday;
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

      final countryList = List<Map<String, dynamic>>.from(response as List);
      // Sort manually to guarantee alphabetical order (A-Z)
      countryList.sort((a, b) {
        final nameA = (a['name']?.toString() ?? '').trim().toLowerCase();
        final nameB = (b['name']?.toString() ?? '').trim().toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (!mounted) return;
      setState(() {
        _countries = countryList;
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

  static const Map<String, List<String>> _hardcodedStates = {
    'Nicaragua': [
      'Boaco',
      'Carazo',
      'Chinandega',
      'Chontales',
      'Estelí',
      'Granada',
      'Jinotega',
      'León',
      'Madriz',
      'Managua',
      'Masaya',
      'Matagalpa',
      'Nueva Segovia',
      'Rivas',
      'Río San Juan',
      'Costa Caribe Norte',
      'Costa Caribe Sur'
    ],
    'Argentina': [
      'Buenos Aires',
      'Catamarca',
      'Chaco',
      'Chubut',
      'Ciudad Autónoma de Buenos Aires',
      'Córdoba',
      'Corrientes',
      'Entre Ríos',
      'Formosa',
      'Jujuy',
      'La Pampa',
      'La Rioja',
      'Mendoza',
      'Misiones',
      'Neuquén',
      'Río Negro',
      'Salta',
      'San Juan',
      'San Luis',
      'Santa Cruz',
      'Santa Fe',
      'Santiago del Estero',
      'Tierra del Fuego',
      'Tucumán'
    ],
    'Brazil': [
      'Acre',
      'Alagoas',
      'Amapá',
      'Amazonas',
      'Bahia',
      'Ceará',
      'Distrito Federal',
      'Espírito Santo',
      'Goiás',
      'Maranhão',
      'Mato Grosso',
      'Mato Grosso do Sul',
      'Minas Gerais',
      'Pará',
      'Paraíba',
      'Paraná',
      'Pernambuco',
      'Piauí',
      'Rio de Janeiro',
      'Rio Grande do Norte',
      'Rio Grande do Sul',
      'Rondônia',
      'Roraima',
      'Santa Catarina',
      'São Paulo',
      'Sergipe',
      'Tocantins'
    ],
    'Mexico': [
      'Aguascalientes',
      'Baja California',
      'Baja California Sur',
      'Campeche',
      'Chiapas',
      'Chihuahua',
      'Ciudad de México',
      'Coahuila',
      'Colima',
      'Durango',
      'Estado de México',
      'Guanajuato',
      'Guerrero',
      'Hidalgo',
      'Jalisco',
      'Michoacán',
      'Morelos',
      'Nayarit',
      'Nuevo León',
      'Oaxaca',
      'Puebla',
      'Querétaro',
      'Quintana Roo',
      'San Luis Potosí',
      'Sinaloa',
      'Sonora',
      'Tabasco',
      'Tamaulipas',
      'Tlaxcala',
      'Veracruz',
      'Yucatán',
      'Zacatecas'
    ],
    'Colombia': [
      'Amazonas',
      'Antioquia',
      'Arauca',
      'Archipiélago de San Andrés',
      'Atlántico',
      'Bogotá D.C.',
      'Bolívar',
      'Boyacá',
      'Caldas',
      'Caquetá',
      'Casanare',
      'Cauca',
      'Cesar',
      'Chocó',
      'Córdoba',
      'Cundinamarca',
      'Guainía',
      'Guaviare',
      'Huila',
      'La Guajira',
      'Magdalena',
      'Meta',
      'Nariño',
      'Norte de Santander',
      'Putumayo',
      'Quindío',
      'Risaralda',
      'Santander',
      'Sucre',
      'Tolima',
      'Valle del Cauca',
      'Vaupés',
      'Vichada'
    ],
    'Venezuela': [
      'Amazonas',
      'Anzoátegui',
      'Apure',
      'Aragua',
      'Barinas',
      'Bolívar',
      'Carabobo',
      'Cojedes',
      'Delta Amacuro',
      'Distrito Capital',
      'Falcón',
      'Guárico',
      'Lara',
      'Mérida',
      'Miranda',
      'Monagas',
      'Nueva Esparta',
      'Portuguesa',
      'Sucre',
      'Táchira',
      'Trujillo',
      'Vargas',
      'Yaracuy',
      'Zulia'
    ],
    'Chile': [
      'Arica y Parinacota',
      'Tarapacá',
      'Antofagasta',
      'Atacama',
      'Coquimbo',
      'Valparaíso',
      'Región Metropolitana de Santiago',
      'O\'Higgins',
      'Maule',
      'Ñuble',
      'Biobío',
      'La Araucanía',
      'Los Ríos',
      'Los Lagos',
      'Aysén',
      'Magallanes'
    ],
    'Peru': [
      'Amazonas',
      'Áncash',
      'Apurímac',
      'Arequipa',
      'Ayacucho',
      'Cajamarca',
      'Callao',
      'Cusco',
      'Huancavelica',
      'Huánuco',
      'Ica',
      'Junín',
      'La Libertad',
      'Lambayeque',
      'Lima',
      'Loreto',
      'Madre de Dios',
      'Moquegua',
      'Pasco',
      'Piura',
      'Puno',
      'San Martín',
      'Tacna',
      'Tumbes',
      'Ucayali'
    ],
    'Ecuador': [
      'Azuay',
      'Bolívar',
      'Cañar',
      'Carchi',
      'Chimborazo',
      'Cotopaxi',
      'El Oro',
      'Esmeraldas',
      'Galápagos',
      'Guayas',
      'Imbabura',
      'Loja',
      'Los Ríos',
      'Manabí',
      'Morona Santiago',
      'Napo',
      'Orellana',
      'Pastaza',
      'Pichincha',
      'Santa Elena',
      'Santo Domingo de los Tsáchilas',
      'Sucumbíos',
      'Tungurahua',
      'Zamora Chinchipe'
    ],
    'Bolivia': [
      'Beni',
      'Chuquisaca',
      'Cochabamba',
      'La Paz',
      'Oruro',
      'Pando',
      'Potosí',
      'Santa Cruz',
      'Tarija'
    ],
    'Paraguay': [
      'Alto Paraguay',
      'Alto Paraná',
      'Amambay',
      'Asunción',
      'Boquerón',
      'Caaguazú',
      'Caazapá',
      'Canindeyú',
      'Central',
      'Concepción',
      'Cordillera',
      'Guairá',
      'Itapúa',
      'Misiones',
      'Ñeembucú',
      'Paraguarí',
      'Presidente Hayes',
      'San Pedro'
    ],
    'Uruguay': [
      'Artigas',
      'Canelones',
      'Cerro Largo',
      'Colonia',
      'Durazno',
      'Flores',
      'Florida',
      'Lavalleja',
      'Maldonado',
      'Montevideo',
      'Paysandú',
      'Río Negro',
      'Rivera',
      'Rocha',
      'Salto',
      'San José',
      'Soriano',
      'Tacuarembó',
      'Treinta y Tres'
    ],
    'Spain': [
      'Álava',
      'Albacete',
      'Alicante',
      'Almería',
      'Asturias',
      'Ávila',
      'Badajoz',
      'Baleares',
      'Barcelona',
      'Burgos',
      'Cáceres',
      'Cádiz',
      'Cantabria',
      'Castellón',
      'Ceuta',
      'Ciudad Real',
      'Córdoba',
      'Cuenca',
      'Girona',
      'Granada',
      'Guadalajara',
      'Guipúzcoa',
      'Huelva',
      'Huesca',
      'Jaén',
      'La Coruña',
      'La Rioja',
      'Las Palmas',
      'León',
      'Lleida',
      'Lugo',
      'Madrid',
      'Málaga',
      'Melilla',
      'Murcia',
      'Navarra',
      'Ourense',
      'Palencia',
      'Pontevedra',
      'Salamanca',
      'Santa Cruz de Tenerife',
      'Segovia',
      'Sevilla',
      'Soria',
      'Tarragona',
      'Teruel',
      'Toledo',
      'Valencia',
      'Valladolid',
      'Vizcaya',
      'Zamora',
      'Zaragoza'
    ],
    'Portugal': [
      'Aveiro',
      'Beja',
      'Braga',
      'Bragança',
      'Castelo Branco',
      'Coimbra',
      'Évora',
      'Faro',
      'Guarda',
      'Leiria',
      'Lisboa',
      'Portalegre',
      'Porto',
      'Santarém',
      'Setúbal',
      'Viana do Castelo',
      'Vila Real',
      'Viseu',
      'Açores',
      'Madeira'
    ],
    'Costa Rica': [
      'Alajuela',
      'Cartago',
      'Guanacaste',
      'Heredia',
      'Limón',
      'Puntarenas',
      'San José'
    ],
    'Guatemala': [
      'Alta Verapaz',
      'Baja Verapaz',
      'Chimaltenango',
      'Chiquimula',
      'El Progreso',
      'Escuintla',
      'Guatemala',
      'Huehuetenango',
      'Izabal',
      'Jalapa',
      'Jutiapa',
      'Petén',
      'Quetzaltenango',
      'Quiché',
      'Retalhuleu',
      'Sacatepéquez',
      'San Marcos',
      'Santa Rosa',
      'Sololá',
      'Suchitepéquez',
      'Totonicapán',
      'Zacapa'
    ],
    'Honduras': [
      'Atlántida',
      'Choluteca',
      'Colón',
      'Comayagua',
      'Copán',
      'Cortés',
      'El Paraíso',
      'Francisco Morazán',
      'Gracias a Dios',
      'Intibucá',
      'Islas de la Bahía',
      'La Paz',
      'Lempira',
      'Ocotepeque',
      'Olancho',
      'Santa Bárbara',
      'Valle',
      'Yoro'
    ],
    'El Salvador': [
      'Ahuachapán',
      'Cabañas',
      'Chalatenango',
      'Cuscatlán',
      'La Libertad',
      'La Paz',
      'La Unión',
      'Morazán',
      'San Miguel',
      'San Salvador',
      'San Vicente',
      'Santa Ana',
      'Sonsonate',
      'Usulután'
    ],
    'Panama': [
      'Bocas del Toro',
      'Chiriquí',
      'Coclé',
      'Colón',
      'Darién',
      'Emberá',
      'Guna Yala',
      'Herrera',
      'Los Santos',
      'Ngöbe-Buglé',
      'Panamá',
      'Panamá Oeste',
      'Veraguas'
    ],
    'Dominican Republic': [
      'Azua',
      'Bahoruco',
      'Barahona',
      'Dajabón',
      'Distrito Nacional',
      'Duarte',
      'El Seibo',
      'Elías Piña',
      'Espaillat',
      'Hato Mayor',
      'Hermanas Mirabal',
      'Independencia',
      'La Altagracia',
      'La Romana',
      'La Vega',
      'María Trinidad Sánchez',
      'Monseñor Nouel',
      'Monte Cristi',
      'Monte Plata',
      'Pedernales',
      'Peravia',
      'Puerto Plata',
      'Samaná',
      'Sánchez Ramírez',
      'San Cristóbal',
      'San José de Ocoa',
      'San Juan',
      'San Pedro de Macorís',
      'Santiago',
      'Santiago Rodríguez',
      'Santo Domingo',
      'Valverde'
    ],
    'United States': [
      'Alabama',
      'Alaska',
      'Arizona',
      'Arkansas',
      'California',
      'Colorado',
      'Connecticut',
      'Delaware',
      'Florida',
      'Georgia',
      'Hawaii',
      'Idaho',
      'Illinois',
      'Indiana',
      'Iowa',
      'Kansas',
      'Kentucky',
      'Louisiana',
      'Maine',
      'Maryland',
      'Massachusetts',
      'Michigan',
      'Minnesota',
      'Mississippi',
      'Missouri',
      'Montana',
      'Nebraska',
      'Nevada',
      'New Hampshire',
      'New Jersey',
      'New Mexico',
      'New York',
      'North Carolina',
      'North Dakota',
      'Ohio',
      'Oklahoma',
      'Oregon',
      'Pennsylvania',
      'Rhode Island',
      'South Carolina',
      'South Dakota',
      'Tennessee',
      'Texas',
      'Utah',
      'Vermont',
      'Virginia',
      'Washington',
      'West Virginia',
      'Wisconsin',
      'Wyoming'
    ],
    'Germany': [
      'Baden-Württemberg',
      'Bavaria',
      'Berlin',
      'Brandenburg',
      'Bremen',
      'Hamburg',
      'Hesse',
      'Lower Saxony',
      'Mecklenburg-Vorpommern',
      'North Rhine-Westphalia',
      'Rhineland-Palatinate',
      'Saarland',
      'Saxony',
      'Saxony-Anhalt',
      'Schleswig-Holstein',
      'Thuringia'
    ],
    'France': [
      'Auvergne-Rhône-Alpes',
      'Bourgogne-Franche-Comté',
      'Bretagne',
      'Centre-Val de Loire',
      'Corse',
      'Grand Est',
      'Hauts-de-France',
      'Île-de-France',
      'Normandie',
      'Nouvelle-Aquitaine',
      'Occitanie',
      'Pays de la Loire',
      'Provence-Alpes-Côte d\'Azur'
    ],
    'Italy': [
      'Abruzzo',
      'Basilicata',
      'Calabria',
      'Campania',
      'Emilia-Romagna',
      'Friuli-Venezia Giulia',
      'Lazio',
      'Liguria',
      'Lombardia',
      'Marche',
      'Molise',
      'Piemonte',
      'Puglia',
      'Sardegna',
      'Sicilia',
      'Toscana',
      'Trentino-Alto Adige',
      'Umbria',
      'Valle d\'Aosta',
      'Veneto'
    ],
    'United Kingdom': ['England', 'Northern Ireland', 'Scotland', 'Wales'],
  };

  static const Map<String, List<String>> _hardcodedCities = {
    'Nicaragua|Managua': [
      'Managua',
      'Ciudad Sandino',
      'Ticuantepe',
      'El Crucero',
      'Mateare',
      'Villa El Carmen',
      'San Rafael del Sur'
    ],
    'Nicaragua|Masaya': [
      'Masaya',
      'Nindirí',
      'La Concepción',
      'Tisma',
      'Nandasmo',
      'Niquinohomo',
      'San Juan de Oriente',
      'Catarina'
    ],
    'Nicaragua|Granada': ['Granada', 'Diriomo', 'Diriá', 'Nandaime'],
    'Nicaragua|León': [
      'León',
      'Nagarote',
      'La Paz Centro',
      'Telica',
      'El Sauce',
      'Malpaisillo',
      'Quezalguaque',
      'Santa Rosa del Peñón',
      'Larreynaga',
      'Achuapa'
    ],
    'Nicaragua|Chinandega': [
      'Chinandega',
      'Corinto',
      'El Viejo',
      'Posoltega',
      'Chichigalpa',
      'Puerto Morazán',
      'Villanueva',
      'Somotillo',
      'El Realejo',
      'Santo Tomás del Norte'
    ],
    'Nicaragua|Estelí': [
      'Estelí',
      'Condega',
      'Pueblo Nuevo',
      'La Trinidad',
      'San Juan de Limay',
      'San Nicolás'
    ],
    'Nicaragua|Matagalpa': [
      'Matagalpa',
      'Ciudad Darío',
      'Sébaco',
      'San Ramón',
      'Río Blanco',
      'Muy Muy',
      'Rancho Grande',
      'Tuma La Dalia'
    ],
    'Nicaragua|Carazo': [
      'Jinotepe',
      'Diriamba',
      'San Marcos',
      'Dolores',
      'El Rosario',
      'La Conquista',
      'La Paz de Carazo',
      'Santa Teresa'
    ],
    'Nicaragua|Rivas': [
      'Rivas',
      'San Juan del Sur',
      'Tola',
      'Cárdenas',
      'Buenos Aires',
      'Altagracia',
      'Belén',
      'Moyogalpa',
      'San Jorge'
    ],
    'Nicaragua|Chontales': [
      'Juigalpa',
      'Acoyapa',
      'La Libertad',
      'Comalapa',
      'Cuapa',
      'Villa Sandino',
      'El Coral',
      'Santo Tomás',
      'San Pedro de Lóvago',
      'Santo Domingo'
    ],
    'Nicaragua|Boaco': [
      'Boaco',
      'Camoapa',
      'Teustepe',
      'San José de los Remates',
      'San Lorenzo',
      'Santa Lucía'
    ],
    'Nicaragua|Nueva Segovia': [
      'Ocotal',
      'Jalapa',
      'Mozonte',
      'Dipilto',
      'El Jícaro',
      'Macuelizo',
      'Murra',
      'Quilalí',
      'Santa María',
      'Wiwilí de Nueva Segovia'
    ],
    'Nicaragua|Jinotega': [
      'Jinotega',
      'San Sebastián de Yalí',
      'El Cuá',
      'Wiwilí de Jinotega',
      'San José de Bocay',
      'La Concordia',
      'Santa María de Pantasma'
    ],
    'Nicaragua|Madriz': [
      'Somoto',
      'Palacagüina',
      'San Lucas',
      'Totogalpa',
      'Telpaneca',
      'San Juan de Río Coco',
      'Las Sabanas',
      'Yalagüina'
    ],
    'Nicaragua|Río San Juan': [
      'San Carlos',
      'El Castillo',
      'Morrito',
      'El Almendro',
      'San Miguelito'
    ],
    'Nicaragua|Costa Caribe Norte': [
      'Bilwi',
      'Waspam',
      'Siuna',
      'Rosita',
      'Bonanza',
      'Prinzapolka',
      'Mulukukú'
    ],
    'Nicaragua|Costa Caribe Sur': [
      'Bluefields',
      'El Rama',
      'Nueva Guinea',
      'Pearl Lagoon',
      'Bocana de Paiwas',
      'La Cruz del Río Grande',
      'Laguna de Perlas',
      'Muelle de los Bueyes'
    ],
    'Argentina|Buenos Aires': [
      'La Plata',
      'Mar del Plata',
      'Quilmes',
      'Lomas de Zamora',
      'Lanús',
      'Almirante Brown',
      'Florencio Varela',
      'General San Martín',
      'Tres de Febrero',
      'Morón',
      'Tigre',
      'Avellaneda',
      'Berazategui',
      'Vicente López',
      'San Isidro',
      'Bahía Blanca',
      'Tandil',
      'Olavarría',
      'Necochea',
      'Junín',
      'Pergamino',
      'Azul',
      'Chivilcoy'
    ],
    'Argentina|Ciudad Autónoma de Buenos Aires': [
      'Buenos Aires',
      'Palermo',
      'Belgrano',
      'Flores',
      'Caballito',
      'Recoleta',
      'San Telmo',
      'La Boca',
      'Almagro',
      'Villa Crespo',
      'Núñez',
      'Saavedra'
    ],
    'Argentina|Córdoba': [
      'Córdoba',
      'Villa Carlos Paz',
      'Río Cuarto',
      'San Francisco',
      'Villa María',
      'Alta Gracia',
      'Jesús María',
      'La Calera',
      'Cosquín',
      'Río Tercero'
    ],
    'Argentina|Santa Fe': [
      'Rosario',
      'Santa Fe',
      'Rafaela',
      'Venado Tuerto',
      'Reconquista',
      'Santo Tomé',
      'Villa Constitución',
      'San Lorenzo'
    ],
    'Argentina|Mendoza': [
      'Mendoza',
      'Godoy Cruz',
      'Guaymallén',
      'Las Heras',
      'Maipú',
      'San Rafael',
      'Luján de Cuyo',
      'Rivadavia'
    ],
    'Argentina|Tucumán': [
      'San Miguel de Tucumán',
      'Tafí Viejo',
      'Concepción',
      'Yerba Buena',
      'Banda del Río Salí'
    ],
    'Argentina|Salta': ['Salta', 'Tartagal', 'Orán', 'Metán', 'General Güemes'],
    'Argentina|Entre Ríos': [
      'Paraná',
      'Concordia',
      'Gualeguaychú',
      'Concepción del Uruguay',
      'Villaguay'
    ],
    'Argentina|Corrientes': [
      'Corrientes',
      'Goya',
      'Paso de los Libres',
      'Mercedes',
      'Curuzú Cuatiá'
    ],
    'Argentina|Chaco': [
      'Resistencia',
      'Barranqueras',
      'Presidencia Roque Sáenz Peña',
      'Villa Ángela'
    ],
    'Argentina|Misiones': [
      'Posadas',
      'Oberá',
      'Eldorado',
      'Puerto Iguazú',
      'Apóstoles'
    ],
    'Argentina|Jujuy': [
      'San Salvador de Jujuy',
      'Palpalá',
      'La Quiaca',
      'Humahuaca'
    ],
    'Argentina|Santiago del Estero': [
      'Santiago del Estero',
      'La Banda',
      'Termas de Río Hondo'
    ],
    'Argentina|San Juan': [
      'San Juan',
      'Rivadavia',
      'Rawson',
      'Pocito',
      'Chimbas'
    ],
    'Argentina|Neuquén': [
      'Neuquén',
      'Cipolletti',
      'San Martín de los Andes',
      'Zapala',
      'Cutral-Có'
    ],
    'Argentina|Río Negro': [
      'Viedma',
      'General Roca',
      'San Carlos de Bariloche',
      'Cipolletti',
      'El Bolsón'
    ],
    'Argentina|La Rioja': ['La Rioja', 'Chilecito'],
    'Argentina|San Luis': ['San Luis', 'Villa Mercedes', 'Merlo'],
    'Argentina|Catamarca': [
      'San Fernando del Valle de Catamarca',
      'Andalgalá',
      'Belén'
    ],
    'Argentina|La Pampa': ['Santa Rosa', 'General Pico'],
    'Argentina|Chubut': [
      'Comodoro Rivadavia',
      'Rawson',
      'Puerto Madryn',
      'Trelew',
      'Esquel'
    ],
    'Argentina|Santa Cruz': [
      'Río Gallegos',
      'Caleta Olivia',
      'Pico Truncado',
      'Puerto Deseado'
    ],
    'Argentina|Tierra del Fuego': ['Ushuaia', 'Río Grande', 'Tolhuin'],
    'Argentina|Formosa': ['Formosa', 'Clorinda'],
    'Brazil|São Paulo': [
      'São Paulo',
      'Guarulhos',
      'Campinas',
      'São Bernardo do Campo',
      'Santo André',
      'Osasco',
      'Ribeirão Preto',
      'São José dos Campos',
      'Sorocaba',
      'Santos',
      'Mauá',
      'Diadema',
      'Jundiaí',
      'Piracicaba',
      'Bauru',
      'Mogi das Cruzes',
      'Franca'
    ],
    'Brazil|Rio de Janeiro': [
      'Rio de Janeiro',
      'São Gonçalo',
      'Duque de Caxias',
      'Nova Iguaçu',
      'Niterói',
      'Belford Roxo',
      'Campos dos Goytacazes',
      'Petrópolis',
      'Volta Redonda',
      'Macaé'
    ],
    'Brazil|Minas Gerais': [
      'Belo Horizonte',
      'Uberlândia',
      'Contagem',
      'Juiz de Fora',
      'Betim',
      'Montes Claros',
      'Uberaba',
      'Governador Valadares',
      'Ipatinga'
    ],
    'Brazil|Bahia': [
      'Salvador',
      'Feira de Santana',
      'Vitória da Conquista',
      'Camaçari',
      'Juazeiro',
      'Ilhéus',
      'Lauro de Freitas'
    ],
    'Brazil|Rio Grande do Sul': [
      'Porto Alegre',
      'Caxias do Sul',
      'Canoas',
      'Pelotas',
      'Santa Maria',
      'Novo Hamburgo',
      'São Leopoldo',
      'Gravataí',
      'Passo Fundo'
    ],
    'Brazil|Paraná': [
      'Curitiba',
      'Londrina',
      'Maringá',
      'Ponta Grossa',
      'Cascavel',
      'Foz do Iguaçu',
      'São José dos Pinhais',
      'Colombo'
    ],
    'Brazil|Santa Catarina': [
      'Florianópolis',
      'Joinville',
      'Blumenau',
      'São José',
      'Chapecó',
      'Criciúma',
      'Itajaí'
    ],
    'Brazil|Pernambuco': [
      'Recife',
      'Caruaru',
      'Olinda',
      'Paulista',
      'Petrolina',
      'Jaboatão dos Guararapes'
    ],
    'Brazil|Ceará': [
      'Fortaleza',
      'Juazeiro do Norte',
      'Caucaia',
      'Maracanaú',
      'Sobral',
      'Crato'
    ],
    'Brazil|Goiás': [
      'Goiânia',
      'Aparecida de Goiânia',
      'Anápolis',
      'Rio Verde'
    ],
    'Brazil|Amazonas': ['Manaus', 'Parintins', 'Itacoatiara', 'Manacapuru'],
    'Brazil|Pará': ['Belém', 'Ananindeua', 'Santarém', 'Marabá', 'Castanhal'],
    'Brazil|Maranhão': [
      'São Luís',
      'Imperatriz',
      'São José de Ribamar',
      'Timon'
    ],
    'Brazil|Mato Grosso do Sul': [
      'Campo Grande',
      'Dourados',
      'Três Lagoas',
      'Corumbá'
    ],
    'Brazil|Mato Grosso': ['Cuiabá', 'Várzea Grande', 'Rondonópolis', 'Sinop'],
    'Brazil|Espírito Santo': ['Vitória', 'Serra', 'Vila Velha', 'Cariacica'],
    'Brazil|Distrito Federal': [
      'Brasília',
      'Ceilândia',
      'Taguatinga',
      'Samambaia'
    ],
    'Mexico|Ciudad de México': [
      'Ciudad de México',
      'Álvaro Obregón',
      'Azcapotzalco',
      'Benito Juárez',
      'Coyoacán',
      'Cuauhtémoc',
      'Gustavo A. Madero',
      'Iztapalapa',
      'Iztacalco',
      'Miguel Hidalgo',
      'Tlalpan',
      'Xochimilco'
    ],
    'Mexico|Jalisco': [
      'Guadalajara',
      'Zapopan',
      'Tlaquepaque',
      'Tonalá',
      'Tlajomulco de Zúñiga',
      'Puerto Vallarta',
      'Lagos de Moreno'
    ],
    'Mexico|Nuevo León': [
      'Monterrey',
      'Guadalupe',
      'Apodaca',
      'San Nicolás de los Garza',
      'Escobedo',
      'Santa Catarina',
      'San Pedro Garza García'
    ],
    'Mexico|Estado de México': [
      'Ecatepec',
      'Naucalpan',
      'Nezahualcóyotl',
      'Chimalhuacán',
      'Toluca',
      'Tlalnepantla',
      'Ixtapaluca',
      'Tecámac',
      'Cuautitlán Izcalli'
    ],
    'Mexico|Veracruz': [
      'Veracruz',
      'Xalapa',
      'Boca del Río',
      'Coatzacoalcos',
      'Córdoba',
      'Orizaba',
      'Poza Rica'
    ],
    'Mexico|Puebla': ['Puebla', 'Tehuacán', 'Atlixco', 'Cholula'],
    'Mexico|Guanajuato': [
      'León',
      'Irapuato',
      'Celaya',
      'Salamanca',
      'Guanajuato'
    ],
    'Mexico|Chihuahua': [
      'Ciudad Juárez',
      'Chihuahua',
      'Delicias',
      'Cuauhtémoc'
    ],
    'Mexico|Coahuila': ['Torreón', 'Saltillo', 'Monclova', 'Piedras Negras'],
    'Mexico|Tamaulipas': ['Reynosa', 'Matamoros', 'Nuevo Laredo', 'Tampico'],
    'Mexico|Sonora': ['Hermosillo', 'Ciudad Obregón', 'Nogales', 'Guaymas'],
    'Mexico|Sinaloa': ['Culiacán', 'Mazatlán', 'Guasave'],
    'Mexico|Baja California': ['Tijuana', 'Mexicali', 'Ensenada', 'Tecate'],
    'Mexico|Michoacán': ['Morelia', 'Uruapan', 'Zamora', 'Lázaro Cárdenas'],
    'Mexico|Oaxaca': [
      'Oaxaca de Juárez',
      'Juchitán de Zaragoza',
      'Salina Cruz'
    ],
    'Mexico|Chiapas': [
      'Tuxtla Gutiérrez',
      'San Cristóbal de las Casas',
      'Tapachula'
    ],
    'Mexico|Guerrero': ['Acapulco', 'Chilpancingo', 'Iguala', 'Taxco'],
    'Mexico|Yucatán': ['Mérida', 'Valladolid', 'Progreso'],
    'Colombia|Antioquia': [
      'Medellín',
      'Bello',
      'Envigado',
      'Itagüí',
      'Rionegro',
      'Apartadó',
      'Turbo',
      'Caucasia',
      'Sabaneta'
    ],
    'Colombia|Bogotá D.C.': [
      'Bogotá',
      'Suba',
      'Engativá',
      'Kennedy',
      'Usaquén',
      'Chapinero',
      'Fontibón',
      'Bosa'
    ],
    'Colombia|Valle del Cauca': [
      'Cali',
      'Buenaventura',
      'Palmira',
      'Tulúa',
      'Buga',
      'Cartago',
      'Yumbo',
      'Jamundí'
    ],
    'Colombia|Atlántico': ['Barranquilla', 'Soledad', 'Malambo', 'Sabanalarga'],
    'Colombia|Bolívar': [
      'Cartagena',
      'Magangué',
      'El Carmen de Bolívar',
      'Turbaco'
    ],
    'Colombia|Santander': [
      'Bucaramanga',
      'Floridablanca',
      'Girón',
      'Piedecuesta',
      'Barrancabermeja'
    ],
    'Colombia|Cundinamarca': [
      'Soacha',
      'Fusagasugá',
      'Zipaquirá',
      'Chía',
      'Mosquera',
      'Facatativá',
      'Madrid'
    ],
    'Colombia|Norte de Santander': [
      'Cúcuta',
      'Ocaña',
      'Pamplona',
      'Villa del Rosario',
      'Los Patios'
    ],
    'Colombia|Tolima': ['Ibagué', 'Espinal', 'Melgar', 'Honda'],
    'Colombia|Nariño': ['Pasto', 'Tumaco', 'Ipiales'],
    'Colombia|Huila': ['Neiva', 'Pitalito', 'Garzón'],
    'Colombia|Magdalena': ['Santa Marta', 'Ciénaga', 'El Banco', 'Fundación'],
    'Colombia|Caldas': ['Manizales', 'Villamaría', 'La Dorada'],
    'Colombia|Risaralda': ['Pereira', 'Dosquebradas', 'Santa Rosa de Cabal'],
    'Colombia|Quindío': ['Armenia', 'Calarcá', 'Montenegro'],
    'Colombia|Meta': ['Villavicencio', 'Granada', 'Acacías'],
    'Colombia|Cesar': ['Valledupar', 'Aguachica', 'Codazzi'],
    'Colombia|La Guajira': ['Riohacha', 'Maicao', 'Uribia'],
    'Colombia|Boyacá': ['Tunja', 'Duitama', 'Sogamoso'],
    'Venezuela|Distrito Capital': ['Caracas'],
    'Venezuela|Miranda': [
      'Los Teques',
      'Guarenas',
      'Guatire',
      'Ocumare del Tuy',
      'Santa Teresa del Tuy',
      'Charallave'
    ],
    'Venezuela|Carabobo': [
      'Valencia',
      'Puerto Cabello',
      'Guacara',
      'San Diego',
      'Los Guayos',
      'Naguanagua'
    ],
    'Venezuela|Aragua': [
      'Maracay',
      'Turmero',
      'La Victoria',
      'Cagua',
      'El Limón'
    ],
    'Venezuela|Lara': ['Barquisimeto', 'Carora', 'El Tocuyo'],
    'Venezuela|Zulia': [
      'Maracaibo',
      'Cabimas',
      'Ciudad Ojeda',
      'San Francisco',
      'Lagunillas'
    ],
    'Venezuela|Bolívar': [
      'Ciudad Bolívar',
      'Ciudad Guayana',
      'San Félix',
      'Puerto Ordaz',
      'Upata'
    ],
    'Venezuela|Anzoátegui': [
      'Barcelona',
      'Lecherías',
      'El Tigre',
      'Puerto La Cruz',
      'Anaco'
    ],
    'Venezuela|Sucre': ['Cumaná', 'Carúpano', 'Güiria'],
    'Venezuela|Táchira': ['San Cristóbal', 'Táriba', 'Rubio'],
    'Venezuela|Mérida': ['Mérida', 'El Vigía', 'Tovar'],
    'Venezuela|Monagas': ['Maturín', 'Caripito'],
    'Venezuela|Falcón': ['Coro', 'Punto Fijo', 'La Vela de Coro'],
    'Venezuela|Nueva Esparta': ['La Asunción', 'Porlamar', 'Pampatar'],
    'Chile|Región Metropolitana de Santiago': [
      'Santiago',
      'Maipú',
      'La Florida',
      'Puente Alto',
      'Las Condes',
      'Ñuñoa',
      'Quilicura',
      'San Bernardo',
      'Peñalolén',
      'La Pintana',
      'Renca',
      'Pudahuel'
    ],
    'Chile|Valparaíso': [
      'Valparaíso',
      'Viña del Mar',
      'Quilpué',
      'San Antonio',
      'Villa Alemana',
      'Quillota',
      'Los Andes'
    ],
    'Chile|Biobío': [
      'Concepción',
      'Talcahuano',
      'San Pedro de la Paz',
      'Hualpén',
      'Chillán',
      'Los Ángeles',
      'Coronel'
    ],
    'Chile|La Araucanía': ['Temuco', 'Padre Las Casas', 'Villarrica', 'Angol'],
    'Chile|Los Lagos': ['Puerto Montt', 'Osorno', 'Castro', 'Puerto Varas'],
    'Chile|Antofagasta': ['Antofagasta', 'Calama', 'Tocopilla'],
    'Chile|Coquimbo': ['La Serena', 'Coquimbo', 'Ovalle'],
    'Chile|O\'Higgins': ['Rancagua', 'San Fernando', 'Pichilemu'],
    'Chile|Maule': ['Talca', 'Curicó', 'Linares'],
    'Chile|Arica y Parinacota': ['Arica'],
    'Chile|Tarapacá': ['Iquique', 'Alto Hospicio'],
    'Peru|Lima': [
      'Lima',
      'Callao',
      'San Juan de Lurigancho',
      'San Martín de Porres',
      'Ate',
      'Comas',
      'Villa El Salvador',
      'Los Olivos',
      'Puente Piedra',
      'Chorrillos',
      'Independencia'
    ],
    'Peru|Arequipa': [
      'Arequipa',
      'Cayma',
      'Cerro Colorado',
      'Socabaya',
      'Paucarpata'
    ],
    'Peru|La Libertad': [
      'Trujillo',
      'Huanchaco',
      'El Porvenir',
      'La Esperanza'
    ],
    'Peru|Piura': ['Piura', 'Sullana', 'Castilla', 'Talara', 'Paita'],
    'Peru|Cusco': ['Cusco', 'San Sebastián', 'Wanchaq', 'Santiago'],
    'Peru|Junín': ['Huancayo', 'El Tambo', 'Chilca', 'Satipo'],
    'Peru|Lambayeque': ['Chiclayo', 'José Leonardo Ortiz', 'La Victoria'],
    'Peru|Ica': ['Ica', 'Chincha Alta', 'Pisco', 'Nazca'],
    'Peru|Loreto': ['Iquitos', 'Yurimaguas'],
    'Peru|Puno': ['Puno', 'Juliaca', 'Ilave'],
    'Ecuador|Pichincha': ['Quito', 'Cayambe', 'Sangolquí', 'Machachi'],
    'Ecuador|Guayas': [
      'Guayaquil',
      'Durán',
      'Milagro',
      'Samborondón',
      'Playas'
    ],
    'Ecuador|Azuay': ['Cuenca', 'Gualaceo', 'Paute'],
    'Ecuador|Manabí': ['Portoviejo', 'Manta', 'Chone', 'El Carmen'],
    'Ecuador|El Oro': ['Machala', 'Pasaje', 'Santa Rosa', 'Huaquillas'],
    'Ecuador|Tungurahua': ['Ambato', 'Baños', 'Pelileo'],
    'Ecuador|Imbabura': ['Ibarra', 'Otavalo', 'Cotacachi'],
    'Ecuador|Loja': ['Loja', 'Catamayo'],
    'Ecuador|Santa Elena': ['Santa Elena', 'La Libertad', 'Salinas'],
    'Bolivia|La Paz': ['La Paz', 'El Alto', 'Viacha', 'Copacabana', 'Caranavi'],
    'Bolivia|Santa Cruz': [
      'Santa Cruz de la Sierra',
      'Montero',
      'Warnes',
      'Camiri',
      'Cotoca'
    ],
    'Bolivia|Cochabamba': [
      'Cochabamba',
      'Sacaba',
      'Quillacollo',
      'Tiquipaya',
      'Colcapirhua'
    ],
    'Bolivia|Oruro': ['Oruro', 'Llallagua'],
    'Bolivia|Potosí': ['Potosí', 'Uyuni', 'Tupiza'],
    'Bolivia|Chuquisaca': ['Sucre', 'Camargo'],
    'Bolivia|Tarija': ['Tarija', 'Yacuiba', 'Bermejo'],
    'Paraguay|Central': [
      'Luque',
      'San Lorenzo',
      'Capiatá',
      'Lambaré',
      'Fernando de la Mora',
      'Mariano Roque Alonso',
      'Ñemby',
      'Limpio'
    ],
    'Paraguay|Asunción': ['Asunción'],
    'Paraguay|Alto Paraná': [
      'Ciudad del Este',
      'Presidente Franco',
      'Hernandarias'
    ],
    'Paraguay|Itapúa': ['Encarnación'],
    'Paraguay|Caaguazú': ['Coronel Oviedo', 'Caaguazú'],
    'Uruguay|Montevideo': [
      'Montevideo',
      'Ciudad Vieja',
      'Pocitos',
      'Punta Carretas',
      'Malvín',
      'Carrasco',
      'Prado'
    ],
    'Uruguay|Canelones': [
      'Las Piedras',
      'La Paz',
      'Pando',
      'Progreso',
      'Santa Lucía'
    ],
    'Uruguay|Maldonado': [
      'Maldonado',
      'Punta del Este',
      'San Carlos',
      'Piriápolis'
    ],
    'Uruguay|Salto': ['Salto'],
    'Uruguay|Paysandú': ['Paysandú'],
    'Uruguay|Rivera': ['Rivera'],
    'Uruguay|Colonia': ['Colonia del Sacramento', 'Juan Lacaze', 'Carmelo'],
    'Spain|Madrid': [
      'Madrid',
      'Móstoles',
      'Alcalá de Henares',
      'Fuenlabrada',
      'Leganés',
      'Getafe',
      'Alcorcón',
      'Torrejón de Ardoz',
      'Parla',
      'Alcobendas',
      'Pozuelo de Alarcón'
    ],
    'Spain|Barcelona': [
      'Barcelona',
      'L\'Hospitalet de Llobregat',
      'Badalona',
      'Terrassa',
      'Sabadell',
      'Mataró',
      'Santa Coloma de Gramenet',
      'Cornellà de Llobregat',
      'Rubí'
    ],
    'Spain|Valencia': [
      'Valencia',
      'Alicante',
      'Elche',
      'Torrent',
      'Castellón de la Plana',
      'Alcoy',
      'Orihuela',
      'Gandia'
    ],
    'Spain|Sevilla': [
      'Sevilla',
      'Dos Hermanas',
      'Alcalá de Guadaíra',
      'Jerez de la Frontera',
      'Utrera'
    ],
    'Spain|Málaga': [
      'Málaga',
      'Marbella',
      'Fuengirola',
      'Torremolinos',
      'Vélez-Málaga',
      'Estepona'
    ],
    'Spain|Murcia': ['Murcia', 'Cartagena', 'Lorca', 'Molina de Segura'],
    'Spain|Vizcaya': ['Bilbao', 'Barakaldo', 'Getxo', 'Basauri', 'Portugalete'],
    'Spain|Guipúzcoa': ['San Sebastián', 'Irun', 'Errenteria'],
    'Spain|Zaragoza': ['Zaragoza', 'Calatayud'],
    'Spain|Asturias': ['Oviedo', 'Gijón', 'Avilés'],
    'Spain|Cantabria': ['Santander', 'Torrelavega'],
    'Spain|Navarra': ['Pamplona', 'Tudela'],
    'Spain|La Rioja': ['Logroño', 'Calahorra'],
    'Spain|Baleares': ['Palma', 'Ibiza', 'Maó'],
    'Spain|Las Palmas': ['Las Palmas de Gran Canaria', 'Telde', 'Arrecife'],
    'Spain|Santa Cruz de Tenerife': [
      'Santa Cruz de Tenerife',
      'San Cristóbal de La Laguna',
      'Arona'
    ],
    'Portugal|Lisboa': [
      'Lisboa',
      'Sintra',
      'Cascais',
      'Loures',
      'Odivelas',
      'Amadora',
      'Almada',
      'Setúbal',
      'Seixal'
    ],
    'Portugal|Porto': [
      'Porto',
      'Vila Nova de Gaia',
      'Matosinhos',
      'Gondomar',
      'Maia',
      'Valongo'
    ],
    'Portugal|Braga': ['Braga', 'Guimarães', 'Barcelos'],
    'Portugal|Faro': ['Faro', 'Loulé', 'Portimão', 'Lagos', 'Olhão'],
    'Portugal|Aveiro': ['Aveiro', 'Oliveira de Azeméis', 'São João da Madeira'],
    'Portugal|Madeira': ['Funchal', 'Câmara de Lobos'],
    'Portugal|Açores': ['Ponta Delgada', 'Angra do Heroísmo'],
    'Costa Rica|San José': [
      'San José',
      'Desamparados',
      'Alajuelita',
      'Aserrí',
      'Curridabat',
      'Tibás',
      'Goicoechea',
      'Escazú',
      'Santa Ana'
    ],
    'Costa Rica|Alajuela': [
      'Alajuela',
      'San Carlos',
      'Grecia',
      'Atenas',
      'Naranjo'
    ],
    'Costa Rica|Cartago': ['Cartago', 'El Guarco', 'La Unión', 'Turrialba'],
    'Costa Rica|Heredia': ['Heredia', 'San Rafael', 'Santa Bárbara', 'Belén'],
    'Costa Rica|Guanacaste': ['Liberia', 'Nicoya', 'Santa Cruz'],
    'Costa Rica|Puntarenas': ['Puntarenas', 'Quepos'],
    'Costa Rica|Limón': ['Limón', 'Pococí', 'Siquirres'],
    'Guatemala|Guatemala': [
      'Guatemala City',
      'Mixco',
      'Villa Nueva',
      'San Juan Sacatepéquez',
      'Chinautla',
      'Petapa'
    ],
    'Guatemala|Quetzaltenango': ['Quetzaltenango', 'Coatepeque'],
    'Guatemala|Alta Verapaz': ['Cobán', 'Chisec'],
    'Guatemala|Izabal': ['Puerto Barrios', 'Morales', 'Livingston'],
    'Guatemala|Petén': ['Flores', 'Santa Elena'],
    'Guatemala|Sacatepéquez': ['Antigua Guatemala', 'Jocotenango'],
    'Honduras|Francisco Morazán': ['Tegucigalpa', 'Comayagüela'],
    'Honduras|Cortés': [
      'San Pedro Sula',
      'Puerto Cortés',
      'Villanueva',
      'Choloma',
      'La Lima'
    ],
    'Honduras|Atlántida': ['La Ceiba', 'El Progreso', 'Tela'],
    'Honduras|Comayagua': ['Comayagua', 'Siguatepeque'],
    'Honduras|El Paraíso': ['Danlí', 'El Paraíso'],
    'El Salvador|San Salvador': [
      'San Salvador',
      'Soyapango',
      'Mejicanos',
      'Apopa',
      'Ciudad Delgado',
      'Santa Tecla',
      'Antiguo Cuscatlán',
      'Ilopango',
      'San Marcos'
    ],
    'El Salvador|Santa Ana': ['Santa Ana', 'Chalchuapa', 'Coatepeque'],
    'El Salvador|San Miguel': ['San Miguel'],
    'El Salvador|Sonsonate': ['Sonsonate', 'Acajutla', 'Armenia'],
    'Panama|Panamá': [
      'Ciudad de Panamá',
      'San Miguelito',
      'Tocumen',
      'Arraiján',
      'La Chorrera'
    ],
    'Panama|Panamá Oeste': ['La Chorrera', 'Arraiján'],
    'Panama|Colón': ['Colón', 'Portobelo'],
    'Panama|Chiriquí': ['David', 'Boquete', 'La Concepción'],
    'Dominican Republic|Distrito Nacional': ['Santo Domingo'],
    'Dominican Republic|Santo Domingo': [
      'Santo Domingo Este',
      'Santo Domingo Norte',
      'Santo Domingo Oeste',
      'Boca Chica'
    ],
    'Dominican Republic|Santiago': ['Santiago de los Caballeros', 'Moca'],
    'Dominican Republic|La Altagracia': ['Higüey'],
    'Dominican Republic|La Vega': [
      'La Vega',
      'Jarabacoa',
      'Constanza',
      'Bonao'
    ],
    'Dominican Republic|San Pedro de Macorís': ['San Pedro de Macorís'],
    'Dominican Republic|Puerto Plata': ['Puerto Plata', 'Sosúa', 'Cabarete'],
    'United States|Florida': [
      'Miami',
      'Orlando',
      'Tampa',
      'Jacksonville',
      'St. Petersburg',
      'Hialeah',
      'Fort Lauderdale',
      'Cape Coral'
    ],
    'United States|California': [
      'Los Angeles',
      'San Diego',
      'San Jose',
      'San Francisco',
      'Fresno',
      'Sacramento',
      'Long Beach',
      'Oakland',
      'Bakersfield'
    ],
    'United States|Texas': [
      'Houston',
      'San Antonio',
      'Dallas',
      'Austin',
      'Fort Worth',
      'El Paso',
      'Arlington',
      'Corpus Christi',
      'Laredo'
    ],
    'United States|New York': [
      'New York City',
      'Buffalo',
      'Rochester',
      'Yonkers',
      'Syracuse',
      'Albany'
    ],
    'United States|Illinois': [
      'Chicago',
      'Aurora',
      'Naperville',
      'Joliet',
      'Rockford',
      'Springfield'
    ],
    'Italy|Lombardia': [
      'Milano',
      'Brescia',
      'Bergamo',
      'Monza',
      'Como',
      'Varese'
    ],
    'Italy|Lazio': ['Roma', 'Latina', 'Frosinone', 'Viterbo'],
    'Italy|Campania': [
      'Napoli',
      'Salerno',
      'Torre del Greco',
      'Pozzuoli',
      'Caserta'
    ],
    'Italy|Sicilia': [
      'Palermo',
      'Catania',
      'Messina',
      'Siracusa',
      'Ragusa',
      'Agrigento'
    ],
    'Italy|Piemonte': ['Torino', 'Novara', 'Alessandria', 'Asti', 'Cuneo'],
    'Italy|Veneto': ['Venezia', 'Verona', 'Padova', 'Vicenza', 'Treviso'],
    'Italy|Emilia-Romagna': [
      'Bologna',
      'Modena',
      'Reggio nell\'Emilia',
      'Parma',
      'Ferrara',
      'Ravenna',
      'Rimini'
    ],
    'Italy|Toscana': ['Firenze', 'Prato', 'Livorno', 'Pisa', 'Arezzo'],
    'Italy|Puglia': ['Bari', 'Taranto', 'Foggia', 'Lecce'],
    'Germany|North Rhine-Westphalia': [
      'Köln',
      'Düsseldorf',
      'Dortmund',
      'Essen',
      'Duisburg',
      'Bochum',
      'Wuppertal',
      'Bielefeld',
      'Bonn',
      'Münster'
    ],
    'Germany|Bavaria': [
      'München',
      'Nürnberg',
      'Augsburg',
      'Würzburg',
      'Regensburg'
    ],
    'Germany|Baden-Württemberg': [
      'Stuttgart',
      'Mannheim',
      'Karlsruhe',
      'Freiburg im Breisgau',
      'Heidelberg'
    ],
    'Germany|Hesse': ['Frankfurt am Main', 'Wiesbaden', 'Kassel', 'Darmstadt'],
    'Germany|Saxony': ['Leipzig', 'Dresden', 'Chemnitz'],
    'Germany|Berlin': [
      'Berlin',
      'Mitte',
      'Kreuzberg',
      'Prenzlauer Berg',
      'Charlottenburg',
      'Neukölln'
    ],
    'Germany|Hamburg': ['Hamburg', 'Wandsbek', 'Altona'],
    'France|Île-de-France': [
      'Paris',
      'Boulogne-Billancourt',
      'Saint-Denis',
      'Argenteuil',
      'Montreuil',
      'Nanterre',
      'Versailles',
      'Créteil'
    ],
    'France|Auvergne-Rhône-Alpes': [
      'Lyon',
      'Grenoble',
      'Saint-Étienne',
      'Villeurbanne',
      'Clermont-Ferrand'
    ],
    'France|Nouvelle-Aquitaine': [
      'Bordeaux',
      'Limoges',
      'Pau',
      'La Rochelle',
      'Poitiers'
    ],
    'France|Occitanie': ['Toulouse', 'Montpellier', 'Nîmes', 'Perpignan'],
    'France|Hauts-de-France': ['Lille', 'Amiens', 'Dunkerque', 'Roubaix'],
    'France|Provence-Alpes-Côte d\'Azur': [
      'Marseille',
      'Nice',
      'Toulon',
      'Aix-en-Provence',
      'Avignon'
    ],
    'United Kingdom|England': [
      'London',
      'Birmingham',
      'Leeds',
      'Sheffield',
      'Manchester',
      'Liverpool',
      'Bristol',
      'Coventry',
      'Newcastle',
      'Nottingham',
      'Leicester'
    ],
    'United Kingdom|Scotland': ['Glasgow', 'Edinburgh', 'Aberdeen', 'Dundee'],
    'United Kingdom|Wales': ['Cardiff', 'Swansea', 'Newport'],
    'United Kingdom|Northern Ireland': ['Belfast', 'Londonderry'],
  };

  List<String> _getHardcodedCities(String apiCountryName, String stateName) {
    return _hardcodedCities['$apiCountryName|$stateName'] ?? [];
  }

  List<String> _getHardcodedCitiesForCountry(String apiCountryName) {
    final cities = <String>{};
    for (final entry in _hardcodedCities.entries) {
      if (entry.key.startsWith('$apiCountryName|')) {
        cities.addAll(entry.value);
      }
    }
    final list = cities.toList()..sort();
    return list;
  }

  String? _findNormalizedOption(Iterable<String> options, String? value) {
    final key = normalizeLookupKey(value);
    if (key.isEmpty) return null;

    for (final option in options) {
      if (normalizeLookupKey(option) == key) {
        return option;
      }
    }
    return null;
  }

  bool _hasNormalizedOption(Iterable<String> options, String? value) =>
      _findNormalizedOption(options, value) != null;

  void _validateLocationSelection({
    required String country,
    required String state,
    required String city,
  }) {
    if (country.isEmpty) {
      if (state.isEmpty && city.isEmpty) return;
      throw Exception('Selecciona un país válido para completar la ubicación.');
    }

    if (_countryOptions.isNotEmpty && _selectedCountryId == null) {
      throw Exception('Selecciona un país de la lista para continuar.');
    }

    final knownStates = _states.isNotEmpty
        ? _states
        : location_data.getHardcodedStates(country);
    final countryHasKnownStates = knownStates.isNotEmpty ||
        location_data.hasHardcodedStatesForCountry(country);

    if (state.isNotEmpty &&
        countryHasKnownStates &&
        !_hasNormalizedOption(knownStates, state)) {
      throw Exception(
        'El estado/provincia seleccionado no pertenece al país elegido.',
      );
    }

    if (city.isEmpty) return;

    if (countryHasKnownStates && state.isEmpty) {
      throw Exception(
        'Selecciona un estado/provincia antes de elegir la ciudad.',
      );
    }

    final knownStateCities = state.isNotEmpty
        ? (_cities.isNotEmpty
            ? _cities
            : location_data.getHardcodedCities(country, state))
        : <String>[];
    final countryHasKnownCities =
        location_data.hasHardcodedCitiesForCountry(country);

    if (knownStateCities.isNotEmpty) {
      if (!_hasNormalizedOption(knownStateCities, city)) {
        throw Exception(
          'La ciudad seleccionada no pertenece al estado/provincia elegido.',
        );
      }
      return;
    }

    final knownCountryCities = _cities.isNotEmpty
        ? _cities
        : location_data.getHardcodedCitiesForCountry(country);
    if (knownCountryCities.isNotEmpty &&
        !_hasNormalizedOption(knownCountryCities, city)) {
      throw Exception('La ciudad seleccionada no pertenece al país elegido.');
    }

    if (knownCountryCities.isEmpty && countryHasKnownCities) {
      throw Exception('La ciudad seleccionada no pertenece al país elegido.');
    }
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

    // Check hardcoded list first (instant, offline)
    final hardcoded = _hardcodedStates[apiName] ?? [];
    if (hardcoded.isNotEmpty) {
      final matchedState = hardcoded.cast<String?>().firstWhere(
            (s) =>
                normalizeLookupKey(s) == normalizeLookupKey(preferredStateText),
            orElse: () => null,
          );
      final selectedState = matchedState;
      if (!mounted) return;
      setState(() {
        _states = hardcoded;
        _isStatesLoading = false;
        _selectedState = selectedState;
        _stateController?.text = selectedState ?? '';
        if (selectedState == null) {
          _selectedCity = null;
          _cityController?.text = '';
        }
      });
      if (selectedState != null) {
        await _loadCitiesByState(countryName, selectedState,
            preferredCity: preferredCityText);
      }
      return;
    }

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

      final selectedState = matchedState;

      if (!mounted) return;
      setState(() {
        _selectedState = selectedState;
        _stateController?.text = selectedState ?? '';
        if (selectedState == null) {
          _selectedCity = null;
          _cityController?.text = '';
        }
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

    // Check hardcoded list first (instant, offline)
    final hardcodedForCountry = _getHardcodedCitiesForCountry(apiCountryName);
    if (hardcodedForCountry.isNotEmpty) {
      final matchedCity = hardcodedForCountry.cast<String?>().firstWhere(
            (c) =>
                normalizeLookupKey(c) == normalizeLookupKey(preferredCityText),
            orElse: () => null,
          );
      final selectedCity = matchedCity;
      if (!mounted) return;
      setState(() {
        _cities = List<String>.from(hardcodedForCountry);
        _selectedCity = selectedCity;
        _cityController?.text = selectedCity ?? '';
        _isCitiesLoading = false;
      });
      return;
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

          final selectedCity = matchedCity;

          if (!mounted) return;
          setState(() {
            _cities = cityList;
            _selectedCity = selectedCity;
            _cityController?.text = selectedCity ?? '';
          });
        }
      }
      if (_cities.isEmpty &&
          preferredCityText.isNotEmpty &&
          !location_data.hasHardcodedCitiesForCountry(apiCountryName) &&
          mounted) {
        setState(() {
          _cities = [preferredCityText];
          _selectedCity = preferredCityText;
          _cityController?.text = preferredCityText;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar ciudades: $e');
      if (preferredCityText.isNotEmpty &&
          !location_data.hasHardcodedCitiesForCountry(apiCountryName) &&
          mounted) {
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

    // Check hardcoded list first (instant, offline)
    final hardcodedForState = _getHardcodedCities(apiName, stateName);
    if (hardcodedForState.isNotEmpty) {
      final matchedCity = hardcodedForState.cast<String?>().firstWhere(
            (c) =>
                normalizeLookupKey(c) == normalizeLookupKey(preferredCityText),
            orElse: () => null,
          );
      final selectedCity = matchedCity;
      if (!mounted) return;
      setState(() {
        _cities = List<String>.from(hardcodedForState);
        _selectedCity = selectedCity;
        _cityController?.text = selectedCity ?? '';
        _isCitiesLoading = false;
      });
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(
                'https://countriesnow.space/api/v0.1/countries/state/cities'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiName, 'state': stateName}),
          )
          .timeout(const Duration(seconds: 10));

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

          final selectedCity = matchedCity;

          if (!mounted) return;
          setState(() {
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
                if ((isProfilePhoto
                    ? (_photoUrl?.isNotEmpty ?? false)
                    : (_coverUrl?.isNotEmpty ?? false)))
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
                      isProfilePhoto
                          ? 'Eliminar Foto'
                          : 'Eliminar Foto de Portada',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: Text(
                      isProfilePhoto
                          ? 'Quitar la foto actual'
                          : 'Quitar la portada actual',
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos procesar tu imagen. Verifica tu conexión e intenta de nuevo con una imagen más liviana.'),
            backgroundColor: Colors.red));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos subir tu imagen. Verifica tu conexión e intenta de nuevo con una imagen más liviana.'),
            backgroundColor: Colors.red));
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
  String? _extractPhotoStoragePath(String? rawUrl) {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final publicIndex = segments.indexOf('public');
    if (publicIndex == -1) return null;

    final bucketIndex = publicIndex + 1;
    if (bucketIndex >= segments.length || segments[bucketIndex] != 'Fotos') {
      return null;
    }

    final objectSegments = segments.skip(bucketIndex + 1).toList();
    if (objectSegments.isEmpty) return null;

    return objectSegments.map(Uri.decodeComponent).join('/');
  }

  Future<void> _deletePhotoStorageAsset(String? rawUrl) async {
    final storagePath = _extractPhotoStoragePath(rawUrl);
    if (storagePath == null || storagePath.isEmpty) return;

    try {
      await SupaFlow.client.storage.from('Fotos').remove([storagePath]);
    } catch (e) {
      debugPrint('Storage delete failed for $storagePath: $e');
    }
  }

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
      final previousUrl = isProfilePhoto ? _photoUrl : _coverUrl;
      final updateData =
          isProfilePhoto ? {'photo_url': null} : {'cover_url': null};

      await SupaFlow.client.from('users').update(updateData).eq('user_id', uid);
      await _deletePhotoStorageAsset(previousUrl);

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos eliminar la foto en este momento. Intenta de nuevo más tarde.'),
            backgroundColor: Colors.red));
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

    for (var attempt = 0; attempt <= payload.length + 4; attempt++) {
      try {
        await SupaFlow.client
            .from(table)
            .update(mutablePayload)
            .eq(matchColumn, matchValue);
        return;
      } catch (e) {
        final missingColumn = _missingColumnFromSchemaError(e, table);
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

  String? _missingColumnFromSchemaError(Object error, String table) {
    final message = error.toString();
    final escapedTable = RegExp.escape(table);
    final patterns = [
      RegExp("Could not find the '([^']+)' column of '$escapedTable'"),
      RegExp('Could not find the "([^"]+)" column of "$escapedTable"'),
      RegExp("Could not find the '([^']+)' column"),
      RegExp('Could not find the "([^"]+)" column'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      final column = match?.group(1)?.trim();
      if (column != null && column.isNotEmpty) return column;
    }
    return null;
  }

  Future<void> _insertTableWithSchemaFallback({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final mutablePayload = Map<String, dynamic>.from(payload);

    for (var attempt = 0; attempt <= payload.length + 4; attempt++) {
      try {
        await SupaFlow.client.from(table).insert(mutablePayload);
        return;
      } catch (e) {
        final missingColumn = _missingColumnFromSchemaError(e, table);
        if (missingColumn == null || missingColumn.isEmpty) rethrow;
        if (!mutablePayload.containsKey(missingColumn)) rethrow;
        mutablePayload.remove(missingColumn);
        if (mutablePayload.isEmpty) rethrow;
      }
    }

    throw Exception(
        'No se pudo insertar en $table por incompatibilidad de schema');
  }

  Future<void> _saveChanges() async {
    try {
      setState(() => _isSaving = true);
      final uid = currentUserUid;
      final registeredBirthday = _registeredBirthday;
      final effectiveBirthday = registeredBirthday ?? _selectedBirthday;
      double? parsedHeightCm;
      double? parsedWeightKg;
      int? parsedExperienceYears;

      // 2.1 — Validação de inputs numéricos
      if (_currentUserType == 'jugador') {
        final heightText = _heightController?.text.trim() ?? '';
        parsedHeightCm = _parseHeightInCentimeters(heightText);
        if (heightText.isNotEmpty &&
            (parsedHeightCm == null ||
                parsedHeightCm < _minPlayerHeightCm ||
                parsedHeightCm > _maxPlayerHeightCm)) {
          throw Exception(
            'La altura debe estar entre 110 y 230 cm.',
          );
        }

        final weightText = _weightController?.text.trim() ?? '';
        parsedWeightKg = _tryParseFiniteDouble(weightText);
        if (weightText.isNotEmpty &&
            (parsedWeightKg == null ||
                parsedWeightKg < _minPlayerWeightKg ||
                parsedWeightKg > _maxPlayerWeightKg)) {
          throw Exception(
            'El peso debe estar entre 25 y 180 kg.',
          );
        }

        final experienceText = _experienceController?.text.trim() ?? '';
        parsedExperienceYears = _tryParseInt(experienceText);
        if (experienceText.isNotEmpty &&
            (parsedExperienceYears == null ||
                parsedExperienceYears < _minPlayerExperienceYears ||
                parsedExperienceYears > _maxPlayerExperienceYears)) {
          throw Exception(
            'La experiencia debe estar entre 0 y 40 años.',
          );
        }

        final age = _ageInYears(effectiveBirthday);
        if (age != null &&
            parsedExperienceYears != null &&
            parsedExperienceYears > age) {
          throw Exception(
            'La experiencia no puede superar la edad del jugador.',
          );
        }
      }

      if (registeredBirthday != null) {
        _selectedBirthday = registeredBirthday;
        _birthdayController?.text =
            _formatDateForInput(registeredBirthday.toIso8601String());
      }

      // 1.5 — Verificar se a primeira data cadastrada exige responsável
      if (effectiveBirthday != null &&
          registeredBirthday == null &&
          _currentUserType == 'jugador') {
        final now = DateTime.now();
        int age = now.year - effectiveBirthday.year;
        if (now.month < effectiveBirthday.month ||
            (now.month == effectiveBirthday.month &&
                now.day < effectiveBirthday.day)) {
          age--;
        }

        if (age < 13) {
          throw Exception(
            'FutbolTalent está disponible solo para jugadores a partir de 13 años.',
          );
        }

        if (age < 18) {
          // Verifica se tem guardian
          final userData = await SupaFlow.client
              .from('users')
              .select('has_guardian, guardian_status')
              .eq('user_id', uid)
              .maybeSingle();
          final hasGuardian = userData?['has_guardian'] == true;
          if (!hasGuardian) {
            throw Exception(
              'Los menores de 18 años necesitan un responsable registrado. '
              'Contacte al soporte para actualizar su cuenta.',
            );
          }
        }
      }

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
      _validateLocationSelection(
        country: country,
        state: state,
        city: city,
      );
      final normalizedPosition =
          normalizePlayerPosition(_posicaoController?.text);
      var normalizedCategory =
          normalizePlayerCategory(_categoryController?.text);
      if (normalizedCategory.isEmpty) {
        normalizedCategory = normalizePlayerCategory(
          '',
          birthday:
              effectiveBirthday?.toIso8601String() ?? _birthdayController?.text,
        );
      }
      final normalizedFoot =
          normalizeDominantFoot(_pieDominanteController?.text);
      final normalizedPhone = _validateAndNormalizeLatamPhone(
        _phoneController?.text ?? '',
      );
      final normalizedProfessionalUrl = _validateAndNormalizeProfessionalUrl(
        _professionalUrlController?.text ?? '',
      );
      final normalizedName = normalizePersonNameInput(_nomeController?.text);
      final normalizedUsername = (_usernameController?.text.trim() ?? '')
          .replaceFirst(RegExp(r'^@+'), '');

      final userPayload = <String, dynamic>{
        'name': normalizedName,
        'username': normalizedUsername.isNotEmpty
            ? normalizedUsername
            : usernameSlugFromName(normalizedName, userId: currentUserUid),
        'city': city,
        'ciudad': city,
        'country': country,
        'pais': country,
        'country_id': _selectedCountryId != null
            ? int.tryParse(_selectedCountryId!)
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (registeredBirthday == null && effectiveBirthday != null) {
        final birthdayIso = effectiveBirthday.toIso8601String();
        userPayload['birthday'] = birthdayIso;
        userPayload['birth_date'] = birthdayIso;
      }

      if (state.isNotEmpty) {
        userPayload['state'] = state;
        userPayload['estado'] = state;
        userPayload['province'] = state;
        userPayload['provincia'] = state;
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
          'current_role': _currentRoleController?.text.trim() ?? '',
          'rol_actual': _currentRoleController?.text.trim() ?? '',
          'organization_type': _selectedOrganizationType ?? '',
          'tipo_organizacion': _selectedOrganizationType ?? '',
          'work_zone': _workZoneController?.text.trim() ?? '',
          'zona_trabajo': _workZoneController?.text.trim() ?? '',
          'interest_categories':
              _interestCategoriesController?.text.trim() ?? '',
          'categorias_interes':
              _interestCategoriesController?.text.trim() ?? '',
          'interest_positions': _interestPositionsController?.text.trim() ?? '',
          'posiciones_interes': _interestPositionsController?.text.trim() ?? '',
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
          'telephone': normalizedPhone,
          'club': _clubController?.text.trim() ?? '',
          'organization_type': _selectedOrganizationType ?? '',
          'current_role': _currentRoleController?.text.trim() ?? '',
          'work_zone': _workZoneController?.text.trim() ?? '',
          'interest_categories':
              _interestCategoriesController?.text.trim() ?? '',
          'interest_positions': _interestPositionsController?.text.trim() ?? '',
          'url_profesional': normalizedProfessionalUrl,
          'dni': _tryParseInt(_dniController?.text),
          'city': city,
          'ciudad': city,
          'country': country,
          'pais': country,
          if (state.isNotEmpty) 'state': state,
          if (state.isNotEmpty) 'estado': state,
          if (state.isNotEmpty) 'province': state,
          if (state.isNotEmpty) 'provincia': state,
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
            'telephone': normalizedPhone,
            'club': _clubController?.text.trim() ?? '',
            'organization_type': _selectedOrganizationType ?? '',
            'current_role': _currentRoleController?.text.trim() ?? '',
            'work_zone': _workZoneController?.text.trim() ?? '',
            'interest_categories':
                _interestCategoriesController?.text.trim() ?? '',
            'interest_positions':
                _interestPositionsController?.text.trim() ?? '',
            'url_profesional': normalizedProfessionalUrl,
            'dni': _tryParseInt(_dniController?.text),
            'city': city,
            'ciudad': city,
            'country': country,
            'pais': country,
            if (state.isNotEmpty) 'state': state,
            if (state.isNotEmpty) 'estado': state,
            if (state.isNotEmpty) 'province': state,
            if (state.isNotEmpty) 'provincia': state,
            if (state.isNotEmpty) 'region': state,
          };
          await _insertTableWithSchemaFallback(table: 'scouts', payload: {
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
          'experience': parsedExperienceYears,
          'altura': parsedHeightCm,
          'peso': parsedWeightKg,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_saveErrorMessage(e)), backgroundColor: Colors.red));
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

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  String? _dialCodeFromCountrySelection() {
    final country = normalizeCountryName(_countryController?.text);
    if (country.isEmpty) return null;
    return _latamCountryDialCode[country];
  }

  String _chunkBySize(String input, List<int> chunkSizes) {
    if (input.isEmpty) return '';
    final chunks = <String>[];
    var cursor = 0;
    for (final size in chunkSizes) {
      if (cursor >= input.length) break;
      final end = (cursor + size > input.length) ? input.length : cursor + size;
      chunks.add(input.substring(cursor, end));
      cursor = end;
    }
    if (cursor < input.length) {
      chunks.add(input.substring(cursor));
    }
    return chunks.join(' ');
  }

  String _formatLatamPhone(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return '';

    final hasExplicitPlus = raw.startsWith('+');
    final digits = _digitsOnly(raw);
    if (digits.isEmpty) return '';

    String? dialCode;
    String localDigits = digits;

    if (hasExplicitPlus) {
      for (final code in _latamDialCodes) {
        if (digits.startsWith(code)) {
          dialCode = code;
          localDigits = digits.substring(code.length);
          break;
        }
      }
      dialCode ??= _dialCodeFromCountrySelection();
      if (dialCode != null && digits.startsWith(dialCode)) {
        localDigits = digits.substring(dialCode.length);
      }
    } else {
      dialCode = _dialCodeFromCountrySelection();
    }

    if (dialCode == null || dialCode.isEmpty) {
      // Without selected country, preserve a generic international-like mask.
      if (hasExplicitPlus) {
        return '+${_chunkBySize(digits, [3, 3, 4])}';
      }
      return _chunkBySize(digits, [3, 3, 4]);
    }

    final formattedLocal = _chunkBySize(localDigits, [3, 3, 4]);
    return formattedLocal.isEmpty ? '+$dialCode' : '+$dialCode $formattedLocal';
  }

  void _handlePhoneInputChange() {
    if (_isFormattingPhone) return;
    final controller = _phoneController;
    if (controller == null) return;

    final formatted = _formatLatamPhone(controller.text);
    if (formatted == controller.text) return;

    _isFormattingPhone = true;
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormattingPhone = false;
  }

  String _validateAndNormalizeLatamPhone(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return '';

    final formatted = _formatLatamPhone(raw);
    final digits = _digitsOnly(formatted);
    if (digits.length < 10 || digits.length > 14) {
      throw Exception(
        'Teléfono inválido. Usa formato internacional LATAM, por ejemplo +54 911 1234 5678.',
      );
    }

    if (!formatted.startsWith('+')) {
      throw Exception(
        'Teléfono inválido. Incluye código de país de América Latina (ej: +54, +55, +52).',
      );
    }

    final withoutPlus = digits;
    final hasKnownDialCode = _latamDialCodes.any(
      (code) => withoutPlus.startsWith(code),
    );
    if (!hasKnownDialCode) {
      throw Exception(
        'Código de país no reconocido para LATAM. Revisa el prefijo internacional.',
      );
    }

    return formatted;
  }

  String _validateAndNormalizeProfessionalUrl(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return '';

    final normalized = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';

    final uri = Uri.tryParse(normalized);
    final isValid = uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.host.isNotEmpty && uri.host.contains('.'));

    if (!isValid) {
      throw Exception(
        'Link profesional inválido. Ingresa una URL válida, por ejemplo https://linkedin.com/in/usuario.',
      );
    }

    return normalized;
  }

  String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  List<String> get _countryOptions => buildNormalizedOptions(
        _countries.map((country) => country['name']),
        normalizeCountryName,
      );

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

  double? _tryParseFiniteDouble(String? rawValue) {
    final cleaned = (rawValue ?? '').trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final parsed = double.tryParse(cleaned);
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  double? _parseHeightInCentimeters(String? rawValue) {
    final parsed = _tryParseFiniteDouble(rawValue);
    if (parsed == null) return null;
    if (parsed >= 1 && parsed < 3) {
      return double.parse((parsed * 100).toStringAsFixed(1));
    }
    return parsed;
  }

  int? _ageInYears(DateTime? birthday) {
    if (birthday == null) return null;
    final today = DateTime.now();
    var years = today.year - birthday.year;
    final hasHadBirthdayThisYear = today.month > birthday.month ||
        (today.month == birthday.month && today.day >= birthday.day);
    if (!hasHadBirthdayThisYear) years -= 1;
    return years < 0 ? null : years;
  }

  String _saveErrorMessage(Object error) {
    final text = error.toString();
    const exceptionPrefix = 'Exception: ';
    if (text.startsWith(exceptionPrefix)) {
      return text.substring(exceptionPrefix.length);
    }
    return 'Hubo un problema al guardar tus cambios. Por favor, verifica tu conexión e intenta nuevamente.';
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
    if (_registeredBirthday != null) {
      _showBirthdayLockedMessage();
      return;
    }

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

  void _showBirthdayLockedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La fecha de nacimiento no se puede modificar después del registro.',
        ),
        backgroundColor: Color(0xFF0D3B66),
      ),
    );
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
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
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
            onChanged: onChanged,
            obscureText: false,
            keyboardType: keyboardType,
            maxLines: maxLines,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
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

  Widget _buildSearchableField({
    required String label,
    required String hintText,
    required String? value,
    required bool enabled,
    required ValueChanged<String> onSelected,
    required List<String> items,
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
          GestureDetector(
            onTap: enabled
                ? () => _showSearchableBottomSheet(
                      title: hintText,
                      items: items,
                      onSelected: onSelected,
                      selectedValue: value,
                    )
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                    color: enabled
                        ? const Color(0xFFA0AEC0)
                        : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? hintText,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: value != null
                            ? const Color(0xFF1A202C)
                            : const Color(0xFF718096),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF718096)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSearchableBottomSheet({
    required String title,
    required List<String> items,
    required ValueChanged<String> onSelected,
    String? selectedValue,
  }) async {
    final selected = await showGeoSelectionBottomSheet(
      context: context,
      title: title,
      options: items,
      selectedValue: selectedValue,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
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
            hintText: 'Nombre',
            textCapitalization: TextCapitalization.words),
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
            onTap: _registeredBirthday == null
                ? _pickBirthday
                : _showBirthdayLockedMessage,
            suffixIcon: Icon(
                _registeredBirthday == null
                    ? Icons.calendar_today_outlined
                    : Icons.lock_outline,
                size: 18,
                color: const Color(0xFF718096))),
        _buildSearchableField(
            label: 'País / nacionalidad',
            hintText: 'Selecciona tu país',
            value: _countryOptions.contains(_countryController?.text.trim())
                ? _countryController?.text.trim()
                : null,
            enabled: _countryOptions.isNotEmpty,
            onSelected: (value) {
              final country = normalizeCountryName(value);
              setState(() => _applySelectedCountryByName(country));
              _loadStates(country);
            },
            items: _countryOptions),
        _buildSearchableField(
            label: 'Estado / provincia',
            hintText: _isStatesLoading
                ? 'Cargando estados...'
                : 'Selecciona tu estado',
            value: _states.contains(_selectedState) ? _selectedState : null,
            enabled: !_isStatesLoading && _states.isNotEmpty,
            onSelected: (value) {
              setState(() {
                _selectedState = value;
                _stateController?.text = value;
                _isCitiesLoading = true;
              });
              final country = normalizeCountryName(_countryController?.text);
              if (country.isNotEmpty && value.isNotEmpty) {
                _loadCitiesByState(country, value);
              }
            },
            items: _states),
        if (_selectedState != null && _selectedState!.isNotEmpty)
          _buildSearchableField(
              label: 'Ciudad',
              hintText: _isCitiesLoading
                  ? 'Cargando ciudades...'
                  : 'Selecciona tu ciudad',
              value: _cities.contains(_selectedCity) ? _selectedCity : null,
              enabled: !_isCitiesLoading && _cities.isNotEmpty,
              onSelected: (value) {
                setState(() {
                  _selectedCity = value;
                  _cityController?.text = value;
                });
              },
              items: _cities),
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
        _buildDropdownField(
            label: 'Categoría',
            hintText: 'Selecciona tu categoría',
            value: canonicalPlayerCategories
                    .contains(_categoryController?.text.trim())
                ? _categoryController?.text.trim()
                : null,
            onChanged: (value) {
              setState(() => _categoryController?.text = value ?? '');
            },
            options: canonicalPlayerCategories),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              LengthLimitingTextInputFormatter(6),
            ]),
        _buildTextField(
            label: 'Peso (kg)',
            controller: _weightController,
            focusNode: null,
            hintText: '75',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              LengthLimitingTextInputFormatter(6),
            ]),
        _buildTextField(
            label: 'Años de experiencia',
            controller: _experienceController,
            focusNode: null,
            hintText: '6',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ]),
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
            hintText: 'Nombre',
            textCapitalization: TextCapitalization.words),
        _buildTextField(
            label: 'Nombre de usuario',
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            hintText: 'usuario',
            textCapitalization: TextCapitalization.none),
        _buildSearchableField(
            label: 'País',
            hintText: 'Selecciona tu país',
            value: _countryOptions.contains(_countryController?.text.trim())
                ? _countryController?.text.trim()
                : null,
            enabled: _countryOptions.isNotEmpty,
            onSelected: (value) {
              final country = normalizeCountryName(value);
              setState(() => _applySelectedCountryByName(country));
              _loadStates(country);
            },
            items: _countryOptions),
        _buildSearchableField(
            label: 'Estado / provincia',
            hintText: _isStatesLoading
                ? 'Cargando estados...'
                : 'Selecciona tu estado',
            value: _states.contains(_selectedState) ? _selectedState : null,
            enabled: !_isStatesLoading && _states.isNotEmpty,
            onSelected: (value) {
              setState(() {
                _selectedState = value;
                _stateController?.text = value;
                _isCitiesLoading = true;
              });
              final country = normalizeCountryName(_countryController?.text);
              if (country.isNotEmpty && value.isNotEmpty) {
                _loadCitiesByState(country, value);
              }
            },
            items: _states),
        if (_selectedState != null && _selectedState!.isNotEmpty)
          _buildSearchableField(
              label: 'Ciudad',
              hintText: _isCitiesLoading
                  ? 'Cargando ciudades...'
                  : 'Selecciona tu ciudad',
              value: _cities.contains(_selectedCity) ? _selectedCity : null,
              enabled: !_isCitiesLoading && _cities.isNotEmpty,
              onSelected: (value) {
                setState(() {
                  _selectedCity = value;
                  _cityController?.text = value;
                });
              },
              items: _cities),
        _buildTextField(
            label: 'Fecha de nacimiento',
            controller: _birthdayController,
            focusNode: null,
            hintText: 'YYYY-MM-DD',
            readOnly: true,
            onTap: _registeredBirthday == null
                ? _pickBirthday
                : _showBirthdayLockedMessage,
            suffixIcon: Icon(
                _registeredBirthday == null
                    ? Icons.calendar_today_outlined
                    : Icons.lock_outline,
                size: 18,
                color: const Color(0xFF718096))),
        _buildSectionTitle(
          'Perfil profesional',
          subtitle: 'Completá tus datos de contacto y tu enfoque de scouting.',
        ),
        _buildDropdownField(
            label: 'Tipo de perfil profesional',
            hintText: 'Selecciona una opción',
            value: _selectedOrganizationType,
            onChanged: (value) {
              setState(() => _selectedOrganizationType = value);
            },
            options: _organizationTypeOptions),
        _buildTextField(
            label: 'Rol actual',
            controller: _currentRoleController,
            focusNode: null,
            hintText: 'Scout senior, analista de talento...'),
        _buildTextField(
            label: 'Club / organización',
            controller: _clubController,
            focusNode: null,
            hintText: 'Rede Iberica de Scouts'),
        _buildTextField(
            label: 'Zona de trabajo',
            controller: _workZoneController,
            focusNode: null,
            hintText: 'Buenos Aires, LATAM, España norte...'),
        _buildTextField(
            label: 'Teléfono',
            controller: _phoneController,
            focusNode: null,
            hintText: '+351910000201',
            keyboardType: TextInputType.phone,
            textCapitalization: TextCapitalization.none,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s()\-]')),
            ]),
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
        _buildTextField(
            label: 'Categorías de interés',
            controller: _interestCategoriesController,
            focusNode: null,
            hintText: 'Sub-15, Sub-17, Senior (separá por coma)',
            maxLines: 2),
        _buildTextField(
            label: 'Posiciones de interés',
            controller: _interestPositionsController,
            focusNode: null,
            hintText: 'Extremo, central, mediocentro (separá por coma)',
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
            _currentUserType == 'profesional'
                ? 'Editar Perfil Scout'
                : 'Editar Perfil',
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
                  child: SizedBox(
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
