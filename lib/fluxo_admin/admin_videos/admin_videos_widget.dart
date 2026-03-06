import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'admin_videos_model.dart';
export 'admin_videos_model.dart';

class AdminVideosWidget extends StatefulWidget {
  const AdminVideosWidget({super.key});

  static String routeName = 'admin_videos';
  static String routePath = '/adminVideos';

  @override
  State<AdminVideosWidget> createState() => _AdminVideosWidgetState();
}

class _AdminVideosWidgetState extends State<AdminVideosWidget> {
  late AdminVideosModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  List<Map<String, dynamic>> _videos = [];
  final Map<String, String> _userNameById = {};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminVideosModel());
    _loadVideos();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final videosResponse = await SupaFlow.client
          .from('videos')
          .select(
              'id, title, description, video_url, thumbnail_url, created_at, user_id, is_public')
          .eq('is_public', true)
          .order('created_at', ascending: false);

      final usersResponse =
          await SupaFlow.client.from('users').select('user_id, name, lastname');

      final userNameById = <String, String>{};
      for (final row
          in List<Map<String, dynamic>>.from(usersResponse as List)) {
        final userId = (row['user_id'] ?? '').toString();
        if (userId.isEmpty) continue;
        final fullName = '${row['name'] ?? ''} ${row['lastname'] ?? ''}'.trim();
        userNameById[userId] =
            fullName.isEmpty ? 'Usuario desconocido' : fullName;
      }

      if (mounted) {
        setState(() {
          _videos = List<Map<String, dynamic>>.from(videosResponse as List);
          _userNameById
            ..clear()
            ..addAll(userNameById);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading videos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openVideo(Map<String, dynamic> video) {
    final url = (video['video_url'] ?? '').toString().trim();
    if (url.isEmpty) {
      _showSnack('Este video no tiene URL válida.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => _AdminVideoPlayerDialog(
        title: (video['title'] ?? 'Video').toString(),
        url: url,
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteVideo(Map<String, dynamic> video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Video'),
        content: Text(
            'Eliminar "${video['title'] ?? 'este video'}"? Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final videoId = (video['id'] ?? '').toString().trim();
    if (videoId.isEmpty) {
      _showSnack('No se pudo identificar el video.');
      return;
    }

    try {
      bool removed = false;

      // 1) Try hard delete first.
      try {
        final deleteResponse = await SupaFlow.client
            .from('videos')
            .delete()
            .eq('id', videoId)
            .select('id');
        removed = (deleteResponse as List).isNotEmpty;
      } catch (e) {
        debugPrint('Hard delete failed for video $videoId: $e');
      }

      // 2) Fallback to soft delete so it disappears from feed/admin list.
      if (!removed) {
        try {
          final updateResponse = await SupaFlow.client
              .from('videos')
              .update({
                'is_public': false,
              })
              .eq('id', videoId)
              .select('id, is_public');
          removed = (updateResponse as List).isNotEmpty;
        } catch (e) {
          debugPrint('Soft delete failed for video $videoId: $e');
        }
      }

      if (!removed) {
        _showSnack(
          'No se pudo eliminar. Verificá permisos RLS de admin en la tabla videos.',
        );
        return;
      }

      if (mounted) {
        setState(() {
          _videos.removeWhere(
            (item) => (item['id'] ?? '').toString() == videoId,
          );
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video eliminado')),
        );
        _loadVideos();
      }
    } catch (e) {
      debugPrint('Error deleting video: $e');
      _showSnack('Error al eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        title: Text(
          'Videos',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                fontFamily: 'Poppins',
                color: Colors.white,
                letterSpacing: 0.0,
              ),
        ),
        centerTitle: true,
        elevation: 2.0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? const Center(child: Text('No hay videos'))
              : RefreshIndicator(
                  onRefresh: _loadVideos,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _videos.length,
                    itemBuilder: (context, index) =>
                        _buildVideoCard(_videos[index]),
                  ),
                ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    final userId = (video['user_id'] ?? '').toString();
    final userName = _userNameById[userId] ?? 'Usuario desconocido';
    final createdAt = video['created_at'] != null
        ? DateTime.tryParse(video['created_at'].toString())
        : null;
    final dateStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openVideo(video),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 96,
                  height: 68,
                  color: Colors.grey.shade300,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (video['thumbnail_url'] != null &&
                          video['thumbnail_url'].toString().isNotEmpty)
                        Image.network(
                          video['thumbnail_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.video_library, size: 30),
                        )
                      else
                        const Icon(Icons.video_library, size: 30),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['title']?.toString() ?? 'Sin titulo',
                      style: FlutterFlowTheme.of(context).titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: FlutterFlowTheme.of(context).bodySmall,
                    ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              letterSpacing: 0.0,
                            ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openVideo(video),
                          icon: const Icon(Icons.play_circle_outline, size: 16),
                          label: const Text('Ver'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _deleteVideo(video),
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                          label: const Text(
                            'Eliminar',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminVideoPlayerDialog extends StatefulWidget {
  const _AdminVideoPlayerDialog({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<_AdminVideoPlayerDialog> createState() =>
      _AdminVideoPlayerDialogState();
}

class _AdminVideoPlayerDialogState extends State<_AdminVideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null || widget.url.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'URL inválida.';
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo reproducir el video.';
        });
      }
      debugPrint('Admin video player init error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null || controller == null)
              SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    _error ?? 'No se pudo reproducir el video.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Column(
                children: [
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio <= 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (controller.value.isPlaying) {
                              controller.pause();
                            } else {
                              controller.play();
                            }
                          });
                        },
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFF0D3B66),
                            bufferedColor: Color(0xFF8CB4D9),
                            backgroundColor: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
