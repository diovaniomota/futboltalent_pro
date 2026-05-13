import 'package:flutter/foundation.dart';

import '/backend/supabase/supabase.dart';

class PlayerPublicProgressService {
  static Future<Map<String, Map<String, dynamic>>> loadByUserId(
    Iterable<String> playerIds,
  ) async {
    final ids = playerIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const {};

    List<dynamic> rows = const [];
    try {
      final response = await SupaFlow.client.rpc(
        'get_player_public_progress',
        params: <String, dynamic>{'p_player_ids': ids},
      );
      rows = response is List ? response : const [];
    } catch (e) {
      debugPrint('Public player progress RPC failed, falling back: $e');
    }

    if (rows.isEmpty) {
      try {
        rows = await SupaFlow.client
            .from('user_progress')
            .select(
              'user_id, total_xp, current_level_id, courses_completed, exercises_completed',
            )
            .inFilter('user_id', ids);
      } catch (e) {
        debugPrint('Direct player progress load failed: $e');
        rows = const [];
      }
    }

    final byUserId = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final uid = map['user_id']?.toString().trim() ?? '';
      if (uid.isNotEmpty) {
        byUserId[uid] = map;
      }
    }
    return byUserId;
  }

  static Future<Map<String, dynamic>?> loadOne(String playerId) async {
    final progressByUserId = await loadByUserId([playerId]);
    return progressByUserId[playerId.trim()];
  }
}
