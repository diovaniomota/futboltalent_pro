

DateTime? converterDateTimeEmString(String? time) {
  // crie uma função que converter date time em string
  if (time == null) return null;
  try {
    return DateTime.parse(time);
  } catch (e) {
    return null; // Return null if parsing fails
  }
}
