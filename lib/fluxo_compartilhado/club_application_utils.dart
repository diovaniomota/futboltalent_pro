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

Map<String, dynamic> normalizeClubApplicationRow(
  Map<String, dynamic> row, {
  required String sourceTable,
}) {
  final map = Map<String, dynamic>.from(row);
  map['_source_table'] = sourceTable;
  map['player_id'] = map['player_id'] ?? map['jugador_id'];
  map['jugador_id'] = map['jugador_id'] ?? map['player_id'];
  map['estado'] = map['estado'] ?? map['status'] ?? 'pendiente';
  return map;
}

String clubApplicationDedupKey(Map<String, dynamic> row) {
  final convocatoriaId = row['convocatoria_id']?.toString() ?? '';
  final playerId = clubApplicationPlayerId(row);
  final sourceTable = row['_source_table']?.toString() ?? 'postulaciones';
  final fallbackId = row['id']?.toString() ?? '';
  if (convocatoriaId.isNotEmpty && playerId.isNotEmpty) {
    return '$convocatoriaId::$playerId';
  }
  return '$sourceTable::$fallbackId';
}

List<Map<String, dynamic>> mergeClubApplicationRows(
  Iterable<Map<String, dynamic>> rows,
) {
  final dedup = <String, Map<String, dynamic>>{};
  for (final post in rows) {
    final key = clubApplicationDedupKey(post);
    final current = dedup[key];
    if (current == null ||
        clubApplicationCreatedAt(post).isAfter(
          clubApplicationCreatedAt(current),
        )) {
      dedup[key] = Map<String, dynamic>.from(post);
    }
  }

  final merged = dedup.values.toList();
  merged.sort(
    (a, b) => clubApplicationCreatedAt(b).compareTo(
      clubApplicationCreatedAt(a),
    ),
  );
  return merged;
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
        normalized.add(
          normalizeClubApplicationRow(
            row,
            sourceTable: tableName,
          ),
        );
      }
    } catch (_) {}
  }

  await Future.wait([
    loadFromTable('postulaciones'),
    loadFromTable('aplicaciones_convocatoria'),
  ]);

  if (normalized.isEmpty) return const [];
  return mergeClubApplicationRows(normalized);
}
