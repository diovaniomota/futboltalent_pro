String storagePublicBaseUrlFromProbeUrl(String probeUrl) {
  const marker = '/storage/v1/object/public/';
  final markerIndex = probeUrl.indexOf(marker);
  if (markerIndex <= 0) return '';
  return probeUrl.substring(0, markerIndex);
}

String storageBucketPublicPrefixFromProbeUrl(String probeUrl) {
  const marker = '/storage/v1/object/public/';
  final markerIndex = probeUrl.indexOf(marker);
  if (markerIndex <= 0) return '';

  final base = probeUrl.substring(0, markerIndex);
  final suffix = probeUrl.substring(markerIndex + marker.length);
  final slashIndex = suffix.indexOf('/');
  if (slashIndex <= 0) return '';
  final bucket = suffix.substring(0, slashIndex);
  return '$base$marker$bucket';
}

bool isLegacyPlaceholderVideoUrl(String raw) {
  final input = raw.trim().toLowerCase();
  if (input.isEmpty) return false;
  if (input.contains('https://...')) return true;
  if (input.contains('tutorial_curso.mp4')) return true;
  if (input.contains('tutorial_ejercicio.mp4')) return true;
  final uri = Uri.tryParse(raw.trim());
  return uri?.host == '...';
}

String normalizePublicVideoSource({
  required String raw,
  required String storageProbeUrl,
}) {
  final input = raw.trim();
  if (input.isEmpty) return '';

  final lower = input.toLowerCase();
  if (lower.startsWith('blob:') || lower.startsWith('data:')) {
    return input;
  }

  if (input.startsWith('//')) {
    return 'https:$input';
  }

  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return input;
  }

  if (lower.startsWith('www.')) {
    return 'https://$input';
  }

  final storageBase = storagePublicBaseUrlFromProbeUrl(storageProbeUrl);
  if (input.startsWith('/storage/v1/object/public/')) {
    return storageBase.isEmpty ? input : '$storageBase$input';
  }

  if (input.startsWith('storage/v1/object/public/')) {
    return storageBase.isEmpty ? input : '$storageBase/$input';
  }

  final normalizedPath = input.replaceFirst(RegExp(r'^/+'), '');
  final normalizedLower = normalizedPath.toLowerCase();
  final hasVideoExtension = normalizedLower.endsWith('.mp4') ||
      normalizedLower.endsWith('.webm') ||
      normalizedLower.endsWith('.mov') ||
      normalizedLower.endsWith('.mkv') ||
      normalizedLower.endsWith('.m3u8');
  final looksLikeStoragePath = normalizedPath.contains('/') &&
      (normalizedPath.startsWith('challenge_assets/') ||
          normalizedPath.startsWith('videos/') ||
          normalizedPath.startsWith('tutorials/') ||
          normalizedPath.startsWith('covers/') ||
          hasVideoExtension);

  if (!looksLikeStoragePath) {
    return input;
  }

  final bucketPrefix = storageBucketPublicPrefixFromProbeUrl(storageProbeUrl);
  if (bucketPrefix.isEmpty) {
    return input;
  }
  return '$bucketPrefix/$normalizedPath';
}
