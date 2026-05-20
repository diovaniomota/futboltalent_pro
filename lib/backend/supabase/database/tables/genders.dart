import '../database.dart';

class GendersTable extends SupabaseTable<GendersRow> {
  @override
  String get tableName => 'genders';

  @override
  GendersRow createRow(Map<String, dynamic> data) => GendersRow(data);
}

class GendersRow extends SupabaseDataRow {
  GendersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => GendersTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String get name => getField<String>('name')!;
  set name(String value) => setField<String>('name', value);
}
