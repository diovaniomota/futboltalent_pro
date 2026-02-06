import '../database.dart';

class ConvocatoriasDetalleViewTable
    extends SupabaseTable<ConvocatoriasDetalleViewRow> {
  @override
  String get tableName => 'convocatorias_detalle_view';

  @override
  ConvocatoriasDetalleViewRow createRow(Map<String, dynamic> data) =>
      ConvocatoriasDetalleViewRow(data);
}

class ConvocatoriasDetalleViewRow extends SupabaseDataRow {
  ConvocatoriasDetalleViewRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ConvocatoriasDetalleViewTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String? get convocatoriaId => getField<String>('convocatoria_id');
  set convocatoriaId(String? value) =>
      setField<String>('convocatoria_id', value);

  String? get titulo => getField<String>('titulo');
  set titulo(String? value) => setField<String>('titulo', value);

  String? get ubicacion => getField<String>('ubicacion');
  set ubicacion(String? value) => setField<String>('ubicacion', value);

  String? get descripcion => getField<String>('descripcion');
  set descripcion(String? value) => setField<String>('descripcion', value);

  int? get edadMin => getField<int>('edad_min');
  set edadMin(int? value) => setField<int>('edad_min', value);

  int? get edadMax => getField<int>('edad_max');
  set edadMax(int? value) => setField<int>('edad_max', value);

  DateTime? get fechaInicio => getField<DateTime>('fecha_inicio');
  set fechaInicio(DateTime? value) => setField<DateTime>('fecha_inicio', value);

  DateTime? get fechaFin => getField<DateTime>('fecha_fin');
  set fechaFin(DateTime? value) => setField<DateTime>('fecha_fin', value);

  bool? get isActive => getField<bool>('is_active');
  set isActive(bool? value) => setField<bool>('is_active', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  String? get clubNombre => getField<String>('club_nombre');
  set clubNombre(String? value) => setField<String>('club_nombre', value);

  String? get clubFoto => getField<String>('club_foto');
  set clubFoto(String? value) => setField<String>('club_foto', value);

  int? get totalPostulaciones => getField<int>('total_postulaciones');
  set totalPostulaciones(int? value) =>
      setField<int>('total_postulaciones', value);

  bool? get yaPostulado => getField<bool>('ya_postulado');
  set yaPostulado(bool? value) => setField<bool>('ya_postulado', value);
}
