import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/index.dart';
import 'perfil_profesioanl_widget.dart' show PerfilProfesioanlWidget;
import 'package:flutter/material.dart';

class PerfilProfesioanlModel extends FlutterFlowModel<PerfilProfesioanlWidget> {
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
    navBarProfesionalModel.dispose();
    navBarJudadorModel.dispose();
  }
}
