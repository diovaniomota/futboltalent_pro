import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard_model.dart';
export 'admin_dashboard_model.dart';

class AdminDashboardWidget extends StatefulWidget {
  const AdminDashboardWidget({super.key});

  static String routeName = 'admin_dashboard';
  static String routePath = '/adminDashboard';

  @override
  State<AdminDashboardWidget> createState() => _AdminDashboardWidgetState();
}

class _AdminDashboardWidgetState extends State<AdminDashboardWidget> {
  late AdminDashboardModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalJugadores = 0;
  int _totalProfesionales = 0;
  int _totalClubes = 0;
  int _totalVideos = 0;
  int _totalChallenges = 0;
  int _totalChallengeAttempts = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminDashboardModel());
    _loadStats();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final usersResponse =
          await SupaFlow.client.from('users').select('userType');

      final videosResponse = await SupaFlow.client.from('videos').select('id');
      final coursesResponse =
          await SupaFlow.client.from('courses').select('id');
      final exercisesResponse =
          await SupaFlow.client.from('exercises').select('id');

      int totalAttempts = 0;
      try {
        final attemptsResponse =
            await SupaFlow.client.from('user_challenge_attempts').select('id');
        totalAttempts = (attemptsResponse as List).length;
      } catch (_) {
        totalAttempts = 0;
      }

      int jugadores = 0, profesionales = 0, clubes = 0;
      for (final user in usersResponse as List) {
        final type = user['userType']?.toString() ?? '';
        if (type == 'jugador')
          jugadores++;
        else if (type == 'profesional')
          profesionales++;
        else if (type == 'club') clubes++;
      }

      if (mounted) {
        setState(() {
          _totalUsers = (usersResponse as List).length;
          _totalJugadores = jugadores;
          _totalProfesionales = profesionales;
          _totalClubes = clubes;
          _totalVideos = (videosResponse as List).length;
          _totalChallenges = (coursesResponse as List).length +
              (exercisesResponse as List).length;
          _totalChallengeAttempts = totalAttempts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        title: Text(
          'Painel Admin',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                fontFamily: 'Poppins',
                color: Colors.white,
                letterSpacing: 0.0,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              GoRouter.of(context).prepareAuthEvent();
              await authManager.signOut();
              GoRouter.of(context).clearRedirectLocation();
              context.goNamed(LoginWidget.routeName);
            },
          ),
        ],
        centerTitle: true,
        elevation: 2.0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen',
                      style: FlutterFlowTheme.of(context).headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 32),
                    Text(
                      'Gestionar',
                      style: FlutterFlowTheme.of(context).headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _buildMenuCard(
                      icon: Icons.people,
                      title: 'Usuarios',
                      subtitle: '$_totalUsers usuarios registrados',
                      onTap: () =>
                          context.pushNamed(AdminUsuariosWidget.routeName),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: Icons.video_library,
                      title: 'Videos',
                      subtitle: '$_totalVideos videos publicados',
                      onTap: () =>
                          context.pushNamed(AdminVideosWidget.routeName),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: Icons.fitness_center,
                      title: 'Desafíos',
                      subtitle:
                          '$_totalChallenges desafíos · $_totalChallengeAttempts envíos',
                      onTap: () =>
                          context.pushNamed(AdminDesafiosWidget.routeName),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
            'Total Usuarios', _totalUsers, Icons.people, Colors.blue),
        _buildStatCard(
            'Jugadores', _totalJugadores, Icons.sports_soccer, Colors.green),
        _buildStatCard(
            'Scouts', _totalProfesionales, Icons.search, Colors.orange),
        _buildStatCard('Clubes', _totalClubes, Icons.business, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: FlutterFlowTheme.of(context).bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  fontFamily: 'Poppins',
                  color: color,
                  letterSpacing: 0.0,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: FlutterFlowTheme.of(context).primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FlutterFlowTheme.of(context).titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: FlutterFlowTheme.of(context).bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: FlutterFlowTheme.of(context).secondaryText),
          ],
        ),
      ),
    );
  }
}
