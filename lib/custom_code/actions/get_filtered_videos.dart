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

Future<List<dynamic>> getFilteredVideos(String filter) async {
  try {
    final userId = SupaFlow.client.auth.currentUser?.id;

    if (filter == 'todos') {
      // Todos os vídeos públicos
      final response = await SupaFlow.client
          .from('videos')
          .select()
          .eq('is_public', true)
          .order('created_at', ascending: false);

      return List<dynamic>.from(response);
    } else {
      // Só vídeos de quem eu sigo
      if (userId == null) return [];

      // Buscar IDs de quem eu sigo
      final followsResponse = await SupaFlow.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      final followingIds = (followsResponse as List)
          .map((f) => f['following_id'] as String)
          .toList();

      if (followingIds.isEmpty) return [];

      // Buscar vídeos dessas pessoas
      final videosResponse = await SupaFlow.client
          .from('videos')
          .select()
          .inFilter('user_id', followingIds)
          .eq('is_public', true)
          .order('created_at', ascending: false);

      return List<dynamic>.from(videosResponse);
    }
  } catch (e) {
    debugPrint('Erro ao buscar vídeos: $e');
    return [];
  }
}
