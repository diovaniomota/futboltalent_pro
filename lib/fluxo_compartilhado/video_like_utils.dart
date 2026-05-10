import '/backend/supabase/supabase.dart';

class VideoLikeSnapshot {
  const VideoLikeSnapshot({
    required this.isLiked,
    required this.count,
  });

  final bool isLiked;
  final int count;
}

Future<VideoLikeSnapshot> fetchVideoLikeSnapshot({
  required String videoId,
  String? userId,
  int fallbackCount = 0,
}) async {
  final cleanVideoId = videoId.trim();
  final cleanUserId = userId?.trim() ?? '';
  if (cleanVideoId.isEmpty) {
    return VideoLikeSnapshot(
      isLiked: false,
      count: fallbackCount < 0 ? 0 : fallbackCount,
    );
  }

  try {
    const pageSize = 250;
    var from = 0;
    var total = 0;
    var isLiked = false;

    while (true) {
      final response = await SupaFlow.client
          .from('likes')
          .select('user_id')
          .eq('video_id', cleanVideoId)
          .range(from, from + pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(response as List);
      total += rows.length;
      if (!isLiked && cleanUserId.isNotEmpty) {
        isLiked = rows.any((row) => row['user_id']?.toString() == cleanUserId);
      }
      if (rows.length < pageSize) break;
      from += pageSize;
    }

    return VideoLikeSnapshot(isLiked: isLiked, count: total);
  } catch (_) {
    return VideoLikeSnapshot(
      isLiked: false,
      count: fallbackCount < 0 ? 0 : fallbackCount,
    );
  }
}

Future<void> persistVideoLikeCount({
  required String videoId,
  required int count,
}) async {
  final cleanVideoId = videoId.trim();
  if (cleanVideoId.isEmpty) return;
  try {
    await SupaFlow.client.from('videos').update({
      'likes_count': count < 0 ? 0 : count,
    }).eq('id', cleanVideoId);
  } catch (_) {}
}
