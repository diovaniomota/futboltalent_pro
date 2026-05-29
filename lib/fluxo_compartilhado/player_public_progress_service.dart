import 'package:flutter/foundation.dart';

import '/backend/supabase/supabase.dart';
import '/gamification/gamification_service.dart';

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
        byUserId[uid] = _withDerivedProgress(map);
      }
    }

    // Fallback: for players without progress data, stale completion counts,
    // or stale XP, count directly from activity tables.
    final missingIds = ids.where((id) {
      final data = byUserId[id];
      if (data == null) return true;
      final courses = _toInt(data['courses_completed']);
      final exercises = _toInt(data['exercises_completed']);
      final xp = _toInt(data['total_xp']);
      return (courses == 0 && exercises == 0) || xp == 0;
    }).toList();

    if (missingIds.isNotEmpty) {
      await _fillFromDirectCount(missingIds, byUserId);
    }

    for (final uid in ids) {
      final existing = byUserId[uid];
      if (existing != null) byUserId[uid] = _withDerivedProgress(existing);
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

      try {
        final attempts = await SupaFlow.client
            .from('user_challenge_attempts')
            .select('item_id, item_type, status')
            .eq('user_id', uid);
        final courseAttemptIds = <String>{};
        final exerciseAttemptIds = <String>{};
        for (final row in (attempts as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          final status = map['status']?.toString().toLowerCase().trim() ?? '';
          if (status != 'completed' &&
              status != 'submitted' &&
              status != 'in_progress') {
            continue;
          }
          final id = map['item_id']?.toString().trim() ?? '';
          final type = map['item_type']?.toString().toLowerCase().trim() ?? '';
          if (id.isEmpty) continue;
          if (type == 'course') courseAttemptIds.add(id);
          if (type == 'exercise') exerciseAttemptIds.add(id);
        }
        if (courseAttemptIds.length > coursesCompleted) {
          coursesCompleted = courseAttemptIds.length;
        }
        if (exerciseAttemptIds.length > exercisesCompleted) {
          exercisesCompleted = exerciseAttemptIds.length;
        }
      } catch (e) {
        debugPrint('Direct challenge attempt count failed for $uid: $e');
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
        byUserId[uid] = _withDerivedProgress(existing);
      }
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _withDerivedProgress(
    Map<String, dynamic> source,
  ) {
    final data = Map<String, dynamic>.from(source);
    final courses = _toInt(data['courses_completed']);
    final exercises = _toInt(data['exercises_completed']);
    final inferredXp =
        (courses + exercises) * GamificationService.challengeCompletedPoints;
    final totalXp = _toInt(data['total_xp']);
    if (inferredXp > totalXp) {
      data['total_xp'] = inferredXp;
    }
    final normalizedXp = _toInt(data['total_xp']);
    final currentLevel = _toInt(data['current_level_id']);
    final derivedLevel = GamificationService.levelIdFromPoints(normalizedXp);
    if (derivedLevel > currentLevel) {
      data['current_level_id'] = derivedLevel;
    }
    data['level_name'] = GamificationService.levelNameFromPoints(normalizedXp);
    return data;
  }

  static Future<Map<String, dynamic>?> loadOne(String playerId) async {
    final progressByUserId = await loadByUserId([playerId]);
    return progressByUserId[playerId.trim()];
  }
}
