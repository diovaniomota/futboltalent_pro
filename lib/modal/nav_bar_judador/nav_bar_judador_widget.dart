import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'nav_bar_judador_model.dart';
export 'nav_bar_judador_model.dart';

class NavBarJudadorWidget extends StatefulWidget {
  const NavBarJudadorWidget({super.key});

  @override
  State<NavBarJudadorWidget> createState() => _NavBarJudadorWidgetState();
}

class _NavBarJudadorWidgetState extends State<NavBarJudadorWidget> {
  late NavBarJudadorModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NavBarJudadorModel());

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
        color: FlutterFlowTheme.of(context).secondaryBackground,
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
                Icons.sports_soccer,
                color: Color(0xFF0D3B66),
                size: 30.0,
              ),
              onPressed: () async {
                context.pushNamed(FeedWidget.routeName);
              },
            ),
            FlutterFlowIconButton(
              icon: Icon(
                Icons.campaign,
                color: Color(0xFF0D3B66),
                size: 30.0,
              ),
              onPressed: () async {
                context.pushNamed(ConvocatoriaJugador1Widget.routeName);
              },
            ),
            FlutterFlowIconButton(
              icon: Icon(
                Icons.add,
                color: Color(0xFF0D3B66),
                size: 35.0,
              ),
              onPressed: () async {
                context.pushNamed(CrearPublicacinDeVideoWidget.routeName);
              },
            ),
            FlutterFlowIconButton(
              borderRadius: 8.0,
              icon: Icon(
                Icons.emoji_events,
                color: Color(0xFF0D3B66),
                size: 30.0,
              ),
              onPressed: () async {
                context.pushNamed(CursosEjerciciosWidget.routeName);
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
                context.pushNamed(PerfilJugadorWidget.routeName);
              },
            ),
          ],
        ),
      ),
    );
  }
}
