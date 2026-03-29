
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

DateTime? converterDateTimeEmString(String? time) {
  // crie uma função que converter date time em string
  if (time == null) return null;
  try {
    return DateTime.parse(time);
  } catch (e) {
    return null; // Return null if parsing fails
  }
}
