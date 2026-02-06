import '../database.dart';

class UserStatsTable extends SupabaseTable<UserStatsRow> {
  @override
  String get tableName => 'user_stats';

  @override
  UserStatsRow createRow(Map<String, dynamic> data) => UserStatsRow(data);
}

class UserStatsRow extends SupabaseDataRow {
  UserStatsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => UserStatsTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get points => getField<int>('points');
  set points(int? value) => setField<int>('points', value);

  int? get level => getField<int>('level');
  set level(int? value) => setField<int>('level', value);

  DateTime? get updatedAt => getField<DateTime>('updated_at');
  set updatedAt(DateTime? value) => setField<DateTime>('updated_at', value);
}
