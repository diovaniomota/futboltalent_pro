import 'dart:async';

import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'auth/supabase_auth/supabase_user_provider.dart';
import 'auth/supabase_auth/auth_util.dart';

import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';
import 'flutter_flow/nav/nav.dart';
import 'index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint('🚨 Flutter Error: ${details.exception}');
  };

  try {
    debugPrint('🚀 Iniciando aplicativos...');
    GoRouter.optionURLReflectsImperativeAPIs = true;
    usePathUrlStrategy();

    debugPrint('📡 Inicializando Supabase...');
    await SupaFlow.initialize();

    debugPrint('📦 Inicializando AppState...');
    final appState = FFAppState();
    await appState.initializePersistedState();

    debugPrint('🎬 Executando runApp...');
    runApp(ChangeNotifierProvider(
      create: (context) => appState,
      child: MyApp(),
    ));
  } catch (e, stackTrace) {
    debugPrint('❌ Erro Fatal na Inicialização: $e');
    debugPrint('📝 StackTrace: $stackTrace');

    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Erro ao iniciar o app:\n$e\n\nVerifique os logs do console para mais detalhes.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Locale? _locale;

  ThemeMode _themeMode = ThemeMode.system;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;
  StreamSubscription<BaseAuthUser>? _userStreamSubscription;
  Timer? _accountGuardTimer;
  bool _isCheckingAccountGuard = false;
  bool _isForcingLogout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = futboltalentProSupabaseUserStream();
    _userStreamSubscription = userStream.listen((user) {
      _appStateNotifier.update(user);
      _onAuthUserChanged(user);
    });
    _enforceAccountAccessRules();
    jwtTokenStream.listen((_) {});
    Future.delayed(
      Duration(milliseconds: 1000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accountGuardTimer?.cancel();
    _userStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enforceAccountAccessRules();
    }
  }

  void _onAuthUserChanged(BaseAuthUser user) {
    if (user.loggedIn && (user.uid?.isNotEmpty ?? false)) {
      _startAccountGuard();
      _enforceAccountAccessRules();
      return;
    }
    _stopAccountGuard();
  }

  void _startAccountGuard() {
    _accountGuardTimer?.cancel();
    _accountGuardTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _enforceAccountAccessRules(),
    );
  }

  void _stopAccountGuard() {
    _accountGuardTimer?.cancel();
    _accountGuardTimer = null;
  }

  Future<void> _enforceAccountAccessRules() async {
    if (_isCheckingAccountGuard || _isForcingLogout) return;
    if (currentUserUid.isEmpty) return;
    _isCheckingAccountGuard = true;
    try {
      final userData = await SupaFlow.client
          .from('users')
          .select('banned_until, is_minor, has_guardian')
          .eq('user_id', currentUserUid)
          .maybeSingle();
      if (userData == null) return;

      final bannedUntilRaw = userData['banned_until']?.toString();
      final bannedUntil = bannedUntilRaw != null
          ? DateTime.tryParse(bannedUntilRaw)?.toLocal()
          : null;
      if (bannedUntil != null && bannedUntil.isAfter(DateTime.now())) {
        final formattedDate =
            '${bannedUntil.day.toString().padLeft(2, '0')}/${bannedUntil.month.toString().padLeft(2, '0')}/${bannedUntil.year}';
        await _forceLogoutWithMessage(
          'Cuenta suspendida hasta $formattedDate. Contacte al administrador.',
        );
        return;
      }

      if (userData['is_minor'] == true && userData['has_guardian'] != true) {
        await _forceLogoutWithMessage(
          'Cuenta de menor sin adulto responsable. Registre nuevamente con un responsable.',
        );
      }
    } catch (e) {
      debugPrint('Account guard check failed: $e');
    } finally {
      _isCheckingAccountGuard = false;
    }
  }

  Future<void> _forceLogoutWithMessage(String message) async {
    if (_isForcingLogout) return;
    _isForcingLogout = true;
    try {
      FFAppState().authBlockMessage = message;
      await authManager.signOut();
      _router.clearRedirectLocation();
      _router.goNamed(LoginWidget.routeName);
    } catch (e) {
      debugPrint('Force logout failed: $e');
    } finally {
      _isForcingLogout = false;
    }
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'FutboltalentPro',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      locale: _locale,
      supportedLocales: const [
        Locale('es'),
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
        dialogTheme: DialogThemeData(
          elevation: 0,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          contentTextStyle: const TextStyle(
            fontSize: 16,
            color: Color(0xFF4B5563),
            height: 1.35,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          modalBackgroundColor: Colors.white,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0D3B66),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}
