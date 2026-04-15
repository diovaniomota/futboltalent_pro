import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/fluxo_compartilhado/profile_taxonomy_utils.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/guardian/guardian_mvp_service.dart';
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

  // Focus nodes
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _senhaFocusNode = FocusNode();
  final FocusNode _confirmarSenhaFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _dataNascimentoFocusNode = FocusNode();
  final FocusNode _paisFocusNode = FocusNode();
  final FocusNode _cidadeFocusNode = FocusNode();
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
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
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
    _emailFocusNode.dispose();
    _senhaFocusNode.dispose();
    _confirmarSenhaFocusNode.dispose();
    _nameFocusNode.dispose();
    _dataNascimentoFocusNode.dispose();
    _paisFocusNode.dispose();
    _cidadeFocusNode.dispose();
    _guardianEmailFocusNode.dispose();
    _guardianEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final response =
          await SupaFlow.client.from('countrys').select().order('name');
      if (mounted) {
        setState(() => _countries = List<Map<String, dynamic>>.from(response));
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
    try {
      final uri =
          Uri.parse('https://countriesnow.space/api/v0.1/countries/states');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': apiName}),
      );
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
    setState(() => _isCitiesLoading = true);
    try {
      final uri =
          Uri.parse('https://countriesnow.space/api/v0.1/countries/cities');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': apiCountryName}),
      );
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
              if (_selectedState == null) _selectedState = '__all__';
            });
          }
        }
      }
      // Último recurso: texto libre
      if (_cities.isEmpty && mounted) {
        setState(() {
          _cityFreeText = true;
          if (_selectedState == null) _selectedState = '__all__';
        });
      }
    } catch (e) {
      debugPrint('Error al cargar ciudades directas: $e');
      if (mounted)
        setState(() {
          _cityFreeText = true;
          if (_selectedState == null) _selectedState = '__all__';
        });
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
    try {
      final uri = Uri.parse(
          'https://countriesnow.space/api/v0.1/countries/state/cities');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': apiName, 'state': stateName}),
      );
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
      final success = await SupaFlow.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.futboltalentpro://login-callback/',
      );
      if (!success) {
        _showSnackBar('Error al iniciar sesión con ${provider.name}');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
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
    if (_senhaController.text.isEmpty) {
      _showSnackBar('Por favor ingresa una contraseña');
      return;
    }
    if (_senhaController.text != _confirmarSenhaController.text) {
      _showSnackBar('Las contraseñas no coinciden');
      return;
    }
    if (_senhaController.text.length < 6) {
      _showSnackBar('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final user = await authManager.createAccountWithEmail(
        context,
        _emailController.text.trim(),
        _senhaController.text,
      );

      if (user == null) {
        _showSnackBar('Error al crear la cuenta. Intenta de nuevo.');
        return;
      }

      _goToNextTab();
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
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
      debugPrint('Erro ao converter data: $e');
    }
    return null;
  }

  String get _normalizedSelectedUserType =>
      (widget.selectedUserType ?? 'jugador').trim().toLowerCase();

  bool get _usesMinorProtectionFlow => const [
        'jugador',
        'jogador',
        'player',
        'athlete',
        'atleta',
      ].contains(_normalizedSelectedUserType);

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
    if (age < 13) {
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

  /// Salva perfil + guardian se menor
  Future<void> _saveProfileAndFinish() async {
    setState(() => _isSavingProfile = true);

    try {
      final uid = currentUserUid.trim();
      if (uid.isEmpty) {
        _showSnackBar('Sesión inválida. Inicia sesión nuevamente.');
        return;
      }

      final birthday = _parseBirthday();
      final age = birthday != null ? _calculateAge(birthday) : 99;
      final isMinor = _usesMinorProtectionFlow && age < 18;

      // Se menor, validar guardian
      if (isMinor) {
        if (_guardianEmailController.text.trim().isEmpty) {
          _showSnackBar('Es necesario el email del adulto responsable');
          setState(() => _isSavingProfile = false);
          return;
        }
        if (!_guardianEmailController.text.trim().contains('@')) {
          _showSnackBar('Ingresá un email válido del responsable.');
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

      final userType = _normalizedSelectedUserType;
      final nowIso = DateTime.now().toIso8601String();
      final approvalCode =
          isMinor ? GuardianMvpService.generateApprovalCode() : null;
      final selectedCountryName = _countries
          .where((country) => country['id']?.toString() == _selectedCountryId)
          .map((country) => normalizeCountryName(country['name']))
          .firstWhere((country) => country.isNotEmpty, orElse: () => '');
      final normalizedCity = normalizeCityName(_cidadeController.text);

      final userPayload = {
        'name': _nameController.text.trim(),
        'birthday': birthday?.toIso8601String(),
        'country_id': _selectedCountryId != null
            ? int.tryParse(_selectedCountryId!) ?? 1
            : 1,
        'country': selectedCountryName,
        'pais': selectedCountryName,
        'city': normalizedCity,
        'userType': userType,
        'user_id': uid,
        'username': _nameController.text.trim(),
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

      final fallbackPayload = {
        ...userPayload,
        'usertype': userType,
      }..remove('userType');

      final legacyUserPayload = Map<String, dynamic>.from(userPayload)
        ..remove('guardian_status')
        ..remove('visibility_status');
      final legacyFallbackPayload = Map<String, dynamic>.from(fallbackPayload)
        ..remove('guardian_status')
        ..remove('visibility_status');

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

      // Se menor, salvar guardian
      if (isMinor) {
        final guardianPayload = {
          'name': 'Responsable legal',
          'relationship': _guardianRelationship,
          'email': _guardianEmailController.text.trim(),
          'player_id': uid,
          'status': GuardianMvpService.pendingStatus,
          'approval_code': approvalCode,
          'approved_at': null,
        };
        final legacyGuardianPayload = Map<String, dynamic>.from(guardianPayload)
          ..remove('status')
          ..remove('approval_code')
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
      }

      FFAppState().userType = userType;

      if (isMinor &&
          approvalCode != null &&
          approvalCode.isNotEmpty &&
          mounted) {
        await _showGuardianApprovalCodeDialog(
          approvalCode: approvalCode,
          guardianEmail: _guardianEmailController.text.trim(),
        );
      }

      if (!mounted) return;
      if (userType == 'club') {
        context.goNamed('dashboard_club');
      } else {
        context.goNamed('feed');
      }
    } catch (e) {
      _showSnackBar('Error al guardar: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
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
              guardianEmail.isNotEmpty
                  ? 'La cuenta quedó en modo limitado hasta que el adulto responsable apruebe el acceso. Compartí este código con $guardianEmail.'
                  : 'La cuenta quedó en modo limitado hasta que el adulto responsable apruebe el acceso. Compartí este código con tu responsable.',
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            const Text(
              'El responsable puede aprobarlo desde la pantalla de login usando este código.',
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

            // Título
            Text(
              'Mostrá tu talento al mundo.',
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
              'Plataforma de scouting y desarrollo de talento en el fútbol.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: subtitleFontSize,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

            SizedBox(height: screenHeight * 0.05),

            // Cards de benefícios
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBenefitCard('Scouting', Icons.travel_explore, cardSize),
                SizedBox(width: cardSpacing),
                _buildBenefitCard('Desarrollo', Icons.school, cardSize),
                SizedBox(width: cardSpacing),
                _buildBenefitCard('Seguridad', Icons.shield, cardSize),
              ],
            ),
            SizedBox(height: cardSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBenefitCard('Videos', Icons.videocam, cardSize),
                SizedBox(width: cardSpacing),
                _buildBenefitCard('Desafíos', Icons.flag, cardSize),
                SizedBox(width: cardSpacing),
                _buildBenefitCard('Explorer', Icons.manage_search, cardSize),
              ],
            ),

            SizedBox(height: screenHeight * 0.06),

            // Botón Siguiente
            _buildPrimaryButton(
              context: context,
              text: 'Crear perfil',
              onPressed: _goToNextTab,
              width: buttonWidth,
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard(String title, IconData icon, double size) {
    final scale = _scaleFactor(context);
    return Container(
      width: size,
      height: size * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF2B6CB0),
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
            style: GoogleFonts.inter(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w500,
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
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 20 * scale),
            child: Text(
              'Crea tu cuenta',
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
          _buildTextField(
            context: context,
            label: 'Correo Electrónico',
            hint: 'tu.correo@ejemplo.com',
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            width: double.infinity,
          ),
          SizedBox(height: 15 * scale),
          _buildTextField(
            context: context,
            label: 'Contraseña',
            hint: 'Crea una contraseña segura',
            controller: _senhaController,
            focusNode: _senhaFocusNode,
            obscureText: !_senhaVisibility,
            width: double.infinity,
            suffixIcon: IconButton(
              icon: Icon(
                  _senhaVisibility ? Icons.visibility : Icons.visibility_off),
              onPressed: () =>
                  setState(() => _senhaVisibility = !_senhaVisibility),
            ),
          ),
          SizedBox(height: 15 * scale),
          _buildTextField(
            context: context,
            label: 'Confirmar Contraseña',
            hint: 'Confirma tu contraseña',
            controller: _confirmarSenhaController,
            focusNode: _confirmarSenhaFocusNode,
            obscureText: !_confirmarSenhaVisibility,
            width: double.infinity,
            suffixIcon: IconButton(
              icon: Icon(_confirmarSenhaVisibility
                  ? Icons.visibility
                  : Icons.visibility_off),
              onPressed: () => setState(
                  () => _confirmarSenhaVisibility = !_confirmarSenhaVisibility),
            ),
          ),
          SizedBox(height: 30 * scale),
          const Divider(thickness: 2, color: Colors.black),
          SizedBox(height: 30 * scale),
          _buildSocialButton(context, 'Registrarse con Google',
              FontAwesomeIcons.google, buttonWidth,
              onPressed: () => _signInWithProvider(OAuthProvider.google)),
          SizedBox(height: 10 * scale),
          _buildSocialButton(
              context, 'Registrarse con Apple', Icons.apple, buttonWidth,
              onPressed: () => _signInWithProvider(OAuthProvider.apple)),
          SizedBox(height: 40 * scale),
          _buildPrimaryButton(
            context: context,
            text: _isRegistering ? 'Registrando...' : 'Registrarse',
            onPressed: _isRegistering ? null : _registerWithEmail,
            width: buttonWidth,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('¿Ya tenes cuenta? ',
                    style: GoogleFonts.inter(
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF444444))),
                GestureDetector(
                  onTap: () => context.pushNamed('login'),
                  child: Text('Iniciar Sesión',
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
    );
  }

  Widget _buildSocialButton(
      BuildContext context, String text, IconData icon, double width,
      {VoidCallback? onPressed}) {
    final scale = _scaleFactor(context);
    return SizedBox(
      width: width,
      height: 50 * scale,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon,
            size: icon == Icons.apple ? 28 * scale : 15 * scale,
            color: const Color(0xFF444444)),
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

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal:
              _responsive(context, mobile: 20, tablet: 40, desktop: 60)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 20 * scale),
            child: Text(
              'Verificación de edad',
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
              'FutbolTalent es una plataforma para jugadores a partir de 13 años.',
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
            label: 'Me llamo',
            hint: 'Nombre',
            controller: _nameController,
            focusNode: _nameFocusNode,
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
          SizedBox(height: 40),
        ],
      ),
    );
  }

  // ===== TAB 4: SEGURIDAD DE LA COMUNIDAD =====
  Widget _buildTab4Community(BuildContext context) {
    final scale = _scaleFactor(context);
    final buttonWidth =
        _responsive(context, mobile: 145, tablet: 157, desktop: 180);

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
              'Seguridad de la comunidad',
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
                  'FutbolTalent es una plataforma de scouting deportivo diseñada para ayudar a jugadores a mostrar su talento a scouts y clubes.',
                  style: GoogleFonts.inter(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 14 * scale),
                Text(
                  'Para proteger a los jugadores menores de edad:',
                  style: GoogleFonts.inter(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 14 * scale),
                ruleItem(
                  'no existe chat ni mensajes privados entre jugadores y scouts',
                ),
                ruleItem(
                  'no publiques datos personales o de contacto',
                ),
                ruleItem(
                  'scouts y clubes solo pueden solicitar contacto a través de la plataforma',
                ),
                ruleItem(
                  'los perfiles y videos pueden ser visibles para scouts y clubes registrados',
                ),
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
          SizedBox(height: 40),
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
            label: 'Email del responsable',
            hint: 'email@ejemplo.com',
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
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCountryDropdown(BuildContext context) {
    final scale = _scaleFactor(context);
    final fontSize = 13 * scale;
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
              value: _selectedCountryId,
              hint: Text('Selecciona el país',
                  style: GoogleFonts.inter(
                      fontSize: fontSize, color: const Color(0xFF2F3336))),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _countries
                  .map((c) => DropdownMenuItem<String>(
                      value: c['id'].toString(),
                      child: Text(c['name']?.toString() ?? '',
                          style: GoogleFonts.inter(fontSize: fontSize))))
                  .toList(),
              onChanged: (v) {
                final countryName = _countries
                        .firstWhere((c) => c['id'].toString() == v,
                            orElse: () => {})['name']
                        ?.toString() ??
                    '';
                setState(() {
                  _selectedCountryId = v;
                  _paisController.text = countryName;
                });
                if (countryName.isNotEmpty) _loadStates(countryName);
              },
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
        child: _LegalModal(
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
        child: _LegalModal(
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
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFA0AEC0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isStatesLoading
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 14 * scale),
                  child: Row(children: [
                    SizedBox(
                      width: 16 * scale,
                      height: 16 * scale,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10 * scale),
                    Text('Cargando estados...',
                        style: GoogleFonts.inter(
                            fontSize: fontSize,
                            color: const Color(0xFF2F3336))),
                  ]),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: (_selectedState != null &&
                            _states.contains(_selectedState))
                        ? _selectedState
                        : null,
                    hint: Text(
                      _selectedCountryId == null
                          ? 'Selecciona primero el país'
                          : _states.isEmpty
                              ? 'Cargando...'
                              : 'Selecciona el estado',
                      style: GoogleFonts.inter(
                          fontSize: fontSize, color: const Color(0xFF2F3336)),
                    ),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: _states
                        .map((s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s,
                                style: GoogleFonts.inter(fontSize: fontSize))))
                        .toList(),
                    onChanged: _selectedCountryId == null
                        ? null
                        : (v) {
                            setState(() => _selectedState = v);
                            if (v != null && countryName.isNotEmpty) {
                              _loadCitiesByState(countryName, v);
                            }
                          },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCityDropdown(BuildContext context) {
    final scale = _scaleFactor(context);
    final fontSize = 13 * scale;
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
        else if (_cityFreeText)
          // Texto libre cuando la API no encontró ciudades
          TextField(
            controller: _cidadeController,
            focusNode: _cidadeFocusNode,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(fontSize: fontSize),
            decoration: InputDecoration(
              hintText: 'Escribe el nombre de la ciudad',
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
          )
        else
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
                value: _selectedCity,
                hint: Text(
                  _selectedCountryId == null
                      ? 'Selecciona primero el país'
                      : (_selectedState == null)
                          ? 'Selecciona primero el estado'
                          : _cities.isEmpty
                              ? 'Sin ciudades disponibles'
                              : 'Selecciona la ciudad',
                  style: GoogleFonts.inter(
                      fontSize: fontSize, color: const Color(0xFF2F3336)),
                ),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: _cities
                    .map((city) => DropdownMenuItem<String>(
                        value: city,
                        child: Text(city,
                            style: GoogleFonts.inter(fontSize: fontSize))))
                    .toList(),
                onChanged: _selectedState == null
                    ? null
                    : (v) {
                        setState(() {
                          _selectedCity = v;
                          _cidadeController.text = v ?? '';
                        });
                      },
              ),
            ),
          ),
      ],
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
