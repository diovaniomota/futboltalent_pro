const List<String> canonicalPlayerPositions = [
  'Arquero',
  'Defensor central',
  'Lateral derecho',
  'Lateral izquierdo',
  'Mediocampista defensivo',
  'Mediocampista',
  'Mediocampista ofensivo',
  'Extremo derecho',
  'Extremo izquierdo',
  'Delantero',
];

const List<String> canonicalPlayerCategories = [
  'Sub-13',
  'Sub-15',
  'Sub-17',
  'Sub-20',
  'Senior',
];

const List<String> canonicalDominantFeet = [
  'Derecho',
  'Izquierdo',
  'Ambidiestro',
];

String collapseLabelSpaces(dynamic value) {
  final text = value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  if (text.toLowerCase() == 'null') return '';
  return text;
}

String _stripDiacritics(String input) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

String normalizeLookupKey(dynamic value) {
  final text = collapseLabelSpaces(value).toLowerCase();
  if (text.isEmpty) return '';
  return _stripDiacritics(text);
}

String titleCaseLabel(dynamic value) {
  final text = collapseLabelSpaces(value);
  if (text.isEmpty) return '';

  final words = text.split(' ');
  return words.map((word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();
    if (word.length <= 3 && word == word.toUpperCase()) {
      return word;
    }
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }).join(' ');
}

String normalizeCountryName(dynamic value) => titleCaseLabel(value);

String normalizeCityName(dynamic value) => titleCaseLabel(value);

String normalizeStateName(dynamic value) => titleCaseLabel(value);

String normalizeLeagueName(dynamic value) => titleCaseLabel(value);

String normalizePlayerPosition(dynamic value) {
  final raw = collapseLabelSpaces(value);
  if (raw.isEmpty) return '';

  final key = normalizeLookupKey(raw);
  const aliases = {
    'arquero': 'Arquero',
    'portero': 'Arquero',
    'goalkeeper': 'Arquero',
    'defensor central': 'Defensor central',
    'central': 'Defensor central',
    'zaguero central': 'Defensor central',
    'zaguero': 'Defensor central',
    'lateral derecho': 'Lateral derecho',
    'right back': 'Lateral derecho',
    'lateral izquierdo': 'Lateral izquierdo',
    'left back': 'Lateral izquierdo',
    'mediocampista defensivo': 'Mediocampista defensivo',
    'mediocentro defensivo': 'Mediocampista defensivo',
    'volante defensivo': 'Mediocampista defensivo',
    '5': 'Mediocampista defensivo',
    'mediocampista': 'Mediocampista',
    'mediocentro': 'Mediocampista',
    'volante': 'Mediocampista',
    'volante mixto': 'Mediocampista',
    'mediocampista ofensivo': 'Mediocampista ofensivo',
    'mediapunta': 'Mediocampista ofensivo',
    'enganche': 'Mediocampista ofensivo',
    '10': 'Mediocampista ofensivo',
    'extremo derecho': 'Extremo derecho',
    'right winger': 'Extremo derecho',
    'winger derecho': 'Extremo derecho',
    'extremo izquierdo': 'Extremo izquierdo',
    'left winger': 'Extremo izquierdo',
    'winger izquierdo': 'Extremo izquierdo',
    'delantero': 'Delantero',
    'delantero centro': 'Delantero',
    'centrodelantero': 'Delantero',
    '9': 'Delantero',
    'segundo delantero': 'Delantero',
    'forward': 'Delantero',
    'striker': 'Delantero',
  };

  return aliases[key] ?? titleCaseLabel(raw);
}

String normalizeDominantFoot(dynamic value) {
  final raw = collapseLabelSpaces(value);
  if (raw.isEmpty) return '';

  final key = normalizeLookupKey(raw);
  const aliases = {
    'derecho': 'Derecho',
    'right': 'Derecho',
    'izquierdo': 'Izquierdo',
    'left': 'Izquierdo',
    'ambidiestro': 'Ambidiestro',
    'ambidestro': 'Ambidiestro',
    'both': 'Ambidiestro',
  };

  return aliases[key] ?? titleCaseLabel(raw);
}

String? playerCategoryFromBirthday(dynamic birthday) {
  final raw = collapseLabelSpaces(birthday);
  if (raw.isEmpty) return null;

  try {
    final birth = DateTime.parse(raw);
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }

    if (age <= 13) return 'Sub-13';
    if (age <= 15) return 'Sub-15';
    if (age <= 17) return 'Sub-17';
    if (age <= 20) return 'Sub-20';
    return 'Senior';
  } catch (_) {
    return null;
  }
}

String normalizePlayerCategory(
  dynamic value, {
  dynamic birthday,
}) {
  final derived = playerCategoryFromBirthday(birthday);
  if (derived != null && derived.isNotEmpty) return derived;

  final raw = collapseLabelSpaces(value);
  if (raw.isEmpty) return '';

  final key = normalizeLookupKey(raw);
  const aliases = {
    'u12': 'Sub-13',
    'u13': 'Sub-13',
    'sub 13': 'Sub-13',
    'sub-13': 'Sub-13',
    'sub13': 'Sub-13',
    'u14': 'Sub-15',
    'u15': 'Sub-15',
    'sub 15': 'Sub-15',
    'sub-15': 'Sub-15',
    'sub15': 'Sub-15',
    'u16': 'Sub-17',
    'u17': 'Sub-17',
    'sub 17': 'Sub-17',
    'sub-17': 'Sub-17',
    'sub17': 'Sub-17',
    'u19': 'Sub-20',
    'u20': 'Sub-20',
    'sub 20': 'Sub-20',
    'sub-20': 'Sub-20',
    'sub20': 'Sub-20',
    'primera division': 'Senior',
    'primera': 'Senior',
    'mayor': 'Senior',
    'mayores': 'Senior',
    'senior': 'Senior',
  };

  return aliases[key] ?? titleCaseLabel(raw);
}

