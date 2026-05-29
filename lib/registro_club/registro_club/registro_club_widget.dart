import 'dart:async';

import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/fluxo_compartilhado/geo_selection_bottom_sheet.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'registro_club_model.dart';
export 'registro_club_model.dart';

class RegistroClubWidget extends StatefulWidget {
  const RegistroClubWidget({
    super.key,
    this.signupEmail,
    this.signupPassword,
  });

  final String? signupEmail;
  final String? signupPassword;

  static String routeName = 'registro_club';
  static String routePath = '/registro_club';

  @override
  State<RegistroClubWidget> createState() => _RegistroClubWidgetState();
}

class _RegistroClubWidgetState extends State<RegistroClubWidget> {
  late RegistroClubModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers Etapa 1
  final _clubNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  Uint8List? _logoBytes;
  String? _logoUrl;
  List<Map<String, dynamic>> _countries = [];
  String? _selectedCountryId;
  List<String> _states = [];
  List<String> _cities = [];
  String? _selectedState;
  String? _selectedCity;
  bool _isStatesLoading = false;
  bool _isCitiesLoading = false;
  bool _stateFreeText = false;
  bool _cityFreeText = false;
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

  // Controllers Etapa 2
  final _aboutClubController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _websiteController = TextEditingController();
  final _otherUrlController = TextEditingController();

