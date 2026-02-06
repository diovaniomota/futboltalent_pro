import '../database.dart';

class PlayersTable extends SupabaseTable<PlayersRow> {
  @override
  String get tableName => 'players';

  @override
  PlayersRow createRow(Map<String, dynamic> data) => PlayersRow(data);
}

class PlayersRow extends SupabaseDataRow {
  PlayersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => PlayersTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get dominantFoot => getField<String>('dominant_foot');
  set dominantFoot(String? value) => setField<String>('dominant_foot', value);

  int? get genderId => getField<int>('gender_id');
  set genderId(int? value) => setField<int>('gender_id', value);

  int? get positionId => getField<int>('position_id');
  set positionId(int? value) => setField<int>('position_id', value);

  String? get club => getField<String>('club');
  set club(String? value) => setField<String>('club', value);

  int? get experience => getField<int>('experience');
  set experience(int? value) => setField<int>('experience', value);

  double? get altura => getField<double>('altura');
  set altura(double? value) => setField<double>('altura', value);

  double? get peso => getField<double>('peso');
  set peso(double? value) => setField<double>('peso', value);
}