List<String> buildNormalizedOptions(
  Iterable<dynamic> values,
  String Function(dynamic value) normalizer,
) {
  final uniqueByKey = <String, String>{};
  for (final raw in values) {
    final normalized = normalizer(raw);
    if (normalized.isEmpty) continue;
    uniqueByKey.putIfAbsent(normalizeLookupKey(normalized), () => normalized);
  }

  final list = uniqueByKey.values.toList()
    ..sort((a, b) => a.trim().toLowerCase().compareTo(b.trim().toLowerCase()));
  return list;
}

String countryFlagEmoji(dynamic value) {
  final key = normalizeLookupKey(value);
  if (key.isEmpty) return '';

  const _flags = <String, String>{
    // Americas
    'argentina': '🇦🇷',
    'brasil': '🇧🇷',
    'brazil': '🇧🇷',
    'mexico': '🇲🇽',
    'colombia': '🇨🇴',
    'chile': '🇨🇱',
    'peru': '🇵🇪',
    'ecuador': '🇪🇨',
    'venezuela': '🇻🇪',
    'uruguay': '🇺🇾',
    'paraguay': '🇵🇾',
    'bolivia': '🇧🇴',
    'estados unidos': '🇺🇸',
    'usa': '🇺🇸',
    'canada': '🇨🇦',
    'costa rica': '🇨🇷',
    'panama': '🇵🇦',
    'honduras': '🇭🇳',
    'guatemala': '🇬🇹',
    'el salvador': '🇸🇻',
    'nicaragua': '🇳🇮',
    'cuba': '🇨🇺',
    'republica dominicana': '🇩🇴',
    'haiti': '🇭🇹',
    'jamaica': '🇯🇲',
    'trinidad y tobago': '🇹🇹',
    // Europe
    'espana': '🇪🇸',
    'españa': '🇪🇸',
    'spain': '🇪🇸',
    'portugal': '🇵🇹',
    'alemania': '🇩🇪',
    'germany': '🇩🇪',
    'francia': '🇫🇷',
    'france': '🇫🇷',
    'italia': '🇮🇹',
    'italy': '🇮🇹',
    'reino unido': '🇬🇧',
    'uk': '🇬🇧',
    'inglaterra': '🇬🇧',
    'england': '🇬🇧',
    'paises bajos': '🇳🇱',
    'holanda': '🇳🇱',
    'netherlands': '🇳🇱',
    'belgica': '🇧🇪',
    'belgium': '🇧🇪',
    'suiza': '🇨🇭',
    'switzerland': '🇨🇭',
    'austria': '🇦🇹',
    'suecia': '🇸🇪',
    'sweden': '🇸🇪',
    'noruega': '🇳🇴',
    'norway': '🇳🇴',
    'dinamarca': '🇩🇰',
    'denmark': '🇩🇰',
    'finlandia': '🇫🇮',
    'finland': '🇫🇮',
    'polonia': '🇵🇱',
    'poland': '🇵🇱',
    'rusia': '🇷🇺',
    'russia': '🇷🇺',
    'ucrania': '🇺🇦',
    'ukraine': '🇺🇦',
    'croacia': '🇭🇷',
    'croatia': '🇭🇷',
    'serbia': '🇷🇸',
    'rumania': '🇷🇴',
    'romania': '🇷🇴',
    'hungria': '🇭🇺',
    'hungary': '🇭🇺',
    'chequia': '🇨🇿',
    'czech republic': '🇨🇿',
    'grecia': '🇬🇷',
    'greece': '🇬🇷',
    'turquia': '🇹🇷',
    'turkey': '🇹🇷',
    'escocia': '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
    'gales': '🏴󠁧󠁢󠁷󠁬󠁳󠁿',
    'irlanda': '🇮🇪',
    'ireland': '🇮🇪',
    // Africa
    'nigeria': '🇳🇬',
    'ghana': '🇬🇭',
    'senegal': '🇸🇳',
    'marruecos': '🇲🇦',
    'morocco': '🇲🇦',
    'camerun': '🇨🇲',
    'cameroon': '🇨🇲',
    'costa de marfil': '🇨🇮',
    'ivory coast': '🇨🇮',
    'mali': '🇲🇱',
    'egipto': '🇪🇬',
    'egypt': '🇪🇬',
    'sudafrica': '🇿🇦',
    'south africa': '🇿🇦',
    'angola': '🇦🇴',
    'mozambique': '🇲🇿',
    'guinea ecuatorial': '🇬🇶',
    'cabo verde': '🇨🇻',
    // Asia & Oceania
    'japon': '🇯🇵',
    'japan': '🇯🇵',
    'corea del sur': '🇰🇷',
    'south korea': '🇰🇷',
    'china': '🇨🇳',
    'australia': '🇦🇺',
    'arabia saudita': '🇸🇦',
    'iran': '🇮🇷',
    'qatar': '🇶🇦',
    'emiratos arabes': '🇦🇪',
    'india': '🇮🇳',
  };

  return _flags[key] ?? '';
}
