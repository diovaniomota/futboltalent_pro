import '/backend/supabase/supabase.dart';

String clubApplicationPlayerId(Map<String, dynamic> row) {
  return row['jugador_id']?.toString() ??
      row['player_id']?.toString() ??
      row['user_id']?.toString() ??
      '';
}

DateTime clubApplicationCreatedAt(Map<String, dynamic> row) {
  final raw = row['created_at'];
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

Future<List<Map<String, dynamic>>> fetchClubApplicationsForConvocatorias({
  required List<String> convocatoriaIds,
  int limitPerTable = 500,
}) async {
  final cleanIds = convocatoriaIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  if (cleanIds.isEmpty) return const [];

  final normalized = <Map<String, dynamic>>[];

  Future<void> loadFromTable(String tableName) async {
    try {
      final response = await SupaFlow.client
          .from(tableName)
          .select()
          .inFilter('convocatoria_id', cleanIds)
          .order('created_at', ascending: false)
          .limit(limitPerTable);

      for (final row in List<Map<String, dynamic>>.from(response as List)) {
        final map = Map<String, dynamic>.from(row);
        map['_source_table'] = tableName;
        map['player_id'] = map['player_id'] ?? map['jugador_id'];
        map['jugador_id'] = map['jugador_id'] ?? map['player_id'];
        map['estado'] = map['estado'] ?? map['status'] ?? 'pendiente';
        normalized.add(map);
      }
    } catch (_) {}
  }

  await Future.wait([
    loadFromTable('postulaciones'),
    loadFromTable('aplicaciones_convocatoria'),
  ]);

  if (normalized.isEmpty) return const [];

  final dedup = <String, Map<String, dynamic>>{};
  for (final post in normalized) {
    final convocatoriaId = post['convocatoria_id']?.toString() ?? '';
    final playerId = clubApplicationPlayerId(post);
    final sourceTable = post['_source_table']?.toString() ?? 'postulaciones';
    final fallbackId = post['id']?.toString() ?? '';
    final key = convocatoriaId.isNotEmpty && playerId.isNotEmpty
        ? '$convocatoriaId::$playerId'
        : '$sourceTable::$fallbackId';

    final current = dedup[key];
    if (current == null ||
        clubApplicationCreatedAt(post).isAfter(clubApplicationCreatedAt(current))) {
      dedup[key] = post;
    }
  }

  final merged = dedup.values.toList();
  merged.sort(
    (a, b) => clubApplicationCreatedAt(b).compareTo(clubApplicationCreatedAt(a)),
  );
  return merged;
}
