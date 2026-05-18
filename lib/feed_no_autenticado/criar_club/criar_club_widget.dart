import '/flutter_flow/flutter_flow_util.dart';
import '/fluxo_compartilhado/password_policy.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'criar_club_model.dart';
export 'criar_club_model.dart';

class CriarClubWidget extends StatefulWidget {
  const CriarClubWidget({super.key});

  static String routeName = 'criar_club';
  static String routePath = '/Registro_clubs';

  @override
  State<CriarClubWidget> createState() => _CriarClubWidgetState();
}

class _CriarClubWidgetState extends State<CriarClubWidget> {
  late CriarClubModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _senhaVisibility = false;
  bool _confirmarSenhaVisibility = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CriarClubModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _registrar() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Por favor, ingresa tu correo electrónico');
      return;
    }
    final passwordError = PasswordPolicy.firstError(_senhaController.text);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }
    if (_senhaController.text != _confirmarSenhaController.text) {
      _showError('Las contraseñas no coinciden');
      return;
    }

    setState(() => _isLoading = true);

    try {
      FFAppState().registrationFlowActive = true;
      _showSuccess('Datos de acceso listos. Completa el perfil del club.');
      if (mounted) {
        context.pushNamed(
          'registro_club',
          extra: {
            'signupEmail': _emailController.text.trim(),
            'signupPassword': _senhaController.text,
          },
        );
      }
    } catch (e) {
      debugPrint('Error al registrar: $e');
      FFAppState().registrationFlowActive = false;
      _showError('No pudimos iniciar el registro del club. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Logo
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logoftp_1.png',
                    width: 193,
                    height: 193,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 193,
                      height: 193,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D3B66),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // Título
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  'Bienvenido',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0D3B66),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Email
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: 337,
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('Correo electrónico'),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Senha
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: 337,
                  child: TextField(
                    controller: _senhaController,
                    keyboardType: TextInputType.visiblePassword,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    obscureText: !_senhaVisibility,
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDecoration('Contraseña').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _senhaVisibility
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                            () => _senhaVisibility = !_senhaVisibility),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _buildPasswordRequirements(),

              const SizedBox(height: 15),

              // Confirmar Senha
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: 337,
                  child: TextField(
                    controller: _confirmarSenhaController,
                    keyboardType: TextInputType.visiblePassword,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    obscureText: !_confirmarSenhaVisibility,
                    decoration:
                        _inputDecoration('Confirma tu contraseña').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmarSenhaVisibility
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() =>
                            _confirmarSenhaVisibility =
                                !_confirmarSenhaVisibility),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 80),

              // Botão Registrar
              ElevatedButton(
                onPressed: _isLoading ? null : _registrar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF070121),
                  minimumSize: const Size(231, 53),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Registrarse',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF444444),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFA0AEC0)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFA0AEC0)),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildPasswordRequirements() {
    final rules = PasswordPolicy.rules(_senhaController.text);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: 337,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu contraseña debe tener:',
              style: GoogleFonts.inter(
                color: const Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...rules.map((rule) {
              final color = rule.isMet
                  ? const Color(0xFF168A3A)
                  : const Color(0xFF6B7280);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      rule.isMet
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rule.label,
                        style: GoogleFonts.inter(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
