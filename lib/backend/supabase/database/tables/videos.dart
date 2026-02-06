import '../database.dart';

class VideosTable extends SupabaseTable<VideosRow> {
  @override
  String get tableName => 'videos';

  @override
  VideosRow createRow(Map<String, dynamic> data) => VideosRow(data);
}

class VideosRow extends SupabaseDataRow {
  VideosRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => VideosTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String get title => getField<String>('title')!;
  set title(String value) => setField<String>('title', value);

  String get videoUrl => getField<String>('video_url')!;
  set videoUrl(String value) => setField<String>('video_url', value);

  String get userId => getField<String>('user_id')!;
  set userId(String value) => setField<String>('user_id', value);

  String? get thumbnail => getField<String>('thumbnail');
  set thumbnail(String? value) => setField<String>('thumbnail', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);

  bool? get isPublic => getField<bool>('is_public');
  set isPublic(bool? value) => setField<bool>('is_public', value);

  int get likesCount => getField<int>('likes_count')!;
  set likesCount(int value) => setField<int>('likes_count', value);
}
