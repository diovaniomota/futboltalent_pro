import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/profile_taxonomy_utils.dart';

void main() {
  group('Profile validation and taxonomy (Bugs 15, 16, 17)', () {
    test('normalized country options are unique and alphabetically sorted', () {
      final countries = buildNormalizedOptions(
        ['Zambia', ' argentina ', 'Brasil', 'Argentina', 'Chile'],
        normalizeCountryName,
      );

      expect(countries, ['Argentina', 'Brasil', 'Chile', 'Zambia']);
    });

    test('category normalization only returns known category aliases', () {
      expect(normalizePlayerCategory('sub 17'), 'Sub-17');
      expect(normalizePlayerCategory('u20'), 'Sub-20');
      expect(canonicalPlayerCategories, contains('Sub-17'));
      expect(
        canonicalPlayerCategories.contains(normalizePlayerCategory('sub 17')),
        isTrue,
      );
    });

    test('height, weight and experience ranges reject unrealistic values', () {
      bool isValidHeight(String text) {
        final value = double.tryParse(text);
        return value != null && value >= 100 && value <= 250;
      }

      bool isValidWeight(String text) {
        final value = double.tryParse(text);
        return value != null && value >= 30 && value <= 200;
      }

      bool isValidExperience(String text) {
        final value = int.tryParse(text);
        return value != null && value >= 0 && value <= 60;
      }

      expect(isValidHeight('180'), isTrue);
      expect(isValidHeight('90'), isFalse);
      expect(isValidHeight('300'), isFalse);
      expect(isValidWeight('70'), isTrue);
      expect(isValidWeight('5'), isFalse);
      expect(isValidWeight('400'), isFalse);
      expect(isValidExperience('12'), isTrue);
      expect(isValidExperience('-1'), isFalse);
      expect(isValidExperience('120'), isFalse);
    });
  });
}
