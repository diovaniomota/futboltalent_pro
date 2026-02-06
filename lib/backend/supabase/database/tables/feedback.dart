import '../database.dart';

class FeedbackTable extends SupabaseTable<FeedbackRow> {
  @override
  String get tableName => 'feedback';

  @override
  FeedbackRow createRow(Map<String, dynamic> data) => FeedbackRow(data);
}

class FeedbackRow extends SupabaseDataRow {
  FeedbackRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => FeedbackTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get mensaje => getField<String>('mensaje');
  set mensaje(String? value) => setField<String>('mensaje', value);

  String? get pantalla => getField<String>('pantalla');
  set pantalla(String? value) => setField<String>('pantalla', value);

  String? get tipo => getField<String>('tipo');
  set tipo(String? value) => setField<String>('tipo', value);
}
