import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'convocatoria_jugador1_widget.dart' show ConvocatoriaJugador1Widget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ConvocatoriaJugador1Model
    extends FlutterFlowModel<ConvocatoriaJugador1Widget> {
  ///  State fields for stateful widgets in this page.

  // Model for nav_Bar_judador component.
  late NavBarJudadorModel navBarJudadorModel;
  // Model for nav_Bar_Profesional component.
  late NavBarProfesionalModel navBarProfesionalModel;

  @override
  void initState(BuildContext context) {
    navBarJudadorModel = createModel(context, () => NavBarJudadorModel());
    navBarProfesionalModel =
        createModel(context, () => NavBarProfesionalModel());
  }

  @override
  void dispose() {
    navBarJudadorModel.dispose();
    navBarProfesionalModel.dispose();
  }
}
