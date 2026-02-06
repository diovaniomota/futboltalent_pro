import '../database.dart';

class AdsTable extends SupabaseTable<AdsRow> {
  @override
  String get tableName => 'ads';

  @override
  AdsRow createRow(Map<String, dynamic> data) => AdsRow(data);
}

class AdsRow extends SupabaseDataRow {
  AdsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => AdsTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get title => getField<String>('title');
  set title(String? value) => setField<String>('title', value);

  String get adVideoUrl => getField<String>('ad_video_url')!;
  set adVideoUrl(String value) => setField<String>('ad_video_url', value);

  bool get isActive => getField<bool>('is_active')!;
  set isActive(bool value) => setField<bool>('is_active', value);

  int? get priority => getField<int>('priority');
  set priority(int? value) => setField<int>('priority', value);
}
