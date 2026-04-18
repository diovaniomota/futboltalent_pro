import 'dart:convert';

import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'registro_club_model.dart';
export 'registro_club_model.dart';

class RegistroClubWidget extends StatefulWidget {
  const RegistroClubWidget({super.key});

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
      if (mounted) {
        setState(
            () => _countries = List<Map<String, dynamic>>.from(response ?? []));
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
        await _uploadLogo(bytes, image.name);
      }
    } catch (e) {
      _showError('Error al seleccionar imagen');
    }
  }

  Future<void> _uploadLogo(Uint8List bytes, String fileName) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${currentUserUid}_$timestamp.jpg';
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

    try {
      final response = await http.post(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/states'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': apiCountryName}),
      );

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
            '_loadStates: sin estados para $apiCountryName, activando texto libre');
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

    try {
      final response = await http.post(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/state/cities'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': apiCountryName, 'state': stateName}),
      );

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
    for (var i = 0; i < 4; i++) {
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
    for (var i = 0; i < 4; i++) {
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

  bool _validateStep3() {
    if (_emailController.text.trim().isEmpty) {
      _showError('Por favor, ingresa un email de contacto');
      return false;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showError('Por favor, ingresa un teléfono de contacto');
      return false;
    }
    return true;
  }

  Future<void> _saveClub() async {
    if (!_validateStep3()) return;
    setState(() => _isLoading = true);
    try {
      final sitioWeb = _websiteController.text.isNotEmpty
          ? _websiteController.text
          : _otherUrlController.text;
      final normalizedCountry = normalizeCountryName(_countryController.text);
      final normalizedState = _stateController.text.trim();
      final normalizedCity = normalizeCityName(_cityController.text);

      // Update User
      final existingUser = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', currentUserUid)
          .maybeSingle();
      final userData = {
        'name': _clubNameController.text,
        'city': normalizedCity,
        'state': normalizedState,
        'country': normalizedCountry,
        'country_id': _selectedCountryId != null
            ? int.tryParse(_selectedCountryId!)
            : null,
        'userType': 'club',
        'photo_url': _logoUrl,
        'role_id': 2,
      };
      if (existingUser != null) {
        await SupaFlow.client
            .from('users')
            .update(userData)
            .eq('user_id', currentUserUid);
      } else {
        userData['user_id'] = currentUserUid;
        userData['username'] = _clubNameController.text
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll(RegExp(r'[^a-z0-9_]'), '');
        userData['created_at'] = DateTime.now().toIso8601String();
        try {
          await SupaFlow.client.from('users').insert(userData);
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('users_pkey') || msg.contains('duplicate key')) {
            final updatePayload = Map<String, dynamic>.from(userData)
              ..remove('created_at');
            try {
              await SupaFlow.client
                  .from('users')
                  .update(updatePayload)
                  .eq('user_id', currentUserUid);
            } catch (_) {
              await SupaFlow.client
                  .from('users')
                  .update(updatePayload)
                  .eq('id', currentUserUid);
            }
          } else {
            rethrow;
          }
        }
      }

      // Update Club
      final existingClub = await SupaFlow.client
          .from('clubes')
          .select()
          .eq('id', currentUserUid)
          .maybeSingle();
      final clubData = {
        'email': _emailController.text,
        'telephone': _phoneController.text,
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
        'sitio_web': sitioWeb.isNotEmpty ? sitioWeb : '',
      };
      if (existingClub != null) {
        await _safeUpdate('clubes', clubData, 'id', currentUserUid);
      } else {
        clubData['id'] = currentUserUid;
        clubData['created_at'] = DateTime.now().toIso8601String();
        await _safeInsert('clubes', clubData);
      }

      // Also create/update in 'clubs' table (used by all club screens)
      final existingClubs = await SupaFlow.client
          .from('clubs')
          .select()
          .eq('owner_id', currentUserUid)
          .maybeSingle();
      final clubsData = {
        'nombre': _clubNameController.text,
        'nombre_corto': _clubNameController.text,
        'country': normalizedCountry,
        'state': normalizedState,
        'city': normalizedCity,
        'liga': _leagueController.text.isNotEmpty ? _leagueController.text : '',
        'descripcion': _aboutClubController.text.isNotEmpty
            ? _aboutClubController.text
            : '',
        'sitio_web': sitioWeb.isNotEmpty ? sitioWeb : '',
        'logo_url': _logoUrl,
        'owner_id': currentUserUid,
      };
      if (existingClubs != null) {
        await _safeUpdate('clubs', clubsData, 'owner_id', currentUserUid);
      } else {
        await _safeInsert('clubs', clubsData);
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _ValidationPendingDialog(
            onContinue: () {
              Navigator.pop(context);
              context.goNamed('dashboard_club');
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar clube: $e');
      _showError('Error al guardar: ${e.toString()}');
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
                  child: _buildCurrentStep(),
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
    return Padding(
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
    return Column(children: [
      Text('Crea el perfil de tu Club',
          style: GoogleFonts.inter(
              color: const Color(0xFF0D3B66),
              fontSize: 28,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 30),
      GestureDetector(
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
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF718096)))
                    ]),
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
      _buildLabel('Ciudad'),
      _buildCityDropdown(),
    ]);
  }

  Widget _buildStep2() {
    return Column(children: [
      Text('Contanos sobre el Club',
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
    return Column(children: [
      Text('Contacto y Verificación',
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
      {TextInputType? keyboardType}) {
    return TextField(
        controller: ctrl,
        keyboardType: keyboardType,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
        value: _selectedCountryId,
        hint: const Text('Selecciona país'),
        isExpanded: true,
        items: _countries
            .map((c) => DropdownMenuItem(
                value: c['id'].toString(), child: Text(c['name'])))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          final selected =
              _countries.firstWhere((c) => c['id'].toString() == v);
          final countryName = (selected['name'] ?? '').toString();
          setState(() {
            _selectedCountryId = v;
            _countryController.text = countryName;
            _selectedState = null;
            _stateController.text = '';
            _states = [];
            _stateFreeText = false;
            _selectedCity = null;
            _cityController.text = '';
            _cities = [];
            _cityFreeText = false;
          });
          _loadStates(countryName);
        },
      )),
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
        else if (_stateFreeText || (_states.isEmpty && !_isStatesLoading))
          _buildTextField(_stateController, 'Escribe el estado / provincia')
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value:
                    (_selectedState != null && _states.contains(_selectedState))
                        ? _selectedState
                        : null,
                hint: const Text('Selecciona el estado'),
                isExpanded: true,
                items: _states
                    .map((state) => DropdownMenuItem<String>(
                          value: state,
                          child: Text(state),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedState = v;
                    _stateController.text = v ?? '';
                  });
                  if (v != null) {
                    _loadCitiesByState(_countryController.text, v);
                  }
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCityDropdown() {
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

    if (_cityFreeText) {
      return _buildTextField(_cityController, 'Escribe la ciudad');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: (_selectedCity != null && _cities.contains(_selectedCity))
              ? _selectedCity
              : null,
          hint: Text(
            _selectedCountryId == null
                ? 'Selecciona primero el país'
                : ((_selectedState == null) && !_cityFreeText)
                    ? 'Selecciona primero el estado'
                    : _cities.isEmpty
                        ? 'Sin ciudades disponibles'
                        : 'Selecciona la ciudad',
          ),
          isExpanded: true,
          items: _cities
              .map((city) => DropdownMenuItem<String>(
                    value: city,
                    child: Text(city),
                  ))
              .toList(),
          onChanged: ((_selectedState == null) && !_cityFreeText)
              ? null
              : (v) {
                  setState(() {
                    _selectedCity = v;
                    _cityController.text = v ?? '';
                  });
                },
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
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
                          } else if (_currentStep == 1)
                            setState(() => _currentStep++);
                          else if (_currentStep == 2) _saveClub();
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_currentStep == 2 ? 'Finalizar' : 'Siguiente',
                          style: const TextStyle(color: Colors.white)),
                ))),
      ]),
    );
  }
}

// ===== DIALOG DE VALIDAÇÃO PENDENTE =====
class _ValidationPendingDialog extends StatelessWidget {
  final VoidCallback onContinue;

  const _ValidationPendingDialog({required this.onContinue});

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
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  minimumSize: const Size(0, 43),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Continuar',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
