import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'nav_bar_judador_model.dart';
export 'nav_bar_judador_model.dart';

class NavBarJudadorWidget extends StatefulWidget {
  const NavBarJudadorWidget({super.key});

  @override
  State<NavBarJudadorWidget> createState() => _NavBarJudadorWidgetState();
}

class _NavBarJudadorWidgetState extends State<NavBarJudadorWidget> {
  late NavBarJudadorModel _model;

  Widget _navButton({
    required IconData icon,
    required Future<void> Function() onPressed,
    double size = 30.0,
    double buttonSize = 42.0,
    Color fillColor = Colors.transparent,
    Color iconColor = const Color(0xFF0D3B66),
  }) {
    return FlutterFlowIconButton(
      borderRadius: buttonSize / 2,
      buttonSize: buttonSize,
      fillColor: fillColor,
      icon: Icon(
        icon,
        color: iconColor,
        size: size,
      ),
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
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final navBarBottomPadding = bottomSafeArea > 0 ? bottomSafeArea : 8.0;
    final navBarHeight = 56.0 + 8.0 + navBarBottomPadding;

    return Container(
      height: navBarHeight,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 360;
                final centerGap = isCompact ? 88.0 : 102.0;
                final iconButtonSize = isCompact ? 38.0 : 42.0;
                final iconSize = isCompact ? 28.0 : 30.0;
                final plusButtonSize = isCompact ? 42.0 : 46.0;
                final plusIconSize = isCompact ? 26.0 : 28.0;

                return SizedBox(
                  height: 56.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _navButton(
                                  icon: Icons.stadium_rounded,
                                  buttonSize: iconButtonSize,
                                  size: iconSize,
                                  onPressed: () async {
                                    context.pushNamed(FeedWidget.routeName);
                                  },
                                ),
                                _navButton(
                                  icon: Icons.search,
                                  buttonSize: iconButtonSize,
                                  size: iconSize,
                                  onPressed: () async {
                                    context.pushNamed(ExplorarWidget.routeName);
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: centerGap),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _navButton(
                                  icon: Icons.emoji_events,
                                  buttonSize: iconButtonSize,
                                  size: iconSize,
                                  onPressed: () async {
                                    context.pushNamed(
                                      CursosEjerciciosWidget.routeName,
                                    );
                                  },
                                ),
                                _navButton(
                                  icon: Icons.person,
                                  buttonSize: iconButtonSize,
                                  size: iconSize,
                                  onPressed: () async {
                                    context.pushNamed(
                                      PerfilJugadorWidget.routeName,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _navButton(
                        icon: Icons.add,
                        size: plusIconSize,
                        buttonSize: plusButtonSize,
                        fillColor: const Color(0xFF0D3B66),
                        iconColor: Colors.white,
                        onPressed: () async {
                          context.pushNamed(
                            CrearPublicacinDeVideoWidget.routeName,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
