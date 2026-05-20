// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// ...existing code...
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';

Future<bool> delayedReturn(
  int delaySeconds,
) async {
  await Future.delayed(Duration(seconds: delaySeconds));
  return true;
}
