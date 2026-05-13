import '/flutter_flow/flutter_flow_util.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/auth/supabase_auth/social_oauth.dart';
import '/backend/supabase/supabase.dart';
import '/guardian/guardian_mvp_service.dart';
import '/index.dart'; // For routes
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'login_model.dart';
export 'login_model.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'login';
  static String routePath = '/login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late LoginModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _senhaFocusNode = FocusNode();

  bool _senhaVisibility = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingGuardianPlayerId;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final blockMessage = FFAppState().authBlockMessage.trim();
      if (blockMessage.isNotEmpty) {
        setState(() => _errorMessage = blockMessage);
        FFAppState().authBlockMessage = '';
      } else {
        safeSetState(() {});
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _emailFocusNode.dispose();
    _senhaFocusNode.dispose();
    super.dispose();
  }

  // ============ HELPERS ============
  double _responsive(BuildContext context,
      {required double mobile, double? tablet, double? desktop}) {
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

  // ============ LOGIC ============
  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Por favor, ingresa tu correo electrónico');
      return;
    }
    if (_senhaController.text.isEmpty) {
      setState(() => _errorMessage = 'Por favor, ingresa tu contraseña');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.signInWithEmail(
          context, _emailController.text.trim(), _senhaController.text);

      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Correo o contraseña incorrectos';
          });
        }
        return;
      }

      // Sincroniza o userType do banco e aguarda conclusão
      final signedInUid = user.uid?.trim() ?? '';
      FFAppState().clearAuthenticatedSessionState();
      await FFAppState().syncUserType(expectedUid: signedInUid);

      if (!FFAppState().registrationComplete) {
        FFAppState().registrationFlowActive = true;
        if (mounted) {
          setState(() => _isLoading = false);
          context.goNamed(SeleccionDelTipoDePerfilWidget.routeName);
        }
        return;
      }

      String userType = FFAppState.normalizeUserType(FFAppState().userType);

      // Fallback: se syncUserType não encontrou, busca diretamente
      if (userType.isEmpty) {
        final uidForProfileLookup =
            signedInUid.isNotEmpty ? signedInUid : currentUserUid;
        final response = await SupaFlow.client
            .from('users')
            .select('userType')
            .eq('user_id', uidForProfileLookup)
            .maybeSingle();
        userType = FFAppState.normalizeUserType(
          response?['userType'],
          fallback: 'jugador',
        );
        FFAppState().userType = userType;
      }

      debugPrint('🔑 Login: userType resolvido = "$userType"');

      // Check if user is suspended or minor without guardian
      final userData = await SupaFlow.client
          .from('users')
          .select('banned_until, is_minor, has_guardian, guardian_status')
          .eq(
            'user_id',
            signedInUid.isNotEmpty ? signedInUid : currentUserUid,
          )
          .maybeSingle();
      if (userData != null && userData['banned_until'] != null) {
        final bannedUntil =
            DateTime.tryParse(userData['banned_until'].toString())?.toLocal();
        if (bannedUntil != null && bannedUntil.isAfter(DateTime.now())) {
          final formattedDate =
              '${bannedUntil.day.toString().padLeft(2, '0')}/${bannedUntil.month.toString().padLeft(2, '0')}/${bannedUntil.year}';
          final blockMessage =
              'Cuenta suspendida hasta $formattedDate. Contacta al administrador.';
          FFAppState().authBlockMessage = blockMessage;
          FFAppState().authBlockMessage = blockMessage;
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = blockMessage;
            });
          }
          return;
        }
      }
      // Block minor without guardian
      if (userData != null &&
          userData['is_minor'] == true &&
          userData['has_guardian'] != true) {
        const blockMessage =
            'Cuenta de menor sin adulto responsable. Vuelve a registrarte con un adulto responsable.';
        FFAppState().authBlockMessage = blockMessage;
        await authManager.signOut();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = blockMessage;
          });
        }
        return;
      }
      // Block minor with pending guardian approval
      if (userData != null && userData['is_minor'] == true) {
        final guardianStatus =
            userData['guardian_status']?.toString().trim().toLowerCase() ?? '';
        if (guardianStatus != 'approved') {
          const blockMessage =
              'Esta cuenta aún no fue aprobada por el adulto responsable. '
              'Usa el botón "Aprobar cuenta de menor" con el código que recibió el responsable.';
          _pendingGuardianPlayerId =
              signedInUid.isNotEmpty ? signedInUid : currentUserUid;
          FFAppState().authBlockMessage = blockMessage;
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = blockMessage;
            });
          }
          return;
        }
      }

      if (mounted) {
        if (userType == 'admin') {
          context.goNamed(AdminDashboardWidget.routeName);
        } else if (userType == 'jugador' || userType == 'profesional') {
          context.goNamed(FeedWidget.routeName);
        } else if (userType == 'club') {
          context.goNamed(DashboardClubWidget.routeName);
        } else {
          context.goNamed(FeedWidget.routeName);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No pudimos iniciar tu sesión. Verifica tus credenciales y conexión e intenta de nuevo.';
        });
      }
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      final success = await signInWithSocialProvider(provider);
      if (!success && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = socialAuthLaunchErrorMessage(provider);
        });
      }
    } catch (e) {
      debugPrint('Social auth failed for ${socialProviderLabel(provider)}: $e');
      if (isSocialAuthCanceled(e)) return;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = socialAuthFriendlyErrorMessage(e, provider);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ UI ============
  @override
  Widget build(BuildContext context) {
    final scale = _scaleFactor(context);
    final maxWidth = _responsive(context,
        mobile: double.infinity, tablet: 450, desktop: 500);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Container(
                    width: maxWidth == double.infinity ? null : maxWidth,
                    padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 40 * scale),
                          _buildLogo(context),
                          SizedBox(height: 20 * scale),
                          Text('Bienvenido',
                              style: GoogleFonts.inter(
                                  fontSize: _responsive(context,
                                          mobile: 24, tablet: 28, desktop: 32) *
                                      scale,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D3B66))),
                          SizedBox(height: 40 * scale),
                          _buildForm(context),
                          SizedBox(height: 100 * scale),
                          _buildLoginButton(context),
                          SizedBox(height: 30 * scale),
                          const Divider(thickness: 1, color: Color(0xFFE2E8F0)),
                          SizedBox(height: 20 * scale),
                          _buildSocialButton(context, 'Continuar con Google',
                              FontAwesomeIcons.google, maxWidth,
                              onPressed: () =>
                                  _signInWithProvider(OAuthProvider.google)),
                          if (isiOS) ...[
                            SizedBox(height: 12 * scale),
                            _buildSocialButton(context, 'Continuar con Apple',
                                Icons.apple, maxWidth,
                                onPressed: () =>
                                    _signInWithProvider(OAuthProvider.apple)),
                          ],
                          SizedBox(height: 30 * scale),
                          _buildRegisterLink(context),
                          SizedBox(height: 40 * scale),
                        ]),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final scale = _scaleFactor(context);
    final logoSize =
        _responsive(context, mobile: 150, tablet: 170, desktop: 193);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/logoftp_1.png',
        width: logoSize * scale,
        height: logoSize * scale,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
            width: logoSize * scale,
            height: logoSize * scale,
            decoration: BoxDecoration(
                color: const Color(0xFF0D3B66),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.sports_soccer,
                size: 80 * scale, color: Colors.white)),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final scale = _scaleFactor(context);
    final fieldWidth =
        _responsive(context, mobile: 337, tablet: 380, desktop: 400);

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      SizedBox(
          width: fieldWidth * scale,
          child: TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _senhaFocusNode.requestFocus(),
            style: GoogleFonts.inter(fontSize: 16 * scale),
            decoration: _inputDecoration('Correo electrónico', scale),
          )),
      SizedBox(height: 15 * scale),
      SizedBox(
          width: fieldWidth * scale,
          child: TextFormField(
            controller: _senhaController,
            focusNode: _senhaFocusNode,
            obscureText: !_senhaVisibility,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            style: GoogleFonts.inter(fontSize: 16 * scale),
            decoration: _inputDecoration('Contraseña', scale).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                    _senhaVisibility
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF444444)),
                onPressed: () =>
                    setState(() => _senhaVisibility = !_senhaVisibility),
              ),
            ),
          )),
      SizedBox(height: 10 * scale),
      GestureDetector(
        onTap: _showForgotPasswordDialog,
        child: Text('¿Olvidaste tu contraseña?',
            style: GoogleFonts.inter(
                fontSize: 14 * scale,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66))),
      ),
      SizedBox(height: 14 * scale),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _showGuardianApprovalDialog,
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(
            'Aprobar cuenta de menor',
            style: GoogleFonts.inter(
              fontSize: 14 * scale,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0D3B66),
            ),
          ),
        ),
      ),
      if (_errorMessage != null)
        Padding(
            padding: EdgeInsets.only(top: 16 * scale),
            child: _buildErrorMessage(context, _errorMessage!)),
    ]);
  }

  InputDecoration _inputDecoration(String hint, double scale) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF444444)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.all(16 * scale),
      enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFA0AEC0)),
          borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF0D3B66), width: 2),
          borderRadius: BorderRadius.circular(8)),
      errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.red.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withAlpha(76))),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.red)))
      ]),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final scale = _scaleFactor(context);
    final buttonWidth =
        _responsive(context, mobile: 231, tablet: 260, desktop: 280);
    final buttonHeight =
        _responsive(context, mobile: 53, tablet: 56, desktop: 60);

    return SizedBox(
      width: buttonWidth * scale,
      height: buttonHeight * scale,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF070121),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text('Iniciar sesión',
                style: TextStyle(
                    fontSize: 16 * scale,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    final scale = _scaleFactor(context);
    return RichText(
        text: TextSpan(children: [
      TextSpan(
          text: '¿No tienes cuenta? ',
          style: GoogleFonts.inter(
              fontSize: 14 * scale, color: const Color(0xFF444444))),
      TextSpan(
          text: 'Registrarse',
          style: GoogleFonts.inter(
              fontSize: 14 * scale,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D3B66),
              decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () =>
                context.pushNamed(SeleccionDelTipoDePerfilWidget.routeName)),
    ]));
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Recuperar contraseña'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Ingresa tu correo electrónico para restablecer la contraseña.'),
                  const SizedBox(height: 10),
                  TextField(
                      controller: resetEmailController,
                      decoration: const InputDecoration(
                          hintText: 'Correo electrónico',
                          border: OutlineInputBorder())),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () async {
                        if (resetEmailController.text.trim().isNotEmpty) {
                          try {
                            await authManager.resetPassword(
                                email: resetEmailController.text.trim(),
                                context: context);
                            if (!ctx.mounted || !mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Correo enviado'),
                                    backgroundColor: Colors.green));
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'No pudimos enviar el correo de recuperación. Verifica el correo e intenta de nuevo.'),
                                    backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: const Text('Enviar'))
                ]));
  }

  Future<void> _showGuardianApprovalDialog() async {
    final codeController = TextEditingController();
    final guardianEmailController = TextEditingController();
    final newEmailController = TextEditingController();
    var isSubmitting = false;
    var showChangeEmail = false;
    String? localError;
    String? successMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Aprobar cuenta de menor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingresa el código y el correo del adulto responsable para activar el perfil del menor.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'RESP-123456',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: guardianEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    hintText: 'correo del responsable',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (localError != null) ...[
                  const SizedBox(height: 10),
                  Text(localError!, style: const TextStyle(color: Colors.red)),
                ],
                if (successMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(successMessage!,
                      style: const TextStyle(color: Colors.green)),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () =>
                      setDialogState(() => showChangeEmail = !showChangeEmail),
                  child: Row(
                    children: [
                      Icon(
                        showChangeEmail ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF0D3B66),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          '¿Correo incorrecto? Cambiar correo del responsable',
                          style: TextStyle(
                            color: Color(0xFF0D3B66),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showChangeEmail) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Ingresa el correo correcto del responsable. Se generará un nuevo código.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'nuevo@email.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final newEmail = newEmailController.text.trim();
                              if (newEmail.isEmpty || !newEmail.contains('@')) {
                                setDialogState(() {
                                  localError =
                                      'Ingresa un correo válido para el responsable.';
                                  successMessage = null;
                                });
                                return;
                              }
                              setDialogState(() {
                                isSubmitting = true;
                                localError = null;
                                successMessage = null;
                              });
                              try {
                                final result = await GuardianMvpService
                                    .updateGuardianEmail(
                                  playerId: _pendingGuardianPlayerId,
                                  newEmail: newEmail,
                                );
                                setDialogState(() {
                                  isSubmitting = false;
                                  successMessage = result ??
                                      'Correo actualizado y nuevo código generado. Compártelo con $newEmail.';
                                  guardianEmailController.text = newEmail;
                                  localError = null;
                                });
                              } catch (e) {
                                setDialogState(() {
                                  isSubmitting = false;
                                  localError =
                                      'No se pudo actualizar el correo. Intenta nuevamente.';
                                  successMessage = null;
                                });
                              }
                            },
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Actualizar correo y reenviar código'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final code = codeController.text.trim().toUpperCase();
                      final guardianEmail =
                          guardianEmailController.text.trim().toLowerCase();
                      if (code.isEmpty) {
                        setDialogState(() {
                          localError = 'Ingresa el código del responsable.';
                          successMessage = null;
                        });
                        return;
                      }
                      if (guardianEmail.isEmpty ||
                          !guardianEmail.contains('@')) {
                        setDialogState(() {
                          localError =
                              'Ingresa el correo del adulto responsable.';
                          successMessage = null;
                        });
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        localError = null;
                        successMessage = null;
                      });
                      try {
                        await GuardianMvpService.approveGuardianCode(
                          code,
                          playerId: _pendingGuardianPlayerId,
                          guardianEmail: guardianEmail,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cuenta aprobada. El perfil del menor ya quedó activo.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        FFAppState().authBlockMessage = '';
                        if (currentUserUid.isNotEmpty) {
                          await FFAppState().syncUserType();
                          if (mounted) context.goNamed(FeedWidget.routeName);
                        }
                      } catch (error) {
                        final message = error.toString().toLowerCase();
                        setDialogState(() {
                          isSubmitting = false;
                          if (message.contains('approval_code_not_found') ||
                              message.contains('approval_code_expired') ||
                              message.contains('approval_code_used')) {
                            localError =
                                'Código o correo inválido, usado o vencido.';
                          } else if (message.contains('approval_not_pending') ||
                              message.contains('approval_player_not_pending')) {
                            localError =
                                'La cuenta ya no está pendiente de aprobación.';
                          } else if (message
                                  .contains('approval_context_required') ||
                              message.contains('guardian_email_required')) {
                            localError =
                                'No se pudo validar esta cuenta. Revisa el correo y el código.';
                          } else if (message
                              .contains('approve_guardian_by_code')) {
                            localError =
                                'No se pudo validar la configuración del flujo de responsable.';
                          } else {
                            localError =
                                'No se pudo aprobar la cuenta con ese código.';
                          }
                          successMessage = null;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Aprobar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(
    BuildContext context,
    String label,
    IconData icon,
    double width, {
    required VoidCallback onPressed,
  }) {
    final scale = _scaleFactor(context);
    final buttonWidth =
        _responsive(context, mobile: 231, tablet: 260, desktop: 280);

    return SizedBox(
      width: buttonWidth * scale,
      height: 50 * scale,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon,
            size: icon == Icons.apple ? 24 * scale : 18 * scale,
            color: const Color(0xFF0D3B66)),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0D3B66),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
