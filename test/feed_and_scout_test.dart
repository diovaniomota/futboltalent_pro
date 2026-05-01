import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/guardian/guardian_mvp_service.dart';

void main() {
  group('Feed and scout guards (Bugs 10, 11, 12, 14, 18)', () {
    test('feed queries use explicit limits', () {
      final source = File('lib/feed_no_autenticado/feed/feed_widget.dart')
          .readAsStringSync();

      expect(RegExp(r'\.limit\(60\)').allMatches(source).length,
          greaterThanOrEqualTo(2));
    });

    test('deleted or missing videos are not visible to public/scout flows', () {
      expect(
        GuardianMvpService.isVideoVisibleToPublic({
          'video_url': 'https://example.com/video.mp4',
          'is_public': true,
        }),
        isTrue,
      );
      expect(
        GuardianMvpService.isVideoVisibleToPublic({
          'video_url': 'https://example.com/video.mp4',
          'deleted_at': '2026-04-30T12:00:00Z',
        }),
        isFalse,
      );
      expect(
        GuardianMvpService.isVideoVisibleToPublic({
          'video_url': '',
          'is_public': true,
        }),
        isFalse,
      );
    });

    test('profile grid does not initialize full video previews for thumbnails',
        () {
      final source = File(
        'lib/fluxo_jugador/perfil_jugador/perfil_jugador_widget.dart',
      ).readAsStringSync();
      final preparePreviewBody = RegExp(
        r'Future<void> _preparePreview\(\) async \{([\s\S]*?)\n  \}',
      ).firstMatch(source)!.group(1)!;

      expect(preparePreviewBody,
          isNot(contains('VideoPlayerController.networkUrl')));
    });
  });
}
