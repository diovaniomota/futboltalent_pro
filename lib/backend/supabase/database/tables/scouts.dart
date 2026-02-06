import '../database.dart';

class ScoutsTable extends SupabaseTable<ScoutsRow> {
  @override
  String get tableName => 'scouts';

  @override
  ScoutsRow createRow(Map<String, dynamic> data) => ScoutsRow(data);
}

class ScoutsRow extends SupabaseDataRow {
  ScoutsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ScoutsTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get biography => getField<String>('biography');
  set biography(String? value) => setField<String>('biography', value);

  String get telephone => getField<String>('telephone')!;
  set telephone(String value) => setField<String>('telephone', value);

  String? get urlProfesional => getField<String>('url_profesional');
  set urlProfesional(String? value) =>
      setField<String>('url_profesional', value);

  String get club => getField<String>('club')!;
  set club(String value) => setField<String>('club', value);

  int? get dni => getField<int>('dni');
  set dni(int? value) => setField<int>('dni', value);
}
