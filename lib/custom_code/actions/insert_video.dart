// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/guardian/guardian_mvp_service.dart';
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<bool> insertVideo(
  String videoUrl,
  String title,
  String? description,
  bool isPublic,
) async {
  try {
    final userId = SupaFlow.client.auth.currentUser?.id;

    if (userId == null) {
      debugPrint('Usuário não autenticado');
      return false;
    }

    if (videoUrl.isEmpty) {
      debugPrint('URL do vídeo vazia');
      return false;
    }

    final moderationError = GuardianMvpService.validatePublicFields([
      title,
      description,
    ]);
    if (moderationError != null) {
      debugPrint('Insert blocked by moderation: $moderationError');
      return false;
    }

    Map<String, dynamic>? currentUserData;
    try {
      currentUserData = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (_) {}
    final moderationStatus =
        GuardianMvpService.moderationStatusForUser(currentUserData);

    final payload = <String, dynamic>{
      'video_url': videoUrl,
      'title': title,
      'description': description ?? '',
      'videoType': 'ugc',
      'is_public': isPublic,
      'user_id': userId,
      'likes_count': 0,
      'created_at': DateTime.now().toIso8601String(),
      'moderation_status': moderationStatus,
    };
    try {
      await SupaFlow.client.from('videos').insert(payload);
    } catch (_) {
      try {
        payload.remove('moderation_status');
        await SupaFlow.client.from('videos').insert(payload);
      } catch (_) {
        payload.remove('videoType');
        await SupaFlow.client.from('videos').insert(payload);
      }
    }

    debugPrint('Vídeo salvo no banco de dados');
    return true;
  } catch (e) {
    debugPrint('Erro ao inserir vídeo: $e');
    return false;
  }
}
