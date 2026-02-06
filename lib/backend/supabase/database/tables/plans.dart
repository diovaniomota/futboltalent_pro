import '../database.dart';

class PlansTable extends SupabaseTable<PlansRow> {
  @override
  String get tableName => 'plans';

  @override
  PlansRow createRow(Map<String, dynamic> data) => PlansRow(data);
}

class PlansRow extends SupabaseDataRow {
  PlansRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => PlansTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get name => getField<String>('name');
  set name(String? value) => setField<String>('name', value);
}
