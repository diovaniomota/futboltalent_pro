import '/backend/supabase/supabase.dart';

String firstNonEmptyClubValue(Iterable<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return '';
}

String clubRefFromMap(Map<String, dynamic> club) {
  return firstNonEmptyClubValue([
    club['id'],
    club['owner_id'],
    club['user_id'],
    club['club_id'],
  ]);
}

Future<Map<String, dynamic>?> loadClubByRef(String ref) async {
  final normalizedRef = ref.trim();
  if (normalizedRef.isEmpty) return null;

  Map<String, dynamic>? club;
  try {
    club = await SupaFlow.client
        .from('clubs')
        .select()
        .eq('id', normalizedRef)
        .maybeSingle();
  } catch (_) {}

  if (club == null) {
    try {
      club = await SupaFlow.client
          .from('clubs')
          .select()
          .eq('owner_id', normalizedRef)
          .maybeSingle();
    } catch (_) {}
  }

  if (club == null) {
    try {
      club = await SupaFlow.client
          .from('clubs')
          .select()
          .eq('user_id', normalizedRef)
          .maybeSingle();
    } catch (_) {}
  }

  return club;
}

Future<Set<String>> resolveClubRefsForUser(String authUserId) async {
  final refs = <String>{};
  final normalizedUid = authUserId.trim();
  if (normalizedUid.isEmpty) return refs;

  refs.add(normalizedUid);

  final seenClubIds = <String>{};

  Future<void> addClubData(Map<String, dynamic>? club) async {
    if (club == null) return;

    final clubId = club['id']?.toString().trim() ?? '';
    if (clubId.isNotEmpty) {
      refs.add(clubId);
      seenClubIds.add(clubId);
    }

    final ownerId = club['owner_id']?.toString().trim() ?? '';
    if (ownerId.isNotEmpty) refs.add(ownerId);

    final userId = club['user_id']?.toString().trim() ?? '';
    if (userId.isNotEmpty) refs.add(userId);
  }

  await addClubData(await loadClubByRef(normalizedUid));

  try {
    final rows = await SupaFlow.client
        .from('club_staff')
        .select('club_id')
        .eq('user_id', normalizedUid)
        .limit(20);

    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final clubId = row['club_id']?.toString().trim() ?? '';
      if (clubId.isEmpty || seenClubIds.contains(clubId)) continue;
      refs.add(clubId);
      seenClubIds.add(clubId);
      await addClubData(await loadClubByRef(clubId));
    }
  } catch (_) {}

  refs.removeWhere((value) => value.trim().isEmpty);
  return refs;
}

Future<Map<String, dynamic>?> resolveCurrentClubForUser(String authUserId) async {
  final refs = await resolveClubRefsForUser(authUserId);
  for (final ref in refs) {
    final club = await loadClubByRef(ref);
    if (club != null) return club;
  }
  return null;
}

Future<String?> resolvePrimaryClubIdForUser(String authUserId) async {
  final club = await resolveCurrentClubForUser(authUserId);
  final clubId = club?['id']?.toString().trim() ?? '';
  if (clubId.isNotEmpty) return clubId;

  final refs = await resolveClubRefsForUser(authUserId);
  if (refs.isEmpty) return null;
  return refs.first;
}
