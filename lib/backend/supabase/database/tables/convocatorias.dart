import '../database.dart';

class ConvocatoriasTable extends SupabaseTable<ConvocatoriasRow> {
  @override
  String get tableName => 'convocatorias';

  @override
  ConvocatoriasRow createRow(Map<String, dynamic> data) =>
      ConvocatoriasRow(data);
}

class ConvocatoriasRow extends SupabaseDataRow {
  ConvocatoriasRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ConvocatoriasTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String get titulo => getField<String>('titulo')!;
  set titulo(String value) => setField<String>('titulo', value);

  String get ubicacion => getField<String>('ubicacion')!;
  set ubicacion(String value) => setField<String>('ubicacion', value);

  String? get descripcion => getField<String>('descripcion');
  set descripcion(String? value) => setField<String>('descripcion', value);

  int get edadMin => getField<int>('edad_min')!;
  set edadMin(int value) => setField<int>('edad_min', value);

  int? get edadMax => getField<int>('edad_max');
  set edadMax(int? value) => setField<int>('edad_max', value);

  DateTime? get fechaInicio => getField<DateTime>('fecha_inicio');
  set fechaInicio(DateTime? value) => setField<DateTime>('fecha_inicio', value);

  DateTime? get fechaFin => getField<DateTime>('fecha_fin');
  set fechaFin(DateTime? value) => setField<DateTime>('fecha_fin', value);

  String get clubId => getField<String>('club_id')!;
  set clubId(String value) => setField<String>('club_id', value);

  bool get isActive => getField<bool>('is_active')!;
  set isActive(bool value) => setField<bool>('is_active', value);
}
