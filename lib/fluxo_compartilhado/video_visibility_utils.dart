import 'video_source_utils.dart';

bool truthyVideoFlag(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes' || text == 'sim';
}

bool falseyVideoFlag(dynamic value) {
  if (value is bool) return !value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'false' || text == '0' || text == 'no' || text == 'nao';
}

bool isSoftDeletedVideoRow(Map<String, dynamic> row) {
  final deletedAt = row['deleted_at']?.toString().trim() ?? '';
  if (deletedAt.isNotEmpty && deletedAt.toLowerCase() != 'null') return true;
  return truthyVideoFlag(row['is_deleted']);
}

String playableVideoUrl(Map<String, dynamic> row) {
  final url = row['video_url']?.toString().trim() ??
      row['url']?.toString().trim() ??
      '';
  if (url.isEmpty || isLegacyPlaceholderVideoUrl(url)) return '';
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return '';
  }
  return url;
}

bool hasPlayableVideo(Map<String, dynamic> row) =>
    playableVideoUrl(row).isNotEmpty;

bool isPublicVideoCandidate(Map<String, dynamic> row) {
  if (isSoftDeletedVideoRow(row)) return false;
  if (falseyVideoFlag(row['is_public'])) return false;
  return hasPlayableVideo(row);
}
