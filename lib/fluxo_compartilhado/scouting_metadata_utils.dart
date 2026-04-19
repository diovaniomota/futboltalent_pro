import 'dart:convert';

class ScoutingMetadataUtils {
  static const List<String> states = [
    'descubierto',
    'en_acompanamiento',
    'prioridad',
    'descartado',
  ];

  static String labelFromState(String state) {
    switch (state) {
      case 'descubierto':
        return 'Descubierto';
      case 'en_acompanamiento':
        return 'En acompañamiento';
      case 'prioridad':
        return 'Prioridad';
      case 'descartado':
        return 'Descartado';
      default:
        return 'Descubierto';
    }
  }

  static int ratingFromState(String state) {
    switch (state) {
      case 'descubierto':
        return 1;
      case 'en_acompanamiento':
        return 2;
      case 'prioridad':
        return 4;
      case 'descartado':
        return 5;
      default:
        return 1;
    }
  }

  static String stateFromItem(Map<String, dynamic> item) {
    final direct =
        item['scouting_state']?.toString().trim().toLowerCase() ?? '';
    if (states.contains(direct)) return direct;

    final rating = (item['calificacion'] as int?) ?? 1;
    switch (rating) {
      case 1:
        return 'descubierto';
      case 2:
        return 'en_acompanamiento';
      case 3:
      case 4:
        return 'prioridad';
      case 5:
        return 'descartado';
      default:
        return 'descubierto';
    }
  }

  static List<String> parseTags(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    }

    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return const [];

    if (text.startsWith('[') || text.endsWith(']')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList();
        }
      } catch (_) {
        return const [];
      }
    }

    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
}
