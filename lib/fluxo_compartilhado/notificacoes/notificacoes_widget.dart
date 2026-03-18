import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/fluxo_compartilhado/notificacoes/activity_notifications_service.dart';
import '/fluxo_jugador/detalles_de_la_convocatoria/detalles_de_la_convocatoria_widget.dart';
import '/fluxo_profesional/perfil_profesional_solicitar_contato/perfil_profesional_solicitar_contato_widget.dart';
import '/fluxo_usuario_club/convocatorias_club/convocatorias_club_widget.dart';
import '/fluxo_usuario_club/postulaciones/postulaciones_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificacionesWidget extends StatefulWidget {
  const NotificacionesWidget({
    super.key,
    this.initialUserType,
    this.enablePlayerContactShortcut = false,
  });

  final String? initialUserType;
  final bool enablePlayerContactShortcut;

  @override
  State<NotificacionesWidget> createState() => _NotificacionesWidgetState();
}

class _NotificacionesWidgetState extends State<NotificacionesWidget> {
  bool _isLoading = true;
  String? _errorMessage;
  String _userType = '';
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _userType = FFAppState.normalizeUserType(
      widget.initialUserType ?? FFAppState().userType,
      fallback: 'jugador',
    );
    _loadNotifications();
  }

  int get _unreadCount =>
      _notifications.where((item) => item['is_read'] != true).length;

  bool get _showPlayerContactShortcut =>
      widget.enablePlayerContactShortcut && _userType == 'jugador';

  Future<void> _loadNotifications() async {
    if (currentUserUid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _notifications = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_userType.isEmpty) {
        final user = await SupaFlow.client
            .from('users')
            .select('userType')
            .eq('user_id', currentUserUid)
            .maybeSingle();
        _userType = FFAppState.normalizeUserType(
          user?['userType'] ?? FFAppState().userType,
          fallback: 'jugador',
        );
      }

      final response = await SupaFlow.client
          .from('activity_notifications')
          .select()
          .eq('user_id', currentUserUid)
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar las notificaciones.';
        _isLoading = false;
      });
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    if (notificationId.isEmpty || currentUserUid.isEmpty) return;
    try {
      await SupaFlow.client.from('activity_notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId).eq('user_id', currentUserUid);
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    if (currentUserUid.isEmpty || _unreadCount == 0) return;
    try {
      await SupaFlow.client.from('activity_notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('user_id', currentUserUid).eq('is_read', false);

      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => <String, dynamic>{
                  ...item,
                  'is_read': true,
                  'read_at': DateTime.now().toIso8601String(),
                })
            .toList();
      });
    } catch (_) {}
  }

  Map<String, dynamic> _notificationPayload(Map<String, dynamic> notification) {
    final raw = notification['payload'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    final notificationId = notification['id']?.toString() ?? '';
    if (notificationId.isNotEmpty && notification['is_read'] != true) {
      await _markNotificationAsRead(notificationId);
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere(
            (item) => item['id']?.toString() == notificationId,
          );
          if (index >= 0) {
            _notifications[index] = <String, dynamic>{
              ..._notifications[index],
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
            };
          }
        });
      }
    }

    final actionType =
        notification['action_type']?.toString().trim() ??
            ActivityNotificationsService.actionNone;
    final entityId = notification['entity_id']?.toString() ?? '';
    final payload = _notificationPayload(notification);

    switch (actionType) {
      case ActivityNotificationsService.actionOpenPlayerConvocatoria:
        final convocatoriaId =
            payload['convocatoria_id']?.toString() ?? entityId;
        if (convocatoriaId.isEmpty) return;
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                DetallesDeLaConvocatoriaWidget(convocatoriaId: convocatoriaId),
          ),
        );
        return;
      case ActivityNotificationsService.actionOpenClubPostulaciones:
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PostulacionesWidget()),
        );
        return;
      case ActivityNotificationsService.actionOpenClubConvocatorias:
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConvocatoriasClubWidget()),
        );
        return;
      case ActivityNotificationsService.actionOpenScoutPlayerProfile:
        final playerId =
            payload['player_id']?.toString() ??
            payload['jugador_id']?.toString() ??
            payload['user_id']?.toString() ??
            entityId;
        if (playerId.isEmpty || !mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PerfilProfesionalSolicitarContatoWidget(userId: playerId),
          ),
        );
        return;
      default:
        return;
    }
  }

  IconData _notificationIcon(Map<String, dynamic> notification) {
    final event = notification['event_type']?.toString().trim() ?? '';
    switch (event) {
      case ActivityNotificationsService.eventConvocatoriaInvited:
        return Icons.campaign_rounded;
      case ActivityNotificationsService.eventApplicationSubmitted:
        return Icons.check_circle_outline_rounded;
      case ActivityNotificationsService.eventApplicationStatusUpdated:
        return Icons.sync_alt_rounded;
      case ActivityNotificationsService.eventNewApplicationReceived:
        return Icons.person_add_alt_1_rounded;
      case ActivityNotificationsService.eventContactRequestUpdated:
        return Icons.notifications_active_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _notificationColor(Map<String, dynamic> notification) {
    final event = notification['event_type']?.toString().trim() ?? '';
    switch (event) {
      case ActivityNotificationsService.eventConvocatoriaInvited:
        return const Color(0xFF7C3AED);
      case ActivityNotificationsService.eventApplicationSubmitted:
        return const Color(0xFF15803D);
      case ActivityNotificationsService.eventApplicationStatusUpdated:
        return const Color(0xFF2563EB);
      case ActivityNotificationsService.eventNewApplicationReceived:
        return const Color(0xFF0D3B66);
      case ActivityNotificationsService.eventContactRequestUpdated:
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatRelativeDate(dynamic rawDate) {
    final parsed =
        rawDate == null ? null : DateTime.tryParse(rawDate.toString());
    if (parsed == null) return '';
    return dateTimeFormat('relative', parsed, locale: 'es');
  }

  String _emptyTitle() {
    switch (_userType) {
      case 'club':
        return 'No hay actividad del club';
      case 'profesional':
        return 'No hay actividad del scout';
      default:
        return 'No hay actividad del jugador';
    }
  }

  String _emptySubtitle() {
    switch (_userType) {
      case 'club':
        return 'Cuando lleguen nuevas postulaciones o movimientos relevantes de tus convocatorias, aparecerán acá.';
      case 'profesional':
        return 'Las novedades relevantes para tu seguimiento aparecerán en este centro de actividad.';
      default:
        return 'Las invitaciones y actualizaciones de tus postulaciones aparecerán en este centro de actividad.';
    }
  }

  String _headerSubtitle() {
    switch (_userType) {
      case 'club':
        return 'Actividad reciente de tus convocatorias y postulaciones.';
      case 'profesional':
        return 'Eventos clave para tu seguimiento como scout.';
      default:
        return 'Invitaciones, postulaciones y movimientos importantes.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A)),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notificaciones',
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            Text(
              _headerSubtitle(),
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Marcar leídas',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D3B66),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF475569),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFF0D3B66),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF4FB),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.notifications_active_outlined,
                                color: Color(0xFF0D3B66),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Centro de actividad',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _unreadCount == 0
                                        ? 'No tenés notificaciones sin leer.'
                                        : 'Tenés $_unreadCount notificaciones sin leer.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showPlayerContactShortcut) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () =>
                              Navigator.of(context).pop('open_contact_requests'),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.contact_phone_outlined,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Solicitudes de contacto',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Abrí este acceso para revisar, aprobar o rechazar contactos pendientes.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_notifications.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.inbox_outlined,
                                color: Color(0xFF94A3B8),
                                size: 44,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _emptyTitle(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _emptySubtitle(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._notifications.map((notification) {
                          final isRead = notification['is_read'] == true;
                          final color = _notificationColor(notification);
                          final icon = _notificationIcon(notification);
                          final createdLabel =
                              _formatRelativeDate(notification['created_at']);
                          final title =
                              notification['title']?.toString().trim() ??
                                  'Notificación';
                          final body =
                              notification['body']?.toString().trim() ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _handleNotificationTap(notification),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? Colors.white
                                      : const Color(0xFFF8FBFF),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isRead
                                        ? const Color(0xFFE2E8F0)
                                        : color.withOpacity(0.22),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(icon, color: color, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(
                                                      0xFF0F172A,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (body.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              body,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: const Color(0xFF475569),
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(
                                            createdLabel.isEmpty
                                                ? 'Ahora'
                                                : createdLabel,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
