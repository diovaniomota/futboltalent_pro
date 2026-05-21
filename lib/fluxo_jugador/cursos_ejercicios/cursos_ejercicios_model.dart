import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'cursos_ejercicios_widget.dart' show CursosEjerciciosWidget;
import 'package:flutter/material.dart';

class CursosEjerciciosModel extends FlutterFlowModel<CursosEjerciciosWidget> {
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
