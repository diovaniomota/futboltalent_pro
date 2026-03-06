import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  Widget _navButton({
    required Widget icon,
    required Future<void> Function() onPressed,
    double buttonSize = 42.0,
    Color fillColor = Colors.transparent,
  }) {
    return FlutterFlowIconButton(
      borderRadius: buttonSize / 2,
      buttonSize: buttonSize,
      fillColor: fillColor,
      icon: icon,
      onPressed: () async {
        await onPressed();
      },
    );
  }

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
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final navBarBottomPadding = bottomSafeArea > 0 ? bottomSafeArea : 8.0;
    final navBarHeight = 56.0 + 8.0 + navBarBottomPadding;

    return Container(
      height: navBarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          8.0,
          8.0,
          8.0,
          navBarBottomPadding,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(
              height: 56.0,
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: _navButton(
                        icon: const Icon(
                          Icons.stadium_rounded,
                          color: Color(0xFF0D3B66),
                          size: 30.0,
                        ),
                        onPressed: () async {
                          context.pushNamed(FeedWidget.routeName);
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _navButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.magnifyingGlass,
                          color: Color(0xFF0D3B66),
                          size: 30.0,
                        ),
                        onPressed: () async {
                          context.pushNamed(ExplorarWidget.routeName);
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _navButton(
                        icon: const Icon(
                          Icons.event_note_outlined,
                          color: Color(0xFF0D3B66),
                          size: 30.0,
                        ),
                        onPressed: () async {
                          context.pushNamed(ListaYNotasWidget.routeName);
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _navButton(
                        icon: const Icon(
                          Icons.campaign_outlined,
                          color: Color(0xFF0D3B66),
                          size: 30.0,
                        ),
                        onPressed: () async {
                          context.pushNamed(
                              ConvocatoriaProfesionalWidget.routeName);
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _navButton(
                        icon: const Icon(
                          Icons.person,
                          color: Color(0xFF0D3B66),
                          size: 30.0,
                        ),
                        onPressed: () async {
                          context.pushNamed(PerfilProfesioanlWidget.routeName);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
