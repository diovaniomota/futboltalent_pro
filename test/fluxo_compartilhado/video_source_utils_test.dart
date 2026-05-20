import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/video_source_utils.dart';

void main() {
  group('video_source_utils', () {
    const probeUrl =
        'https://demo.supabase.co/storage/v1/object/public/Videos/__probe__.mp4';

    test('storagePublicBaseUrlFromProbeUrl extracts host base', () {
      expect(
        storagePublicBaseUrlFromProbeUrl(probeUrl),
        'https://demo.supabase.co',
      );
    });

    test('storageBucketPublicPrefixFromProbeUrl extracts bucket public prefix', () {
      expect(
        storageBucketPublicPrefixFromProbeUrl(probeUrl),
        'https://demo.supabase.co/storage/v1/object/public/Videos',
      );
    });

    test('normalizePublicVideoSource preserves valid absolute urls and web shortcuts', () {
      expect(
        normalizePublicVideoSource(
          raw: 'https://example.com/video.mp4',
          storageProbeUrl: probeUrl,
        ),
        'https://example.com/video.mp4',
      );
      expect(
        normalizePublicVideoSource(
          raw: '//cdn.example.com/video.mp4',
          storageProbeUrl: probeUrl,
        ),
        'https://cdn.example.com/video.mp4',
      );
      expect(
        normalizePublicVideoSource(
          raw: 'www.example.com/video.mp4',
          storageProbeUrl: probeUrl,
        ),
        'https://www.example.com/video.mp4',
      );
    });

    test('normalizePublicVideoSource reconstructs storage urls and bare bucket paths', () {
      expect(
        normalizePublicVideoSource(
          raw: '/storage/v1/object/public/Videos/tutorials/demo.mp4',
          storageProbeUrl: probeUrl,
        ),
        'https://demo.supabase.co/storage/v1/object/public/Videos/tutorials/demo.mp4',
      );

      expect(
        normalizePublicVideoSource(
          raw: 'challenge_assets/admin/tutorials/demo.mp4',
          storageProbeUrl: probeUrl,
        ),
        'https://demo.supabase.co/storage/v1/object/public/Videos/challenge_assets/admin/tutorials/demo.mp4',
      );
    });

    test('isLegacyPlaceholderVideoUrl detects invalid legacy placeholders', () {
      expect(isLegacyPlaceholderVideoUrl('https://.../tutorial_curso.mp4'), isTrue);
      expect(isLegacyPlaceholderVideoUrl('https://.../tutorial_ejercicio.mp4'), isTrue);
      expect(isLegacyPlaceholderVideoUrl('https://example.com/video.mp4'), isFalse);
    });
  });
}
