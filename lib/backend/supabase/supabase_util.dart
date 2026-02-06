bool validSupabaseQuery(dynamic res) {
  if (res == null) return false;
  if (res is List && res.isEmpty) return false;
  return true;
}
