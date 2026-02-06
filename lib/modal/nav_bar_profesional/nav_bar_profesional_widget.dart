import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'nav_bar_profesional_model.dart';
export 'nav_bar_profesional_model.dart';

class NavBarProfesionalWidget extends StatefulWidget {
  const NavBarProfesionalWidget({super.key});

  @override
  State<NavBarProfesionalWidget> createState() =>
      _NavBarProfesionalWidgetState();
}

class _NavBarProfesionalWidgetState extends State<NavBarProfesionalWidget> {
  late NavBarProfesionalModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NavBarProfesionalModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 83.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0.0),
          bottomRight: Radius.circular(0.0),
          topLeft: Radius.circular(0.0),
          topRight: Radius.circular(0.0),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FlutterFlowIconButton(
              borderRadius: 8.0,
              icon: Icon(
                Icons.stadium_rounded,
                color: Color(0xFF0D3B66),
                size: 30.0,
              ),
              onPressed: () async {
                context.pushNamed(FeedWidget.routeName);
              },
            ),
            FlutterFlowIconButton(
              icon: FaIcon(
                FontAwesomeIcons.search,
                color: Color(0xFF0D3B66),
                size: 30.0,
              ),
              onPressed: () async {
                context.pushNamed(ExplorarWidget.routeName);
              },
            ),
            FlutterFlowIconButton(
              icon: Icon(
                Icons.event_note_outlined,
                color: Color(0xFF0D3B66),
                size: 30.0,
              ),
              onPressed: () async {
                context.pushNamed(ListaYNotasWidget.routeName);
              },
            ),
            FlutterFlowIconButton(
              borderRadius: 8.0,
              icon: Icon(
                Icons.campaign_outlined,
                color: Color(0xFF0D3B66),
                size: 30.0,
              ),
              onPressed: () async {
                context.pushNamed(ConvocatoriaProfesionalWidget.routeName);
              },
            ),
            FlutterFlowIconButton(
              borderRadius: 8.0,
              icon: Icon(
                Icons.person,
                color: Color(0xFF0D3B66),
                size: 30.0,
              ),
              onPressed: () async {
                context.pushNamed(PerfilProfesioanlWidget.routeName);
              },
            ),
          ],
        ),
      ),
    );
  }
}
