import '../database.dart';

class UserVideosSavedTable extends SupabaseTable<UserVideosSavedRow> {
  @override
  String get tableName => 'user_videos_saved';

  @override
  UserVideosSavedRow createRow(Map<String, dynamic> data) =>
      UserVideosSavedRow(data);
}

class UserVideosSavedRow extends SupabaseDataRow {
  UserVideosSavedRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => UserVideosSavedTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get videoId => getField<String>('video_id');
  set videoId(String? value) => setField<String>('video_id', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);
}
