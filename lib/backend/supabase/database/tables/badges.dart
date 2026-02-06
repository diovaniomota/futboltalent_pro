import '../database.dart';

class BadgesTable extends SupabaseTable<BadgesRow> {
  @override
  String get tableName => 'badges';

  @override
  BadgesRow createRow(Map<String, dynamic> data) => BadgesRow(data);
}

class BadgesRow extends SupabaseDataRow {
  BadgesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => BadgesTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  String get name => getField<String>('name')!;
  set name(String value) => setField<String>('name', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);

  String? get iconUrl => getField<String>('icon_url');
  set iconUrl(String? value) => setField<String>('icon_url', value);

  int? get pointsRequired => getField<int>('points_required');
  set pointsRequired(int? value) => setField<int>('points_required', value);

  int? get levelRequired => getField<int>('level_required');
  set levelRequired(int? value) => setField<int>('level_required', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  String? get actionType => getField<String>('action_type');
  set actionType(String? value) => setField<String>('action_type', value);

  int? get targetValue => getField<int>('target_value');
  set targetValue(int? value) => setField<int>('target_value', value);

  int? get timeLimitHours => getField<int>('time_limit_hours');
  set timeLimitHours(int? value) => setField<int>('time_limit_hours', value);

  String? get entityType => getField<String>('entity_type');
  set entityType(String? value) => setField<String>('entity_type', value);
}
