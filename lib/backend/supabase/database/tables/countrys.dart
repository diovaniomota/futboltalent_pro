import '../database.dart';

class CountrysTable extends SupabaseTable<CountrysRow> {
  @override
  String get tableName => 'countrys';

  @override
  CountrysRow createRow(Map<String, dynamic> data) => CountrysRow(data);
}

class CountrysRow extends SupabaseDataRow {
  CountrysRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => CountrysTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get name => getField<String>('name');
  set name(String? value) => setField<String>('name', value);
}
