import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
      _showError('Por favor, ingresa tu email');
      return;
    }
    if (_senhaController.text.isEmpty) {
      _showError('Por favor, ingresa una contraseña');
      return;
    }
    if (_senhaController.text.length < 6) {
      _showError('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (_senhaController.text != _confirmarSenhaController.text) {
      _showError('Las contraseñas no coinciden');
      return;
    }

    setState(() => _isLoading = true);

    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.createAccountWithEmail(
        context,
        _emailController.text.trim(),
        _senhaController.text,
      );

      if (user == null) {
        _showError('Error al crear la cuenta');
        setState(() => _isLoading = false);
        return;
      }

      _showSuccess('Cuenta creada con éxito!');
      if (mounted) context.pushNamed('registro_club');
    } catch (e) {
      debugPrint('Erro ao registrar: $e');
      _showError('Error: ${e.toString()}');
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
                  child: Container(
                    width: 193,
                    height: 193,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sports_soccer,
                        size: 80, color: Color(0xFF0D3B66)),
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
                    decoration: _inputDecoration('Email'),
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
                    obscureText: !_senhaVisibility,
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

              const SizedBox(height: 15),

              // Confirmar Senha
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: 337,
                  child: TextField(
                    controller: _confirmarSenhaController,
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

              // Esqueceu a senha
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 40),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => context.pushNamed('recuperar_contrasena'),
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0D3B66),
                        fontWeight: FontWeight.bold,
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

              const SizedBox(height: 20),

              // Link para login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Ya tienes cuenta? ',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF444444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.pushNamed('login'),
                    child: Text(
                      'Inicia sesión',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0D3B66),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
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
}
