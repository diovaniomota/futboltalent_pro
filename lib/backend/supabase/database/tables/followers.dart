import '../database.dart';

class FollowersTable extends SupabaseTable<FollowersRow> {
  @override
  String get tableName => 'followers';

  @override
  FollowersRow createRow(Map<String, dynamic> data) => FollowersRow(data);
}

class FollowersRow extends SupabaseDataRow {
  FollowersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => FollowersTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String get followerId => getField<String>('follower_id')!;
  set followerId(String value) => setField<String>('follower_id', value);

  String get followingId => getField<String>('following_id')!;
  set followingId(String value) => setField<String>('following_id', value);
}
