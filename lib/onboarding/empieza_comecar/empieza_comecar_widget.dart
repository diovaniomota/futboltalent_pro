import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
    _tabController = TabController(length: 3, vsync: this);
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
    super.dispose();
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

  Future<void> _saveProfileAndFinish() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Por favor ingresa tu nombre');
      return;
    }
    if (_dataNascimentoController.text.trim().isEmpty) {
      _showSnackBar('Por favor ingresa tu fecha de nacimiento');
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      DateTime? birthday;
      try {
        final parts = _dataNascimentoController.text.split('/');
        if (parts.length == 3) {
          birthday = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (e) {
        debugPrint('Erro ao converter data: $e');
      }

      await SupaFlow.client.from('users').insert({
        'name': _nameController.text.trim(),
        'birthday': birthday?.toIso8601String(),
        'country_id': 1,
        'city': _cidadeController.text.trim(),
        'userType': widget.selectedUserType,
        'user_id': currentUserUid,
        'username': _nameController.text.trim(),
        'lastname': '',
        'role_id': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (widget.selectedUserType == 'club') {
        context.goNamed('dashboardClub');
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
              'Tu Carrera Empieza acá',
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
              'Entrená, participá y hacé visible tu progreso dentro y fuera de la cancha.',
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
                _buildBenefitCard('Puntos', Icons.leaderboard, cardSize),
                SizedBox(width: cardSpacing),
                _buildBenefitCard('Ranking', Icons.emoji_events, cardSize),
                SizedBox(width: cardSpacing),
                _buildBenefitCard('Desafios', Icons.shield, cardSize),
              ],
            ),
            SizedBox(height: cardSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBenefitCard('Recompensas', Icons.star, cardSize),
                SizedBox(width: cardSpacing),
                _buildBenefitCard('Cursos', Icons.school, cardSize),
                SizedBox(width: cardSpacing),
                _buildBenefitCard('Convocatorias', Icons.campaign, cardSize),
              ],
            ),

            SizedBox(height: screenHeight * 0.06),

            // Botón Siguiente
            _buildPrimaryButton(
              context: context,
              text: 'Siguiente',
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
              FontAwesomeIcons.google, buttonWidth),
          SizedBox(height: 10 * scale),
          _buildSocialButton(
              context, 'Registrarse con Apple', Icons.apple, buttonWidth),
          SizedBox(height: 10 * scale),
          _buildSocialButton(
              context, 'Registrarse con TikTok', Icons.tiktok, buttonWidth),
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
      BuildContext context, String text, IconData icon, double width) {
    final scale = _scaleFactor(context);
    return SizedBox(
      width: width,
      height: 50 * scale,
      child: ElevatedButton.icon(
        onPressed: () => _showSnackBar('Login social en desarrollo'),
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
              'Contanos sobre vos',
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
            label: 'Me llamo',
            hint: 'Nombre',
            controller: _nameController,
            focusNode: _nameFocusNode,
            width: double.infinity,
          ),
          SizedBox(height: 15 * scale),
          _buildTextField(
            context: context,
            label: 'Año de nacimiento',
            hint: 'DD/MM/AAAA',
            controller: _dataNascimentoController,
            focusNode: _dataNascimentoFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [_dataNascimentoMask],
            width: double.infinity,
            suffixIcon: const Icon(Icons.calendar_month),
          ),
          SizedBox(height: 15 * scale),
          _buildTextField(
            context: context,
            label: 'País',
            hint: 'Selecciona el país',
            controller: _paisController,
            focusNode: _paisFocusNode,
            width: double.infinity,
            suffixIcon: const Icon(Icons.keyboard_arrow_down),
          ),
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
                  onPressed: _isSavingProfile ? null : _saveProfileAndFinish,
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
