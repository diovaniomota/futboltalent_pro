import '/backend/supabase/supabase.dart';

class GamificationService {
  static const int profileCompletePoints = 50;
  static const int firstVideoBonusPoints = 50;
  static const int videoUploadPoints = 30;
  static const int challengeParticipatedPoints = 40;
  static const int challengeCompletedPoints = 60;

  static const List<_GamificationTier> _tiers = [
    _GamificationTier(levelId: 1, name: 'Aficionado', minPoints: 0),
    _GamificationTier(levelId: 2, name: 'Amateur', minPoints: 100),
    _GamificationTier(levelId: 3, name: 'Semi-Pro', minPoints: 300),
    _GamificationTier(levelId: 4, name: 'Pro', minPoints: 700),
    _GamificationTier(levelId: 5, name: 'Élite', minPoints: 1500),
  ];

  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool _hasText(dynamic value) =>
      value?.toString().trim().isNotEmpty == true;

  static int? birthYearFromRaw(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final isoParsed = DateTime.tryParse(text);
    if (isoParsed != null) return isoParsed.year;

    final digitsOnly = RegExp(r'^\d{4}$');
    if (digitsOnly.hasMatch(text)) {
      return int.tryParse(text);
    }

    final brFormat = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    final match = brFormat.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(3) ?? '');
    }

    return null;
  }

  static int? birthYearFromUser(Map<String, dynamic>? user) {
    if (user == null) return null;
    return birthYearFromRaw(
      user['birthday'] ??
          user['birth_date'] ??
          user['fecha_nacimiento'] ??
          user['categoria'],
    );
  }

  static bool isProfileComplete(Map<String, dynamic>? user) {
    if (user == null) return false;
    final hasName = _hasText(user['name']) || _hasText(user['username']);
    final hasLastName = _hasText(user['lastname']) || _hasText(user['surname']);
    final hasPosition =
        _hasText(user['posicion']) || _hasText(user['position']);
    final hasLocation = _hasText(user['city']) ||
        _hasText(user['country']) ||
        _hasText(user['country_id']) ||
        _hasText(user['ubicacion']) ||
        _hasText(user['location']);
    final hasBirth = birthYearFromUser(user) != null;
    final hasPhoto =
        _hasText(user['photo_url']) || _hasText(user['avatar_url']);

    return hasName &&
        hasLastName &&
        hasPosition &&
        hasLocation &&
        hasBirth &&
        hasPhoto;
  }

  static String levelNameFromPoints(int points) {
    var selected = _tiers.first;
    for (final tier in _tiers) {
      if (points >= tier.minPoints) {
        selected = tier;
      } else {
        break;
      }
    }
    return selected.name;
  }

  static int levelIdFromPoints(int points) {
    var selected = _tiers.first;
    for (final tier in _tiers) {
      if (points >= tier.minPoints) {
        selected = tier;
      } else {
        break;
      }
    }
    return selected.levelId;
  }

  static int currentLevelFloor(int points) {
    var selected = _tiers.first;
    for (final tier in _tiers) {
      if (points >= tier.minPoints) {
        selected = tier;
      } else {
        break;
      }
    }
    return selected.minPoints;
  }

  static int? nextLevelTarget(int points) {
    for (final tier in _tiers) {
      if (points < tier.minPoints) return tier.minPoints;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> recalculateUserProgress({
    required String userId,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return null;

    Map<String, dynamic>? user;
    try {
      user = await SupaFlow.client
          .from('users')
          .select(
              'user_id, name, lastname, username, posicion, position, city, country, country_id, birthday, birth_date, fecha_nacimiento, categoria, photo_url, avatar_url, location, ubicacion')
          .eq('user_id', uid)
          .maybeSingle();
    } catch (_) {}

    List<dynamic> videosRows = const [];
    try {
      videosRows = await SupaFlow.client
          .from('videos')
          .select('id, description')
          .eq('user_id', uid);
    } catch (_) {}

    final participatedKeys = <String>{};
    final completedKeys = <String>{};
    int coursesCompleted = 0;
    int exercisesCompleted = 0;

    void addChallengeKey({
      required String type,
      required String itemId,
      bool completed = false,
    }) {
      final safeType = type.trim().toLowerCase();
      final safeId = itemId.trim();
      if (safeType.isEmpty || safeId.isEmpty) return;
      final key = '$safeType:$safeId';
      participatedKeys.add(key);
      if (completed) completedKeys.add(key);
    }

    try {
      final attempts = await SupaFlow.client
          .from('user_challenge_attempts')
          .select('item_type, item_id, status')
          .eq('user_id', uid);
      for (final row in (attempts as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final status = map['status']?.toString().toLowerCase().trim() ?? '';
        final isSubmittedLike = status == 'submitted' ||
            status == 'in_progress' ||
            status == 'completed';
        if (!isSubmittedLike) continue;
        addChallengeKey(
          type: map['item_type']?.toString() ?? '',
          itemId: map['item_id']?.toString() ?? '',
          completed: status == 'completed',
        );
      }
    } catch (_) {}

    try {
      final rows = await SupaFlow.client
          .from('user_courses')
          .select('course_id, status')
          .eq('user_id', uid);
      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final status = map['status']?.toString().toLowerCase().trim() ?? '';
        final completed = status == 'completed';
        if (completed || status == 'in_progress') {
          addChallengeKey(
            type: 'course',
            itemId: map['course_id']?.toString() ?? '',
            completed: completed,
          );
        }
        if (completed) coursesCompleted += 1;
      }
    } catch (_) {}

    try {
      final rows = await SupaFlow.client
          .from('user_exercises')
          .select('exercise_id, status')
          .eq('user_id', uid);
      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final status = map['status']?.toString().toLowerCase().trim() ?? '';
        final completed = status == 'completed';
        if (completed || status == 'in_progress') {
          addChallengeKey(
            type: 'exercise',
            itemId: map['exercise_id']?.toString() ?? '',
            completed: completed,
          );
        }
        if (completed) exercisesCompleted += 1;
      }
    } catch (_) {}

    final challengeRefExp =
        RegExp(r'\[challenge_ref:(course|exercise):([^\]]+)\]');
    for (final row in videosRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final description = map['description']?.toString() ?? '';
      final match = challengeRefExp.firstMatch(description);
      if (match == null) continue;
      addChallengeKey(
        type: match.group(1) ?? '',
        itemId: match.group(2) ?? '',
      );
    }

    final videosCount = videosRows.length;
    final profilePoints = isProfileComplete(user) ? profileCompletePoints : 0;
    final videoPoints = videosCount > 0
        ? firstVideoBonusPoints + (videosCount * videoUploadPoints)
        : 0;
    final challengeParticipatedPts =
        participatedKeys.length * challengeParticipatedPoints;
    final challengeCompletedPts =
        completedKeys.length * challengeCompletedPoints;
    final totalPoints = profilePoints +
        videoPoints +
        challengeParticipatedPts +
        challengeCompletedPts;
    final levelId = levelIdFromPoints(totalPoints);

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final dayIso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final payload = <String, dynamic>{
      'user_id': uid,
      'total_xp': totalPoints,
      'courses_completed': coursesCompleted,
      'exercises_completed': exercisesCompleted,
      'current_level_id': levelId,
      'last_activity_date': dayIso,
      'updated_at': nowIso,
    };

    try {
      final existing = await SupaFlow.client
          .from('user_progress')
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();
      if (existing != null) {
        await SupaFlow.client.from('user_progress').update(payload).eq(
              'user_id',
              uid,
            );
      } else {
        await SupaFlow.client.from('user_progress').insert(payload);
      }
    } catch (_) {
      final fallbackPayload = <String, dynamic>{
        'user_id': uid,
        'total_xp': totalPoints,
      };
      try {
        final existing = await SupaFlow.client
            .from('user_progress')
            .select('user_id')
            .eq('user_id', uid)
            .maybeSingle();
        if (existing != null) {
          await SupaFlow.client
              .from('user_progress')
              .update(fallbackPayload)
              .eq(
                'user_id',
                uid,
              );
        } else {
          await SupaFlow.client.from('user_progress').insert(fallbackPayload);
        }
      } catch (_) {}
    }

    return {
      'total_xp': totalPoints,
      'courses_completed': coursesCompleted,
      'exercises_completed': exercisesCompleted,
      'current_level_id': levelId,
      'level_name': levelNameFromPoints(totalPoints),
      'category_year': birthYearFromUser(user),
      'profile_complete': profilePoints > 0,
      'videos_count': videosCount,
      'challenges_participated': participatedKeys.length,
      'challenges_completed': completedKeys.length,
    };
  }
}

class _GamificationTier {
  final int levelId;
  final String name;
  final int minPoints;

  const _GamificationTier({
    required this.levelId,
    required this.name,
    required this.minPoints,
  });
}
