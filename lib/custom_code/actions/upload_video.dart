// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/guardian/guardian_mvp_service.dart';
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'dart:typed_data';
import 'package:video_compress/video_compress.dart';

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
    Uint8List? thumbnailBytes;
    try {
      thumbnailBytes = await VideoCompress.getByteThumbnail(
        videoPath,
        quality: 75,
        position: 1000,
      );
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
    }

    final fileExt = videoPath.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = 'users/$userId/$fileName';

    await SupaFlow.client.storage.from('Videos').uploadBinary(
          path,
          bytes,
        );

    final publicUrl = SupaFlow.client.storage.from('Videos').getPublicUrl(path);
    String? thumbnailUrl;
    if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
      try {
        final thumbPath =
            'users/$userId/thumbnails/${fileName.replaceAll(RegExp(r'\.[^.]+$'), '')}.jpg';
        await SupaFlow.client.storage.from('Videos').uploadBinary(
              thumbPath,
              thumbnailBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        thumbnailUrl =
            SupaFlow.client.storage.from('Videos').getPublicUrl(thumbPath);
      } catch (e) {
        debugPrint('Thumbnail upload failed: $e');
      }
    }

    final payload = <String, dynamic>{
      'title': title,
      'description': description ?? '',
      'video_url': publicUrl,
      if (thumbnailUrl?.isNotEmpty == true) 'thumbnail_url': thumbnailUrl,
      'user_id': userId,
      'videoType': 'ugc',
      'is_public': isPublic,
      'created_at': DateTime.now().toIso8601String(),
      'likes_count': 0,
      'moderation_status': moderationStatus,
    };
    await _insertVideoWithSchemaFallback(payload);

    return true;
  } catch (e) {
    debugPrint('Erro ao fazer upload: $e');
    return false;
  }
}

Future<void> _insertVideoWithSchemaFallback(
    Map<String, dynamic> payload) async {
  final mutablePayload = Map<String, dynamic>.from(payload);
  final optionalColumns = ['moderation_status', 'thumbnail_url', 'videoType'];

  for (var attempt = 0; attempt <= optionalColumns.length; attempt++) {
    try {
      await SupaFlow.client.from('videos').insert(mutablePayload);
      return;
    } catch (_) {
      if (attempt >= optionalColumns.length) rethrow;
      mutablePayload.remove(optionalColumns[attempt]);
    }
  }
}
