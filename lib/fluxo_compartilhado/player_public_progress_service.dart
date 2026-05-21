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

    // Fallback: for players without progress data or with all zeros,
    // count directly from user_courses and user_exercises tables.
    final missingIds = ids.where((id) {
      final data = byUserId[id];
      if (data == null) return true;
      final courses = _toInt(data['courses_completed']);
      final exercises = _toInt(data['exercises_completed']);
      final xp = _toInt(data['total_xp']);
      return courses == 0 && exercises == 0 && xp == 0;
    }).toList();

    if (missingIds.isNotEmpty) {
      await _fillFromDirectCount(missingIds, byUserId);
    }

    return byUserId;
  }

  /// Counts completed courses and exercises directly from tracking tables
  /// when the aggregated user_progress row is missing or stale.
  static Future<void> _fillFromDirectCount(
    List<String> playerIds,
    Map<String, Map<String, dynamic>> byUserId,
  ) async {
    for (final uid in playerIds) {
      int coursesCompleted = 0;
      int exercisesCompleted = 0;
      int totalXp = 0;

      try {
        final courseRows = await SupaFlow.client
            .from('user_courses')
            .select('course_id, status')
            .eq('user_id', uid);
        for (final row in (courseRows as List)) {
          final status =
              (row as Map)['status']?.toString().toLowerCase().trim() ?? '';
          if (status == 'completed') coursesCompleted++;
        }
      } catch (e) {
        debugPrint('Direct course count failed for $uid: $e');
      }

      try {
        final exerciseRows = await SupaFlow.client
            .from('user_exercises')
            .select('exercise_id, status')
            .eq('user_id', uid);
        for (final row in (exerciseRows as List)) {
          final status =
              (row as Map)['status']?.toString().toLowerCase().trim() ?? '';
          if (status == 'completed') exercisesCompleted++;
        }
      } catch (e) {
        debugPrint('Direct exercise count failed for $uid: $e');
      }

      // Also try to get XP from user_progress if we only got zeros before
      if (coursesCompleted > 0 || exercisesCompleted > 0) {
        try {
          final progressRow = await SupaFlow.client
              .from('user_progress')
              .select('total_xp, current_level_id')
              .eq('user_id', uid)
              .maybeSingle();
          if (progressRow != null) {
            totalXp = _toInt(progressRow['total_xp']);
          }
        } catch (_) {}
      }

      if (coursesCompleted > 0 || exercisesCompleted > 0 || totalXp > 0) {
        final existing = byUserId[uid] ?? <String, dynamic>{'user_id': uid};
        // Only override if the direct count yields better data
        if (coursesCompleted > _toInt(existing['courses_completed'])) {
          existing['courses_completed'] = coursesCompleted;
        }
        if (exercisesCompleted > _toInt(existing['exercises_completed'])) {
          existing['exercises_completed'] = exercisesCompleted;
        }
        if (totalXp > _toInt(existing['total_xp'])) {
          existing['total_xp'] = totalXp;
        }
        byUserId[uid] = existing;
      }
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<Map<String, dynamic>?> loadOne(String playerId) async {
    final progressByUserId = await loadByUserId([playerId]);
    return progressByUserId[playerId.trim()];
  }
}
