import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
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

  void _showFeatureUnavailableMessage(String featureName) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName no está habilitado para tu cuenta.'),
      ),
    );
  }

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
    final appState = context.watch<FFAppState>();
    final canOpenExplorer = appState.canAccessFeature('explorer');
    final canUploadVideos = appState.canAccessFeature('videos');
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
                                  iconColor: canOpenExplorer
                                      ? const Color(0xFF0D3B66)
                                      : const Color(0xFF94A3B8),
                                  onPressed: () async {
                                    if (!canOpenExplorer) {
                                      _showFeatureUnavailableMessage(
                                        'Explorer',
                                      );
                                      return;
                                    }
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
                                      RankingWidget.routeName,
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
                        fillColor: canUploadVideos
                            ? const Color(0xFF0D3B66)
                            : const Color(0xFFE2E8F0),
                        iconColor: canUploadVideos
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        onPressed: () async {
                          if (!canUploadVideos) {
                            _showFeatureUnavailableMessage('Subir videos');
                            return;
                          }
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
