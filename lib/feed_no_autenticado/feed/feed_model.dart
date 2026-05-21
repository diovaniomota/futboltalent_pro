import '/flutter_flow/flutter_flow_util.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'feed_widget.dart' show FeedWidget;
import 'package:flutter/material.dart';

class FeedModel extends FlutterFlowModel<FeedWidget> {
  ///  Local state fields for this page.

  bool showLoginAlert = false;

  ///  State fields for stateful widgets in this page.

  // State field(s) for PageView widget.
  PageController? pageViewController;

  int get pageViewCurrentIndex => pageViewController != null &&
          pageViewController!.hasClients &&
          pageViewController!.page != null
      ? pageViewController!.page!.round()
      : 0;
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
