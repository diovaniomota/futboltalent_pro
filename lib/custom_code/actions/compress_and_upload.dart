// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/index.dart';

import 'dart:io';
import 'package:video_compress/video_compress.dart';

Future<String?> compressAndUpload(FFUploadedFile video) async {
  try {
    if (video.bytes == null) {
      debugPrint('Vídeo não selecionado');
      return null;
    }

    // Salvar temporariamente
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/temp_video.mp4');
    await tempFile.writeAsBytes(video.bytes!);

    debugPrint('Comprimindo vídeo...');

    // Comprimir
    final compressed = await VideoCompress.compressVideo(
      tempFile.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );

    if (compressed?.file == null) {
      debugPrint('Erro na compressão');
      return null;
    }

    debugPrint('Fazendo upload...');

    // Upload
    final fileBytes = await compressed!.file!.readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';

    await SupaFlow.client.storage.from('Videos').uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: 'video/mp4',
          ),
        );

    final publicUrl =
        SupaFlow.client.storage.from('Videos').getPublicUrl(fileName);

    // Limpar cache
    await VideoCompress.deleteAllCache();
    await tempFile.delete();

    debugPrint('Upload concluído: $publicUrl');
    return publicUrl;
  } catch (e) {
    debugPrint('Erro: $e');
    await VideoCompress.deleteAllCache();
    return null;
  }
}
