import '../database.dart';

class GuardiansTable extends SupabaseTable<GuardiansRow> {
  @override
  String get tableName => 'guardians';

  @override
  GuardiansRow createRow(Map<String, dynamic> data) => GuardiansRow(data);
}

class GuardiansRow extends SupabaseDataRow {
  GuardiansRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => GuardiansTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String get name => getField<String>('name')!;
  set name(String value) => setField<String>('name', value);

  String get relationship => getField<String>('relationship')!;
  set relationship(String value) => setField<String>('relationship', value);

  String get email => getField<String>('email')!;
  set email(String value) => setField<String>('email', value);

  String get playerId => getField<String>('player_id')!;
  set playerId(String value) => setField<String>('player_id', value);
}
