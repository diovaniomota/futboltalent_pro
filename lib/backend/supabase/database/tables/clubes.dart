import '../database.dart';

class ClubesTable extends SupabaseTable<ClubesRow> {
  @override
  String get tableName => 'clubes';

  @override
  ClubesRow createRow(Map<String, dynamic> data) => ClubesRow(data);
}

class ClubesRow extends SupabaseDataRow {
  ClubesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ClubesTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get email => getField<String>('email');
  set email(String? value) => setField<String>('email', value);

  String? get telephone => getField<String>('telephone');
  set telephone(String? value) => setField<String>('telephone', value);

  int? get dni => getField<int>('dni');
  set dni(int? value) => setField<int>('dni', value);

  String get aboutClub => getField<String>('about_club')!;
  set aboutClub(String value) => setField<String>('about_club', value);

  bool get isApproved => getField<bool>('is_approved')!;
  set isApproved(bool value) => setField<bool>('is_approved', value);

  String get nombreCorto => getField<String>('nombre_corto')!;
  set nombreCorto(String value) => setField<String>('nombre_corto', value);

  String get liga => getField<String>('liga')!;
  set liga(String value) => setField<String>('liga', value);

  String get sitioWeb => getField<String>('sitio_web')!;
  set sitioWeb(String value) => setField<String>('sitio_web', value);
}
