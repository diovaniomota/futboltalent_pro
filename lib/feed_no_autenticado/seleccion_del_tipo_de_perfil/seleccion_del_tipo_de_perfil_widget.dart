import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'seleccion_del_tipo_de_perfil_model.dart';
export 'seleccion_del_tipo_de_perfil_model.dart';

class SeleccionDelTipoDePerfilWidget extends StatefulWidget {
  const SeleccionDelTipoDePerfilWidget({super.key});

  static String routeName = 'seleccion_del_tipo_de_perfil';
  static String routePath = '/seleccionDelTipoDePerfil';

  @override
  State<SeleccionDelTipoDePerfilWidget> createState() =>
      _SeleccionDelTipoDePerfilWidgetState();
}

class _SeleccionDelTipoDePerfilWidgetState
    extends State<SeleccionDelTipoDePerfilWidget> {
  late SeleccionDelTipoDePerfilModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String? _selectedType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SeleccionDelTipoDePerfilModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

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

  // ============ LOGIC ============
  void _selectType(String type) async {
    setState(() {
      _selectedType = type;
      _isLoading = true;
    });

    FFAppState().userType = type;

    try {
      if (type == 'jugador') {
        context.pushNamed(
          EmpiezaComecarWidget.routeName,
          queryParameters: {
            'selectedUserType': serializeParam(
              'jugador',
              ParamType.String,
            ),
          }.withoutNulls,
        );
      } else if (type == 'profesional') {
        context.pushNamed(
          EmpiezaComecarWidget.routeName,
          queryParameters: {
            'selectedUserType': serializeParam(
              'profesional',
              ParamType.String,
            ),
          }.withoutNulls,
        );
      } else if (type == 'club') {
        context.pushNamed(CriarClubWidget.routeName);
      }
    } catch (e) {
      debugPrint('Erro ao navegar: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final scale = _scaleFactor(context);

    // Responsive values
    final horizontalPadding =
        _responsive(context, mobile: 20, tablet: 40, desktop: 80);
    final titleFontSize =
        _responsive(context, mobile: 28, tablet: 32, desktop: 36) * scale;
    final subtitleFontSize =
        _responsive(context, mobile: 15, tablet: 16, desktop: 18) * scale;
    final topPadding = _responsive(context,
        mobile: screenHeight * 0.04, tablet: 50, desktop: 60);
    final cardSpacing =
        _responsive(context, mobile: 16, tablet: 20, desktop: 24);
    final maxCardWidth = _responsive(context,
        mobile: double.infinity, tablet: 500, desktop: 600);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: topPadding),

                        // Título
                        Text(
                          'Elige tu Camino',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),

                        SizedBox(height: 8 * scale),

                        // Subtítulo
                        Text(
                          'Selecciona el rol que mejor te describe',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),

                        SizedBox(
                            height: _responsive(context,
                                mobile: 30, tablet: 40, desktop: 50)),

                        // Cards
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxCardWidth == double.infinity
                                  ? constraints.maxWidth
                                  : maxCardWidth,
                            ),
                            child: Column(
                              children: [
                                _buildProfileCard(
                                  context: context,
                                  type: 'jugador',
                                  title: 'Jugador',
                                  description:
                                      'Para jóvenes talentos (10-20 años) que quieren mostrar sus habilidades al mundo.',
                                ),
                                SizedBox(height: cardSpacing),
                                _buildProfileCard(
                                  context: context,
                                  type: 'profesional',
                                  title: 'Profesional',
                                  description:
                                      'Para scout, entrenadores o representantes de clubes en busca de nuevos talentos.',
                                ),
                                SizedBox(height: cardSpacing),
                                _buildProfileCard(
                                  context: context,
                                  type: 'club',
                                  title: 'Club o Institución',
                                  description: 'Clubes, agencias deportivas',
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(
                            height: _responsive(context,
                                mobile: 30, tablet: 40, desktop: 50)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required BuildContext context,
    required String type,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedType == type;
    final isLoadingThis = _isLoading && _selectedType == type;
    final scale = _scaleFactor(context);

    // Responsive card values
    final verticalPadding =
        _responsive(context, mobile: 20, tablet: 28, desktop: 32) * scale;
    final horizontalPadding =
        _responsive(context, mobile: 18, tablet: 24, desktop: 28) * scale;
    final iconSize =
        _responsive(context, mobile: 44, tablet: 52, desktop: 56) * scale;
    final innerCircleSize =
        _responsive(context, mobile: 18, tablet: 22, desktop: 24) * scale;
    final checkIconSize =
        _responsive(context, mobile: 24, tablet: 28, desktop: 30) * scale;
    final titleFontSize =
        _responsive(context, mobile: 18, tablet: 20, desktop: 22) * scale;
    final descFontSize =
        _responsive(context, mobile: 13, tablet: 14, desktop: 15) * scale;
    final borderRadius =
        _responsive(context, mobile: 12, tablet: 14, desktop: 16);

    return GestureDetector(
      onTap: _isLoading ? null : () => _selectType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0D3B66),
          borderRadius: BorderRadius.circular(borderRadius),
          border: isSelected
              ? Border.all(color: const Color(0xFF5BA4E6), width: 2.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.15 : 0.1),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ícone circular
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: Center(
                      child: isSelected
                          ? Icon(Icons.check,
                              color: const Color(0xFF0D3B66),
                              size: checkIconSize)
                          : Container(
                              width: innerCircleSize,
                              height: innerCircleSize,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: 12 * scale),

                  // Título
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 6 * scale),

                  // Descrição
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: descFontSize,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Loading overlay
            if (isLoadingThis)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
