import 'package:supabase_flutter/supabase_flutter.dart';

export 'database/database.dart';

String _kSupabaseUrl = 'https://zwjdxizbakfhklpjoalt.supabase.co';
String _kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3amR4aXpiYWtmaGtscGpvYWx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxNTY2NzgsImV4cCI6MjA3MTczMjY3OH0.DYVh9bSM37OC6Admo7RANJrVcpg2pzX5NEc01hPcJy0';

class SupaFlow {
  SupaFlow._();

  static SupaFlow? _instance;
  static SupaFlow get instance => _instance ??= SupaFlow._();

  static SupabaseClient? _testClient;
  static set testClient(SupabaseClient? client) => _testClient = client;

  final _supabase = Supabase.instance.client;
  static SupabaseClient get client => _testClient ?? instance._supabase;

  static Future initialize() => Supabase.initialize(
        url: _kSupabaseUrl,
        headers: {
          'X-Client-Info': 'flutterflow',
        },
        anonKey: _kSupabaseAnonKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          // 1.2 Persistência de sessão: autoRefreshToken é true por padrão.
          // A sessão é mantida automaticamente pelo supabase_flutter
          // usando SharedPreferences e refresh token.
          autoRefreshToken: true,
        ),
      );
}
