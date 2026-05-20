import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/guardian/guardian_mvp_service.dart';
import 'package:flutter/material.dart';
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
  String? _deletingCommentId;
  final Set<String> _reportingCommentIds = <String>{};

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

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  String _formatCreatedAt(dynamic raw) {
    final date = raw == null ? null : DateTime.tryParse(raw.toString());
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  bool _isOwnComment(Map<String, dynamic> comment) {
    final ownerId = comment['user_id']?.toString().trim() ?? '';
    return ownerId.isNotEmpty && ownerId == currentUserUid;
  }

  Future<void> _deleteOwnComment(Map<String, dynamic> comment) async {
    final commentId = comment['comment_id']?.toString().trim() ??
        comment['id']?.toString().trim() ??
        '';
    if (commentId.isEmpty || !_isOwnComment(comment)) return;

    final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar comentario'),
            content:
                const Text('Este comentario dejará de aparecer en el feed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                ),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _deletingCommentId = commentId);
    try {
      try {
        await SupaFlow.client.from('comments').update({
          'deleted_at': DateTime.now().toIso8601String(),
          'deleted_by': currentUserUid,
        }).eq('id', commentId).eq('user_id', currentUserUid);
      } catch (_) {
        await SupaFlow.client
            .from('comments')
            .delete()
            .eq('id', commentId)
            .eq('user_id', currentUserUid);
      }

      if (!mounted) return;
      setState(() {
        _comments.removeWhere((item) =>
            (item['comment_id']?.toString().trim() ??
                item['id']?.toString().trim() ??
                '') ==
            commentId);
        _deletingCommentId = null;
      });
      _showSnack('Comentario eliminado');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingCommentId = null);
      _showSnack('No se pudo eliminar el comentario.');
    }
  }

  Future<String?> _askReportReason() async {
    String? selected;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Widget buildOption(String value, String label) {
            final isSelected = selected == value;
            return InkWell(
              onTap: () => setModalState(() => selected = value),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0D3B66).withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0D3B66)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0D3B66)
                        : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Reportar comentario',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Elegí el motivo del reporte.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  buildOption('external_contact', 'Contacto externo'),
                  const SizedBox(height: 10),
                  buildOption('spam', 'Spam o contenido repetido'),
                  const SizedBox(height: 10),
                  buildOption('inappropriate', 'Contenido inapropiado'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selected == null
                              ? null
                              : () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D3B66),
                          ),
                          child: const Text(
                            'Enviar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return selected;
  }

  Future<void> _reportComment(Map<String, dynamic> comment) async {
    final commentId = comment['comment_id']?.toString().trim() ??
        comment['id']?.toString().trim() ??
        '';
    if (commentId.isEmpty || currentUserUid.isEmpty || _isOwnComment(comment)) {
      return;
    }

    final reason = await _askReportReason();
    if (reason == null || reason.isEmpty) return;

    setState(() => _reportingCommentIds.add(commentId));
    try {
      await SupaFlow.client.from('comment_reports').upsert(
        {
          'comment_id': commentId,
          'reporter_user_id': currentUserUid,
          'reason': reason,
        },
        onConflict: 'comment_id,reporter_user_id',
      );
      if (!mounted) return;
      _showSnack(
        'Comentario reportado. Lo revisaremos.',
        color: const Color(0xFF0D3B66),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'No se pudo reportar el comentario. Si persiste, aplicá la migración SQL de comentarios.',
      );
    } finally {
      if (mounted) {
        setState(() => _reportingCommentIds.remove(commentId));
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || widget.videoID == null) return;

    final userId = currentUserUid;
    if (userId.isEmpty) return;

    final moderationError = GuardianMvpService.validatePublicText(text);
    if (moderationError != null) {
      _showSnack(
        moderationError,
        color: const Color(0xFFB91C1C),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      try {
        await SupaFlow.client.from('comments').insert({
          'content': text,
          'video_id': widget.videoID!,
          'user_id': userId,
          'moderation_status': GuardianMvpService.approvedStatus,
        });
      } catch (_) {
        await SupaFlow.client.from('comments').insert({
          'content': text,
          'video_id': widget.videoID!,
          'user_id': userId,
        });
      }

      _commentController.clear();
      await _loadComments();
      _showSnack(
        'Comentario publicado',
        color: const Color(0xFF0F766E),
      );
    } catch (e) {
      debugPrint('Erro ao adicionar comentário: $e');
      _showSnack('No se pudo publicar el comentario.');
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
                          final commentId =
                              comment['comment_id']?.toString().trim() ??
                                  comment['id']?.toString().trim() ??
                                  '';
                          final isOwnComment = _isOwnComment(comment);
                          final isDeleting = _deletingCommentId == commentId;
                          final isReporting =
                              _reportingCommentIds.contains(commentId);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: (userPhoto != null &&
                                          userPhoto.isNotEmpty)
                                      ? NetworkImage(userPhoto)
                                      : null,
                                  child:
                                      (userPhoto == null || userPhoto.isEmpty)
                                          ? const Icon(Icons.person_outline)
                                          : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    userName,
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatCreatedAt(
                                                        comment['created_at']),
                                                    style: const TextStyle(
                                                      color: Color(0xFF64748B),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (commentId.isNotEmpty)
                                              PopupMenuButton<String>(
                                                icon: isDeleting || isReporting
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.more_horiz,
                                                        color:
                                                            Color(0xFF64748B),
                                                      ),
                                                onSelected: (value) async {
                                                  if (value == 'delete') {
                                                    await _deleteOwnComment(
                                                        comment);
                                                  } else if (value ==
                                                      'report') {
                                                    await _reportComment(
                                                        comment);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  if (isOwnComment)
                                                    const PopupMenuItem(
                                                      value: 'delete',
                                                      child:
                                                          Text('Eliminar comentario'),
                                                    )
                                                  else
                                                    const PopupMenuItem(
                                                      value: 'report',
                                                      child:
                                                          Text('Reportar comentario'),
                                                    ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          content,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
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
