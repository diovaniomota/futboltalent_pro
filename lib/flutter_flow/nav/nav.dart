import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

import '/backend/supabase/supabase.dart';

import '/auth/base_auth_user_provider.dart';

import '/main.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'serialization_util.dart';

import '/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final routeObserver = RouteObserver<PageRoute>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  /// Determines whether the app will refresh and build again when a sign
  /// in or sign out happens. This is useful when the app is launched or
  /// on an unexpected logout. However, this must be turned off when we
  /// intend to sign in/out and then navigate or perform any actions after.
  /// Otherwise, this will trigger a refresh and interrupt the action(s).
  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  /// Mark as not needing to notify on a sign in / out when we intend
  /// to perform subsequent actions (such as navigation) afterwards.
  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    // Refresh the app on auth change unless explicitly marked otherwise.
    // No need to update unless the user has changed.
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    // Once again mark the notifier as needing to update on auth change
    // (in order to catch sign in / out events).
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

Widget _homeForUserType() {
  final userType = FFAppState.normalizeUserType(FFAppState().userType);
  if (userType == 'admin') return AdminDashboardWidget();
  if (userType == 'club') return DashboardClubWidget();
  return FeedWidget();
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      observers: [routeObserver],
      errorBuilder: (context, state) =>
          appStateNotifier.loggedIn ? _homeForUserType() : LoginWidget(),
      routes: [
        FFRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) =>
              appStateNotifier.loggedIn ? _homeForUserType() : LoginWidget(),
        ),
        FFRoute(
          name: Onboardign1Widget.routeName,
          path: Onboardign1Widget.routePath,
          builder: (context, params) => Onboardign1Widget(),
        ),
        FFRoute(
          name: EmpiezaComecarWidget.routeName,
          path: EmpiezaComecarWidget.routePath,
          builder: (context, params) => EmpiezaComecarWidget(
            selectedUserType: params.getParam(
              'selectedUserType',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: FeedWidget.routeName,
          path: FeedWidget.routePath,
          builder: (context, params) => FeedWidget(),
        ),
        FFRoute(
          name: SeleccionDelTipoDePerfilWidget.routeName,
          path: SeleccionDelTipoDePerfilWidget.routePath,
          builder: (context, params) => SeleccionDelTipoDePerfilWidget(),
        ),
        FFRoute(
          name: RegistroClubWidget.routeName,
          path: RegistroClubWidget.routePath,
          builder: (context, params) => RegistroClubWidget(),
        ),
        FFRoute(
          name: ConvocatoriaJugador1Widget.routeName,
          path: ConvocatoriaJugador1Widget.routePath,
          builder: (context, params) => ConvocatoriaJugador1Widget(),
        ),
        FFRoute(
          name: DetallesDeLaConvocatoriaWidget.routeName,
          path: DetallesDeLaConvocatoriaWidget.routePath,
          builder: (context, params) => DetallesDeLaConvocatoriaWidget(
            convocatoriaId: params.getParam(
              'convocatoriaId',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: CrearPublicacinDeVideoWidget.routeName,
          path: CrearPublicacinDeVideoWidget.routePath,
          builder: (context, params) => CrearPublicacinDeVideoWidget(),
        ),
        FFRoute(
          name: CursosEjerciciosWidget.routeName,
          path: CursosEjerciciosWidget.routePath,
          builder: (context, params) => CursosEjerciciosWidget(
            initialChallengeId: params.getParam(
              'challengeId',
              ParamType.String,
            ),
            initialChallengeType: params.getParam(
              'challengeType',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: RankingWidget.routeName,
          path: RankingWidget.routePath,
          builder: (context, params) => RankingWidget(),
        ),
        FFRoute(
          name: PerfilJugadorWidget.routeName,
          path: PerfilJugadorWidget.routePath,
          builder: (context, params) => PerfilJugadorWidget(),
        ),
        FFRoute(
          name: EditarPerfilWidget.routeName,
          path: EditarPerfilWidget.routePath,
          builder: (context, params) => EditarPerfilWidget(),
        ),
        FFRoute(
          name: ExplorarWidget.routeName,
          path: ExplorarWidget.routePath,
          builder: (context, params) => ExplorarWidget(),
        ),
        FFRoute(
          name: ListaYNotasWidget.routeName,
          path: ListaYNotasWidget.routePath,
          builder: (context, params) => ListaYNotasWidget(),
        ),
        FFRoute(
          name: ConvocatoriaProfesionalWidget.routeName,
          path: ConvocatoriaProfesionalWidget.routePath,
          builder: (context, params) => ConvocatoriaProfesionalWidget(),
        ),
        FFRoute(
          name: DetallesDeLaConvocatoriaProfesionalWidget.routeName,
          path: DetallesDeLaConvocatoriaProfesionalWidget.routePath,
          builder: (context, params) =>
              DetallesDeLaConvocatoriaProfesionalWidget(
            convocatoriasID: params.getParam(
              'convocatoriasID',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: PerfilProfesioanlWidget.routeName,
          path: PerfilProfesioanlWidget.routePath,
          builder: (context, params) => PerfilProfesioanlWidget(),
        ),
        FFRoute(
          name: PerfilProfesionalSolicitarContatoWidget.routeName,
          path: PerfilProfesionalSolicitarContatoWidget.routePath,
          builder: (context, params) => PerfilProfesionalSolicitarContatoWidget(
            userId: params.getParam(
              'userId',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: DashboardClubWidget.routeName,
          path: DashboardClubWidget.routePath,
          builder: (context, params) => DashboardClubWidget(),
        ),
        FFRoute(
          name: ConvocatoriasClubWidget.routeName,
          path: ConvocatoriasClubWidget.routePath,
          builder: (context, params) => ConvocatoriasClubWidget(),
        ),
        FFRoute(
          name: PostulacionesWidget.routeName,
          path: PostulacionesWidget.routePath,
          builder: (context, params) => PostulacionesWidget(),
        ),
        FFRoute(
          name: ListaYNotaWidget.routeName,
          path: ListaYNotaWidget.routePath,
          builder: (context, params) => ListaYNotaWidget(),
        ),
        FFRoute(
          name: ConfiguracinWidget.routeName,
          path: ConfiguracinWidget.routePath,
          builder: (context, params) => ConfiguracinWidget(),
        ),
        FFRoute(
          name: LoginWidget.routeName,
          path: LoginWidget.routePath,
          builder: (context, params) => LoginWidget(),
        ),
        FFRoute(
          name: CriarClubWidget.routeName,
          path: CriarClubWidget.routePath,
          builder: (context, params) => CriarClubWidget(),
        ),
        FFRoute(
          name: AdminDashboardWidget.routeName,
          path: AdminDashboardWidget.routePath,
          requireAdmin: true,
          builder: (context, params) => AdminDashboardWidget(),
        ),
        FFRoute(
          name: AdminUsuariosWidget.routeName,
          path: AdminUsuariosWidget.routePath,
          requireAdmin: true,
          builder: (context, params) => AdminUsuariosWidget(),
        ),
        FFRoute(
          name: AdminVideosWidget.routeName,
          path: AdminVideosWidget.routePath,
          requireAdmin: true,
          builder: (context, params) => AdminVideosWidget(),
        ),
        FFRoute(
          name: AdminDesafiosWidget.routeName,
          path: AdminDesafiosWidget.routePath,
          requireAdmin: true,
          builder: (context, params) => AdminDesafiosWidget(),
        ),
        FFRoute(
          name: AdminConvocatoriasWidget.routeName,
          path: AdminConvocatoriasWidget.routePath,
          requireAdmin: true,
          builder: (context, params) => AdminConvocatoriasWidget(),
        ),
        FFRoute(
          name: AdminSettingsWidget.routeName,
          path: AdminSettingsWidget.routePath,
          requireAdmin: true,
          builder: (context, params) => AdminSettingsWidget(),
        ),
        FFRoute(
          name: AdminCategoriesWidget.routeName,
          path: AdminCategoriesWidget.routePath,
          requireAdmin: true,
          builder: (context, params) => AdminCategoriesWidget(),
        )
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect
          ? null
          : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) =>
      !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) =>
      appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.requireAdmin = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final bool requireAdmin;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }

          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/login';
          }
          if (requireAdmin) {
            if (!appStateNotifier.loggedIn) {
              appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
              return '/login';
            }
            if (!FFAppState().isAdminSession) {
              return '/';
            }
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = appStateNotifier.loading
              ? Center(
                  child: SizedBox(
                    width: 50.0,
                    height: 50.0,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  ),
                )
              : page;

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(key: state.pageKey, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
