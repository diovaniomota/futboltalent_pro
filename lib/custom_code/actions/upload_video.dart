// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/guardian/guardian_mvp_service.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/index.dart';

import 'dart:io';

Future<bool> uploadVideo(
  String videoPath,
  String title,
  String? description,
  String? tags,
  bool isPublic,
) async {
  try {
    final userId = SupaFlow.client.auth.currentUser?.id;
    if (userId == null) {
      return false;
    }

    final moderationError = GuardianMvpService.validatePublicFields([
      title,
      description,
      tags,
    ]);
    if (moderationError != null) {
      debugPrint('Upload blocked by moderation: $moderationError');
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

    final file = File(videoPath);
    final bytes = await file.readAsBytes();

    final fileExt = videoPath.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = 'users/$userId/$fileName';

    await SupaFlow.client.storage.from('Videos').uploadBinary(
          path,
          bytes,
        );

    final publicUrl = SupaFlow.client.storage.from('Videos').getPublicUrl(path);

    final payload = <String, dynamic>{
      'title': title,
      'description': description ?? '',
      'video_url': publicUrl,
      'user_id': userId,
      'is_public': isPublic,
      'created_at': DateTime.now().toIso8601String(),
      'likes_count': 0,
      'moderation_status': moderationStatus,
    };
    try {
      await SupaFlow.client.from('videos').insert(payload);
    } catch (_) {
      payload.remove('moderation_status');
      await SupaFlow.client.from('videos').insert(payload);
    }

    return true;
  } catch (e) {
    debugPrint('Erro ao fazer upload: $e');
    return false;
  }
}
