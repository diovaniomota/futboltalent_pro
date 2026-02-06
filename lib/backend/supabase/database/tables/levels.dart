import '../database.dart';

class LevelsTable extends SupabaseTable<LevelsRow> {
  @override
  String get tableName => 'levels';

  @override
  LevelsRow createRow(Map<String, dynamic> data) => LevelsRow(data);
}

class LevelsRow extends SupabaseDataRow {
  LevelsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => LevelsTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  int get levelNumber => getField<int>('level_number')!;
  set levelNumber(int value) => setField<int>('level_number', value);

  int get pointsRequired => getField<int>('points_required')!;
  set pointsRequired(int value) => setField<int>('points_required', value);

  String? get name => getField<String>('name');
  set name(String? value) => setField<String>('name', value);

  String? get reward => getField<String>('reward');
  set reward(String? value) => setField<String>('reward', value);

  bool? get isActive => getField<bool>('is_active');
  set isActive(bool? value) => setField<bool>('is_active', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
