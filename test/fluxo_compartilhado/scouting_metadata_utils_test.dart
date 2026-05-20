import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/scouting_metadata_utils.dart';

void main() {
  group('scouting_metadata_utils', () {
    test('labelFromState returns expected labels and fallback', () {
      expect(
          ScoutingMetadataUtils.labelFromState('descubierto'), 'Descubierto');
      expect(
        ScoutingMetadataUtils.labelFromState('en_acompanamiento')
            .startsWith('En '),
        isTrue,
      );
      expect(ScoutingMetadataUtils.labelFromState('prioridad'), 'Prioridad');
      expect(ScoutingMetadataUtils.labelFromState('descartado'), 'Descartado');
      expect(ScoutingMetadataUtils.labelFromState('unknown'), 'Descubierto');
    });

    test('ratingFromState maps states to legacy rating scale', () {
      expect(ScoutingMetadataUtils.ratingFromState('descubierto'), 1);
      expect(ScoutingMetadataUtils.ratingFromState('en_acompanamiento'), 2);
      expect(ScoutingMetadataUtils.ratingFromState('prioridad'), 4);
      expect(ScoutingMetadataUtils.ratingFromState('descartado'), 5);
      expect(ScoutingMetadataUtils.ratingFromState('other'), 1);
    });

    test('stateFromItem prefers explicit scouting_state', () {
      final item = {
        'scouting_state': 'prioridad',
        'calificacion': 1,
      };
      expect(ScoutingMetadataUtils.stateFromItem(item), 'prioridad');
    });

    test('stateFromItem falls back to rating when scouting_state is missing',
        () {
      expect(ScoutingMetadataUtils.stateFromItem({'calificacion': 1}),
          'descubierto');
      expect(
        ScoutingMetadataUtils.stateFromItem({'calificacion': 2}),
        'en_acompanamiento',
      );
      expect(ScoutingMetadataUtils.stateFromItem({'calificacion': 3}),
          'prioridad');
      expect(ScoutingMetadataUtils.stateFromItem({'calificacion': 4}),
          'prioridad');
      expect(ScoutingMetadataUtils.stateFromItem({'calificacion': 5}),
          'descartado');
    });

    test('parseTags supports list input with dedupe/trim', () {
      final tags = ScoutingMetadataUtils.parseTags(
          [' potencia ', 'potencia', '', 'vision']);
      expect(tags, ['potencia', 'vision']);
    });

    test('parseTags supports json string and comma string', () {
      final fromJson =
          ScoutingMetadataUtils.parseTags('["uno", " dos ", "uno"]');
      expect(fromJson, ['uno', 'dos']);

      final fromComma = ScoutingMetadataUtils.parseTags('uno, dos, ,uno');
      expect(fromComma, ['uno', 'dos']);
    });

    test('parseTags returns empty on blank/invalid values', () {
      expect(ScoutingMetadataUtils.parseTags(null), isEmpty);
      expect(ScoutingMetadataUtils.parseTags(''), isEmpty);
      expect(ScoutingMetadataUtils.parseTags('[]'), isEmpty);
      expect(ScoutingMetadataUtils.parseTags('[invalid-json'), isEmpty);
    });
  });
}
