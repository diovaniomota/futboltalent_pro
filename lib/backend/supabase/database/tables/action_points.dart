import '../database.dart';

class ActionPointsTable extends SupabaseTable<ActionPointsRow> {
  @override
  String get tableName => 'action_points';

  @override
  ActionPointsRow createRow(Map<String, dynamic> data) => ActionPointsRow(data);
}

class ActionPointsRow extends SupabaseDataRow {
  ActionPointsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ActionPointsTable();

  String get actionName => getField<String>('action_name')!;
  set actionName(String value) => setField<String>('action_name', value);

  int get points => getField<int>('points')!;
  set points(int value) => setField<int>('points', value);
}
