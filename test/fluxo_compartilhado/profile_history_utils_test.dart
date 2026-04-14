import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/profile_history_utils.dart';

void main() {
  group('profile_history_utils', () {
    test('parseHistoryYear accepts valid years and extracts years from text', () {
      expect(parseHistoryYear(2004), 2004);
      expect(parseHistoryYear('2018'), 2018);
      expect(parseHistoryYear('Temporada 2019/2020'), 2019);
      expect(parseHistoryYear('1899'), isNull);
      expect(parseHistoryYear('sin dato'), isNull);
    });

    test('parseHistoryCurrentFlag detects current status across legacy fields', () {
      expect(parseHistoryCurrentFlag({'is_current': true}), isTrue);
      expect(parseHistoryCurrentFlag({'actual': '1'}), isTrue);
      expect(parseHistoryCurrentFlag({'periodo': '2021 - Presente'}), isTrue);
      expect(parseHistoryCurrentFlag({'period': '2018 - 2020'}), isFalse);
    });

    test('normalizeProfileHistory maps legacy fields, filters blanks and sorts current first', () {
      final normalized = normalizeProfileHistory([
        {
          'club': 'Club actual',
          'posición': 'Delantero',
          'inicio': '2023',
          'presente': true,
          'nota': 'Titular',
        },
        {
          'nombre': 'Club anterior',
          'posicion': 'Volante',
          'desde': '2020',
          'hasta': '2022',
        },
        {
          'nombre': '',
          'period': '',
        },
      ]);

      expect(normalized, hasLength(2));
      expect(normalized.first['name'], 'Club actual');
      expect(normalized.first['position'], 'Delantero');
      expect(normalized.first['start_year'], 2023);
      expect(normalized.first['is_current'], isTrue);
      expect(normalized[1]['name'], 'Club anterior');
      expect(normalized[1]['end_year'], 2022);
    });

    test('formatProfileHistoryPeriod and currentClubFromProfileHistory work together', () {
      final items = normalizeProfileHistory([
        {'club': 'Academia Norte', 'start_year': 2022, 'is_current': true},
        {'club': 'Atlético Sur', 'start_year': 2019, 'end_year': 2021},
      ]);

      expect(formatProfileHistoryPeriod(items.first), '2022 - presente');
      expect(formatProfileHistoryPeriod(items.last), '2019 - 2021');
      expect(currentClubFromProfileHistory(items), 'Academia Norte');
    });

    test('normalizeProfileHistory accepts JSON string payload', () {
      final normalized = normalizeProfileHistory(
        '[{"club":"River","inicio":"2017","fin":"2019"}]',
      );

      expect(normalized, hasLength(1));
      expect(normalized.first['name'], 'River');
      expect(normalized.first['start_year'], 2017);
      expect(normalized.first['end_year'], 2019);
    });
  });
}
