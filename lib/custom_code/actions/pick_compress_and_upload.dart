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
// Begin custom widget code

import 'package:image_picker/image_picker.dart';

Future<String?> pickCompressAndUpload() async {
  try {
    // 1. Selecionar vídeo
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60), // Limita a 60 segundos
    );

    if (pickedFile == null) {
      debugPrint('Nenhum vídeo selecionado');
      return null;
    }

    debugPrint('Vídeo selecionado: ${pickedFile.path}');

    // 2. Ler bytes do vídeo
    final fileBytes = await pickedFile.readAsBytes();
    final fileSizeMB = fileBytes.length / 1024 / 1024;

    debugPrint('Tamanho: ${fileSizeMB.toStringAsFixed(2)} MB');

    // 3. Verificar tamanho (limite de 20MB)
    if (fileSizeMB > 50) {
      debugPrint('Vídeo muito grande! Máximo: 20MB');
      return 'ERROR_FILE_TOO_LARGE';
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';

    debugPrint('Fazendo upload...');

    // 4. Upload para Supabase
    await SupaFlow.client.storage.from('Videos').uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: 'video/mp4',
          ),
        );

    // 5. Retornar URL
    final publicUrl =
        SupaFlow.client.storage.from('Videos').getPublicUrl(fileName);

    debugPrint('Upload concluído: $publicUrl');

    return publicUrl;
  } catch (e) {
    debugPrint('Erro: $e');
    return null;
  }
}
