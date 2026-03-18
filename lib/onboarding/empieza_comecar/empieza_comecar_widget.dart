import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/guardian/guardian_mvp_service.dart';
import 'package:flutter/material.dart';
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

  // Guardian controllers (Tab 4 - menores)
  final TextEditingController _guardianEmailController = TextEditingController();
  final String _guardianRelationship = 'tutor';
  bool _acceptedCommunityRules = false;
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
      final response = await SupaFlow.client.from('countrys').select().order('name');
      if (mounted) {
        setState(() => _countries = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      debugPrint('Error loading countries: $e');
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
      _showSnackBar('Fecha de nacimiento inválida. Usa el formato DD/MM/AAAA con un año entre 1920 y ${DateTime.now().year}');
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

    setState(() => _shouldShowGuardianStep = _usesMinorProtectionFlow && age < 18);
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

      final userPayload = {
        'name': _nameController.text.trim(),
        'birthday': birthday?.toIso8601String(),
        'country_id':
            _selectedCountryId != null ? int.tryParse(_selectedCountryId!) ?? 1 : 1,
        'city': _cidadeController.text.trim(),
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
          await SupaFlow.client
              .from('users')
              .update({
                'has_guardian': true,
                'guardian_status': GuardianMvpService.pendingStatus,
                'visibility_status': GuardianMvpService.limitedVisibility,
              })
              .eq('user_id', uid);
        } catch (_) {
          try {
            await SupaFlow.client
                .from('users')
                .update({
                  'has_guardian': true,
                  'guardian_status': GuardianMvpService.pendingStatus,
                  'visibility_status': GuardianMvpService.limitedVisibility,
                })
                .eq('id', uid);
          } catch (_) {
            try {
              await SupaFlow.client
                  .from('users')
                  .update({'has_guardian': true})
                  .eq('user_id', uid);
            } catch (_) {
              await SupaFlow.client
                  .from('users')
                  .update({'has_guardian': true})
                  .eq('id', uid);
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
          _buildTextField(
            context: context,
            label: 'Ciudad',
            hint: 'Selecciona la ciudad',
            controller: _cidadeController,
            focusNode: _cidadeFocusNode,
            width: double.infinity,
            suffixIcon: const Icon(Icons.keyboard_arrow_down),
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
                consentItem(Icons.privacy_tip_outlined, 'política de privacidad'),
                consentItem(Icons.photo_camera_back_outlined, 'autorización de uso de imagen'),
                consentItem(Icons.video_library_outlined, 'publicación de videos en la plataforma'),
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
              onChanged: (v) => setState(() {
                _selectedCountryId = v;
                _paisController.text = _countries
                    .firstWhere((c) => c['id'].toString() == v)['name']
                    ?.toString() ?? '';
              }),
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
