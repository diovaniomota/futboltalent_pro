import 'dart:convert';

String? firstNonEmptyHistoryValue(Iterable<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return null;
}

int? parseHistoryYear(dynamic rawValue) {
  if (rawValue == null) return null;

  if (rawValue is int) {
    return rawValue >= 1900 && rawValue <= 2100 ? rawValue : null;
  }

  final text = rawValue.toString().trim();
  if (text.isEmpty) return null;

  final exact = int.tryParse(text);
  if (exact != null) {
    return exact >= 1900 && exact <= 2100 ? exact : null;
  }

  final match = RegExp(r'(?<!\d)(19|20)\d{2}(?!\d)').firstMatch(text);
  if (match == null) return null;
  return int.tryParse(match.group(0)!);
}

bool parseHistoryCurrentFlag(Map<String, dynamic> item) {
  final direct = item['is_current'];
  if (direct is bool) return direct;

  final currentValues = [
    item['is_current'],
    item['actual'],
    item['current'],
    item['presente'],
  ];
  for (final value in currentValues) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
  }

  final rawPeriod = firstNonEmptyHistoryValue([
    item['period'],
    item['periodo'],
    item['range'],
  ]);
  if (rawPeriod == null) return false;

  final normalized = rawPeriod.toLowerCase();
  return normalized.contains('presente') ||
      normalized.contains('present') ||
      normalized.contains('actualidad') ||
      normalized.contains('atual');
}

List<Map<String, dynamic>> normalizeProfileHistory(dynamic rawValue) {
  dynamic source = rawValue;
  if (source is String) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return const [];
    try {
      source = jsonDecode(trimmed);
    } catch (_) {
      return const [];
    }
  }

  if (source is! List) return const [];

  final items = <Map<String, dynamic>>[];
  for (final entry in source) {
    final map = entry is Map<String, dynamic>
        ? Map<String, dynamic>.from(entry)
        : entry is Map
            ? Map<String, dynamic>.from(entry)
            : null;
    if (map == null) continue;

    final isCurrent = parseHistoryCurrentFlag(map);
    final startYear = parseHistoryYear(
      firstNonEmptyHistoryValue([
        map['start_year'],
        map['from_year'],
        map['desde'],
        map['inicio'],
      ]),
    );
    final endYear = isCurrent
        ? null
        : parseHistoryYear(
            firstNonEmptyHistoryValue([
              map['end_year'],
              map['to_year'],
              map['hasta'],
              map['fin'],
            ]),
          );

    final period = firstNonEmptyHistoryValue([
      map['period'],
      map['periodo'],
      map['range'],
    ]);

    items.add({
      'name': firstNonEmptyHistoryValue([
            map['name'],
            map['nombre'],
            map['club'],
            map['club_name'],
          ]) ??
          '',
      'position': firstNonEmptyHistoryValue([
            map['position'],
            map['posicion'],
            map['posición'],
          ]) ??
          '',
      'note': firstNonEmptyHistoryValue([
            map['note'],
            map['nota'],
            map['description'],
          ]) ??
          '',
      'start_year': startYear,
      'end_year': endYear,
      'is_current': isCurrent,
      'period': period ?? '',
    });
  }

  final filtered = items.where((item) {
    final name = item['name']?.toString().trim() ?? '';
    final startYear = item['start_year'];
    final endYear = item['end_year'];
    final period = item['period']?.toString().trim() ?? '';
    return name.isNotEmpty ||
        startYear != null ||
        endYear != null ||
        period.isNotEmpty;
  }).toList();

  filtered.sort((a, b) {
    final aCurrent = a['is_current'] == true ? 1 : 0;
    final bCurrent = b['is_current'] == true ? 1 : 0;
    if (aCurrent != bCurrent) return bCurrent.compareTo(aCurrent);

    final aEnd = a['end_year'] as int? ?? a['start_year'] as int? ?? 0;
    final bEnd = b['end_year'] as int? ?? b['start_year'] as int? ?? 0;
    return bEnd.compareTo(aEnd);
  });

  return filtered;
}

String formatProfileHistoryPeriod(Map<String, dynamic> item) {
  final startYear = parseHistoryYear(item['start_year']);
  final endYear = parseHistoryYear(item['end_year']);
  final isCurrent = item['is_current'] == true;
  final legacyPeriod = item['period']?.toString().trim() ?? '';

  if (startYear != null && isCurrent) {
    return '$startYear - presente';
  }
  if (startYear != null && endYear != null) {
    return '$startYear - $endYear';
  }
  if (startYear != null) {
    return '$startYear';
  }
  if (endYear != null) {
    return '$endYear';
  }
  return legacyPeriod;
}

String? currentClubFromProfileHistory(dynamic rawValue) {
  final items = normalizeProfileHistory(rawValue);
  for (final item in items) {
    final name = item['name']?.toString().trim() ?? '';
    if (name.isEmpty) continue;
    if (item['is_current'] == true) return name;
  }

  for (final item in items) {
    final name = item['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
  }

  return null;
}
