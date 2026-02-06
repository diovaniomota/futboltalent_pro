import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'comments_sheet_model.dart';
export 'comments_sheet_model.dart';

class CommentsSheetWidget extends StatefulWidget {
  const CommentsSheetWidget({
    super.key,
    required this.videoID,
    this.width,
    this.height,
  });

  final String? videoID;
  final double? width;
  final double? height;

  @override
  State<CommentsSheetWidget> createState() => _CommentsSheetWidgetState();
}

class _CommentsSheetWidgetState extends State<CommentsSheetWidget> {
  late CommentsSheetModel _model;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CommentsSheetModel());
    _loadComments();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (widget.videoID == null) return;
    try {
      final response = await SupaFlow.client
          .from('comments_with_user')
          .select()
          .eq('video_id', widget.videoID!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar comentários: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || widget.videoID == null) return;

    final userId = currentUserUid;
    if (userId.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await SupaFlow.client.from('comments').insert({
        'content': text,
        'video_id': widget.videoID!,
        'user_id': userId,
      });

      _commentController.clear();
      await _loadComments();
    } catch (e) {
      debugPrint('Erro ao adicionar comentário: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Comentarios',
              style: theme.titleMedium.override(
                fontFamily: 'Inter',
                color: Colors.black,
                letterSpacing: 0.0,
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: theme.primary),
                  )
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin comentarios aún.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final userPhoto = comment['user_photo'] as String?;
                          final userName =
                              comment['user_name'] as String? ?? 'Usuario';
                          final content = comment['content'] as String? ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: NetworkImage(
                                    (userPhoto != null && userPhoto.isNotEmpty)
                                        ? userPhoto
                                        : 'https://via.placeholder.com/150',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        content,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _addComment,
                  icon: _isSending
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.primary,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: theme.primary,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
