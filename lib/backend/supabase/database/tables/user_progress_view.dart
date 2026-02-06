import '../database.dart';

class UserProgressViewTable extends SupabaseTable<UserProgressViewRow> {
  @override
  String get tableName => 'user_progress_view';

  @override
  UserProgressViewRow createRow(Map<String, dynamic> data) =>
      UserProgressViewRow(data);
}

class UserProgressViewRow extends SupabaseDataRow {
  UserProgressViewRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => UserProgressViewTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get name => getField<String>('name');
  set name(String? value) => setField<String>('name', value);

  String? get lastname => getField<String>('lastname');
  set lastname(String? value) => setField<String>('lastname', value);

  String? get username => getField<String>('username');
  set username(String? value) => setField<String>('username', value);

  String? get photoUrl => getField<String>('photo_url');
  set photoUrl(String? value) => setField<String>('photo_url', value);

  int? get points => getField<int>('points');
  set points(int? value) => setField<int>('points', value);

  int? get level => getField<int>('level');
  set level(int? value) => setField<int>('level', value);

  dynamic? get badges => getField<dynamic>('badges');
  set badges(dynamic? value) => setField<dynamic>('badges', value);
}