  // Controllers Etapa 3
  final _linkStaffController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dniController = TextEditingController();
  final _leagueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RegistroClubModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    final signupEmail = widget.signupEmail?.trim() ?? '';
    if (signupEmail.isNotEmpty) {
      _emailController.text = signupEmail;
    }
    _phoneController.addListener(_handlePhoneInputChange);
    _loadCountries();
  }

  @override
  void dispose() {
    _model.dispose();
    _clubNameController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _aboutClubController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _websiteController.dispose();
    _otherUrlController.dispose();
    _linkStaffController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dniController.dispose();
    _leagueController.dispose();
    super.dispose();
  }

  // ============ LOGIC ============
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
      debugPrint('Erro ao carregar países: $e');
    }
  }

  Future<void> _pickLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _logoBytes = bytes);
        _showSuccess('Logo seleccionado. Se subirá al finalizar.');
      }
    } catch (e) {
      _showError('Error al seleccionar imagen');
    }
  }

  Future<void> _uploadLogo(
    Uint8List bytes,
    String fileName, {
    String? ownerUid,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uid = ownerUid?.trim().isNotEmpty == true
          ? ownerUid!.trim()
          : currentUserUid.trim();
      final filePath = '${uid}_$timestamp.jpg';
      await SupaFlow.client.storage.from('logos clubs').uploadBinary(
          filePath, bytes,
          fileOptions: const FileOptions(
              cacheControl: '3600', upsert: true, contentType: 'image/jpeg'));
      final publicUrl =
          SupaFlow.client.storage.from('logos clubs').getPublicUrl(filePath);
      setState(() => _logoUrl = publicUrl);
      _showSuccess('Logo enviado con éxito!');
    } catch (e) {
      _showError('Error al subir el logo');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  Future<void> _abortIncompleteClubRegistration(Object error) async {
    FFAppState().authBlockMessage =
        'No se completó el registro del club. Crea la cuenta nuevamente.';
    FFAppState().registrationFlowActive = false;
    try {
      await authManager.signOut();
    } catch (signOutError) {
      debugPrint(
          'Error al cerrar sesión tras registro de club fallido: $signOutError');
    }
    if (!mounted) return;
    context.goNamed('login');
  }

  Future<String?> _ensureClubAuthAccount() async {
    final existingUid = currentUserUid.trim();
    if (existingUid.isNotEmpty) {
      FFAppState().registrationFlowActive = true;
      return existingUid;
    }

    final email = (widget.signupEmail?.trim().isNotEmpty ?? false)
        ? widget.signupEmail!.trim()
        : _emailController.text.trim();
    final password = widget.signupPassword ?? '';

    if (email.isEmpty || password.isEmpty) {
      FFAppState().registrationFlowActive = false;
      _showError(
        'Datos de acceso incompletos. Vuelve al inicio del registro.',
      );
      return null;
    }

    FFAppState().registrationFlowActive = true;
    GoRouter.of(context).prepareAuthEvent();
    final user = await authManager.createAccountWithEmail(
      context,
      email,
      password,
    );
    final uid = (user?.uid ?? '').trim();
    if (uid.isEmpty) {
      FFAppState().registrationFlowActive = false;
      _showError('No se pudo crear la cuenta. Intenta nuevamente.');
      return null;
    }
    return uid;
  }

  bool _validateStep1() {
    if (_clubNameController.text.trim().isEmpty) {
      _showError('Por favor, ingresa el nombre del club');
      return false;
    }
    if (_countryController.text.trim().isEmpty && _selectedCountryId == null) {
      _showError('Por favor, selecciona el país');
      return false;
    }
    if (_cityController.text.trim().isEmpty) {
      _showError('Por favor, ingresa la ciudad');
      return false;
    }
    if (_states.isNotEmpty &&
        !_stateFreeText &&
        _selectedState != '__all__' &&
        (_selectedState == null || _selectedState!.trim().isEmpty)) {
      _showError('Por favor, selecciona el estado/provincia');
      return false;
    }
    if (_stateFreeText &&
        _stateController.text.trim().isEmpty &&
        _selectedState != '__all__') {
      _showError('Por favor, ingresa el estado/provincia');
      return false;
    }
    return true;
  }

  String _toApiCountryName(String name) {
    final input = name.trim();
    final map = <String, String>{
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
      'Escocia': 'Scotland',
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
      'Emiratos Arabes': 'United Arab Emirates',
    };
    return map[input] ?? input;
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
    'México': [
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
    'Perú': [
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
    'España': [
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
    'Panamá': [
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
    'República Dominicana': [
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
      'Moca',
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
  };

  static const Map<String, List<String>> _hardcodedCities = {
    // Nicaragua
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
      'Muelle de los Bueyes',
      'Desembocadura del Río Grande'
    ],
    // Argentina
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
      'Mar del Plata',
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
    'Argentina|Salta': [
      'Salta',
      'Tartagal',
      'Orán',
      'Metán',
      'General Güemes',
      'Rosario de la Frontera'
    ],
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
      'Villa Ángela',
      'Quitilipi'
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
      'Termas de Río Hondo',
      'Añatuya'
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
      'Cutral-Có',
      'Centenario'
    ],
    'Argentina|Río Negro': [
      'Viedma',
      'General Roca',
      'San Carlos de Bariloche',
      'Cipolletti',
      'El Bolsón'
    ],
    'Argentina|La Rioja': ['La Rioja', 'Chilecito', 'Aimogasta'],
    'Argentina|San Luis': ['San Luis', 'Villa Mercedes', 'Merlo'],
    'Argentina|Catamarca': [
      'San Fernando del Valle de Catamarca',
      'Andalgalá',
      'Belén',
      'Santa María'
    ],
    'Argentina|La Pampa': ['Santa Rosa', 'General Pico', 'Realicó'],
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
      'Las Heras',
      'Puerto Deseado'
    ],
    'Argentina|Tierra del Fuego': ['Ushuaia', 'Río Grande', 'Tolhuin'],
    'Argentina|Formosa': ['Formosa', 'Clorinda', 'Pirané'],
    // Brazil
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
      'Carapicuíba',
      'Piracicaba',
      'Bauru',
      'São José do Rio Preto',
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
      'São João de Meriti',
      'Campos dos Goytacazes',
      'Petrópolis',
      'Volta Redonda',
      'Macaé',
      'Itaboraí'
    ],
    'Brazil|Minas Gerais': [
      'Belo Horizonte',
      'Uberlândia',
      'Contagem',
      'Juiz de Fora',
      'Betim',
      'Montes Claros',
      'Ribeirão das Neves',
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
      'Lauro de Freitas',
      'Itabuna'
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
      'Viamão',
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
      'Colombo',
      'Guarapuava'
    ],
    'Brazil|Santa Catarina': [
      'Florianópolis',
      'Joinville',
      'Blumenau',
      'São José',
      'Chapecó',
      'Criciúma',
      'Itajaí',
      'Jaraguá do Sul',
      'Palhoça'
    ],
    'Brazil|Pernambuco': [
      'Recife',
      'Caruaru',
      'Olinda',
      'Paulista',
      'Petrolina',
      'Jaboatão dos Guararapes',
      'Caruaru',
      'Camaragibe'
    ],
    'Brazil|Ceará': [
      'Fortaleza',
      'Juazeiro do Norte',
      'Caucaia',
      'Maracanaú',
      'Sobral',
      'Crato',
      'Itapipoca'
    ],
    'Brazil|Goiás': [
      'Goiânia',
      'Aparecida de Goiânia',
      'Anápolis',
      'Rio Verde',
      'Luziânia',
      'Águas Lindas de Goiás'
    ],
    'Brazil|Amazonas': [
      'Manaus',
      'Parintins',
      'Itacoatiara',
      'Manacapuru',
      'Coari'
    ],
    'Brazil|Pará': [
      'Belém',
      'Ananindeua',
      'Santarém',
      'Marabá',
      'Castanhal',
      'Parauapebas'
    ],
    'Brazil|Maranhão': [
      'São Luís',
      'Imperatriz',
      'São José de Ribamar',
      'Timon',
      'Caxias'
    ],
    'Brazil|Mato Grosso do Sul': [
      'Campo Grande',
      'Dourados',
      'Três Lagoas',
      'Corumbá',
      'Ponta Porã'
    ],
    'Brazil|Mato Grosso': [
      'Cuiabá',
      'Várzea Grande',
      'Rondonópolis',
      'Sinop',
      'Cáceres'
    ],
    'Brazil|Espírito Santo': [
      'Vitória',
      'Serra',
      'Vila Velha',
      'Cariacica',
      'Cachoeiro de Itapemirim'
    ],
    'Brazil|Alagoas': [
      'Maceió',
      'Arapiraca',
      'Palmeira dos Índios',
      'União dos Palmares'
    ],
    'Brazil|Piauí': ['Teresina', 'Parnaíba', 'Picos', 'Floriano'],
    'Brazil|Rio Grande do Norte': ['Natal', 'Mossoró', 'Parnamirim', 'Caicó'],
    'Brazil|Paraíba': ['João Pessoa', 'Campina Grande', 'Santa Rita', 'Patos'],
    'Brazil|Sergipe': [
      'Aracaju',
      'Nossa Senhora do Socorro',
      'Lagarto',
      'Itabaiana'
    ],
    'Brazil|Rondônia': ['Porto Velho', 'Ji-Paraná', 'Ariquemes', 'Vilhena'],
    'Brazil|Tocantins': ['Palmas', 'Araguaína', 'Gurupi'],
    'Brazil|Amapá': ['Macapá', 'Santana'],
    'Brazil|Roraima': ['Boa Vista'],
    'Brazil|Acre': ['Rio Branco', 'Cruzeiro do Sul'],
    'Brazil|Distrito Federal': [
      'Brasília',
      'Ceilândia',
      'Taguatinga',
      'Samambaia',
      'Planaltina'
    ],
    // Mexico (API name)
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
      'Milpa Alta',
      'Tláhuac',
      'Tlalpan',
      'Venustiano Carranza',
      'Xochimilco'
    ],
    'Mexico|Jalisco': [
      'Guadalajara',
      'Zapopan',
      'Tlaquepaque',
      'Tonalá',
      'Tlajomulco de Zúñiga',
      'Puerto Vallarta',
      'Lagos de Moreno',
      'Tepatitlán de Morelos'
    ],
    'Mexico|Nuevo León': [
      'Monterrey',
      'Guadalupe',
      'Apodaca',
      'San Nicolás de los Garza',
      'Escobedo',
      'Santa Catarina',
      'San Pedro Garza García',
      'Linares'
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
      'Tultitlán',
      'Cuautitlán Izcalli'
    ],
    'Mexico|Veracruz': [
      'Veracruz',
      'Xalapa',
      'Boca del Río',
      'Coatzacoalcos',
      'Córdoba',
      'Orizaba',
      'Poza Rica',
      'Tuxpan'
    ],
    'Mexico|Puebla': [
      'Puebla',
      'Tehuacán',
      'Atlixco',
      'Cholula',
      'Cuautlancingo'
    ],
    'Mexico|Guanajuato': [
      'León',
      'Irapuato',
      'Celaya',
      'Salamanca',
      'Guanajuato',
      'Silao',
      'San Luis de la Paz'
    ],
    'Mexico|Chihuahua': [
      'Ciudad Juárez',
      'Chihuahua',
      'Delicias',
      'Cuauhtémoc',
      'Parral'
    ],
    'Mexico|Coahuila': [
      'Torreón',
      'Saltillo',
      'Monclova',
      'Piedras Negras',
      'Acuña'
    ],
    'Mexico|Tamaulipas': [
      'Reynosa',
      'Matamoros',
      'Nuevo Laredo',
      'Tampico',
      'Cd. Victoria'
    ],
    'Mexico|Sonora': [
      'Hermosillo',
      'Ciudad Obregón',
      'Nogales',
      'Guaymas',
      'San Luis Río Colorado'
    ],
    'Mexico|Sinaloa': ['Culiacán', 'Mazatlán', 'Ahome (Los Mochis)', 'Guasave'],
    'Mexico|Baja California': [
      'Tijuana',
      'Mexicali',
      'Ensenada',
      'Tecate',
      'Rosarito'
    ],
    'Mexico|Michoacán': [
      'Morelia',
      'Uruapan',
      'Zamora',
      'Lázaro Cárdenas',
      'Apatzingán'
    ],
    'Mexico|Oaxaca': [
      'Oaxaca de Juárez',
      'Juchitán de Zaragoza',
      'Salina Cruz',
      'Tuxtepec'
    ],
    'Mexico|Chiapas': [
      'Tuxtla Gutiérrez',
      'San Cristóbal de las Casas',
      'Tapachula',
      'Comitán'
    ],
    'Mexico|Guerrero': [
      'Acapulco',
      'Chilpancingo',
      'Iguala',
      'Taxco',
      'Zihuatanejo'
    ],
    'Mexico|Hidalgo': ['Pachuca', 'Tulancingo', 'Tizayuca', 'Tula de Allende'],
    'Mexico|Querétaro': ['Querétaro', 'San Juan del Río', 'El Marqués'],
    'Mexico|Yucatán': ['Mérida', 'Valladolid', 'Tizimín', 'Progreso'],
    // Colombia
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
    'Colombia|Atlántico': [
      'Barranquilla',
      'Soledad',
      'Malambo',
      'Sabanalarga',
      'Baranoa'
    ],
    'Colombia|Bolívar': [
      'Cartagena',
      'Magangué',
      'El Carmen de Bolívar',
      'Turbaco',
      'Mompós'
    ],
    'Colombia|Santander': [
      'Bucaramanga',
      'Floridablanca',
      'Girón',
      'Piedecuesta',
      'Barrancabermeja',
      'Socorro'
    ],
    'Colombia|Cundinamarca': [
      'Soacha',
      'Fusagasugá',
      'Zipaquirá',
      'Chía',
      'Mosquera',
      'Facatativá',
      'Madrid',
      'Funza'
    ],
    'Colombia|Norte de Santander': [
      'Cúcuta',
      'Ocaña',
      'Pamplona',
      'Villa del Rosario',
      'Los Patios'
    ],
    'Colombia|Córdoba': [
      'Montería',
      'Cereté',
      'Sahagún',
      'Lorica',
      'Montelíbano'
    ],
    'Colombia|Tolima': ['Ibagué', 'Espinal', 'Melgar', 'El Guamo', 'Honda'],
    'Colombia|Nariño': ['Pasto', 'Tumaco', 'Ipiales', 'Túquerres'],
    'Colombia|Huila': ['Neiva', 'Pitalito', 'Garzón', 'La Plata'],
    'Colombia|Magdalena': [
      'Santa Marta',
      'Ciénaga',
      'El Banco',
      'Fundación',
      'Plato'
    ],
    'Colombia|Caldas': [
      'Manizales',
      'Villamaría',
      'La Dorada',
      'Chinchiná',
      'Riosucio'
    ],
    'Colombia|Risaralda': [
      'Pereira',
      'Dosquebradas',
      'Santa Rosa de Cabal',
      'La Virginia'
    ],
    'Colombia|Quindío': ['Armenia', 'Calarcá', 'Montenegro', 'Quimbaya'],
    'Colombia|Meta': ['Villavicencio', 'Granada', 'Acacías', 'Puerto López'],
    'Colombia|Cauca': [
      'Popayán',
      'Santander de Quilichao',
      'Puerto Tejada',
      'Guapi'
    ],
    'Colombia|Sucre': ['Sincelejo', 'Corozal', 'Sampués', 'Tolú'],
    'Colombia|Cesar': [
      'Valledupar',
      'Aguachica',
      'Bosconia',
      'La Paz',
      'Codazzi'
    ],
    'Colombia|La Guajira': ['Riohacha', 'Maicao', 'Uribia', 'Manaure'],
    'Colombia|Boyacá': [
      'Tunja',
      'Duitama',
      'Sogamoso',
      'Chiquinquirá',
      'Nobsa'
    ],
    // Venezuela
    'Venezuela|Distrito Capital': ['Caracas'],
    'Venezuela|Miranda': [
      'Los Teques',
      'Guarenas',
      'Guatire',
      'Ocumare del Tuy',
      'Santa Teresa del Tuy',
      'Charallave',
      'Cúa'
    ],
    'Venezuela|Carabobo': [
      'Valencia',
      'Puerto Cabello',
      'Guacara',
      'San Diego',
      'Los Guayos',
      'Naguanagua',
      'Mariara'
    ],
    'Venezuela|Aragua': [
      'Maracay',
      'Turmero',
      'La Victoria',
      'Cagua',
      'El Limón',
      'Villa de Cura'
    ],
    'Venezuela|Lara': [
      'Barquisimeto',
      'Carora',
      'El Tocuyo',
      'Quibor',
      'Chivacoa'
    ],
    'Venezuela|Zulia': [
      'Maracaibo',
      'Cabimas',
      'Ciudad Ojeda',
      'San Francisco',
      'Lagunillas',
      'Punto Fijo (Falcón)',
      'Machiques'
    ],
    'Venezuela|Bolívar': [
      'Ciudad Bolívar',
      'Ciudad Guayana',
      'San Félix',
      'Puerto Ordaz',
      'Upata',
      'Caicara del Orinoco'
    ],
    'Venezuela|Anzoátegui': [
      'Barcelona',
      'Lecherías',
      'El Tigre',
      'Puerto La Cruz',
      'Anaco',
      'Guanta'
    ],
    'Venezuela|Sucre': ['Cumaná', 'Carúpano', 'Güiria', 'Maturín'],
    'Venezuela|Táchira': [
      'San Cristóbal',
      'Táriba',
      'Rubio',
      'San Antonio del Táchira',
      'La Fría'
    ],
    'Venezuela|Mérida': ['Mérida', 'El Vigía', 'Tovar', 'Barinas'],
    'Venezuela|Monagas': ['Maturín', 'Caripito', 'Punta de Mata'],
    'Venezuela|Falcón': [
      'Coro',
      'Punto Fijo',
      'La Vela de Coro',
      'Chichiriviche'
    ],
    'Venezuela|Portuguesa': ['Guanare', 'Acarigua', 'Araure', 'Guanarito'],
    'Venezuela|Barinas': ['Barinas', 'Barinitas', 'Socopó'],
    'Venezuela|Guárico': [
      'San Juan de los Morros',
      'Calabozo',
      'Valle de la Pascua',
      'Zaraza'
    ],
    'Venezuela|Yaracuy': ['San Felipe', 'Chivacoa', 'Nirgua', 'Independencia'],
    'Venezuela|Cojedes': ['San Carlos', 'Tinaquillo', 'El Tinaco'],
    'Venezuela|Nueva Esparta': [
      'La Asunción',
      'Porlamar',
      'Pampatar',
      'Juangriego'
    ],
    // Chile
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
      'Pudahuel',
      'Estación Central'
    ],
    'Chile|Valparaíso': [
      'Valparaíso',
      'Viña del Mar',
      'Quilpué',
      'San Antonio',
      'Villa Alemana',
      'Quillota',
      'Los Andes',
      'Rancagua'
    ],
    'Chile|Biobío': [
      'Concepción',
      'Talcahuano',
      'San Pedro de la Paz',
      'Hualpén',
      'Chillán',
      'Los Ángeles',
      'Coronel',
      'Lota'
    ],
    'Chile|La Araucanía': [
      'Temuco',
      'Padre Las Casas',
      'Villarrica',
      'Angol',
      'Pucon'
    ],
    'Chile|Los Lagos': ['Puerto Montt', 'Osorno', 'Castro', 'Puerto Varas'],
    'Chile|Antofagasta': ['Antofagasta', 'Calama', 'Tocopilla', 'Mejillones'],
    'Chile|Atacama': ['Copiapó', 'Vallenar', 'Caldera'],
    'Chile|Coquimbo': ['La Serena', 'Coquimbo', 'Ovalle', 'Illapel'],
    'Chile|O\'Higgins': ['Rancagua', 'San Fernando', 'Pichilemu', 'Graneros'],
    'Chile|Maule': ['Talca', 'Curicó', 'Linares', 'Constitución'],
    'Chile|Los Ríos': ['Valdivia', 'La Unión', 'Río Bueno'],
    'Chile|Tarapacá': ['Iquique', 'Alto Hospicio'],
    'Chile|Arica y Parinacota': ['Arica', 'Putre'],
    'Chile|Aysén': ['Coyhaique', 'Puerto Aysén'],
    'Chile|Magallanes': ['Punta Arenas', 'Puerto Natales', 'Puerto Williams'],
    // Peru
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
      'San Juan de Miraflores',
      'Villa María del Triunfo',
      'Carabayllo',
      'Chorrillos',
      'Independencia',
      'El Agustino'
    ],
    'Peru|Arequipa': [
      'Arequipa',
      'Cayma',
      'Cerro Colorado',
      'Socabaya',
      'Paucarpata',
      'Yanahuara'
    ],
    'Peru|La Libertad': [
      'Trujillo',
      'Chimbote',
      'Huanchaco',
      'El Porvenir',
      'La Esperanza',
      'Florencia de Mora'
    ],
    'Peru|Piura': [
      'Piura',
      'Sullana',
      'Castilla',
      'Talara',
      'Paita',
      'Chulucanas'
    ],
    'Peru|Cusco': ['Cusco', 'San Sebastián', 'Wanchaq', 'Santiago', 'Sicuani'],
    'Peru|Junín': ['Huancayo', 'El Tambo', 'Chilca', 'Satipo', 'Tarma'],
    'Peru|Áncash': ['Huaraz', 'Chimbote', 'Nuevo Chimbote', 'Huari'],
    'Peru|Lambayeque': [
      'Chiclayo',
      'José Leonardo Ortiz',
      'La Victoria',
      'Ferreñafe',
      'Lambayeque'
    ],
    'Peru|Ica': ['Ica', 'Chincha Alta', 'Pisco', 'Nazca'],
    'Peru|Loreto': ['Iquitos', 'Yurimaguas', 'Nauta'],
    'Peru|Puno': ['Puno', 'Juliaca', 'Ilave', 'Ayaviri'],
    'Peru|Cajamarca': ['Cajamarca', 'Jaén', 'Chota'],
    'Peru|San Martín': ['Tarapoto', 'Moyobamba', 'Juanjuí'],
    'Peru|Ucayali': ['Pucallpa', 'Aguaytía'],
    'Peru|Huánuco': ['Huánuco', 'Leoncio Prado', 'Tingo María'],
    'Peru|Madre de Dios': ['Puerto Maldonado'],
    'Peru|Ayacucho': ['Ayacucho', 'Huamanga'],
    'Peru|Apurímac': ['Abancay', 'Andahuaylalas'],
    'Peru|Pasco': ['Cerro de Pasco', 'Yanacancha'],
    'Peru|Moquegua': ['Moquegua', 'Ilo'],
    'Peru|Tacna': ['Tacna', 'Ciudad Nueva'],
    'Peru|Tumbes': ['Tumbes', 'Aguas Verdes'],
    // Ecuador
    'Ecuador|Pichincha': [
      'Quito',
      'Cayambe',
      'Sangolquí',
      'Machachi',
      'Santo Domingo'
    ],
    'Ecuador|Guayas': [
      'Guayaquil',
      'Durán',
      'Milagro',
      'Samborondón',
      'Playas',
      'Daule'
    ],
    'Ecuador|Azuay': ['Cuenca', 'Gualaceo', 'Paute', 'Sígsig'],
    'Ecuador|Manabí': [
      'Portoviejo',
      'Manta',
      'Chone',
      'El Carmen',
      'Bahía de Caráquez'
    ],
    'Ecuador|El Oro': ['Machala', 'Pasaje', 'Santa Rosa', 'Huaquillas'],
    'Ecuador|Los Ríos': ['Quevedo', 'Babahoyo', 'Vinces', 'Ventanas'],
    'Ecuador|Tungurahua': ['Ambato', 'Baños', 'Pelileo', 'Píllaro'],
    'Ecuador|Chimborazo': ['Riobamba', 'Guano', 'Alausí'],
    'Ecuador|Imbabura': ['Ibarra', 'Otavalo', 'Cotacachi', 'Antonio Ante'],
    'Ecuador|Esmeraldas': ['Esmeraldas', 'Atacames', 'Quinindé'],
    'Ecuador|Loja': ['Loja', 'Catamayo', 'Cariamanga'],
    'Ecuador|Cotopaxi': ['Latacunga', 'La Maná', 'Salcedo'],
    'Ecuador|Carchi': ['Tulcán', 'Montúfar'],
    'Ecuador|Bolívar': ['Guaranda', 'San Miguel'],
    'Ecuador|Santo Domingo de los Tsáchilas': ['Santo Domingo'],
    'Ecuador|Santa Elena': ['Santa Elena', 'La Libertad', 'Salinas'],
    'Ecuador|Sucumbíos': ['Nueva Loja (Lago Agrio)', 'Shushufindi'],
    'Ecuador|Orellana': ['Puerto Francisco de Orellana', 'Loreto'],
    'Ecuador|Galápagos': ['Puerto Ayora', 'Puerto Baquerizo Moreno'],
    // Bolivia
    'Bolivia|La Paz': [
      'La Paz',
      'El Alto',
      'Viacha',
      'Achacachi',
      'Copacabana',
      'Caranavi'
    ],
    'Bolivia|Santa Cruz': [
      'Santa Cruz de la Sierra',
      'Montero',
      'Warnes',
      'Yapacaní',
      'Camiri',
      'Cotoca'
    ],
    'Bolivia|Cochabamba': [
      'Cochabamba',
      'Sacaba',
      'Quillacollo',
      'Tiquipaya',
      'Colcapirhua',
      'Punata'
    ],
    'Bolivia|Oruro': ['Oruro', 'Llallagua', 'Huanuni'],
    'Bolivia|Potosí': ['Potosí', 'Uyuni', 'Tupiza', 'Villazón'],
    'Bolivia|Chuquisaca': ['Sucre', 'Camargo', 'Monteagudo'],
    'Bolivia|Tarija': ['Tarija', 'Yacuiba', 'Bermejo', 'Entre Ríos'],
    'Bolivia|Beni': ['Trinidad', 'Riberalta', 'Guayaramerín'],
    'Bolivia|Pando': ['Cobija'],
    // Paraguay
    'Paraguay|Central': [
      'Luque',
      'San Lorenzo',
      'Capiatá',
      'Lambaré',
      'Fernando de la Mora',
      'Mariano Roque Alonso',
      'Ñemby',
      'Limpio',
      'Areguá'
    ],
    'Paraguay|Asunción': ['Asunción'],
    'Paraguay|Alto Paraná': [
      'Ciudad del Este',
      'Presidente Franco',
      'Hernandarias',
      'Minga Guazú'
    ],
    'Paraguay|Itapúa': ['Encarnación', 'Fram', 'Coronel Bogado'],
    'Paraguay|Caaguazú': ['Coronel Oviedo', 'Caaguazú', 'Vaquería'],
    'Paraguay|Guairá': ['Villarrica', 'Coronel Martínez', 'Borja'],
    'Paraguay|Paraguarí': ['Paraguarí', 'Carapeguá', 'Yaguarón'],
    'Paraguay|Misiones': [
      'San Juan Bautista',
      'San Ignacio',
      'Santa María de Fe'
    ],
    'Paraguay|Cordillera': ['Caacupé', 'Tobatí', 'San Bernardino'],
    'Paraguay|San Pedro': ['San Pedro del Ycuamandiyú', 'Lima'],
    'Paraguay|Concepción': ['Concepción', 'Horqueta'],
    'Paraguay|Amambay': ['Pedro Juan Caballero', 'Bella Vista'],
    'Paraguay|Alto Paraguay': ['Fuerte Olimpo', 'Carmelo Peralta'],
    'Paraguay|Boquerón': ['Filadelfia', 'Mariscal Estigarribia'],
    'Paraguay|Canindeyú': ['Salto del Guairá', 'Curuguaty'],
    'Paraguay|Caazapá': ['Caazapá', 'San Juan Nepomuceno'],
    'Paraguay|Presidente Hayes': ['Villa Hayes', 'Benjamín Aceval'],
    'Paraguay|Ñeembucú': ['Pilar', 'Paso de Patria'],
    // Uruguay
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
      'Santa Lucía',
      'Toledo'
    ],
    'Uruguay|Maldonado': [
      'Maldonado',
      'Punta del Este',
      'San Carlos',
      'Piriápolis'
    ],
    'Uruguay|Salto': ['Salto', 'Constitución'],
    'Uruguay|Paysandú': ['Paysandú', 'Quebracho'],
    'Uruguay|Rivera': ['Rivera', 'Tranqueras'],
    'Uruguay|Colonia': ['Colonia del Sacramento', 'Juan Lacaze', 'Carmelo'],
    'Uruguay|San José': ['San José de Mayo', 'Ciudad del Plata'],
    'Uruguay|Tacuarembó': ['Tacuarembó', 'Paso de los Toros'],
    'Uruguay|Durazno': ['Durazno', 'Carmen'],
    'Uruguay|Rocha': ['Rocha', 'La Paloma', 'Chuy'],
    'Uruguay|Soriano': ['Mercedes', 'Dolores'],
    'Uruguay|Florida': ['Florida', 'Sarandí Grande'],
    'Uruguay|Río Negro': ['Fray Bentos', 'Young'],
    'Uruguay|Artigas': ['Artigas', 'Tomás Gomensoro'],
    'Uruguay|Cerro Largo': ['Melo', 'Río Branco'],
    'Uruguay|Treinta y Tres': ['Treinta y Tres', 'Vergara'],
    'Uruguay|Lavalleja': ['Minas', 'Solís de Mataojo'],
    'Uruguay|Flores': ['Trinidad'],
    // Spain
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
      'Pozuelo de Alarcón',
      'Rivas-Vaciamadrid'
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
      'Sant Boi de Llobregat',
      'Rubí',
      'Castelldefels',
      'Gavà'
    ],
    'Spain|Valencia': [
      'Valencia',
      'Alicante',
      'Elche',
      'Torrent',
      'Mislata',
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
      'Utrera',
      'Mairena del Aljarafe'
    ],
    'Spain|Málaga': [
      'Málaga',
      'Marbella',
      'Fuengirola',
      'Torremolinos',
      'Vélez-Málaga',
      'Estepona'
    ],
    'Spain|Murcia': [
      'Murcia',
      'Cartagena',
      'Lorca',
      'Molina de Segura',
      'Alcantarilla'
    ],
    'Spain|Bilbao': ['Bilbao', 'Barakaldo', 'Getxo', 'Basauri'],
    'Spain|Vizcaya': ['Bilbao', 'Barakaldo', 'Getxo', 'Basauri', 'Portugalete'],
    'Spain|Guipúzcoa': ['San Sebastián', 'Irun', 'Errenteria', 'Zarautz'],
    'Spain|Zaragoza': [
      'Zaragoza',
      'Calatayud',
      'Utebo',
      'Ejea de los Caballeros'
    ],
    'Spain|Alicante': [
      'Alicante',
      'Elche',
      'Torrevieja',
      'Benidorm',
      'Orihuela'
    ],
    'Spain|Granada': ['Granada', 'Motril', 'Almuñécar', 'Guadix'],
    'Spain|Córdoba': ['Córdoba', 'Lucena', 'Cabra', 'Montoro'],
    'Spain|La Coruña': ['A Coruña', 'Santiago de Compostela', 'Ferrol', 'Lugo'],
    'Spain|Asturias': ['Oviedo', 'Gijón', 'Avilés', 'Mieres'],
    'Spain|Cantabria': ['Santander', 'Torrelavega', 'Camargo', 'Piélagos'],
    'Spain|Navarra': ['Pamplona', 'Tudela', 'Burlada', 'Barañáin'],
    'Spain|La Rioja': ['Logroño', 'Calahorra', 'Arnedo', 'Haro'],
    'Spain|Castilla y León (León)': [
      'León',
      'Ponferrada',
      'San Andrés del Rabanedo'
    ],
    'Spain|Castilla y León (Valladolid)': [
      'Valladolid',
      'Medina del Campo',
      'Aranda de Duero'
    ],
    'Spain|Castilla y León (Burgos)': ['Burgos', 'Miranda de Ebro'],
    'Spain|Castilla y León (Salamanca)': [
      'Salamanca',
      'Béjar',
      'Ciudad Rodrigo'
    ],
    'Spain|Castilla-La Mancha': [
      'Toledo',
      'Albacete',
      'Ciudad Real',
      'Cuenca',
      'Guadalajara',
      'Talavera de la Reina'
    ],
    'Spain|Extremadura': ['Badajoz', 'Cáceres', 'Mérida', 'Don Benito'],
    'Spain|Galicia': [
      'Vigo',
      'A Coruña',
      'Santiago de Compostela',
      'Ourense',
      'Lugo',
      'Pontevedra'
    ],
    'Spain|Pontevedra': [
      'Vigo',
      'Pontevedra',
      'Vilagarcía de Arousa',
      'Redondela'
    ],
    'Spain|Baleares': ['Palma', 'Ibiza', 'Maó', 'Manacor'],
    'Spain|Las Palmas': [
      'Las Palmas de Gran Canaria',
      'Telde',
      'Arrecife',
      'Puerto del Rosario'
    ],
    'Spain|Santa Cruz de Tenerife': [
      'Santa Cruz de Tenerife',
      'San Cristóbal de La Laguna',
      'Arona',
      'Adeje'
    ],
    // Portugal
    'Portugal|Lisboa': [
      'Lisboa',
      'Sintra',
      'Cascais',
      'Loures',
      'Odivelas',
      'Amadora',
      'Almada',
      'Setúbal',
      'Seixal',
      'Barreiro',
      'Montijo'
    ],
    'Portugal|Porto': [
      'Porto',
      'Vila Nova de Gaia',
      'Matosinhos',
      'Gondomar',
      'Maia',
      'Valongo',
      'Braga',
      'Guimarães'
    ],
    'Portugal|Braga': [
      'Braga',
      'Guimarães',
      'Barcelos',
      'Famalicão',
      'Vila Verde'
    ],
    'Portugal|Setúbal': ['Setúbal', 'Almada', 'Seixal', 'Barreiro', 'Sesimbra'],
    'Portugal|Aveiro': [
      'Aveiro',
      'Oliveira de Azeméis',
      'São João da Madeira',
      'Ovar',
      'Espinho'
    ],
    'Portugal|Faro': ['Faro', 'Loulé', 'Portimão', 'Lagos', 'Tavira', 'Olhão'],
    'Portugal|Coimbra': ['Coimbra', 'Figueira da Foz', 'Cantanhede', 'Lousã'],
    'Portugal|Leiria': [
      'Leiria',
      'Marinha Grande',
      'Caldas da Rainha',
      'Nazaré'
    ],
    'Portugal|Santarém': ['Santarém', 'Tomar', 'Torres Novas', 'Entroncamento'],
    'Portugal|Viseu': ['Viseu', 'Lamego', 'Mangualde'],
    'Portugal|Castelo Branco': ['Castelo Branco', 'Covilhã', 'Fundão'],
    'Portugal|Guarda': ['Guarda', 'Seia', 'Gouveia'],
    'Portugal|Viana do Castelo': [
      'Viana do Castelo',
      'Ponte de Lima',
      'Esposende'
    ],
    'Portugal|Vila Real': ['Vila Real', 'Chaves', 'Peso da Régua'],
    'Portugal|Bragança': ['Bragança', 'Mirandela', 'Macedo de Cavaleiros'],
    'Portugal|Évora': ['Évora', 'Estremoz', 'Reguengos de Monsaraz'],
    'Portugal|Portalegre': ['Portalegre', 'Elvas', 'Ponte de Sor'],
    'Portugal|Beja': ['Beja', 'Moura', 'Serpa'],
    'Portugal|Açores': ['Ponta Delgada', 'Angra do Heroísmo', 'Horta'],
    'Portugal|Madeira': ['Funchal', 'Câmara de Lobos', 'São Vicente'],
    // Costa Rica
    'Costa Rica|San José': [
      'San José',
      'Desamparados',
      'Alajuelita',
      'Aserrí',
      'Curridabat',
      'Tibás',
      'Goicoechea',
      'Moravia',
      'Escazú',
      'Santa Ana'
    ],
    'Costa Rica|Alajuela': [
      'Alajuela',
      'San Carlos',
      'Grecia',
      'Atenas',
      'Naranjo',
      'Palmares',
      'Poás',
      'Upala'
    ],
    'Costa Rica|Cartago': [
      'Cartago',
      'El Guarco',
      'La Unión',
      'Turrialba',
      'Oreamuno',
      'Paraíso'
    ],
    'Costa Rica|Heredia': [
      'Heredia',
      'San Rafael',
      'Santa Bárbara',
      'Belén',
      'Flores',
      'San Isidro',
      'Sarapiquí'
    ],
    'Costa Rica|Guanacaste': [
      'Liberia',
      'Nicoya',
      'Santa Cruz',
      'Cañas',
      'Bagaces',
      'Carrillo',
      'La Cruz'
    ],
    'Costa Rica|Puntarenas': [
      'Puntarenas',
      'Quepos',
      'Golfito',
      'Osa',
      'Aguirre'
    ],
    'Costa Rica|Limón': [
      'Limón',
      'Pococí',
      'Siquirres',
      'Talamanca',
      'Matina',
      'Guácimo'
    ],
    // Guatemala
    'Guatemala|Guatemala': [
      'Guatemala City',
      'Mixco',
      'Villa Nueva',
      'San Juan Sacatepéquez',
      'Chinautla',
      'Petapa',
      'Villa Canales'
    ],
    'Guatemala|Quetzaltenango': [
      'Quetzaltenango',
      'Coatepeque',
      'San Marcos',
      'Huehuetenango'
    ],
    'Guatemala|Escuintla': ['Escuintla', 'Mazatenango', 'Puerto San José'],
    'Guatemala|Alta Verapaz': ['Cobán', 'Chisec', 'Panzós'],
    'Guatemala|Izabal': ['Puerto Barrios', 'Morales', 'Livingston'],
    'Guatemala|Suchitepéquez': ['Mazatenango', 'Cuyotenango', 'Retalhuleu'],
    'Guatemala|San Marcos': ['San Marcos', 'Quetzaltenango', 'Malacatán'],
    'Guatemala|Petén': ['Flores', 'Santa Elena', 'San Benito'],
    'Guatemala|Chimaltenango': [
      'Chimaltenango',
      'Tecpán',
      'San Martín Jilotepeque'
    ],
    'Guatemala|Sacatepéquez': [
      'Antigua Guatemala',
      'Jocotenango',
      'Ciudad Vieja'
    ],
    // Honduras
    'Honduras|Francisco Morazán': [
      'Tegucigalpa',
      'Comayagüela',
      'San Pedro Sula',
      'Valle de Ángeles',
      'Santa Lucía'
    ],
    'Honduras|Cortés': [
      'San Pedro Sula',
      'Puerto Cortés',
      'Villanueva',
      'Choloma',
      'La Lima'
    ],
    'Honduras|Atlántida': ['La Ceiba', 'El Progreso', 'Tela', 'La Masica'],
    'Honduras|Yoro': ['Yoro', 'El Progreso', 'Santa Rita', 'Olanchito'],
    'Honduras|Santa Bárbara': ['Santa Bárbara', 'Santa Rosa de Copán'],
    'Honduras|Choluteca': ['Choluteca', 'El Triunfo'],
    'Honduras|Olancho': ['Juticalpa', 'Catacamas'],
    'Honduras|Colón': ['Trujillo', 'Tocoa', 'Sonaguera'],
    'Honduras|Copán': ['Santa Rosa de Copán', 'Copán Ruinas', 'La Entrada'],
    'Honduras|Comayagua': ['Comayagua', 'Siguatepeque'],
    'Honduras|El Paraíso': ['Danlí', 'El Paraíso', 'Yuscarán'],
    // El Salvador
    'El Salvador|San Salvador': [
      'San Salvador',
      'Soyapango',
      'Mejicanos',
      'Apopa',
      'Ciudad Delgado',
      'Santa Tecla',
      'Antiguo Cuscatlán',
      'Ilopango',
      'San Marcos',
      'San Martín'
    ],
    'El Salvador|Santa Ana': [
      'Santa Ana',
      'Ahuachapán',
      'Chalchuapa',
      'Coatepeque'
    ],
    'El Salvador|San Miguel': ['San Miguel', 'Ciudad Barrios', 'Usulután'],
    'El Salvador|La Libertad': [
      'Santa Tecla',
      'Antiguo Cuscatlán',
      'Quezaltepeque',
      'Zaragoza',
      'La Libertad'
    ],
    'El Salvador|Sonsonate': ['Sonsonate', 'Acajutla', 'Armenia', 'Izalco'],
    'El Salvador|Usulután': ['Usulután', 'Jiquilisco', 'San Francisco Javier'],
    'El Salvador|Cuscatlán': [
      'Cojutepeque',
      'Suchitoto',
      'San Pedro Perulapán'
    ],
    'El Salvador|Chalatenango': [
      'Chalatenango',
      'La Palma',
      'Nueva Concepción'
    ],
    'El Salvador|La Paz': ['Zacatecoluca', 'San Luis Talpa', 'Olocuilta'],
    'El Salvador|Cabañas': ['Sensuntepeque', 'Ilobasco'],
    'El Salvador|Morazán': ['San Francisco Gotera', 'Jocoaitique', 'Corinto'],
    'El Salvador|La Unión': ['La Unión', 'San Alejo', 'Conchagua'],
    'El Salvador|San Vicente': ['San Vicente', 'Tecoluca'],
    'El Salvador|Ahuachapán': [
      'Ahuachapán',
      'Atiquizaya',
      'Concepción de Ataco'
    ],
    // Panama
    'Panama|Panamá': [
      'Ciudad de Panamá',
      'San Miguelito',
      'Tocumen',
      'Panamá Oeste',
      'Arraiján',
      'La Chorrera'
    ],
    'Panama|Panamá Oeste': ['La Chorrera', 'Arraiján', 'Capira'],
    'Panama|Colón': ['Colón', 'Portobelo', 'Chagres'],
    'Panama|Chiriquí': ['David', 'Boquete', 'La Concepción', 'Changuinola'],
    'Panama|Coclé': ['Penonomé', 'La Pintada', 'Natá', 'Antón'],
    'Panama|Herrera': ['Chitré', 'Los Santos', 'Parita'],
    'Panama|Los Santos': ['Las Tablas', 'Chitré', 'Macaracas'],
    'Panama|Veraguas': ['Santiago', 'Las Palmas', 'Soná'],
    'Panama|Bocas del Toro': ['Bocas del Toro', 'Changuinola', 'Almirante'],
    'Panama|Darién': ['La Palma', 'Metetí'],
    // Dominican Republic (API name)
    'Dominican Republic|Distrito Nacional': ['Santo Domingo'],
    'Dominican Republic|Santo Domingo': [
      'Santo Domingo Este',
      'Santo Domingo Norte',
      'Santo Domingo Oeste',
      'Boca Chica',
      'San Antonio de Guerra'
    ],
    'Dominican Republic|Santiago': [
      'Santiago de los Caballeros',
      'San José de las Matas',
      'Moca',
      'Licey al Medio'
    ],
    'Dominican Republic|San Cristóbal': [
      'San Cristóbal',
      'Villa Altagracia',
      'Baní'
    ],
    'Dominican Republic|Puerto Plata': [
      'Puerto Plata',
      'Sosúa',
      'Cabarete',
      'Imbert'
    ],
    'Dominican Republic|La Altagracia': [
      'Higüey',
      'San Rafael del Yuma',
      'El Seibo'
    ],
    'Dominican Republic|La Romana': ['La Romana', 'San Pedro de Macorís'],
    'Dominican Republic|Duarte': ['San Francisco de Macorís', 'Tenares'],
    'Dominican Republic|Espaillat': ['Moca', 'Gaspar Hernández'],
    'Dominican Republic|La Vega': [
      'La Vega',
      'Jarabacoa',
      'Constanza',
      'Bonao'
    ],
    'Dominican Republic|Peravia': ['Baní', 'Nizao'],
    'Dominican Republic|San Pedro de Macorís': [
      'San Pedro de Macorís',
      'Hato Mayor'
    ],
    'Dominican Republic|Valverde': ['Mao', 'Esperanza'],
    // United States (partial)
    'United States|Florida': [
      'Miami',
      'Orlando',
      'Tampa',
      'Jacksonville',
      'St. Petersburg',
      'Hialeah',
      'Tallahassee',
      'Fort Lauderdale',
      'Cape Coral',
      'Pembroke Pines'
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
      'Bakersfield',
      'Anaheim'
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
      'Plano',
      'Laredo'
    ],
    'United States|New York': [
      'New York City',
      'Buffalo',
      'Rochester',
      'Yonkers',
      'Syracuse',
      'Albany',
      'New Rochelle',
      'Mount Vernon'
    ],
    'United States|Illinois': [
      'Chicago',
      'Aurora',
      'Naperville',
      'Joliet',
      'Rockford',
      'Springfield',
      'Elgin',
      'Peoria'
    ],
    'United States|Georgia': [
      'Atlanta',
      'Augusta',
      'Columbus',
      'Macon',
      'Savannah',
      'Athens'
    ],
    'United States|North Carolina': [
      'Charlotte',
      'Raleigh',
      'Greensboro',
      'Durham',
      'Winston-Salem',
      'Fayetteville'
    ],
    'United States|Arizona': [
      'Phoenix',
      'Tucson',
      'Mesa',
      'Chandler',
      'Scottsdale',
      'Glendale',
      'Gilbert',
      'Tempe'
    ],
    'United States|Nevada': [
      'Las Vegas',
      'Henderson',
      'Reno',
      'North Las Vegas',
      'Sparks'
    ],
    'United States|Washington': [
      'Seattle',
      'Spokane',
      'Tacoma',
      'Vancouver',
      'Bellevue',
      'Kirkland'
    ],
    'United States|Colorado': [
      'Denver',
      'Colorado Springs',
      'Aurora',
      'Fort Collins',
      'Lakewood',
      'Thornton',
      'Pueblo'
    ],
    'United States|New Jersey': [
      'Newark',
      'Jersey City',
      'Paterson',
      'Elizabeth',
      'Edison',
      'Woodbridge'
    ],
    // Italy
    'Italy|Lombardia': [
      'Milano',
      'Brescia',
      'Bergamo',
      'Monza',
      'Como',
      'Varese',
      'Pavia'
    ],
    'Italy|Lazio': ['Roma', 'Latina', 'Frosinone', 'Viterbo', 'Rieti'],
    'Italy|Campania': [
      'Napoli',
      'Salerno',
      'Torre del Greco',
      'Pozzuoli',
      'Caserta',
      'Benevento'
    ],
    'Italy|Sicilia': [
      'Palermo',
      'Catania',
      'Messina',
      'Siracusa',
      'Ragusa',
      'Agrigento',
      'Trapani'
    ],
    'Italy|Piemonte': [
      'Torino',
      'Novara',
      'Alessandria',
      'Asti',
      'Cuneo',
      'Biella'
    ],
    'Italy|Veneto': [
      'Venezia',
      'Verona',
      'Padova',
      'Vicenza',
      'Treviso',
      'Mestre'
    ],
    'Italy|Emilia-Romagna': [
      'Bologna',
      'Modena',
      'Reggio nell\'Emilia',
      'Parma',
      'Ferrara',
      'Ravenna',
      'Rimini'
    ],
    'Italy|Toscana': ['Firenze', 'Prato', 'Livorno', 'Pisa', 'Arezzo', 'Siena'],
    'Italy|Puglia': ['Bari', 'Taranto', 'Foggia', 'Lecce', 'Brindisi'],
    'Italy|Calabria': ['Reggio Calabria', 'Catanzaro', 'Cosenza', 'Crotone'],
    'Italy|Sardegna': ['Cagliari', 'Sassari', 'Nuoro', 'Oristano'],
    'Italy|Friuli-Venezia Giulia': ['Trieste', 'Udine', 'Pordenone', 'Gorizia'],
    'Italy|Trentino-Alto Adige': ['Trento', 'Bolzano', 'Rovereto'],
    'Italy|Marche': ['Ancona', 'Pesaro', 'Fano', 'Macerata'],
    'Italy|Liguria': ['Genova', 'La Spezia', 'Savona', 'Imperia'],
    'Italy|Abruzzo': ['L\'Aquila', 'Pescara', 'Chieti', 'Teramo'],
    'Italy|Basilicata': ['Potenza', 'Matera'],
    'Italy|Molise': ['Campobasso', 'Isernia'],
    'Italy|Umbria': ['Perugia', 'Terni'],
    'Italy|Valle d\'Aosta': ['Aosta'],
    // Germany
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
      'Münster',
      'Gelsenkirchen',
      'Aachen'
    ],
    'Germany|Bavaria': [
      'München',
      'Nürnberg',
      'Augsburg',
      'Würzburg',
      'Regensburg',
      'Ingolstadt',
      'Fürth',
      'Erlangen'
    ],
    'Germany|Baden-Württemberg': [
      'Stuttgart',
      'Mannheim',
      'Karlsruhe',
      'Freiburg im Breisgau',
      'Heidelberg',
      'Heilbronn',
      'Ulm'
    ],
    'Germany|Lower Saxony': [
      'Hannover',
      'Braunschweig',
      'Osnabrück',
      'Oldenburg',
      'Göttingen',
      'Wolfsburg'
    ],
    'Germany|Hesse': [
      'Frankfurt am Main',
      'Wiesbaden',
      'Kassel',
      'Darmstadt',
      'Offenbach am Main'
    ],
    'Germany|Saxony': ['Leipzig', 'Dresden', 'Chemnitz', 'Zwickau'],
    'Germany|Berlin': [
      'Berlin',
      'Mitte',
      'Kreuzberg',
      'Prenzlauer Berg',
      'Charlottenburg',
      'Neukölln'
    ],
    'Germany|Hamburg': ['Hamburg', 'Wandsbek', 'Altona', 'Harburg'],
    'Germany|Brandenburg': ['Potsdam', 'Cottbus', 'Brandenburg an der Havel'],
    'Germany|Saxony-Anhalt': ['Halle', 'Magdeburg', 'Dessau-Roßlau'],
    'Germany|Thuringia': ['Erfurt', 'Jena', 'Gera', 'Weimar'],
    'Germany|Rhineland-Palatinate': [
      'Mainz',
      'Ludwigshafen',
      'Koblenz',
      'Trier',
      'Kaiserslautern'
    ],
    'Germany|Saarland': ['Saarbrücken', 'Neunkirchen', 'Völklingen'],
    'Germany|Schleswig-Holstein': ['Kiel', 'Lübeck', 'Flensburg'],
    'Germany|Mecklenburg-Vorpommern': ['Rostock', 'Schwerin', 'Stralsund'],
    'Germany|Bremen': ['Bremen', 'Bremerhaven'],
    // France
    'France|Île-de-France': [
      'Paris',
      'Boulogne-Billancourt',
      'Saint-Denis',
      'Argenteuil',
      'Montreuil',
      'Nanterre',
      'Versailles',
      'Créteil',
      'Vitry-sur-Seine',
      'Colombes'
    ],
    'France|Auvergne-Rhône-Alpes': [
      'Lyon',
      'Grenoble',
      'Saint-Étienne',
      'Villeurbanne',
      'Clermont-Ferrand',
      'Annecy',
      'Chambéry'
    ],
    'France|Nouvelle-Aquitaine': [
      'Bordeaux',
      'Limoges',
      'Pau',
      'La Rochelle',
      'Poitiers',
      'Bayonne'
    ],
    'France|Occitanie': [
      'Toulouse',
      'Montpellier',
      'Nîmes',
      'Narbonne',
      'Perpignan',
      'Carcassonne'
    ],
    'France|Hauts-de-France': [
      'Lille',
      'Amiens',
      'Dunkerque',
      'Roubaix',
      'Tourcoing',
      'Valenciennes'
    ],
    'France|Grand Est': [
      'Strasbourg',
      'Reims',
      'Metz',
      'Nancy',
      'Mulhouse',
      'Colmar'
    ],
    'France|Provence-Alpes-Côte d\'Azur': [
      'Marseille',
      'Nice',
      'Toulon',
      'Aix-en-Provence',
      'Avignon',
      'Cannes',
      'Antibes'
    ],
    'France|Pays de la Loire': [
      'Nantes',
      'Le Mans',
      'Angers',
      'Saint-Nazaire',
      'Laval'
    ],
    'France|Bretagne': ['Rennes', 'Brest', 'Quimper', 'Lorient', 'Vannes'],
    'France|Normandie': ['Rouen', 'Caen', 'Le Havre', 'Cherbourg', 'Évreux'],
    'France|Centre-Val de Loire': [
      'Orléans',
      'Tours',
      'Bourges',
      'Blois',
      'Chartres'
    ],
    'France|Bourgogne-Franche-Comté': [
      'Dijon',
      'Besançon',
      'Belfort',
      'Chalon-sur-Saône'
    ],
    'France|Corse': ['Ajaccio', 'Bastia'],
    // United Kingdom
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
      'Leicester',
      'Southampton',
      'Oxford',
      'Cambridge',
      'Derby',
      'Brighton'
    ],
    'United Kingdom|Scotland': [
      'Glasgow',
      'Edinburgh',
      'Aberdeen',
      'Dundee',
      'Inverness',
      'Stirling'
    ],
    'United Kingdom|Wales': [
      'Cardiff',
      'Swansea',
      'Newport',
      'Bangor',
      'Wrexham'
    ],
    'United Kingdom|Northern Ireland': [
      'Belfast',
      'Londonderry',
      'Lisburn',
      'Armagh'
    ],
  };

  List<String> _getHardcodedCities(String apiCountryName, String stateName) {
    final key = '$apiCountryName|$stateName';
    return _hardcodedCities[key] ?? [];
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

  List<String> _getHardcodedStates(String apiCountryName) {
    return _hardcodedStates[apiCountryName] ?? [];
  }

  Future<void> _loadStates(String countryName) async {
    if (countryName.trim().isEmpty) return;
    final apiCountryName = _toApiCountryName(countryName.trim());

    setState(() {
      _isStatesLoading = true;
      _states = [];
      _selectedState = null;
      _stateController.text = '';
      _stateFreeText = false;
      _isCitiesLoading = false;
      _cities = [];
      _selectedCity = null;
      _cityController.text = '';
      _cityFreeText = false;
    });

    // Check hardcoded list first (instant, no network needed)
    final hardcoded = _getHardcodedStates(apiCountryName);
    if (hardcoded.isNotEmpty) {
      if (mounted) {
        setState(() {
          _states = hardcoded;
          _isStatesLoading = false;
        });
      }
      return;
    }

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
        if (data['error'] == false && data['data'] is Map) {
          final statesRaw = data['data']['states'];
          if (statesRaw is List) {
            final stateList = statesRaw
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return (item['name'] ?? '').toString().trim();
                  }
                  return item.toString().trim();
                })
                .where((item) => item.isNotEmpty)
                .toList()
              ..sort();
            if (mounted) {
              setState(() => _states = stateList);
            }
          }
        }
      }

      if (_states.isEmpty) {
        debugPrint(
            '_loadStates: sin estados de API para $apiCountryName, activando texto libre');
        if (mounted) {
          setState(() {
            _stateFreeText = true;
            _selectedState = '__all__';
          });
        }
        await _loadCitiesDirectly(apiCountryName);
      }
    } catch (e) {
      debugPrint('Error al cargar estados: $e');
      if (mounted) {
        setState(() {
          _stateFreeText = true;
          _selectedState = '__all__';
        });
      }
      await _loadCitiesDirectly(apiCountryName);
    } finally {
      if (mounted) {
        setState(() => _isStatesLoading = false);
      }
    }
  }

  Future<void> _loadCitiesDirectly(String apiCountryName) async {
    setState(() {
      _isCitiesLoading = true;
      _cities = [];
      _selectedCity = null;
      _cityController.text = '';
      _cityFreeText = false;
    });

    // Hardcoded cities for the country (aggregated from all states)
    final hardcoded = _getHardcodedCitiesForCountry(apiCountryName);
    if (hardcoded.isNotEmpty) {
      if (mounted) {
        setState(() {
          _cities = hardcoded;
          _isCitiesLoading = false;
        });
      }
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
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return (item['name'] ?? item['city'] ?? '').toString().trim();
                }
                return item.toString().trim();
              })
              .where((item) => item.isNotEmpty)
              .toList()
            ..sort();
          if (mounted) {
            setState(() => _cities = cityList);
          }
        }
      }

      if (_cities.isEmpty && mounted) {
        setState(() {
          _cityFreeText = true;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar ciudades: $e');
      if (mounted) {
        setState(() {
          _cityFreeText = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCitiesLoading = false);
      }
    }
  }

  Future<void> _loadCitiesByState(String countryName, String stateName) async {
    if (countryName.trim().isEmpty || stateName.trim().isEmpty) return;

    final apiCountryName = _toApiCountryName(countryName.trim());

    setState(() {
      _isCitiesLoading = true;
      _cities = [];
      _selectedCity = null;
      _cityController.text = '';
      _cityFreeText = false;
    });

    // Hardcoded cities for this country+state
    final hardcoded = _getHardcodedCities(apiCountryName, stateName);
    if (hardcoded.isNotEmpty) {
      if (mounted) {
        setState(() {
          _cities = hardcoded;
          _isCitiesLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(
                'https://countriesnow.space/api/v0.1/countries/state/cities'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiCountryName, 'state': stateName}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] == false && data['data'] is List) {
          final cityList = (data['data'] as List)
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return (item['name'] ?? item['city'] ?? '').toString().trim();
                }
                return item.toString().trim();
              })
              .where((item) => item.isNotEmpty)
              .toList()
            ..sort();
          if (mounted) {
            setState(() => _cities = cityList);
          }
        }
      }

      if (_cities.isEmpty) {
        await _loadCitiesDirectly(apiCountryName);
      }
    } catch (e) {
      debugPrint('Error al cargar ciudades por estado: $e');
      await _loadCitiesDirectly(apiCountryName);
    } finally {
      if (mounted) {
        setState(() => _isCitiesLoading = false);
      }
    }
  }

  bool _removeMissingColumnFromPayload(
    Map<String, dynamic> payload,
    Object error,
  ) {
    final text = error.toString();
    final match =
        RegExp(r"Could not find the '([^']+)' column").firstMatch(text);
    if (match == null) return false;
    final missing = match.group(1);
    if (missing == null || missing.isEmpty) return false;
    return payload.remove(missing) != null;
  }

  Future<void> _safeUpdate(
    String table,
    Map<String, dynamic> payload,
    String eqField,
    dynamic eqValue,
  ) async {
    final mutable = Map<String, dynamic>.from(payload);
    for (var i = 0; i <= payload.length + 4; i++) {
      try {
        await SupaFlow.client.from(table).update(mutable).eq(eqField, eqValue);
        return;
      } catch (e) {
        if (!_removeMissingColumnFromPayload(mutable, e)) rethrow;
      }
    }
    throw Exception(
        'No se pudo actualizar $table por incompatibilidad de schema');
  }

  Future<void> _safeInsert(
    String table,
    Map<String, dynamic> payload,
  ) async {
    final mutable = Map<String, dynamic>.from(payload);
    for (var i = 0; i <= payload.length + 4; i++) {
      try {
        await SupaFlow.client.from(table).insert(mutable);
        return;
      } catch (e) {
        if (!_removeMissingColumnFromPayload(mutable, e)) rethrow;
      }
    }
    throw Exception(
        'No se pudo insertar en $table por incompatibilidad de schema');
  }

  bool _isValueTooLongError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('value too long') ||
        text.contains('character varying');
  }

  String _legacyClubesId(String authUserId) {
    final compact = authUserId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (compact.isEmpty) return authUserId;
    return compact.length <= 10 ? compact : compact.substring(0, 10);
  }

  String _legacyPhoneForVarchar10(String phone) {
    final digits = _digitsOnly(phone);
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  String _limitLegacyText(String value, int maxLength) {
    final trimmed = value.trim();
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }

  Map<String, dynamic> _legacyClubesCompatiblePayload(
    Map<String, dynamic> payload,
  ) {
    final compatible = Map<String, dynamic>.from(payload);
    final id = compatible['id']?.toString() ?? '';
    final phone = compatible['telephone']?.toString() ?? '';

    if (id.length > 10) compatible['id'] = _legacyClubesId(id);
    if (phone.isNotEmpty) {
      compatible['telephone'] = _legacyPhoneForVarchar10(phone);
    }

    for (final field in ['nombre_corto', 'liga', 'sitio_web']) {
      final value = compatible[field]?.toString() ?? '';
      if (value.length > 10) compatible[field] = _limitLegacyText(value, 10);
    }

    for (final field in ['email', 'state', 'city', 'country']) {
      final value = compatible[field]?.toString() ?? '';
      if (value.length > 10) compatible.remove(field);
    }

    return compatible;
  }

  Future<void> _saveLegacyClubesProfile(
    Map<String, dynamic> clubData,
    String ownerUid,
  ) async {
    Map<String, dynamic>? existingClub;
    try {
      existingClub = await SupaFlow.client
          .from('clubes')
          .select()
          .eq('id', ownerUid)
          .maybeSingle();
    } catch (_) {}

    try {
      if (existingClub != null) {
        final legacyId = existingClub['id']?.toString() ?? ownerUid;
        await _safeUpdate('clubes', clubData, 'id', legacyId);
      } else {
        final insertPayload = Map<String, dynamic>.from(clubData)
          ..['id'] = ownerUid
          ..['created_at'] = DateTime.now().toIso8601String();
        await _safeInsert('clubes', insertPayload);
      }
      return;
    } catch (e) {
      if (!_isValueTooLongError(e)) {
        debugPrint('No se pudo guardar en clubes legado: $e');
        return;
      }
    }

    try {
      final compatible = _legacyClubesCompatiblePayload(clubData);
      if (existingClub != null) {
        final legacyId = existingClub['id']?.toString() ?? ownerUid;
        await _safeUpdate('clubes', compatible, 'id', legacyId);
      } else {
        final insertPayload = _legacyClubesCompatiblePayload({
          ...clubData,
          'id': _legacyClubesId(ownerUid),
          'created_at': DateTime.now().toIso8601String(),
        });
        await _safeInsert('clubes', insertPayload);
      }
    } catch (e) {
      debugPrint('No se pudo guardar en clubes legado compatible: $e');
    }
  }

  bool _validateStep3() {
    if (_emailController.text.trim().isEmpty) {
      _showError('Por favor, ingresa un email de contacto');
      return false;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showError('Por favor, ingresa un teléfono de contacto');
      return false;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showError('Email de contacto inválido.');
      return false;
    }
    try {
      _phoneController.text =
          _validateAndNormalizeLatamPhone(_phoneController.text);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    final checks = [
      (_instagramController, 'Instagram'),
      (_facebookController, 'Facebook'),
      (_websiteController, 'Sitio web'),
      (_otherUrlController, 'Otros'),
    ];

    for (final entry in checks) {
      final controller = entry.$1;
      final label = entry.$2;
      if (controller.text.trim().isEmpty) continue;
      try {
        controller.text = _validateAndNormalizeUrl(
          controller.text,
          label: label,
        );
      } catch (e) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
        return false;
      }
    }
    return true;
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  String? _dialCodeFromCountrySelection() {
    final country = normalizeCountryName(_countryController.text);
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
    if (cursor < input.length) chunks.add(input.substring(cursor));
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
      return hasExplicitPlus
          ? '+${_chunkBySize(digits, [3, 3, 4])}'
          : _chunkBySize(digits, [3, 3, 4]);
    }

    final formattedLocal = _chunkBySize(localDigits, [3, 3, 4]);
    return formattedLocal.isEmpty ? '+$dialCode' : '+$dialCode $formattedLocal';
  }

  void _handlePhoneInputChange() {
    if (_isFormattingPhone) return;
    final formatted = _formatLatamPhone(_phoneController.text);
    if (formatted == _phoneController.text) return;

    _isFormattingPhone = true;
    _phoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormattingPhone = false;
  }

  String _validateAndNormalizeLatamPhone(String rawValue) {
    final formatted = _formatLatamPhone(rawValue);
    final digits = _digitsOnly(formatted);
    if (formatted.isEmpty) {
      throw Exception('Por favor, ingresa un teléfono de contacto');
    }
    if (!formatted.startsWith('+')) {
      throw Exception(
          'Teléfono inválido. Incluye código de país LATAM, por ejemplo +54 o +55.');
    }
    if (digits.length < 10 || digits.length > 14) {
      throw Exception(
          'Teléfono inválido. Usa formato internacional, por ejemplo +54 911 1234 5678.');
    }
    final hasKnownDialCode =
        _latamDialCodes.any((code) => digits.startsWith(code));
    if (!hasKnownDialCode) {
      throw Exception('Código de país no reconocido para América Latina.');
    }
    return formatted;
  }

  String _validateAndNormalizeUrl(String rawValue, {required String label}) {
    final value = rawValue.trim();
    if (value.isEmpty) return '';
    final normalized =
        value.startsWith('http://') || value.startsWith('https://')
            ? value
            : 'https://$value';
    final uri = Uri.tryParse(normalized);
    final isValid = uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.host.contains('.');
    if (!isValid) {
      throw Exception('$label inválido. Ingresa un link válido (https://...).');
    }
    return normalized;
  }

  Future<void> _saveClub() async {
    if (!_validateStep3()) return;
    setState(() => _isLoading = true);
    try {
      final uid = await _ensureClubAuthAccount();
      if (uid == null || uid.isEmpty) return;

      final normalizedWebsite = _validateAndNormalizeUrl(
        _websiteController.text,
        label: 'Sitio web',
      );
      final normalizedOtherUrl = _validateAndNormalizeUrl(
        _otherUrlController.text,
        label: 'Link externo',
      );
      final sitioWeb = _websiteController.text.isNotEmpty
          ? normalizedWebsite
          : normalizedOtherUrl;
      final normalizedPhone =
          _validateAndNormalizeLatamPhone(_phoneController.text);
      final normalizedCountry = normalizeCountryName(_countryController.text);
      final normalizedState = _stateController.text.trim();
      final normalizedCity = normalizeCityName(_cityController.text);
      if (_logoBytes != null && _logoUrl == null) {
        await _uploadLogo(_logoBytes!, 'club_logo.jpg', ownerUid: uid);
      }

      // Update User
      final existingUser = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      final userData = {
        'name': _clubNameController.text,
        'city': normalizedCity,
        'state': normalizedState,
        'country': normalizedCountry,
        'ciudad': normalizedCity,
        'estado': normalizedState,
        'pais': normalizedCountry,
        'country_id': _selectedCountryId != null
            ? int.tryParse(_selectedCountryId!)
            : null,
        'userType': 'club',
        'photo_url': _logoUrl,
        'role_id': 2,
      };
      if (existingUser != null) {
        await _safeUpdate('users', userData, 'user_id', uid);
      } else {
        userData['user_id'] = uid;
        userData['username'] = _clubNameController.text
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll(RegExp(r'[^a-z0-9_]'), '');
        userData['created_at'] = DateTime.now().toIso8601String();
        try {
          await _safeInsert('users', userData);
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('users_pkey') || msg.contains('duplicate key')) {
            final updatePayload = Map<String, dynamic>.from(userData)
              ..remove('created_at');
            try {
              await _safeUpdate('users', updatePayload, 'user_id', uid);
            } catch (_) {
              await _safeUpdate('users', updatePayload, 'id', uid);
            }
          } else {
            rethrow;
          }
        }
      }

      // Update Club
      final clubData = {
        'email': _emailController.text,
        'telephone': normalizedPhone,
        'dni': _dniController.text.isNotEmpty
            ? int.tryParse(_dniController.text)
            : null,
        'nombre_corto': _clubNameController.text,
        'is_approved': false,
        'about_club': _aboutClubController.text.isNotEmpty
            ? _aboutClubController.text
            : 'Sin descripción',
        'liga': _leagueController.text.isNotEmpty ? _leagueController.text : '',
        'state': normalizedState,
        'city': normalizedCity,
        'country': normalizedCountry,
        'estado': normalizedState,
        'ciudad': normalizedCity,
        'pais': normalizedCountry,
        'sitio_web': sitioWeb,
      };
      await _saveLegacyClubesProfile(clubData, uid);

      // Also create/update in 'clubs' table (used by all club screens)
      final existingClubs = await SupaFlow.client
          .from('clubs')
          .select()
          .eq('owner_id', uid)
          .maybeSingle();
      final clubsData = {
        'nombre': _clubNameController.text,
        'nombre_corto': _clubNameController.text,
        'country': normalizedCountry,
        'state': normalizedState,
        'city': normalizedCity,
        'pais': normalizedCountry,
        'estado': normalizedState,
        'ciudad': normalizedCity,
        'liga': _leagueController.text.isNotEmpty ? _leagueController.text : '',
        'descripcion': _aboutClubController.text.isNotEmpty
            ? _aboutClubController.text
            : '',
        'sitio_web': sitioWeb,
        'logo_url': _logoUrl,
        'owner_id': uid,
      };
      if (existingClubs != null) {
        await _safeUpdate('clubs', clubsData, 'owner_id', uid);
      } else {
        await _safeInsert('clubs', clubsData);
      }

      FFAppState().userType = 'club';
      FFAppState().registrationFlowActive = false;
      await FFAppState().syncUserType();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _ValidationPendingDialog(
            onContinue: () {
              Navigator.pop(context);
              context.goNamed('dashboard_club');
            },
            onExplore: () {
              Navigator.pop(context);
              context.goNamed(ExplorarWidget.routeName);
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar clube: $e');
      await _abortIncompleteClubRegistration(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ UI ============
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _buildCurrentStep(),
                    ),
                  ),
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentStep + 1) / 3;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEBF4FF),
                      borderRadius: BorderRadius.circular(20)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                        decoration: BoxDecoration(
                            color: const Color(0xFF2B6CB0),
                            borderRadius: BorderRadius.circular(20))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Crea el perfil de tu Club',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              color: const Color(0xFF0D3B66),
              fontSize: 28,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 30),
      Align(
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: _pickLogo,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: const Color(0xFFA0AEC0))),
            child: _logoBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.memory(_logoBytes!, fit: BoxFit.cover))
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(Icons.add_a_photo, color: Color(0xFF718096)),
                        Text('Add Logo',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF718096)))
                      ]),
          ),
        ),
      ),
      const SizedBox(height: 30),
      _buildLabel('Nombre del club'),
      _buildTextField(_clubNameController, 'Ingresa el nombre del club'),
      const SizedBox(height: 20),
      _buildLabel('País'),
      _buildCountryDropdown(),
      const SizedBox(height: 20),
      _buildStateDropdown(),
      const SizedBox(height: 20),
      if (_selectedState != null && _selectedState!.isNotEmpty) ...[
        _buildLabel('Ciudad'),
        _buildCityDropdown(),
      ],
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Contanos sobre el Club',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              color: const Color(0xFF0D3B66),
              fontSize: 28,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 30),
      _buildLabel('Sobre el Club'),
      TextField(
          controller: _aboutClubController,
          maxLines: 4,
          decoration: _inputDecoration('Historia del club')),
      const SizedBox(height: 20),
      _buildLabel('Links'),
      _buildSocialField(_instagramController, 'Instagram', Icons.camera_alt),
      const SizedBox(height: 10),
      _buildSocialField(_facebookController, 'Facebook', Icons.facebook),
      const SizedBox(height: 10),
      _buildSocialField(_websiteController, 'Sitio web', Icons.language),
      const SizedBox(height: 10),
      _buildSocialField(_otherUrlController, 'Otros', Icons.link),
    ]);
  }

  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Contacto y Verificación',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              color: const Color(0xFF0D3B66),
              fontSize: 28,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 30),
      _buildLabel('Email de contacto *'),
      _buildTextField(_emailController, 'Ingresa email',
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 20),
      _buildLabel('Teléfono de contacto *'),
      _buildTextField(_phoneController, 'Ingresa teléfono',
          keyboardType: TextInputType.phone),
      const SizedBox(height: 20),
      _buildLabel('DNI/CUIT'),
      _buildTextField(_dniController, 'Ingresa DNI/CUIT',
          keyboardType: TextInputType.number),
      const SizedBox(height: 20),
      _buildLabel('Liga/Asociación'),
      _buildTextField(_leagueController, 'Ingresa liga'),
    ]);
  }

  Widget _buildLabel(String text) {
    return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF0D3B66), fontWeight: FontWeight.w500))));
  }

  Widget _buildTextField(TextEditingController ctrl, String hint,
      {TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters}) {
    return TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: _inputDecoration(hint));
  }

  Widget _buildSocialField(
      TextEditingController ctrl, String label, IconData icon) {
    return TextField(
        controller: ctrl,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(15))));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(16));
  }

  Widget _buildCountryDropdown() {
    if (_countries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: const Text(
          'Cargando países...',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
        ),
      );
    }

    final selectedCountryName = _countryController.text.trim();
    return _buildSearchableSelector(
      value: selectedCountryName.isNotEmpty ? selectedCountryName : null,
      hint: 'Selecciona país',
      items: _countries
          .map((country) => (country['name'] ?? '').toString().trim())
          .where((country) => country.isNotEmpty)
          .toList(),
      onSelected: (countryName) {
        final selected = _countries.firstWhere(
          (country) =>
              (country['name'] ?? '').toString().trim() == countryName.trim(),
          orElse: () => <String, dynamic>{},
        );
        final countryId = selected['id']?.toString();
        if (countryId == null || countryId.isEmpty) return;

        setState(() {
          _selectedCountryId = countryId;
          _countryController.text = countryName;
          _selectedState = null;
          _stateController.text = '';
          _states = [];
          _stateFreeText = false;
          _isStatesLoading = true;
          _selectedCity = null;
          _cityController.text = '';
          _cities = [];
          _cityFreeText = false;
          _isCitiesLoading = false;
        });
        _loadStates(countryName);
      },
    );
  }

  Widget _buildStateDropdown() {
    // Não mostrar antes de selecionar um país
    if (_selectedCountryId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Estado / Provincia'),
        if (_isStatesLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Cargando estados...'),
              ],
            ),
          )
        else if (_states.isNotEmpty && !_stateFreeText)
          _buildSearchableSelector(
            value: _selectedState,
            hint: 'Selecciona el estado',
            items: _states,
            onSelected: (v) {
              setState(() {
                _selectedState = v;
                _stateController.text = v;
                _isCitiesLoading = true;
              });
              _loadCitiesByState(_countryController.text, v);
            },
          )
        else
          _buildTextField(_stateController, 'Escribe el estado / provincia'),
      ],
    );
  }

  Widget _buildCityDropdown() {
    // Só mostra o campo cidade se um estado foi selecionado
    if (_selectedState == null || _selectedState!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isCitiesLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Cargando ciudades...'),
          ],
        ),
      );
    }

    // Só permite seleção, nunca digitação manual
    if (_cities.isNotEmpty && !_cityFreeText) {
      return _buildSearchableSelector(
        value: _selectedCity,
        hint: 'Selecciona la ciudad',
        items: _cities,
        onSelected: (v) {
          setState(() {
            _selectedCity = v;
            _cityController.text = v;
          });
        },
      );
    }

    // Se não houver cidades disponíveis, não mostra nada
    return const SizedBox.shrink();
  }

  Widget _buildSearchableSelector({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) {
    return GestureDetector(
      onTap: () => _showSearchableBottomSheet(
        title: hint,
        items: items,
        onSelected: onSelected,
        selectedValue: value,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  color: value != null
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF9CA3AF),
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
          ],
        ),
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

  Widget _buildNavigationButtons() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            if (_currentStep > 0)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ElevatedButton(
                          onPressed: () => setState(() => _currentStep--),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2B6CB0)),
                          child: const Text('Anterior',
                              style: TextStyle(color: Colors.white))))),
            Expanded(
                child: Padding(
                    padding: EdgeInsets.only(left: _currentStep > 0 ? 10 : 0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3B66)),
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_currentStep == 0 && _validateStep1()) {
                                setState(() => _currentStep++);
                              } else if (_currentStep == 1 && _validateStep2())
                                setState(() => _currentStep++);
                              else if (_currentStep == 2) _saveClub();
                            },
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_currentStep == 2 ? 'Finalizar' : 'Siguiente',
                              style: const TextStyle(color: Colors.white)),
                    ))),
          ]),
        ),
      ),
    );
  }
}

// ===== DIALOG DE VALIDAÇÃO PENDENTE =====
class _ValidationPendingDialog extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onExplore;

  const _ValidationPendingDialog({
    required this.onContinue,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEBF4FF),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.hourglass_empty,
                  size: 40, color: Color(0xFF0D3B66)),
            ),
            const SizedBox(height: 20),
            Text(
              'Validación Pendiente',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tu registro está siendo revisado por nuestro equipo. Te notificaremos cuando sea aprobado.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF718096),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onExplore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  minimumSize: const Size(0, 43),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Explorar jugadores',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onContinue,
                child: Text(
                  'Ir al panel del club',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0D3B66),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
