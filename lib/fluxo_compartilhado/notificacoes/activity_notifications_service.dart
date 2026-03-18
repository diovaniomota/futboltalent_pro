import 'dart:developer' as developer;

import '/backend/supabase/supabase.dart';

class ActivityNotificationsService {
  static const String actionNone = 'none';
  static const String actionOpenPlayerConvocatoria =
      'open_player_convocatoria';
  static const String actionOpenClubPostulaciones = 'open_club_postulaciones';
  static const String actionOpenClubConvocatorias = 'open_club_convocatorias';
  static const String actionOpenScoutPlayerProfile =
      'open_scout_player_profile';

  static const String eventApplicationSubmitted = 'application_submitted';
  static const String eventApplicationStatusUpdated =
      'application_status_updated';
  static const String eventConvocatoriaInvited = 'convocatoria_invited';
  static const String eventNewApplicationReceived =
      'new_application_received';
  static const String eventContactRequestUpdated = 'contact_request_updated';

  static Future<void> create({
    required String recipientUserId,
    required String eventType,
    required String title,
    required String body,
    String? recipientUserType,
    String? entityType,
    String? entityId,
    String actionType = actionNone,
    Map<String, dynamic>? payload,
  }) async {
    final userId = recipientUserId.trim();
    if (userId.isEmpty) return;

    try {
      await SupaFlow.client.rpc(
        'create_activity_notification',
        params: <String, dynamic>{
          'p_user_id': userId,
          'p_recipient_user_type': recipientUserType,
          'p_event_type': eventType,
          'p_title': title,
          'p_body': body,
          'p_entity_type': entityType,
          'p_entity_id': entityId,
          'p_action_type': actionType,
          'p_payload': payload ?? <String, dynamic>{},
        },
      );
    } catch (e) {
      developer.log(
        'Erro ao criar notificação ($eventType): $e',
        name: 'ActivityNotificationsService',
      );
    }
  }

  static String statusLabel(dynamic rawStatus) {
    final status =
        rawStatus?.toString().trim().toLowerCase().replaceAll(' ', '_') ?? '';
    switch (status) {
      case 'pendiente':
      case 'nuevo':
        return 'Pendiente';
      case 'revisado':
      case 'revisada':
        return 'Revisado';
      case 'aceptado':
      case 'aceptada':
        return 'Aceptado';
      case 'rechazado':
      case 'rechazada':
        return 'Rechazado';
      case 'guardado':
        return 'Guardado';
      case 'preseleccionado':
        return 'Preseleccionado';
      case 'invitar_prueba':
      case 'convidar_teste':
        return 'Invitado a prueba';
      case 'en_prueba':
      case 'em_teste':
        return 'En prueba';
      case 'contratado':
        return 'Contratado';
      case 'acompanhamento':
      case 'acompanamiento':
        return 'En seguimiento';
      default:
        return 'Actualizado';
    }
  }

  static bool isInvitationStatus(dynamic rawStatus) {
    final status =
        rawStatus?.toString().trim().toLowerCase().replaceAll(' ', '_') ?? '';
    return status == 'invitar_prueba' ||
        status == 'convidar_teste' ||
        status == 'aceptado' ||
        status == 'aceptada' ||
        status == 'preseleccionado';
  }

  static Future<void> notifyPlayerApplicationSubmitted({
    required String playerId,
    required String convocatoriaId,
    required String convocatoriaTitle,
    required String clubName,
  }) async {
    await create(
      recipientUserId: playerId,
      recipientUserType: 'jugador',
      eventType: eventApplicationSubmitted,
      title: 'Postulación enviada correctamente',
      body:
          'Tu postulación a ${_safeTitle(convocatoriaTitle)} quedó registrada${clubName.trim().isNotEmpty ? ' en ${clubName.trim()}' : ''}.',
      entityType: 'convocatoria',
      entityId: convocatoriaId,
      actionType: actionOpenPlayerConvocatoria,
      payload: <String, dynamic>{
        'convocatoria_id': convocatoriaId,
        'convocatoria_title': convocatoriaTitle,
        'club_name': clubName,
      },
    );
  }

  static Future<void> notifyClubNewApplication({
    required String clubUserId,
    required String convocatoriaId,
    required String convocatoriaTitle,
    required String playerId,
    required String playerName,
  }) async {
    await create(
      recipientUserId: clubUserId,
      recipientUserType: 'club',
      eventType: eventNewApplicationReceived,
      title: 'Nueva postulación recibida',
      body:
          '${playerName.trim().isNotEmpty ? playerName.trim() : 'Un jugador'} se postuló a ${_safeTitle(convocatoriaTitle)}.',
      entityType: 'convocatoria',
      entityId: convocatoriaId,
      actionType: actionOpenClubPostulaciones,
      payload: <String, dynamic>{
        'convocatoria_id': convocatoriaId,
        'convocatoria_title': convocatoriaTitle,
        'player_id': playerId,
        'player_name': playerName,
      },
    );
  }

  static Future<void> notifyPlayerApplicationStatusUpdated({
    required String playerId,
    required String convocatoriaId,
    required String convocatoriaTitle,
    required String clubName,
    required String status,
  }) async {
    final invitation = isInvitationStatus(status);
    final cleanStatus = statusLabel(status);
    await create(
      recipientUserId: playerId,
      recipientUserType: 'jugador',
      eventType: invitation
          ? eventConvocatoriaInvited
          : eventApplicationStatusUpdated,
      title: invitation
          ? 'Invitación a convocatoria'
          : 'Actualización de tu postulación',
      body: invitation
          ? '${clubName.trim().isNotEmpty ? clubName.trim() : 'Un club'} te invitó a avanzar en ${_safeTitle(convocatoriaTitle)}.'
          : 'Tu postulación a ${_safeTitle(convocatoriaTitle)} ahora está en estado ${cleanStatus}.',
      entityType: 'convocatoria',
      entityId: convocatoriaId,
      actionType: actionOpenPlayerConvocatoria,
      payload: <String, dynamic>{
        'convocatoria_id': convocatoriaId,
        'convocatoria_title': convocatoriaTitle,
        'club_name': clubName,
        'status': status,
        'status_label': cleanStatus,
      },
    );
  }

  static Future<void> notifyScoutContactRequestUpdated({
    required String scoutId,
    required String playerId,
    required String playerName,
    required String status,
  }) async {
    final normalized =
        status.toString().trim().toLowerCase().replaceAll(' ', '_');
    final accepted = normalized == 'accepted' ||
        normalized == 'aceptado' ||
        normalized == 'aprobado';
    await create(
      recipientUserId: scoutId,
      recipientUserType: 'profesional',
      eventType: eventContactRequestUpdated,
      title: accepted
          ? 'Solicitud de contacto aprobada'
          : 'Solicitud de contacto actualizada',
      body: accepted
          ? '${playerName.trim().isNotEmpty ? playerName.trim() : 'El jugador'} aprobó tu solicitud de contacto.'
          : '${playerName.trim().isNotEmpty ? playerName.trim() : 'El jugador'} rechazó tu solicitud de contacto.',
      entityType: 'user',
      entityId: playerId,
      actionType: actionOpenScoutPlayerProfile,
      payload: <String, dynamic>{
        'player_id': playerId,
        'player_name': playerName,
        'status': normalized,
      },
    );
  }

  static String _safeTitle(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'la convocatoria' : trimmed;
  }
}
