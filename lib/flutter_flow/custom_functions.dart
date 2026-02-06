import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';

DateTime? converterDateTimeEmString(String? time) {
  // crie uma função que converter date time em string
  if (time == null) return null;
  try {
    return DateTime.parse(time);
  } catch (e) {
    return null; // Return null if parsing fails
  }
}
