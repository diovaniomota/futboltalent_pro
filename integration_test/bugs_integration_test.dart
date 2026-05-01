import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/club_application_utils.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/video_visibility_utils.dart';
import 'package:futboltalent_pro/gamification/gamification_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('QA bug regression smoke checks', () {
    test('club application rows deduplicate across both application tables',
        () {
      final merged = mergeClubApplicationRows([
        {
          'id': 'old',
          'convocatoria_id': 'conv-1',
          'jugador_id': 'player-1',
          'created_at': '2026-04-30T10:00:00Z',
        },
        {
          'id': 'new',
          'convocatoria_id': 'conv-1',
          'player_id': 'player-1',
          'created_at': '2026-04-30T11:00:00Z',
        },
      ]);

      expect(merged, hasLength(1));
      expect(merged.single['id'], 'new');
      expect(clubApplicationPlayerId(merged.single), 'player-1');
    });

    test('deleted or missing videos are excluded from evaluation flows', () {
      expect(
        isPublicVideoCandidate({
          'video_url': 'https://example.com/video.mp4',
          'is_public': true,
        }),
        isTrue,
      );
      expect(
        isPublicVideoCandidate({
          'video_url': 'https://example.com/video.mp4',
          'is_deleted': true,
        }),
        isFalse,
      );
      expect(isPublicVideoCandidate({'video_url': ''}), isFalse);
    });

    test('challenge XP eligibility follows valid video visibility', () {
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
          'deleted_at': '2026-04-30T12:00:00Z',
        }),
        isFalse,
      );
    });
  });
}
