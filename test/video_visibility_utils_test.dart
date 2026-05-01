import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/video_visibility_utils.dart';

void main() {
  group('video visibility guards', () {
    test('public candidates must be playable and not deleted', () {
      expect(
        isPublicVideoCandidate({
          'video_url': 'https://example.com/a.mp4',
          'is_public': true,
        }),
        isTrue,
      );
      expect(
        isPublicVideoCandidate({
          'video_url': 'https://example.com/a.mp4',
          'deleted_at': '2026-04-30T12:00:00Z',
        }),
        isFalse,
      );
      expect(
        isPublicVideoCandidate({
          'video_url': 'https://example.com/a.mp4',
          'is_deleted': 'true',
        }),
        isFalse,
      );
      expect(
        isPublicVideoCandidate({
          'video_url': 'file:///tmp/a.mp4',
          'is_public': true,
        }),
        isFalse,
      );
    });
  });
}
