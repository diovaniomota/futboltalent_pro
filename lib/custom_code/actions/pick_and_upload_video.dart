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
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

Future<String?> pickAndUploadVideo(String bucketName) async {
  try {
    // 1. Selecionar vídeo
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3), // Limite de 3 minutos
    );

    if (pickedFile == null) {
      debugPrint('❌ Nenhum vídeo selecionado');
      return null;
    }

    debugPrint('📹 Vídeo selecionado: ${pickedFile.path}');

    // 2. Comprimir vídeo
    debugPrint('🔄 Comprimindo vídeo...');

    final compressedInfo = await VideoCompress.compressVideo(
      pickedFile.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );

    final videoPath = compressedInfo?.file?.path ?? pickedFile.path;

    debugPrint('✅ Compressão concluída');

    // 3. Fazer upload
    debugPrint('📤 Fazendo upload...');

    final file = File(videoPath);
    final fileBytes = await file.readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';

    await SupaFlow.client.storage.from(bucketName).uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: 'video/mp4',
          ),
        );

    // 4. Retornar URL
    final publicUrl =
        SupaFlow.client.storage.from(bucketName).getPublicUrl(fileName);

    debugPrint('✅ Upload concluído: $publicUrl');

    // Limpar cache do compressor
    await VideoCompress.deleteAllCache();

    return publicUrl;
  } catch (e) {
    debugPrint('❌ Erro: $e');
    await VideoCompress.deleteAllCache();
    return null;
  }
}
