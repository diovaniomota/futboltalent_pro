import '../database.dart';

class PostulacionesTable extends SupabaseTable<PostulacionesRow> {
  @override
  String get tableName => 'postulaciones';

  @override
  PostulacionesRow createRow(Map<String, dynamic> data) =>
      PostulacionesRow(data);
}

class PostulacionesRow extends SupabaseDataRow {
  PostulacionesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => PostulacionesTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get convocatoriaId => getField<String>('convocatoria_id');
  set convocatoriaId(String? value) =>
      setField<String>('convocatoria_id', value);

  String? get playerId => getField<String>('player_id');
  set playerId(String? value) => setField<String>('player_id', value);
}
