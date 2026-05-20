import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/gamification/gamification_service.dart';

void main() {
  group('Gamification Service (Bug 3 & 4)', () {
    test(
        'isProfileComplete should return true only when all fields are present',
        () {
      final incompleteUser = {
        'name': 'Test',
        'lastname': 'User',
        // missing photo, birthday, etc
      };
      expect(GamificationService.isProfileComplete(incompleteUser), false);

      final completeUser = {
        'name': 'Test',
        'lastname': 'User',
        'posicion': 'Delantero',
        'city': 'Madrid',
        'country': 'España',
        'birthday': '2005-01-01',
        'photo_url': 'https://example.com/photo.jpg'
      };
      expect(GamificationService.isProfileComplete(completeUser), true);
    });

    test('levelNameFromPoints should return correct tier names', () {
      expect(GamificationService.levelNameFromPoints(0), 'Aficionado');
      expect(GamificationService.levelNameFromPoints(150), 'Amateur');
      expect(GamificationService.levelNameFromPoints(400), 'Semi-Pro');
      expect(GamificationService.levelNameFromPoints(1000), 'Pro');
      expect(GamificationService.levelNameFromPoints(2000), 'Élite');
    });

    test('toInt should handle different input types gracefully', () {
      expect(GamificationService.toInt(10), 10);
      expect(GamificationService.toInt('20'), 20);
      expect(GamificationService.toInt(15.7), 16);
      expect(GamificationService.toInt(null, fallback: 5), 5);
      expect(GamificationService.toInt('invalid', fallback: 0), 0);
    });

    test('challenge XP eligibility requires a playable public video', () {
      expect(
        GamificationService.isXpEligibleVideoRow({
          'video_url': 'https://example.com/video.mp4',
          'is_public': true,
        }),
        isTrue,
      );
      expect(
        GamificationService.isXpEligibleVideoRow({
          'video_url': 'https://example.com/video.mp4',
          'is_public': false,
        }),
        isFalse,
      );
      expect(
        GamificationService.isXpEligibleVideoRow({
          'video_url': 'https://example.com/video.mp4',
          'is_deleted': true,
        }),
        isFalse,
      );
      expect(
        GamificationService.isXpEligibleVideoRow({'video_url': ''}),
        isFalse,
      );
    });
  });
}
