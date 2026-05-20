import '../database.dart';

class SearchViewTable extends SupabaseTable<SearchViewRow> {
  @override
  String get tableName => 'search_view';

  @override
  SearchViewRow createRow(Map<String, dynamic> data) => SearchViewRow(data);
}

class SearchViewRow extends SupabaseDataRow {
  SearchViewRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => SearchViewTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String? get nombre => getField<String>('nombre');
  set nombre(String? value) => setField<String>('nombre', value);

  String? get tipo => getField<String>('tipo');
  set tipo(String? value) => setField<String>('tipo', value);

  String? get imagen => getField<String>('imagen');
  set imagen(String? value) => setField<String>('imagen', value);

  String? get descripcion => getField<String>('descripcion');
  set descripcion(String? value) => setField<String>('descripcion', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);
}
