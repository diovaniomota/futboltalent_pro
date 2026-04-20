// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Removed unused and duplicate imports
// Removed unused and duplicate imports

import 'dart:io';

Future<String?> uploadVideoWithProgress(
  String filePath,
  String bucketName,
) async {
  try {
    final file = File(filePath);

    // Verificar se arquivo existe
    if (!await file.exists()) {
      debugPrint('❌ Arquivo não encontrado: $filePath');
      return null;
    }

    final fileBytes = await file.readAsBytes();
    final fileSize = fileBytes.length;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';

    debugPrint('📤 Iniciando upload...');
    debugPrint('📦 Tamanho: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

    // Upload para Supabase
    await SupaFlow.client.storage.from(bucketName).uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: 'video/mp4',
          ),
        );

    // Retorna URL pública
    final publicUrl =
        SupaFlow.client.storage.from(bucketName).getPublicUrl(fileName);

    debugPrint('✅ Upload concluído: $publicUrl');

    return publicUrl;
  } catch (e) {
    debugPrint('❌ Erro no upload: $e');
    return null;
  }
}
