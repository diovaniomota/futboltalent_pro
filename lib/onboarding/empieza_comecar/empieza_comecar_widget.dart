import 'dart:async';
import '/auth/supabase_auth/auth_util.dart';
import '/auth/supabase_auth/social_oauth.dart';
import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/geo_selection_bottom_sheet.dart';
import '/fluxo_compartilhado/password_policy.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/guardian/guardian_mvp_service.dart';
import '/fluxo_compartilhado/email_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'empieza_comecar_model.dart';
export 'empieza_comecar_model.dart';

class EmpiezaComecarWidget extends StatefulWidget {
  const EmpiezaComecarWidget({
    super.key,
    required this.selectedUserType,
  });

  final String? selectedUserType;

  static String routeName = 'Empieza_Comecar';
  static String routePath = '/empieza_Comecar';

  @override
  State<EmpiezaComecarWidget> createState() => _EmpiezaComecarWidgetState();
}

typedef _WelcomeBenefit = ({String title, IconData icon});

typedef _WelcomeContent = ({
  String eyebrow,
  IconData badgeIcon,
  Color accent,
  String title,
  String subtitle,
  String primaryButton,
  List<_WelcomeBenefit> benefits,
});

class _EmpiezaComecarWidgetState extends State<EmpiezaComecarWidget>
    with TickerProviderStateMixin {
  late EmpiezaComecarModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  late TabController _tabController;

  // Controllers Tab 2 - Registro
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  // Controllers Tab 3 - Dados pessoais
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dataNascimentoController =
      TextEditingController();
  final TextEditingController _paisController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();
  final TextEditingController _clubController = TextEditingController();
  final TextEditingController _currentRoleController = TextEditingController();
  final TextEditingController _workZoneController = TextEditingController();

  // Focus nodes
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _senhaFocusNode = FocusNode();
  final FocusNode _confirmarSenhaFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _dataNascimentoFocusNode = FocusNode();
  final FocusNode _paisFocusNode = FocusNode();
  final FocusNode _cidadeFocusNode = FocusNode();
  final FocusNode _clubFocusNode = FocusNode();
  final FocusNode _currentRoleFocusNode = FocusNode();
  final FocusNode _workZoneFocusNode = FocusNode();
  final FocusNode _guardianEmailFocusNode = FocusNode();

  // Mask
  final MaskTextInputFormatter _dataNascimentoMask = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // Visibility
  bool _senhaVisibility = false;
  bool _confirmarSenhaVisibility = false;

  // Loading states
  bool _isRegistering = false;
  bool _isSavingProfile = false;

  // Country dropdown
  List<Map<String, dynamic>> _countries = [];
  String? _selectedCountryId;

  // State dropdown
  List<String> _states = [];
  String? _selectedState;
  bool _isStatesLoading = false;

  // City dropdown
  List<String> _cities = [];
  String? _selectedCity;
  bool _isCitiesLoading = false;
  bool _cityFreeText = false; // fallback: digitação livre

  // Guardian controllers (Tab 4 - menores)
  final TextEditingController _guardianEmailController =
      TextEditingController();
  final String _guardianRelationship = 'tutor';
  bool _acceptedCommunityRules = false;
  bool _acceptedTerms = false; // términos de uso y privacidad
  bool _guardianAuthorized = false;
  bool _shouldShowGuardianStep = false;
  String? _selectedOrganizationType;

  static const List<String> _organizationTypeOptions = [
    'Organización / club',
    'Independiente',
  ];

  // ============ RESPONSIVE HELPERS ============
  double _responsive(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return desktop ?? tablet ?? mobile;
    if (width >= 600) return tablet ?? mobile;
    return mobile;
  }

  double _scaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 320) return 0.8;
    if (width < 360) return 0.9;
    if (width >= 1024) return 1.1;
    return 1.0;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EmpiezaComecarModel());
    _tabController = TabController(length: 5, vsync: this);
    _loadCountries();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Se já estiver logado (ex: voltou de OAuth), pula para a fase de dados (Tab 3)
      if (currentUserUid.isNotEmpty && _tabController.index < 2) {
        _tabController.animateTo(2);
      }
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _tabController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _nameController.dispose();
    _dataNascimentoController.dispose();
    _paisController.dispose();
    _cidadeController.dispose();
    _clubController.dispose();
    _currentRoleController.dispose();
    _workZoneController.dispose();
    _emailFocusNode.dispose();
    _senhaFocusNode.dispose();
    _confirmarSenhaFocusNode.dispose();
    _nameFocusNode.dispose();
    _dataNascimentoFocusNode.dispose();
    _paisFocusNode.dispose();
    _cidadeFocusNode.dispose();
    _clubFocusNode.dispose();
    _currentRoleFocusNode.dispose();
    _workZoneFocusNode.dispose();
    _guardianEmailFocusNode.dispose();
    _guardianEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final response =
          await SupaFlow.client.from('countrys').select().order('name');
      final countryList = List<Map<String, dynamic>>.from(response as List);
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
      debugPrint('Error loading countries: $e');
    }
  }

  /// Traduz nomes de países do espanhol/português para o inglês aceito pela API.
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
    'Brazil|Distrito Federal': [
      'Brasília',
      'Ceilândia',
      'Taguatinga',
      'Samambaia',
      'Planaltina'
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
      'Silao'
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
    'Mexico|Tamaulipas': ['Reynosa', 'Matamoros', 'Nuevo Laredo', 'Tampico'],
    'Mexico|Sonora': [
      'Hermosillo',
      'Ciudad Obregón',
      'Nogales',
      'Guaymas',
      'San Luis Río Colorado'
    ],
    'Mexico|Sinaloa': ['Culiacán', 'Mazatlán', 'Guasave'],
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
    'Colombia|Caldas': ['Manizales', 'Villamaría', 'La Dorada', 'Chinchiná'],
    'Colombia|Risaralda': [
      'Pereira',
      'Dosquebradas',
      'Santa Rosa de Cabal',
      'La Virginia'
    ],
    'Colombia|Quindío': ['Armenia', 'Calarcá', 'Montenegro', 'Quimbaya'],
    'Colombia|Meta': ['Villavicencio', 'Granada', 'Acacías', 'Puerto López'],
    'Colombia|Cauca': ['Popayán', 'Santander de Quilichao', 'Puerto Tejada'],
    'Colombia|Cesar': ['Valledupar', 'Aguachica', 'Bosconia', 'Codazzi'],
    'Colombia|La Guajira': ['Riohacha', 'Maicao', 'Uribia', 'Manaure'],
    'Colombia|Boyacá': ['Tunja', 'Duitama', 'Sogamoso', 'Chiquinquirá'],
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
    'Venezuela|Lara': ['Barquisimeto', 'Carora', 'El Tocuyo', 'Quibor'],
    'Venezuela|Zulia': [
      'Maracaibo',
      'Cabimas',
      'Ciudad Ojeda',
      'San Francisco',
      'Lagunillas',
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
    'Venezuela|Sucre': ['Cumaná', 'Carúpano', 'Güiria'],
    'Venezuela|Táchira': [
      'San Cristóbal',
      'Táriba',
      'Rubio',
      'San Antonio del Táchira'
    ],
    'Venezuela|Mérida': ['Mérida', 'El Vigía', 'Tovar'],
    'Venezuela|Monagas': ['Maturín', 'Caripito', 'Punta de Mata'],
    'Venezuela|Falcón': [
      'Coro',
      'Punto Fijo',
      'La Vela de Coro',
      'Chichiriviche'
    ],
    'Venezuela|Nueva Esparta': [
      'La Asunción',
      'Porlamar',
      'Pampatar',
      'Juangriego'
    ],
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
      'Los Andes'
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
    'Chile|Coquimbo': ['La Serena', 'Coquimbo', 'Ovalle', 'Illapel'],
    'Chile|O\'Higgins': ['Rancagua', 'San Fernando', 'Pichilemu', 'Graneros'],
    'Chile|Maule': ['Talca', 'Curicó', 'Linares', 'Constitución'],
    'Chile|Arica y Parinacota': ['Arica', 'Putre'],
    'Chile|Tarapacá': ['Iquique', 'Alto Hospicio'],
    'Chile|Atacama': ['Copiapó', 'Vallenar', 'Caldera'],
    'Chile|Magallanes': ['Punta Arenas', 'Puerto Natales'],
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
    'Peru|San Martín': ['Tarapoto', 'Moyobamba', 'Juanjuí'],
    'Ecuador|Pichincha': ['Quito', 'Cayambe', 'Sangolquí', 'Machachi'],
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
    'Ecuador|Tungurahua': ['Ambato', 'Baños', 'Pelileo', 'Píllaro'],
    'Ecuador|Imbabura': ['Ibarra', 'Otavalo', 'Cotacachi'],
    'Ecuador|Loja': ['Loja', 'Catamayo', 'Cariamanga'],
    'Ecuador|Cotopaxi': ['Latacunga', 'La Maná', 'Salcedo'],
    'Ecuador|Santa Elena': ['Santa Elena', 'La Libertad', 'Salinas'],
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
    'Bolivia|Tarija': ['Tarija', 'Yacuiba', 'Bermejo'],
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
    'Paraguay|Itapúa': ['Encarnación', 'Coronel Bogado'],
    'Paraguay|Caaguazú': ['Coronel Oviedo', 'Caaguazú'],
    'Paraguay|Guairá': ['Villarrica', 'Coronel Martínez'],
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
      'Rubí',
      'Castelldefels'
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
    'Spain|Guipúzcoa': ['San Sebastián', 'Irun', 'Errenteria', 'Zarautz'],
    'Spain|Zaragoza': ['Zaragoza', 'Calatayud', 'Utebo'],
    'Spain|Alicante': [
      'Alicante',
      'Elche',
      'Torrevieja',
      'Benidorm',
      'Orihuela'
    ],
    'Spain|Granada': ['Granada', 'Motril', 'Almuñécar', 'Guadix'],
    'Spain|Asturias': ['Oviedo', 'Gijón', 'Avilés', 'Mieres'],
    'Spain|Cantabria': ['Santander', 'Torrelavega'],
    'Spain|Navarra': ['Pamplona', 'Tudela', 'Burlada'],
    'Spain|La Rioja': ['Logroño', 'Calahorra', 'Arnedo'],
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
      'Barreiro'
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
    'Portugal|Faro': ['Faro', 'Loulé', 'Portimão', 'Lagos', 'Tavira', 'Olhão'],
    'Portugal|Aveiro': [
      'Aveiro',
      'Oliveira de Azeméis',
      'São João da Madeira',
      'Ovar'
    ],
    'Portugal|Coimbra': ['Coimbra', 'Figueira da Foz'],
    'Portugal|Madeira': ['Funchal', 'Câmara de Lobos'],
    'Portugal|Açores': ['Ponta Delgada', 'Angra do Heroísmo', 'Horta'],
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
      'Palmares'
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
      'Flores'
    ],
    'Costa Rica|Guanacaste': ['Liberia', 'Nicoya', 'Santa Cruz', 'Cañas'],
    'Costa Rica|Puntarenas': ['Puntarenas', 'Quepos', 'Golfito'],
    'Costa Rica|Limón': ['Limón', 'Pococí', 'Siquirres'],
    'Guatemala|Guatemala': [
      'Guatemala City',
      'Mixco',
      'Villa Nueva',
      'San Juan Sacatepéquez',
      'Chinautla',
      'Petapa',
      'Villa Canales'
    ],
    'Guatemala|Quetzaltenango': ['Quetzaltenango', 'Coatepeque'],
    'Guatemala|Escuintla': ['Escuintla', 'Puerto San José'],
    'Guatemala|Alta Verapaz': ['Cobán', 'Chisec', 'Panzós'],
    'Guatemala|Izabal': ['Puerto Barrios', 'Morales', 'Livingston'],
    'Guatemala|Petén': ['Flores', 'Santa Elena', 'San Benito'],
    'Guatemala|Sacatepéquez': [
      'Antigua Guatemala',
      'Jocotenango',
      'Ciudad Vieja'
    ],
    'Honduras|Francisco Morazán': [
      'Tegucigalpa',
      'Comayagüela',
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
    'Honduras|Atlántida': ['La Ceiba', 'El Progreso', 'Tela'],
    'Honduras|Yoro': ['Yoro', 'El Progreso', 'Santa Rita', 'Olanchito'],
    'Honduras|Comayagua': ['Comayagua', 'Siguatepeque'],
    'Honduras|El Paraíso': ['Danlí', 'El Paraíso'],
    'Honduras|Olancho': ['Juticalpa', 'Catacamas'],
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
    'El Salvador|Santa Ana': ['Santa Ana', 'Chalchuapa', 'Coatepeque'],
    'El Salvador|San Miguel': ['San Miguel', 'Ciudad Barrios'],
    'El Salvador|La Libertad': [
      'Santa Tecla',
      'Antiguo Cuscatlán',
      'Quezaltepeque',
      'La Libertad'
    ],
    'El Salvador|Sonsonate': ['Sonsonate', 'Acajutla', 'Armenia', 'Izalco'],
    'Panama|Panamá': [
      'Ciudad de Panamá',
      'San Miguelito',
      'Tocumen',
      'Arraiján',
      'La Chorrera'
    ],
    'Panama|Panamá Oeste': ['La Chorrera', 'Arraiján', 'Capira'],
    'Panama|Colón': ['Colón', 'Portobelo'],
    'Panama|Chiriquí': ['David', 'Boquete', 'La Concepción', 'Changuinola'],
    'Panama|Coclé': ['Penonomé', 'La Pintada', 'Antón'],
    'Panama|Herrera': ['Chitré', 'Parita'],
    'Dominican Republic|Distrito Nacional': ['Santo Domingo'],
    'Dominican Republic|Santo Domingo': [
      'Santo Domingo Este',
      'Santo Domingo Norte',
      'Santo Domingo Oeste',
      'Boca Chica'
    ],
    'Dominican Republic|Santiago': ['Santiago de los Caballeros', 'Moca'],
    'Dominican Republic|La Altagracia': ['Higüey', 'San Rafael del Yuma'],
    'Dominican Republic|La Vega': [
      'La Vega',
      'Jarabacoa',
      'Constanza',
      'Bonao'
    ],
    'Dominican Republic|San Pedro de Macorís': [
      'San Pedro de Macorís',
      'Hato Mayor'
    ],
    'Dominican Republic|Puerto Plata': ['Puerto Plata', 'Sosúa', 'Cabarete'],
    'United States|Florida': [
      'Miami',
      'Orlando',
      'Tampa',
      'Jacksonville',
      'St. Petersburg',
      'Hialeah',
      'Tallahassee',
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
      'Agrigento'
    ],
    'Italy|Piemonte': ['Torino', 'Novara', 'Alessandria', 'Asti', 'Cuneo'],
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
      'Regensburg',
      'Ingolstadt'
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
    'Germany|Hamburg': ['Hamburg', 'Wandsbek', 'Altona', 'Harburg'],
    'France|Île-de-France': [
      'Paris',
      'Boulogne-Billancourt',
      'Saint-Denis',
      'Argenteuil',
      'Montreuil',
      'Nanterre',
      'Versailles',
      'Créteil',
      'Colombes'
    ],
    'France|Auvergne-Rhône-Alpes': [
      'Lyon',
      'Grenoble',
      'Saint-Étienne',
      'Villeurbanne',
      'Clermont-Ferrand',
      'Annecy'
    ],
    'France|Nouvelle-Aquitaine': [
      'Bordeaux',
      'Limoges',
      'Pau',
      'La Rochelle',
      'Poitiers',
      'Bayonne'
    ],
    'France|Occitanie': ['Toulouse', 'Montpellier', 'Nîmes', 'Perpignan'],
    'France|Hauts-de-France': [
      'Lille',
      'Amiens',
      'Dunkerque',
      'Roubaix',
      'Tourcoing'
    ],
    'France|Provence-Alpes-Côte d\'Azur': [
      'Marseille',
      'Nice',
      'Toulon',
      'Aix-en-Provence',
      'Avignon',
      'Cannes'
    ],
    'France|Grand Est': ['Strasbourg', 'Reims', 'Metz', 'Nancy', 'Mulhouse'],
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
      'Southampton'
    ],
    'United Kingdom|Scotland': [
      'Glasgow',
      'Edinburgh',
      'Aberdeen',
      'Dundee',
      'Inverness'
    ],
    'United Kingdom|Wales': ['Cardiff', 'Swansea', 'Newport', 'Wrexham'],
    'United Kingdom|Northern Ireland': ['Belfast', 'Londonderry', 'Lisburn'],
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

  Future<void> _loadStates(String countryName) async {
    if (countryName.isEmpty) return;
    final apiName = _toApiCountryName(countryName);
    setState(() {
      _states = [];
      _selectedState = null;
      _cities = [];
      _selectedCity = null;
      _cidadeController.text = '';
      _cityFreeText = false;
      _isStatesLoading = true;
    });

    // Check hardcoded list first (instant, offline)
    final hardcoded = _hardcodedStates[apiName] ?? [];
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
      final uri =
          Uri.parse('https://countriesnow.space/api/v0.1/countries/states');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiName}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] == false && data['data'] is Map) {
          final statesRaw = data['data']['states'];
          if (statesRaw is List) {
            final list = statesRaw
                .map((s) => (s['name'] ?? '').toString())
                .where((s) => s.isNotEmpty)
                .toList()
              ..sort();
            if (mounted) setState(() => _states = list);
          }
        }
      }
      // Fallback: sin estados → carga ciudades directamente
      if (_states.isEmpty && mounted) {
        await _loadCitiesDirectly(apiName);
      }
    } catch (e) {
      debugPrint('Error al cargar estados: $e');
      if (mounted) await _loadCitiesDirectly(apiName);
    } finally {
      if (mounted) setState(() => _isStatesLoading = false);
    }
  }

  /// Carga todas las ciudades del país sin filtrar por estado (fallback).
  Future<void> _loadCitiesDirectly(String apiCountryName) async {
    // Hardcoded cities for the country
    final hardcoded = _getHardcodedCitiesForCountry(apiCountryName);
    if (hardcoded.isNotEmpty) {
      if (mounted) {
        setState(() {
          _cities = hardcoded;
          _selectedState ??= '__all__';
          _isCitiesLoading = false;
        });
      }
      return;
    }
    setState(() => _isCitiesLoading = true);
    try {
      final uri =
          Uri.parse('https://countriesnow.space/api/v0.1/countries/cities');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiCountryName}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] == false && data['data'] is List) {
          final list = (data['data'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
            ..sort();
          if (mounted) {
            setState(() {
              _cities = list;
              _selectedState ??= '__all__';
            });
          }
        }
      }
      // Último recurso: texto libre
      if (_cities.isEmpty && mounted) {
        setState(() {
          _cityFreeText = true;
          _selectedState ??= '__all__';
        });
      }
    } catch (e) {
      debugPrint('Error al cargar ciudades directas: $e');
      if (mounted) {
        setState(() {
          _cityFreeText = true;
          _selectedState ??= '__all__';
        });
      }
    } finally {
      if (mounted) setState(() => _isCitiesLoading = false);
    }
  }

  Future<void> _loadCitiesByState(String countryName, String stateName) async {
    if (countryName.isEmpty || stateName.isEmpty) return;
    final apiName = _toApiCountryName(countryName);
    setState(() {
      _cities = [];
      _selectedCity = null;
      _cidadeController.text = '';
      _cityFreeText = false;
      _isCitiesLoading = true;
    });

    // Hardcoded cities for this country+state
    final hardcoded = _getHardcodedCities(apiName, stateName);
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
      final uri = Uri.parse(
          'https://countriesnow.space/api/v0.1/countries/state/cities');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiName, 'state': stateName}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] == false && data['data'] is List) {
          final list = (data['data'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
            ..sort();
          if (mounted) setState(() => _cities = list);
        }
      }
      // Fallback: sin ciudades → texto libre
      if (_cities.isEmpty && mounted) {
        setState(() => _cityFreeText = true);
      }
    } catch (e) {
      debugPrint('Error al cargar ciudades: $e');
      if (mounted) setState(() => _cityFreeText = true);
    } finally {
      if (mounted) setState(() => _isCitiesLoading = false);
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    setState(() => _isRegistering = true);
    try {
      FFAppState().userType = _normalizedSelectedUserType;
      FFAppState().registrationFlowActive = true;
      GoRouter.of(context).prepareAuthEvent();
      final success = await signInWithSocialProvider(provider);
      if (!success && mounted) {
        _showSnackBar(socialAuthLaunchErrorMessage(provider));
      } else if (success) {
        await _handleCompletedSocialAuth(provider);
      }
    } catch (e) {
      debugPrint('Social auth failed for ${socialProviderLabel(provider)}: $e');
      if (isSocialAuthCanceled(e)) return;
      _showSnackBar(socialAuthFriendlyErrorMessage(e, provider));
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _handleCompletedSocialAuth(OAuthProvider provider) async {
    final uid = await _waitForSocialAuthUid();
    if (uid.isEmpty) return;

    await FFAppState().syncUserType(expectedUid: uid);
    if (!mounted || !FFAppState().registrationComplete) return;

    FFAppState().registrationFlowActive = false;
    _showSnackBar(
      'Ya existe una cuenta con ese correo. Iniciamos sesión con ${socialProviderLabel(provider)}.',
    );

    final userType = FFAppState.normalizeUserType(FFAppState().userType);
    if (userType == 'admin') {
      context.goNamed('admin_dashboard');
    } else if (userType == 'club') {
      context.goNamed('dashboard_club');
    } else {
      context.goNamed('feed');
    }
  }

  Future<String> _waitForSocialAuthUid() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final uid = currentUserUid.trim();
      if (uid.isNotEmpty) return uid;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return currentUserUid.trim();
  }

  void _goToNextTab() {
    if (_tabController.index < _tabController.length - 1) {
      _tabController.animateTo(
        _tabController.index + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _goToPreviousTab() {
    if (_tabController.index > 0) {
      _tabController.animateTo(
        _tabController.index - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  Future<void> _registerWithEmail() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Por favor ingresa tu correo electrónico');
      return;
    }
    final passwordError = PasswordPolicy.firstError(_senhaController.text);
    if (passwordError != null) {
      _showSnackBar(passwordError);
      return;
    }
    if (_senhaController.text != _confirmarSenhaController.text) {
      _showSnackBar('Las contraseñas no coinciden');
      return;
    }

    setState(() => _isRegistering = true);
    try {
      FFAppState().registrationFlowActive = true;
      _goToNextTab();
    } catch (e) {
      _showSnackBar(
          'Ocurrió un problema con el registro. Verifica tu conexión e intenta de nuevo.');
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  int _calculateAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  DateTime? _parseBirthday() {
    try {
      final parts = _dataNascimentoController.text.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        // Validate ranges
        if (year < 1920 || year > DateTime.now().year) return null;
        if (month < 1 || month > 12) return null;
        if (day < 1 || day > 31) return null;

        final date = DateTime(year, month, day);
        // Verify the date is valid (e.g., not Feb 30)
        if (date.month != month || date.day != day) return null;

        return date;
      }
    } catch (e) {
      debugPrint('Error al convertir la fecha: $e');
    }
    return null;
  }

  String get _normalizedSelectedUserType => FFAppState.normalizeUserType(
        widget.selectedUserType?.trim().isNotEmpty == true
            ? widget.selectedUserType
            : FFAppState().userType,
        fallback: 'jugador',
      );

  bool get _usesMinorProtectionFlow => _normalizedSelectedUserType == 'jugador';

  bool get _isProfessionalRegistration =>
      _normalizedSelectedUserType == 'profesional';

  _WelcomeContent get _introWelcomeContent {
    switch (_normalizedSelectedUserType) {
      case 'profesional':
        return (
          eyebrow: 'Perfil profesional',
          badgeIcon: Icons.manage_search,
          accent: const Color(0xFF0F766E),
          title: 'Evaluá talento con criterio y contexto.',
          subtitle:
              'Usa filtros deportivos, videos, listas y convocatorias para seguir jugadores sin exponer datos personales ni abrir contactos fuera de la plataforma.',
          primaryButton: 'Crear perfil scout',
          benefits: const [
            (title: 'Evaluación', icon: Icons.fact_check_outlined),
            (title: 'Filtros', icon: Icons.tune),
            (title: 'Listas', icon: Icons.bookmark_border),
            (title: 'Convocatorias', icon: Icons.flag),
            (title: 'Contacto mediado', icon: Icons.shield),
            (title: 'Seguimiento', icon: Icons.timeline),
          ],
        );
      case 'club':
        return (
          eyebrow: 'Perfil institucional',
          badgeIcon: Icons.groups,
          accent: const Color(0xFF6D5BD0),
          title: 'Gestioná talento para tu institución.',
          subtitle:
              'Organizá evaluaciones, convocatorias y seguimiento de jugadores con herramientas pensadas para clubes y academias.',
          primaryButton: 'Crear perfil de club',
          benefits: const [
            (title: 'Candidatos', icon: Icons.groups),
            (title: 'Evaluación', icon: Icons.fact_check_outlined),
            (title: 'Convocatorias', icon: Icons.flag),
            (title: 'Listas', icon: Icons.bookmark_border),
            (title: 'Filtros', icon: Icons.tune),
            (title: 'Control', icon: Icons.admin_panel_settings_outlined),
          ],
        );
      case 'jugador':
      default:
        return (
          eyebrow: 'Perfil jugador',
          badgeIcon: Icons.sports_soccer,
          accent: const Color(0xFF2B6CB0),
          title: 'Convertí tu progreso en oportunidades.',
          subtitle:
              'Mostrá videos, completá desafíos y construí una ficha deportiva clara para que scouts y clubes entiendan tu potencial.',
          primaryButton: 'Crear perfil jugador',
          benefits: const [
            (title: 'Videos', icon: Icons.videocam),
            (title: 'Desafíos', icon: Icons.flag),
            (title: 'Ficha deportiva', icon: Icons.assignment_ind_outlined),
            (title: 'Visibilidad', icon: Icons.travel_explore),
            (title: 'Seguridad', icon: Icons.shield),
            (title: 'Progreso', icon: Icons.trending_up),
          ],
        );
    }
  }

  /// Tab 3 "Siguiente" - valida dados e se menor, vai para Tab 4 (guardian)
  void _onProfileNext() {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Por favor ingresa tu nombre');
      return;
    }
    if (_dataNascimentoController.text.trim().isEmpty) {
      _showSnackBar('Por favor ingresa tu fecha de nacimiento');
      return;
    }

    final birthday = _parseBirthday();
    if (birthday == null) {
      _showSnackBar(
          'Fecha de nacimiento inválida. Usa el formato DD/MM/AAAA con un año entre 1920 y ${DateTime.now().year}');
      return;
    }

    final age = _calculateAge(birthday);
    if (_isProfessionalRegistration && age < 18) {
      _showSnackBar(
        'Los perfiles scout deben ser creados por mayores de 18 años.',
      );
      return;
    }

    if (!_isProfessionalRegistration && age < 13) {
      _showSnackBar(
        'FutbolTalent está disponible solo para jugadores a partir de 13 años.',
      );
      return;
    }

    if (age > 100) {
      _showSnackBar('La edad debe ser válida para continuar.');
      return;
    }

    if (!_acceptedTerms) {
      _showSnackBar(
          'Debes aceptar los Términos de uso y la Política de privacidad para continuar.');
      return;
    }

    if (_selectedCountryId == null || _paisController.text.trim().isEmpty) {
      _showSnackBar('Selecciona tu país para continuar.');
      return;
    }

    if (_states.isNotEmpty &&
        (_selectedState == null || _selectedState!.isEmpty)) {
      _showSnackBar('Selecciona tu estado o provincia.');
      return;
    }

    if (_cities.isNotEmpty &&
        (_selectedCity == null || _selectedCity!.isEmpty)) {
      _showSnackBar('Selecciona tu ciudad.');
      return;
    }

    if (_isProfessionalRegistration) {
      if (_selectedOrganizationType == null ||
          _selectedOrganizationType!.trim().isEmpty) {
        _showSnackBar('Selecciona el tipo de perfil profesional.');
        return;
      }

      if (_currentRoleController.text.trim().isEmpty) {
        _showSnackBar('Indica tu rol actual dentro del scouting.');
        return;
      }
    }

    setState(
        () => _shouldShowGuardianStep = _usesMinorProtectionFlow && age < 18);
    _goToNextTab();
  }

  void _onCommunityNext() {
    if (!_acceptedCommunityRules) {
      _showSnackBar(
        'Debes aceptar las reglas de la comunidad para continuar.',
      );
      return;
    }

    if (_shouldShowGuardianStep) {
      _goToNextTab();
      return;
    }

    _saveProfileAndFinish();
  }

  Future<String> _ensureAuthAccountForFinalRegistration() async {
    final existingUid = currentUserUid.trim();
    if (existingUid.isNotEmpty) {
      FFAppState().registrationFlowActive = true;
      return existingUid;
    }

    final email = _emailController.text.trim();
    final password = _senhaController.text;
    if (email.isEmpty || password.isEmpty) {
      throw Exception(
        'Datos de acceso incompletos. Vuelve a la etapa de cuenta.',
      );
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
      throw Exception('No se pudo crear la cuenta. Intenta de nuevo.');
    }
    TextInput.finishAutofillContext();
    return uid;
  }

  /// Salva perfil + guardian se menor
  Future<void> _saveProfileAndFinish() async {
    setState(() => _isSavingProfile = true);

    try {
      final birthday = _parseBirthday();
      final age = birthday != null ? _calculateAge(birthday) : 99;
      final isMinor = _usesMinorProtectionFlow && age < 18;

      // Se menor, validar guardian
      if (isMinor) {
        if (_guardianEmailController.text.trim().isEmpty) {
          _showSnackBar('Es necesario el correo del adulto responsable.');
          setState(() => _isSavingProfile = false);
          return;
        }
        if (!_guardianEmailController.text.trim().contains('@')) {
          _showSnackBar('Ingresa un correo válido del responsable.');
          setState(() => _isSavingProfile = false);
          return;
        }
        if (!_guardianAuthorized) {
          _showSnackBar(
            'Debes confirmar que el responsable autorizó el uso de FutbolTalent.',
          );
          setState(() => _isSavingProfile = false);
          return;
        }
      }

      final uid = await _ensureAuthAccountForFinalRegistration();
      final userType = _normalizedSelectedUserType;
      final nowIso = DateTime.now().toIso8601String();
      final approvalCode =
          isMinor ? GuardianMvpService.generateApprovalCode() : null;
      final selectedCountryName = _countries
          .where((country) => country['id']?.toString() == _selectedCountryId)
          .map((country) => normalizeCountryName(country['name']))
          .firstWhere((country) => country.isNotEmpty, orElse: () => '');
      final normalizedState =
          _selectedState == '__all__' ? '' : normalizeStateName(_selectedState);
      final normalizedCity = normalizeCityName(
        _cidadeController.text.trim().isNotEmpty
            ? _cidadeController.text
            : _selectedCity,
      );
      final normalizedName = normalizePersonNameInput(_nameController.text);

      final userPayload = <String, dynamic>{
        'name': normalizedName,
        'birthday': birthday?.toIso8601String(),
        'country_id': _selectedCountryId != null
            ? int.tryParse(_selectedCountryId!) ?? 1
            : 1,
        'country': selectedCountryName,
        'pais': selectedCountryName,
        'city': normalizedCity,
        'ciudad': normalizedCity,
        'userType': userType,
        'user_id': uid,
        'username': usernameSlugFromName(normalizedName, userId: uid),
        'lastname': '',
        'role_id': 1,
        'created_at': nowIso,
        'is_minor': isMinor,
        // Só deve ser true após salvar guardian com sucesso.
        'has_guardian': false,
        'guardian_status': isMinor
            ? GuardianMvpService.pendingStatus
            : GuardianMvpService.approvedStatus,
        'visibility_status': isMinor
            ? GuardianMvpService.limitedVisibility
            : GuardianMvpService.activeVisibility,
      };
      if (normalizedState.isNotEmpty) {
        userPayload.addAll({
          'state': normalizedState,
          'estado': normalizedState,
          'province': normalizedState,
          'provincia': normalizedState,
          'region': normalizedState,
        });
      }

      final fallbackPayload = {
        ...userPayload,
        'usertype': userType,
      }..remove('userType');

      final legacyUserPayload = Map<String, dynamic>.from(userPayload)
        ..remove('guardian_status')
        ..remove('visibility_status')
        ..remove('estado')
        ..remove('province')
        ..remove('provincia')
        ..remove('region')
        ..remove('ciudad');
      final legacyFallbackPayload = Map<String, dynamic>.from(fallbackPayload)
        ..remove('guardian_status')
        ..remove('visibility_status')
        ..remove('estado')
        ..remove('province')
        ..remove('provincia')
        ..remove('region')
        ..remove('ciudad');

      Future<void> persistUsersPayload(Map<String, dynamic> payload) async {
        final updatePayload = Map<String, dynamic>.from(payload)
          ..remove('created_at')
          ..remove('user_id');

        try {
          await SupaFlow.client.from('users').upsert(
                payload,
                onConflict: 'user_id',
              );
          return;
        } catch (upsertError) {
          // Alguns ambientes têm conflito na PK (users_pkey) mesmo com user_id.
          final msg = upsertError.toString().toLowerCase();
          if (!msg.contains('users_pkey') && !msg.contains('duplicate key')) {
            rethrow;
          }
        }

        // Fallback defensivo: atualiza por user_id ou id se o registro já existe.
        try {
          await SupaFlow.client
              .from('users')
              .update(updatePayload)
              .eq('user_id', uid);
          return;
        } catch (_) {}

        try {
          await SupaFlow.client
              .from('users')
              .update(updatePayload)
              .eq('id', uid);
          return;
        } catch (_) {}

        // Última tentativa explícita de insert.
        await SupaFlow.client.from('users').insert(payload);
      }

      try {
        await persistUsersPayload(userPayload);
      } catch (_) {
        try {
          await persistUsersPayload(fallbackPayload);
        } catch (_) {
          try {
            await persistUsersPayload(legacyUserPayload);
          } catch (_) {
            await persistUsersPayload(legacyFallbackPayload);
          }
        }
      }

      // guardians.player_id references public.players.id, so players row must
      // exist before inserting guardian data.
      if (userType == 'jugador' ||
          userType == 'jogador' ||
          userType == 'player' ||
          userType == 'athlete' ||
          userType == 'atleta') {
        Future<bool> playerExists() async {
          try {
            final existing = await SupaFlow.client
                .from('players')
                .select('id')
                .eq('id', uid)
                .maybeSingle();
            return existing != null;
          } catch (_) {
            return false;
          }
        }

        if (!await playerExists()) {
          try {
            await SupaFlow.client.from('players').insert(
              {
                'id': uid,
                'created_at': nowIso,
              },
            );
          } catch (insertPlayerError) {
            final msg = insertPlayerError.toString().toLowerCase();
            if (!msg.contains('duplicate key')) {
              try {
                await SupaFlow.client.from('players').upsert(
                  {
                    'id': uid,
                    'created_at': nowIso,
                  },
                  onConflict: 'id',
                );
              } catch (_) {
                // Última validação: se ainda não existe, falha explicitamente.
                if (!await playerExists()) rethrow;
              }
            }
          }
        }
      }

      if (FFAppState.normalizeUserType(userType) == 'profesional') {
        Future<bool> scoutExists() async {
          try {
            final existing = await SupaFlow.client
                .from('scouts')
                .select('id')
                .eq('id', uid)
                .maybeSingle();
            return existing != null;
          } catch (_) {
            return false;
          }
        }

        if (!await scoutExists()) {
          final scoutPayload = <String, dynamic>{
            'id': uid,
            'created_at': nowIso,
            'telephone': '',
            'club': _clubController.text.trim(),
            'organization_type': _selectedOrganizationType ?? '',
            'current_role': _currentRoleController.text.trim(),
            'work_zone': _workZoneController.text.trim(),
            'city': normalizedCity,
            'ciudad': normalizedCity,
            'country': selectedCountryName,
            'pais': selectedCountryName,
            if (normalizedState.isNotEmpty) 'state': normalizedState,
            if (normalizedState.isNotEmpty) 'estado': normalizedState,
            if (normalizedState.isNotEmpty) 'province': normalizedState,
            if (normalizedState.isNotEmpty) 'provincia': normalizedState,
            if (normalizedState.isNotEmpty) 'region': normalizedState,
          };
          final minimalScoutPayload = <String, dynamic>{
            'id': uid,
            'created_at': nowIso,
            'telephone': '',
            'club': _clubController.text.trim(),
          };
          var savedScout = false;

          try {
            await SupaFlow.client.from('scouts').insert(scoutPayload);
            savedScout = true;
          } catch (insertScoutError) {
            final msg = insertScoutError.toString().toLowerCase();
            if (msg.contains('duplicate key')) {
              savedScout = true;
            } else {
              try {
                await SupaFlow.client.from('scouts').insert(
                      minimalScoutPayload,
                    );
                savedScout = true;
              } catch (minimalScoutError) {
                final minimalMsg = minimalScoutError.toString().toLowerCase();
                if (minimalMsg.contains('duplicate key')) {
                  savedScout = true;
                }
              }
            }
          }

          if (!savedScout && !await scoutExists()) {
            throw Exception('No se pudo crear el perfil profesional.');
          }
        }
      }

      // Se menor, salvar guardian
      var guardianEmailSent = false;
      if (isMinor) {
        final approvalCodeExpiresAt = DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .toIso8601String();
        final guardianEmail =
            _guardianEmailController.text.trim().toLowerCase();
        final guardianPayload = {
          'name': 'Responsable legal',
          'relationship': _guardianRelationship,
          'email': guardianEmail,
          'player_id': uid,
          'status': GuardianMvpService.pendingStatus,
          'approval_code': approvalCode,
          'approval_code_expires_at': approvalCodeExpiresAt,
          'approval_code_used_at': null,
          'approved_at': null,
        };
        final legacyGuardianPayload = Map<String, dynamic>.from(guardianPayload)
          ..remove('status')
          ..remove('approval_code')
          ..remove('approval_code_expires_at')
          ..remove('approval_code_used_at')
          ..remove('approved_at');
        try {
          await SupaFlow.client.from('guardians').insert(guardianPayload);
        } catch (guardianInsertError) {
          final msg = guardianInsertError.toString().toLowerCase();
          if (msg.contains('duplicate key') ||
              msg.contains('unique') ||
              msg.contains('guardians_player_id')) {
            try {
              await SupaFlow.client
                  .from('guardians')
                  .update(guardianPayload)
                  .eq('player_id', uid);
            } catch (_) {
              await SupaFlow.client
                  .from('guardians')
                  .update(legacyGuardianPayload)
                  .eq('player_id', uid);
            }
          } else if (msg.contains('column') ||
              msg.contains('approval_code') ||
              msg.contains('status')) {
            try {
              await SupaFlow.client
                  .from('guardians')
                  .insert(legacyGuardianPayload);
            } catch (_) {
              await SupaFlow.client
                  .from('guardians')
                  .update(legacyGuardianPayload)
                  .eq('player_id', uid);
            }
          } else {
            rethrow;
          }
        }

        // Marca guardian somente após sucesso no insert/update.
        try {
          await SupaFlow.client.from('users').update({
            'has_guardian': true,
            'guardian_status': GuardianMvpService.pendingStatus,
            'visibility_status': GuardianMvpService.limitedVisibility,
          }).eq('user_id', uid);
        } catch (_) {
          try {
            await SupaFlow.client.from('users').update({
              'has_guardian': true,
              'guardian_status': GuardianMvpService.pendingStatus,
              'visibility_status': GuardianMvpService.limitedVisibility,
            }).eq('id', uid);
          } catch (_) {
            try {
              await SupaFlow.client
                  .from('users')
                  .update({'has_guardian': true}).eq('user_id', uid);
            } catch (_) {
              await SupaFlow.client
                  .from('users')
                  .update({'has_guardian': true}).eq('id', uid);
            }
          }
        }

        if (approvalCode != null && approvalCode.isNotEmpty) {
          guardianEmailSent = await EmailService.sendGuardianValidationEmail(
            playerId: uid,
            guardianEmail: guardianEmail,
            playerName: normalizedName.isNotEmpty ? normalizedName : 'Jugador',
            approvalCode: approvalCode,
          );
        }
      }

      FFAppState().userType = userType;
      FFAppState().registrationFlowActive = false;
      await FFAppState().syncUserType();

      if (isMinor &&
          approvalCode != null &&
          approvalCode.isNotEmpty &&
          mounted) {
        await _showGuardianApprovalCodeDialog(
          approvalCode: approvalCode,
          guardianEmail: _guardianEmailController.text.trim(),
          emailSent: guardianEmailSent,
        );

        // The minor must NOT access the app until the guardian approves.
        FFAppState().authBlockMessage =
            'Cuenta creada. El adulto responsable debe aprobar el acceso '
            'usando el código de aprobación desde la pantalla de login.';
        FFAppState().registrationFlowActive = false;
        if (mounted) {
          context.goNamed('login');
        }
        return;
      }

      if (!mounted) return;
      if (userType == 'club') {
        context.goNamed('dashboard_club');
      } else {
        context.goNamed('feed');
      }
    } catch (e) {
      debugPrint('Error al guardar perfil durante registro: $e');
      await _abortIncompleteRegistration(e);
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _abortIncompleteRegistration(Object error) async {
    FFAppState().authBlockMessage =
        'No se completó el registro. Crea la cuenta nuevamente.';
    FFAppState().registrationFlowActive = false;
    try {
      await authManager.signOut();
    } catch (signOutError) {
      debugPrint('Error al cerrar sesión tras registro fallido: $signOutError');
    }
    if (!mounted) return;
    context.goNamed('login');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF0D3B66),
      ),
    );
  }

  Future<void> _showGuardianApprovalCodeDialog({
    required String approvalCode,
    required String guardianEmail,
    required bool emailSent,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Código del responsable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emailSent && guardianEmail.isNotEmpty
                  ? 'La cuenta quedó en modo limitado hasta que el adulto responsable apruebe el acceso. Enviamos el código de aprobación a $guardianEmail.'
                  : 'La cuenta quedó en modo limitado hasta que el adulto responsable apruebe el acceso. No pudimos enviar el e-mail automáticamente; inicia sesión y usa la opción de reenviar el código.',
            ),
            const SizedBox(height: 14),
            if (emailSent)
              const Text(
                'Pídele que revise la bandeja de entrada y spam. El código vence en 7 días.',
              )
            else
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: SelectableText(
                  approvalCode,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D3B66),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              emailSent
                  ? 'El responsable puede aprobarlo desde la pantalla de login usando el código recibido.'
                  : 'El responsable puede aprobarlo desde la pantalla de login cuando el reenvío funcione.',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D3B66),
            ),
            child: const Text(
              'Entendido',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: Column(
            children: [
              // TabBar (indicadores)
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2B6CB0),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF2B6CB0),
                indicatorWeight: 4,
                padding: EdgeInsets.all(
                    _responsive(context, mobile: 16, tablet: 24, desktop: 32)),
                tabs: const [
                  Tab(text: '                        '),
                  Tab(text: '                          '),
                  Tab(text: '                        '),
                  Tab(text: '                        '),
                  Tab(text: '                        '),
                ],
              ),

              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildTab1Intro(context),
                    _buildTab2Register(context),
                    _buildTab3Profile(context),
                    _buildTab4Community(context),
                    _buildTab5Guardian(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== TAB 1: INTRODUÇÃO =====
  Widget _buildTab1Intro(BuildContext context) {
    final scale = _scaleFactor(context);
    final screenHeight = MediaQuery.of(context).size.height;

    final logoSize =
        _responsive(context, mobile: 100, tablet: 122, desktop: 140) * scale;
    final titleFontSize =
        _responsive(context, mobile: 24, tablet: 28, desktop: 32) * scale;
    final subtitleFontSize =
        _responsive(context, mobile: 14, tablet: 16, desktop: 18) * scale;
    final cardSize =
        _responsive(context, mobile: 95, tablet: 109, desktop: 120) * scale;
    final cardSpacing = _responsive(context, mobile: 6, tablet: 8, desktop: 10);
    final buttonWidth =
        _responsive(context, mobile: 320, tablet: 357, desktop: 400);
    final horizontalPadding =
        _responsive(context, mobile: 20, tablet: 40, desktop: 60);
    final welcome = _introWelcomeContent;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: screenHeight * 0.05),

            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logoftp_1.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D3B66),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.sports_soccer,
                      color: Colors.white, size: logoSize * 0.5),
                ),
              ),
            ),

            SizedBox(height: 16 * scale),

            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14 * scale,
                vertical: 8 * scale,
              ),
              decoration: BoxDecoration(
                color: welcome.accent.withAlpha(24),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: welcome.accent.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    welcome.badgeIcon,
                    color: welcome.accent,
                    size: 18 * scale,
                  ),
                  SizedBox(width: 8 * scale),
                  Text(
                    welcome.eyebrow,
                    style: GoogleFonts.inter(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w800,
                      color: welcome.accent,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 14 * scale),

            // Título
            Text(
              welcome.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),

            SizedBox(height: 12 * scale),

            // Subtítulo
            Text(
              welcome.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: subtitleFontSize,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

            SizedBox(height: screenHeight * 0.05),

            // Cards de benefícios
            Wrap(
              alignment: WrapAlignment.center,
              spacing: cardSpacing,
              runSpacing: cardSpacing,
              children: [
                for (final benefit in welcome.benefits)
                  _buildBenefitCard(
                    benefit.title,
                    benefit.icon,
                    cardSize,
                    welcome.accent,
                  ),
              ],
            ),

            SizedBox(height: screenHeight * 0.06),

            // Botón Siguiente
            _buildPrimaryButton(
              context: context,
              text: welcome.primaryButton,
              onPressed: _goToNextTab,
              width: buttonWidth,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard(
      String title, IconData icon, double size, Color accent) {
    final scale = _scaleFactor(context);
    return Container(
      width: size,
      height: size * 0.9,
      padding: EdgeInsets.symmetric(horizontal: 6 * scale),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26 * scale),
          SizedBox(height: 8 * scale),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ===== TAB 2: REGISTRO =====
  Widget _buildTab2Register(BuildContext context) {
    final scale = _scaleFactor(context);
    final buttonWidth =
        _responsive(context, mobile: 320, tablet: 337, desktop: 400);

    return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal:
                _responsive(context, mobile: 20, tablet: 40, desktop: 60)),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 20 * scale),
                child: Text(
                  'Crea tu cuenta',
                  style: GoogleFonts.inter(
                    fontSize: _responsive(context,
                            mobile: 24, tablet: 28, desktop: 32) *
                        scale,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D3B66),
                  ),
                ),
              ),
              SizedBox(height: 30 * scale),
              _buildTextField(
                context: context,
                label: 'Correo electrónico',
                hint: 'tu.correo@ejemplo.com',
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                width: double.infinity,
              ),
              SizedBox(height: 15 * scale),
              _buildTextField(
                context: context,
                label: 'Contraseña',
                hint: 'Crea una contraseña segura',
                controller: _senhaController,
                focusNode: _senhaFocusNode,
                keyboardType: TextInputType.visiblePassword,
                obscureText: !_senhaVisibility,
                autofillHints: const [AutofillHints.newPassword],
                width: double.infinity,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                suffixIcon: IconButton(
                  icon: Icon(_senhaVisibility
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _senhaVisibility = !_senhaVisibility),
                ),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: 10 * scale),
              _buildPasswordRequirements(context, width: double.infinity),
              SizedBox(height: 15 * scale),
              _buildTextField(
                context: context,
                label: 'Confirmar contraseña',
                hint: 'Confirma tu contraseña',
                controller: _confirmarSenhaController,
                focusNode: _confirmarSenhaFocusNode,
                keyboardType: TextInputType.visiblePassword,
                obscureText: !_confirmarSenhaVisibility,
                width: double.infinity,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                suffixIcon: IconButton(
                  icon: Icon(_confirmarSenhaVisibility
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () => setState(() =>
                      _confirmarSenhaVisibility = !_confirmarSenhaVisibility),
                ),
              ),
              SizedBox(height: 30 * scale),
              _buildPrimaryButton(
                context: context,
                text: _isRegistering ? 'Registrando...' : 'Registrarse',
                onPressed: _isRegistering ? null : _registerWithEmail,
                width: buttonWidth,
              ),
              SizedBox(height: 30 * scale),
              const Divider(thickness: 2, color: Colors.black),
              SizedBox(height: 30 * scale),
              _buildSocialButton(context, 'Registrarse con Google',
                  FontAwesomeIcons.google, buttonWidth,
                  onPressed: () => _signInWithProvider(OAuthProvider.google)),
              if (isiOS) ...[
                SizedBox(height: 10 * scale),
                _buildSocialButton(
                    context, 'Registrarse con Apple', Icons.apple, buttonWidth,
                    onPressed: () => _signInWithProvider(OAuthProvider.apple)),
              ],
              SizedBox(height: 20 * scale),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20 * scale),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿Ya tienes cuenta? ',
                        style: GoogleFonts.inter(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF444444))),
                    GestureDetector(
                      onTap: () => context.pushNamed('login'),
                      child: Text('Iniciar sesión',
                          style: GoogleFonts.inter(
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D3B66),
                              decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildSocialButton(
      BuildContext context, String text, dynamic icon, double width,
      {VoidCallback? onPressed}) {
    final scale = _scaleFactor(context);
    return SizedBox(
      width: width,
      height: 50 * scale,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon is IconData
            ? Icon(icon,
                size: icon == Icons.apple ? 28 * scale : 15 * scale,
                color: const Color(0xFF444444))
            : FaIcon(icon, size: 15 * scale, color: const Color(0xFF444444)),
        label: Text(text,
            style: GoogleFonts.inter(
                fontSize: 13 * scale,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF444444))),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEAF6FC),
          elevation: 0,
          side: const BorderSide(color: Color(0xFFA39F9F)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ===== TAB 3: PERFIL =====
  Widget _buildTab3Profile(BuildContext context) {
    final scale = _scaleFactor(context);
    final buttonWidth =
        _responsive(context, mobile: 145, tablet: 157, desktop: 180);
    final isProfessional = _isProfessionalRegistration;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal:
              _responsive(context, mobile: 20, tablet: 40, desktop: 60)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 20 * scale),
            child: Text(
              isProfessional ? 'Perfil de scouting' : 'Verificación de edad',
              style: GoogleFonts.inter(
                fontSize:
                    _responsive(context, mobile: 24, tablet: 28, desktop: 32) *
                        scale,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
          ),
          SizedBox(height: 30 * scale),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14 * scale),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD7E0EA)),
            ),
            child: Text(
              isProfessional
                  ? 'Completá tus datos básicos para activar un perfil profesional de scouting. Los perfiles scout deben ser de mayores de 18 años.'
                  : 'FutbolTalent es una plataforma para jugadores a partir de 13 años.',
              style: GoogleFonts.inter(
                fontSize: 13 * scale,
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 18 * scale),
          _buildTextField(
            context: context,
            label: isProfessional ? 'Nombre completo' : 'Me llamo',
            hint: 'Nombre',
            controller: _nameController,
            focusNode: _nameFocusNode,
            textCapitalization: TextCapitalization.words,
            width: double.infinity,
          ),
          SizedBox(height: 15 * scale),
          _buildTextField(
            context: context,
            label: 'Fecha de nacimiento',
            hint: 'DD/MM/AAAA',
            controller: _dataNascimentoController,
            focusNode: _dataNascimentoFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [_dataNascimentoMask],
            width: double.infinity,
            suffixIcon: const Icon(Icons.calendar_month),
          ),
          SizedBox(height: 15 * scale),
          _buildCountryDropdown(context),
          SizedBox(height: 15 * scale),
          _buildStateDropdown(context),
          SizedBox(height: 15 * scale),
          _buildCityDropdown(context),
          if (isProfessional) ...[
            SizedBox(height: 18 * scale),
            _buildProfessionalRegistrationFields(context),
          ],
          SizedBox(height: 24 * scale),
          _buildTermsCheckbox(context),
          SizedBox(height: 32 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: buttonWidth,
                height: 43 * scale,
                child: ElevatedButton(
                  onPressed: _goToPreviousTab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B6CB0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Anterior',
                      style: GoogleFonts.inter(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
              SizedBox(width: 20 * scale),
              SizedBox(
                width: buttonWidth,
                height: 43 * scale,
                child: ElevatedButton(
                  onPressed: _isSavingProfile ? null : _onProfileNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_isSavingProfile ? 'Guardando...' : 'Siguiente',
                      style: GoogleFonts.inter(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ===== TAB 4: SEGURIDAD DE LA COMUNIDAD =====
  Widget _buildTab4Community(BuildContext context) {
    final scale = _scaleFactor(context);
    final buttonWidth =
        _responsive(context, mobile: 145, tablet: 157, desktop: 180);
    final isProfessional = _isProfessionalRegistration;
    final title =
        isProfessional ? 'Scouting seguro' : 'Seguridad de la comunidad';
    final intro = isProfessional
        ? 'FutbolTalent ayuda a scouts y clubes a evaluar talento sin exponer datos personales ni abrir contactos fuera de la plataforma.'
        : 'FutbolTalent es una plataforma de scouting deportivo diseñada para ayudar a jugadores a mostrar su talento a scouts y clubes.';
    final contextLine = isProfessional
        ? 'Como perfil profesional, recordá:'
        : 'Para proteger a los jugadores menores de edad:';
    final rules = isProfessional
        ? const [
            'no solicites datos personales o contacto privado fuera de FutbolTalent',
            'usa las solicitudes de contacto mediadas por la plataforma',
            'evalúa perfiles y videos con respeto y criterio profesional',
            'guarda jugadores solo para seguimiento deportivo legítimo',
          ]
        : const [
            'no existe chat ni mensajes privados entre jugadores y scouts',
            'no publiques datos personales o de contacto',
            'scouts y clubes solo pueden solicitar contacto a través de la plataforma',
            'los perfiles y videos pueden ser visibles para scouts y clubes registrados',
          ];

    Widget ruleItem(String text) {
      return Padding(
        padding: EdgeInsets.only(bottom: 10 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 4 * scale),
              child: const Icon(
                Icons.check_circle_outline,
                size: 18,
                color: Color(0xFF0D3B66),
              ),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13 * scale,
                  color: const Color(0xFF334155),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: _responsive(context, mobile: 20, tablet: 40, desktop: 60),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 20 * scale),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize:
                    _responsive(context, mobile: 24, tablet: 28, desktop: 32) *
                        scale,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
          ),
          SizedBox(height: 22 * scale),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18 * scale),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD7E0EA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intro,
                  style: GoogleFonts.inter(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 14 * scale),
                Text(
                  contextLine,
                  style: GoogleFonts.inter(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 14 * scale),
                ...rules.map(ruleItem),
              ],
            ),
          ),
          SizedBox(height: 18 * scale),
          CheckboxListTile(
            value: _acceptedCommunityRules,
            onChanged: (value) =>
                setState(() => _acceptedCommunityRules = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Entiendo y acepto las reglas de la comunidad',
              style: GoogleFonts.inter(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          SizedBox(height: 26 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: buttonWidth,
                height: 43 * scale,
                child: ElevatedButton(
                  onPressed: _goToPreviousTab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B6CB0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Anterior',
                    style: GoogleFonts.inter(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 20 * scale),
              SizedBox(
                width: buttonWidth,
                height: 43 * scale,
                child: ElevatedButton(
                  onPressed: _isSavingProfile ? null : _onCommunityNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _shouldShowGuardianStep ? 'Continuar' : 'Activar cuenta',
                    style: GoogleFonts.inter(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ===== TAB 5: RESPONSABLE (13-17) =====
  Widget _buildTab5Guardian(BuildContext context) {
    final scale = _scaleFactor(context);
    final buttonWidth =
        _responsive(context, mobile: 145, tablet: 157, desktop: 180);

    Widget consentItem(IconData icon, String text) {
      return Padding(
        padding: EdgeInsets.only(bottom: 10 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 3 * scale),
              child: Icon(
                icon,
                size: 18 * scale,
                color: const Color(0xFF0D3B66),
              ),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13 * scale,
                  color: const Color(0xFF334155),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal:
              _responsive(context, mobile: 20, tablet: 40, desktop: 60)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 20 * scale),
            child: Text(
              'Responsable',
              style: GoogleFonts.inter(
                fontSize:
                    _responsive(context, mobile: 24, tablet: 28, desktop: 32) *
                        scale,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
          ),
          SizedBox(height: 12 * scale),
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD7E0EA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Si tienes menos de 18 años, un padre, madre o tutor debe autorizar el uso de la plataforma.',
                  style: GoogleFonts.inter(
                    fontSize: 13 * scale,
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 10 * scale),
                Text(
                  'Tu responsable también deberá autorizar la publicación de videos y el eventual contacto mediado con scouts o clubes.',
                  style: GoogleFonts.inter(
                    fontSize: 13 * scale,
                    color: const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 14 * scale),
                Text(
                  'Al autorizar el uso de la cuenta, el responsable acepta:',
                  style: GoogleFonts.inter(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 12 * scale),
                consentItem(Icons.description_outlined, 'términos de uso'),
                consentItem(
                    Icons.privacy_tip_outlined, 'política de privacidad'),
                consentItem(Icons.photo_camera_back_outlined,
                    'autorización de uso de imagen'),
                consentItem(Icons.video_library_outlined,
                    'publicación de videos en la plataforma'),
              ],
            ),
          ),
          SizedBox(height: 24 * scale),
          _buildTextField(
            context: context,
            label: 'Correo del adulto responsable',
            hint: 'correo@ejemplo.com',
            controller: _guardianEmailController,
            focusNode: _guardianEmailFocusNode,
            keyboardType: TextInputType.emailAddress,
            width: double.infinity,
          ),
          SizedBox(height: 16 * scale),
          Text(
            'El responsable recibirá una notificación si un scout o club solicita contacto.',
            style: GoogleFonts.inter(
              fontSize: 13 * scale,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 12 * scale),
          CheckboxListTile(
            value: _guardianAuthorized,
            onChanged: (value) =>
                setState(() => _guardianAuthorized = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Confirmo que mi responsable autorizó el uso de FutbolTalent',
              style: GoogleFonts.inter(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          SizedBox(height: 60 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: buttonWidth,
                height: 43 * scale,
                child: ElevatedButton(
                  onPressed: _goToPreviousTab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B6CB0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Anterior',
                      style: GoogleFonts.inter(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
              SizedBox(width: 20 * scale),
              SizedBox(
                width: buttonWidth,
                height: 43 * scale,
                child: ElevatedButton(
                  onPressed: _isSavingProfile ? null : _saveProfileAndFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_isSavingProfile ? 'Guardando...' : 'Continuar',
                      style: GoogleFonts.inter(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfessionalRegistrationFields(BuildContext context) {
    final scale = _scaleFactor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datos profesionales',
          style: GoogleFonts.inter(
            fontSize: 15 * scale,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D3B66),
          ),
        ),
        SizedBox(height: 10 * scale),
        _buildSimpleDropdown(
          context: context,
          label: 'Tipo de perfil profesional',
          hint: 'Selecciona una opción',
          value: _selectedOrganizationType,
          options: _organizationTypeOptions,
          onChanged: (value) =>
              setState(() => _selectedOrganizationType = value),
        ),
        SizedBox(height: 15 * scale),
        _buildTextField(
          context: context,
          label: 'Rol actual',
          hint: 'Scout, analista, entrenador...',
          controller: _currentRoleController,
          focusNode: _currentRoleFocusNode,
          width: double.infinity,
        ),
        SizedBox(height: 15 * scale),
        _buildTextField(
          context: context,
          label: 'Club / organización',
          hint: 'Nombre del club o red de scouting',
          controller: _clubController,
          focusNode: _clubFocusNode,
          width: double.infinity,
        ),
        SizedBox(height: 15 * scale),
        _buildTextField(
          context: context,
          label: 'Zona de trabajo',
          hint: 'Buenos Aires, LATAM, España norte...',
          controller: _workZoneController,
          focusNode: _workZoneFocusNode,
          width: double.infinity,
        ),
      ],
    );
  }

  Widget _buildSimpleDropdown({
    required BuildContext context,
    required String label,
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final scale = _scaleFactor(context);
    final fontSize = 13 * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8 * scale),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFA0AEC0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : null,
              hint: Text(
                hint,
                style: GoogleFonts.inter(
                  fontSize: fontSize,
                  color: const Color(0xFF2F3336),
                ),
              ),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: options
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: GoogleFonts.inter(fontSize: fontSize),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryDropdown(BuildContext context) {
    final scale = _scaleFactor(context);
    final fontSize = 13 * scale;
    final selectedCountryName = _paisController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8 * scale),
          child: Text('País',
              style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black)),
        ),
        GestureDetector(
          onTap: _countries.isEmpty
              ? null
              : () async {
                  final countryName = await showGeoSelectionBottomSheet(
                    context: context,
                    title: 'Selecciona el país',
                    options: _countries.map(
                      (country) => country['name']?.toString() ?? '',
                    ),
                    selectedValue: selectedCountryName,
                  );
                  if (!mounted || countryName == null) return;

                  final selectedCountry = _countries.firstWhere(
                    (country) =>
                        (country['name']?.toString() ?? '').trim() ==
                        countryName.trim(),
                    orElse: () => <String, dynamic>{},
                  );
                  final countryId = selectedCountry['id']?.toString();
                  if (countryId == null || countryId.isEmpty) return;

                  setState(() {
                    _selectedCountryId = countryId;
                    _paisController.text = countryName;
                    _selectedState = null;
                    _states = [];
                    _cities = [];
                    _selectedCity = null;
                    _cidadeController.text = '';
                    _cityFreeText = false;
                    _isStatesLoading = true;
                  });
                  _loadStates(countryName);
                },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 14 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFA0AEC0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedCountryName.isNotEmpty
                        ? selectedCountryName
                        : (_countries.isEmpty
                            ? 'Cargando países...'
                            : 'Selecciona el país'),
                    style: GoogleFonts.inter(
                      fontSize: fontSize,
                      color: selectedCountryName.isNotEmpty
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const _LegalModal(
          title: 'Términos de Uso',
          content: '''
TÉRMINOS DE USO DE FUTBOLTALENT

Última actualización: 2025

1. ACEPTACIÓN DE LOS TÉRMINOS
Al crear una cuenta y utilizar FutbolTalent, aceptas estos Términos de Uso en su totalidad. Si no estás de acuerdo, no utilices la plataforma.

2. DESCRIPCIÓN DEL SERVICIO
FutbolTalent es una plataforma digital que conecta jugadores de fútbol, entrenadores, clubes y ojeadores. Los usuarios pueden crear perfiles, publicar contenido deportivo y acceder a recursos de formación.

3. REGISTRO Y CUENTA
- Debes tener al menos 13 años para usar la plataforma.
- Los menores de 18 años requieren consentimiento de un tutor legal.
- Eres responsable de mantener la confidencialidad de tus credenciales.
- Debes proporcionar información veraz y actualizada.

4. USO ACEPTABLE
Queda prohibido:
- Publicar contenido falso, ofensivo o ilegal.
- Suplantar la identidad de otras personas.
- Usar la plataforma con fines comerciales no autorizados.
- Acosar, intimidar o amenazar a otros usuarios.
- Compartir contenido de terceros sin autorización.

5. CONTENIDO DEL USUARIO
Al publicar contenido en FutbolTalent, nos otorgas una licencia no exclusiva para mostrar y distribuir dicho contenido dentro de la plataforma. Conservas todos los derechos sobre tu contenido.

6. PRIVACIDAD
El tratamiento de tus datos personales se rige por nuestra Política de Privacidad, disponible en la plataforma.

7. PROPIEDAD INTELECTUAL
Todo el contenido de la plataforma (diseño, código, marcas) es propiedad de FutbolTalent y está protegido por las leyes de propiedad intelectual.

8. LIMITACIÓN DE RESPONSABILIDAD
FutbolTalent no garantiza la disponibilidad ininterrumpida del servicio ni la exactitud del contenido publicado por los usuarios.

9. MODIFICACIONES
Podemos actualizar estos términos en cualquier momento. Te notificaremos de los cambios relevantes.

10. CONTACTO
Para cualquier consulta: info@futboltalent.pro
''',
        ),
      ),
    );
  }

  void _showPrivacyModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const _LegalModal(
          title: 'Política de Privacidad',
          content: '''
POLÍTICA DE PRIVACIDAD DE FUTBOLTALENT

Última actualización: 2025

1. RESPONSABLE DEL TRATAMIENTO
FutbolTalent es el responsable del tratamiento de los datos personales recogidos a través de esta aplicación.

2. DATOS QUE RECOPILAMOS
- Datos de registro: nombre, correo electrónico, fecha de nacimiento, país, ciudad.
- Datos de perfil: foto, posición, club, estadísticas deportivas.
- Datos de uso: interacciones, contenidos publicados, videos subidos.
- Datos técnicos: dirección IP, tipo de dispositivo, sistema operativo.

3. FINALIDAD DEL TRATAMIENTO
Utilizamos tus datos para:
- Gestionar tu cuenta y proporcionarte el servicio.
- Conectarte con otros usuarios (jugadores, clubes, ojeadores).
- Personalizar tu experiencia en la plataforma.
- Enviarte notificaciones relacionadas con tu actividad.
- Mejorar y desarrollar nuevas funcionalidades.

4. BASE LEGAL
El tratamiento se basa en tu consentimiento al registrarte y en el interés legítimo de prestar el servicio.

5. CONSERVACIÓN DE DATOS
Conservamos tus datos mientras tu cuenta esté activa. Puedes solicitar la eliminación en cualquier momento.

6. DESTINATARIOS
No compartimos tus datos con terceros salvo:
- Proveedores de servicios técnicos necesarios para operar la plataforma.
- Cuando lo exija la ley o una autoridad competente.

7. DERECHOS DEL USUARIO
Tienes derecho a:
- Acceder a tus datos personales.
- Rectificar datos inexactos.
- Solicitar la supresión de tus datos.
- Oponerte al tratamiento.
- Solicitar la portabilidad de tus datos.

Para ejercer tus derechos, escríbenos a: info@futboltalent.pro

8. MENORES DE EDAD
Los usuarios menores de 18 años deben contar con el consentimiento de su tutor legal para registrarse.

9. SEGURIDAD
Aplicamos medidas técnicas y organizativas para proteger tus datos frente a accesos no autorizados.

10. CAMBIOS EN LA POLÍTICA
Podemos actualizar esta política. Te notificaremos de los cambios relevantes a través de la aplicación.

11. CONTACTO
Para cualquier consulta sobre privacidad: info@futboltalent.pro
''',
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox(BuildContext context) {
    final scale = _scaleFactor(context);
    final fontSize = 13 * scale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptedTerms,
            activeColor: const Color(0xFF0D3B66),
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          ),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                    fontSize: fontSize, color: const Color(0xFF334155)),
                children: [
                  const TextSpan(text: 'He leído y acepto los '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => _showTermsModal(context),
                      child: Text(
                        'Términos de uso',
                        style: GoogleFonts.inter(
                          fontSize: fontSize,
                          color: const Color(0xFF2B6CB0),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' y la '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => _showPrivacyModal(context),
                      child: Text(
                        'Política de privacidad',
                        style: GoogleFonts.inter(
                          fontSize: fontSize,
                          color: const Color(0xFF2B6CB0),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' de FutbolTalent.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateDropdown(BuildContext context) {
    final scale = _scaleFactor(context);
    final fontSize = 13 * scale;
    final countryName = _paisController.text;
    // Si el país no tiene estados (modo fallback), no muestra este campo
    if (_selectedState == '__all__' && _states.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8 * scale),
          child: Text('Estado / Provincia',
              style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black)),
        ),
        if (_isStatesLoading)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: 16 * scale, vertical: 14 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFA0AEC0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              SizedBox(
                width: 16 * scale,
                height: 16 * scale,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10 * scale),
              Text('Cargando estados...',
                  style: GoogleFonts.inter(
                      fontSize: fontSize, color: const Color(0xFF2F3336))),
            ]),
          )
        else if (_states.isNotEmpty)
          GestureDetector(
            onTap: () => _showSearchableBottomSheet(
              title: 'Selecciona el estado',
              items: _states,
              selectedValue: _selectedState,
              onSelected: (v) {
                setState(() {
                  _selectedState = v;
                  _isCitiesLoading = true;
                });
                _loadCitiesByState(countryName, v);
              },
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale, vertical: 14 * scale),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFA0AEC0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedState ?? 'Selecciona el estado',
                      style: GoogleFonts.inter(
                        fontSize: fontSize,
                        color: _selectedState != null
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          )
        else
          TextField(
            controller: TextEditingController(),
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(fontSize: fontSize),
            decoration: InputDecoration(
              hintText: 'Escribe el estado / provincia',
              hintStyle: GoogleFonts.inter(
                  fontSize: fontSize, color: const Color(0xFF2F3336)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16 * scale, vertical: 14 * scale),
              enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFA0AEC0)),
                  borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF2B6CB0)),
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    );
  }

  Widget _buildCityDropdown(BuildContext context) {
    final scale = _scaleFactor(context);
    final fontSize = 13 * scale;
    // Só mostra o campo cidade se um estado foi selecionado
    if (_selectedState == null || _selectedState!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8 * scale),
          child: Text('Ciudad',
              style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black)),
        ),
        if (_isCitiesLoading)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: 16 * scale, vertical: 14 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFA0AEC0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              SizedBox(
                width: 16 * scale,
                height: 16 * scale,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10 * scale),
              Text('Cargando ciudades...',
                  style: GoogleFonts.inter(
                      fontSize: fontSize, color: const Color(0xFF2F3336))),
            ]),
          )
        else if (_cities.isNotEmpty && !_cityFreeText)
          GestureDetector(
            onTap: () => _showSearchableBottomSheet(
              title: 'Selecciona la ciudad',
              items: _cities,
              selectedValue: _selectedCity,
              onSelected: (v) {
                setState(() {
                  _selectedCity = v;
                  _cidadeController.text = v;
                });
              },
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale, vertical: 14 * scale),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFA0AEC0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCity ?? 'Selecciona la ciudad',
                      style: GoogleFonts.inter(
                        fontSize: fontSize,
                        color: _selectedCity != null
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          )
        else
          const SizedBox.shrink(),
      ],
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

  Widget _buildPasswordRequirements(
    BuildContext context, {
    required double width,
  }) {
    final scale = _scaleFactor(context);
    final rules = PasswordPolicy.rules(_senhaController.text);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu contraseña debe tener:',
            style: GoogleFonts.inter(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8 * scale),
          ...rules.map((rule) {
            final color =
                rule.isMet ? const Color(0xFF168A3A) : const Color(0xFF6B7280);
            return Padding(
              padding: EdgeInsets.only(bottom: 6 * scale),
              child: Row(
                children: [
                  Icon(
                    rule.isMet
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16 * scale,
                    color: color,
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: Text(
                      rule.label,
                      style: GoogleFonts.inter(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required double width,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    bool autocorrect = true,
    bool enableSuggestions = true,
    ValueChanged<String>? onChanged,
    Iterable<String>? autofillHints,
  }) {
    final scale = _scaleFactor(context);
    final fontSize = 13 * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8 * scale),
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black)),
        ),
        SizedBox(
          width: width,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            autocorrect: autocorrect,
            enableSuggestions: enableSuggestions,
            onChanged: onChanged,
            autofillHints: autofillHints,
            style: GoogleFonts.inter(fontSize: fontSize),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                  fontSize: fontSize, color: const Color(0xFF2F3336)),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: suffixIcon,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16 * scale, vertical: 14 * scale),
              enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFA0AEC0)),
                  borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF2B6CB0)),
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required String text,
    required VoidCallback? onPressed,
    required double width,
  }) {
    final scale = _scaleFactor(context);
    return SizedBox(
      width: width,
      height: 48 * scale,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D3B66),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 15 * scale,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }
}

class _LegalModal extends StatelessWidget {
  const _LegalModal({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF0D3B66),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              content.trim(),
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.6,
                color: const Color(0xFF334155),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Cerrar',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
