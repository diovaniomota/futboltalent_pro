import '../database.dart';

class UsersTable extends SupabaseTable<UsersRow> {
  @override
  String get tableName => 'users';

  @override
  UsersRow createRow(Map<String, dynamic> data) => UsersRow(data);
}

class UsersRow extends SupabaseDataRow {
  UsersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => UsersTable();

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String get name => getField<String>('name')!;
  set name(String value) => setField<String>('name', value);

  String? get photoUrl => getField<String>('photo_url');
  set photoUrl(String? value) => setField<String>('photo_url', value);

  int get countryId => getField<int>('country_id')!;
  set countryId(int value) => setField<int>('country_id', value);

  int get roleId => getField<int>('role_id')!;
  set roleId(int value) => setField<int>('role_id', value);

  String get userId => getField<String>('user_id')!;
  set userId(String value) => setField<String>('user_id', value);

  DateTime? get updateAt => getField<DateTime>('update_at');
  set updateAt(DateTime? value) => setField<DateTime>('update_at', value);

  int? get planId => getField<int>('plan_id');
  set planId(int? value) => setField<int>('plan_id', value);

  DateTime get birthday => getField<DateTime>('birthday')!;
  set birthday(DateTime value) => setField<DateTime>('birthday', value);

  String get lastname => getField<String>('lastname')!;
  set lastname(String value) => setField<String>('lastname', value);

  String? get banner => getField<String>('banner');
  set banner(String? value) => setField<String>('banner', value);

  String get username => getField<String>('username')!;
  set username(String value) => setField<String>('username', value);

  String? get city => getField<String>('city');
  set city(String? value) => setField<String>('city', value);

  String? get userType => getField<String>('userType');
  set userType(String? value) => setField<String>('userType', value);
}
