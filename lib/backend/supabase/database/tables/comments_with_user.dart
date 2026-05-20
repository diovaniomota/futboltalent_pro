import '../database.dart';

class CommentsWithUserTable extends SupabaseTable<CommentsWithUserRow> {
  @override
  String get tableName => 'comments_with_user';

  @override
  CommentsWithUserRow createRow(Map<String, dynamic> data) =>
      CommentsWithUserRow(data);
}

class CommentsWithUserRow extends SupabaseDataRow {
  CommentsWithUserRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => CommentsWithUserTable();

  String? get commentId => getField<String>('comment_id');
  set commentId(String? value) => setField<String>('comment_id', value);

  String? get content => getField<String>('content');
  set content(String? value) => setField<String>('content', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  String? get videoId => getField<String>('video_id');
  set videoId(String? value) => setField<String>('video_id', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get userName => getField<String>('user_name');
  set userName(String? value) => setField<String>('user_name', value);

  String? get userLastname => getField<String>('user_lastname');
  set userLastname(String? value) => setField<String>('user_lastname', value);

  String? get userPhoto => getField<String>('user_photo');
  set userPhoto(String? value) => setField<String>('user_photo', value);
}
