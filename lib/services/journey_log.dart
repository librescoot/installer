import 'dart:convert';

import 'package:flutter/foundation.dart';

String formatJourneyEvent(
  String event, [
  Map<String, Object?> fields = const {},
]) {
  return 'Journey: ${jsonEncode(<String, Object?>{'event': event, ...fields})}';
}

void logJourneyEvent(String event, [Map<String, Object?> fields = const {}]) {
  debugPrint(formatJourneyEvent(event, fields));
}
