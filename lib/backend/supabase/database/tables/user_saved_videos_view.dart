import '../database.dart';

class UserSavedVideosViewTable extends SupabaseTable<UserSavedVideosViewRow> {
  @override
  String get tableName => 'user_saved_videos_view';

  @override
  UserSavedVideosViewRow createRow(Map<String, dynamic> data) =>
      UserSavedVideosViewRow(data);
}

class UserSavedVideosViewRow extends SupabaseDataRow {
  UserSavedVideosViewRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => UserSavedVideosViewTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get videoId => getField<String>('video_id');
  set videoId(String? value) => setField<String>('video_id', value);

  String? get videoUrl => getField<String>('video_url');
  set videoUrl(String? value) => setField<String>('video_url', value);

  String? get thumbnail => getField<String>('thumbnail');
  set thumbnail(String? value) => setField<String>('thumbnail', value);

  String? get title => getField<String>('title');
  set title(String? value) => setField<String>('title', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
