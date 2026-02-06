import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'lista_y_notas_widget.dart' show ListaYNotasWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ListaYNotasModel extends FlutterFlowModel<ListaYNotasWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for nav_Bar_Profesional component.
  late NavBarProfesionalModel navBarProfesionalModel;
  // Model for NavBarJudador component.
  late NavBarJudadorModel navBarJudadorModel;

  @override
  void initState(BuildContext context) {
    navBarProfesionalModel =
        createModel(context, () => NavBarProfesionalModel());
    navBarJudadorModel = createModel(context, () => NavBarJudadorModel());
  }

  @override
  void dispose() {
    navBarJudadorModel.dispose();
    navBarProfesionalModel.dispose();
  }
}
