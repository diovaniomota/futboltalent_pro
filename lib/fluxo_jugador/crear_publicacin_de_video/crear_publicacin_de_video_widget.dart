import '/backend/supabase/supabase.dart';
import '/gamification/gamification_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/guardian/guardian_mvp_service.dart';
import '/modal/nav_bar_judador/nav_bar_judador_widget.dart';
import '/modal/nav_bar_profesional/nav_bar_profesional_widget.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'crear_publicacin_de_video_model.dart';
export 'crear_publicacin_de_video_model.dart';

class CrearPublicacinDeVideoWidget extends StatefulWidget {
  const CrearPublicacinDeVideoWidget({super.key});

  static String routeName = 'Crear_Publicacin_de_Video';
  static String routePath = '/Crear_Publicacin_de_Video';

  @override
  State<CrearPublicacinDeVideoWidget> createState() =>
      _CrearPublicacinDeVideoWidgetState();
}

class _CrearPublicacinDeVideoWidgetState
    extends State<CrearPublicacinDeVideoWidget> {
  late CrearPublicacinDeVideoModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _etiquetasController = TextEditingController();

  final FocusNode _tituloFocusNode = FocusNode();
  final FocusNode _descripcionFocusNode = FocusNode();
  final FocusNode _etiquetasFocusNode = FocusNode();

  bool _isPublic = true;
  bool _isUploading = false;
  bool _isPublishing = false;
  bool _videoSelected = false;
  String? _uploadedVideoUrl;
  String _uploadStatus = '';
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CrearPublicacinDeVideoModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    _tituloController.dispose();
    _descripcionController.dispose();
    _etiquetasController.dispose();
    _tituloFocusNode.dispose();
    _descripcionFocusNode.dispose();
    _etiquetasFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
        _uploadStatus = 'Preparando video...';
        _videoSelected = false;
      });

      Uint8List videoBytes;
      if (kIsWeb) {
        setState(() => _uploadStatus = 'Leyendo video...');
        videoBytes = await video.readAsBytes();
        setState(() => _uploadProgress = 0.3);
      } else {
        setState(() {
          _uploadStatus = 'Comprimiendo video...';
          _uploadProgress = 0.1;
        });
        try {
          final MediaInfo? compressedVideo = await VideoCompress.compressVideo(
            video.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
          );
          videoBytes = compressedVideo?.file != null
              ? await compressedVideo!.file!.readAsBytes()
              : await File(video.path).readAsBytes();
        } catch (e) {
          debugPrint('⚠️ Erro ao comprimir: $e');
          videoBytes = await File(video.path).readAsBytes();
        }
        setState(() => _uploadProgress = 0.4);
      }

      final String extension = video.name.split('.').last.isNotEmpty
          ? video.name.split('.').last
          : 'mp4';
      final String fileName =
          'video_${DateTime.now().millisecondsSinceEpoch}.$extension';

      setState(() {
        _uploadStatus = 'Subiendo video...';
        _uploadProgress = 0.5;
      });

      await SupaFlow.client.storage.from('Videos').uploadBinary(
            fileName,
            videoBytes,
            fileOptions:
                const FileOptions(contentType: 'video/mp4', upsert: true),
          );

      final String publicUrl =
          SupaFlow.client.storage.from('Videos').getPublicUrl(fileName);

      setState(() {
        _uploadedVideoUrl = publicUrl;
        _videoSelected = true;
        _isUploading = false;
        _uploadProgress = 1.0;
        _uploadStatus = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('¡Video subido correctamente!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('❌ Erro upload: $e');
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _uploadStatus = '';
        _videoSelected = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al subir video: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _publishVideo() async {
    if (_uploadedVideoUrl == null || _uploadedVideoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, selecciona un video primero'),
          backgroundColor: Colors.orange));
      return;
    }
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, añade un título'),
          backgroundColor: Colors.orange));
      return;
    }

    final moderationError = GuardianMvpService.validatePublicFields([
      _tituloController.text,
      _descripcionController.text,
      _etiquetasController.text,
    ]);
    if (moderationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(moderationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = SupaFlow.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Debes iniciar sesión para publicar'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isPublishing = true);
    try {
      Map<String, dynamic>? currentUserData;
      try {
        currentUserData = await SupaFlow.client
            .from('users')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
      } catch (_) {}
      final moderationStatus =
          GuardianMvpService.moderationStatusForUser(currentUserData);

      var isFirstVideo = false;
      try {
        final existingVideos = await SupaFlow.client
            .from('videos')
            .select('id')
            .eq('user_id', user.id)
            .limit(1);
        isFirstVideo = (existingVideos as List).isEmpty;
      } catch (_) {}

      final payload = <String, dynamic>{
        'user_id': user.id,
        'video_url': _uploadedVideoUrl,
        'title': _tituloController.text.trim(),
        'description': _descripcionController.text.trim(),
        'tags': _etiquetasController.text.trim(),
        'videoType': 'ugc',
        'is_public': _isPublic,
        'likes_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'moderation_status': moderationStatus,
      };
      try {
        await SupaFlow.client.from('videos').insert(payload);
      } catch (_) {
        try {
          payload.remove('moderation_status');
          await SupaFlow.client.from('videos').insert(payload);
        } catch (_) {
          payload.remove('videoType');
          await SupaFlow.client.from('videos').insert(payload);
        }
      }
      await GamificationService.recalculateUserProgress(userId: user.id);
      if (mounted) {
        final gained = GamificationService.videoUploadPoints +
            (isFirstVideo ? GamificationService.firstVideoBonusPoints : 0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(moderationStatus == GuardianMvpService.pendingStatus
                ? 'Video recibido. Quedará visible cuando el responsable apruebe la cuenta. +$gained pts'
                : '¡Video publicado con éxito! +$gained pts'),
            backgroundColor: Colors.green));
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.goNamed('feed');
        }
      }
    } catch (e) {
      debugPrint('❌ Erro publicar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al publicar: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<FFAppState>().userType;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 25, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVideoUploadArea(),
                    const SizedBox(height: 20),
                    _buildTextField(
                        label: 'Título',
                        hint: 'Ej: Mi mejor gol',
                        controller: _tituloController,
                        focusNode: _tituloFocusNode),
                    const SizedBox(height: 20),
                    _buildTextField(
                        label: 'Descripción',
                        hint: 'Describe tu video',
                        controller: _descripcionController,
                        focusNode: _descripcionFocusNode,
                        maxLines: 4),
                    const SizedBox(height: 20),
                    _buildTextField(
                        label: 'Etiquetas',
                        hint: 'delantero, gol',
                        controller: _etiquetasController,
                        focusNode: _etiquetasFocusNode,
                        helperText: 'Separa con comas'),
                    const SizedBox(height: 20),
                    _buildPrivacySection(),
                    const SizedBox(height: 30),
                    _buildPublishButton(),
                  ],
                ),
              ),
            ),
            if (userType == 'jugador')
              Align(
                alignment: const AlignmentDirectional(0.0, 1.0),
                child: wrapWithModel(
                  model: _model.navBarJudadorModel,
                  updateCallback: () => safeSetState(() {}),
                  child: const NavBarJudadorWidget(),
                ),
              ),
            if (userType == 'profesional')
              Align(
                alignment: const AlignmentDirectional(0.0, 1.0),
                child: wrapWithModel(
                  model: _model.navBarProfesionalModel,
                  updateCallback: () => safeSetState(() {}),
                  child: const NavBarProfesionalWidget(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoUploadArea() {
    return GestureDetector(
      onTap: _isUploading || _isPublishing ? null : _pickAndUploadVideo,
      child: Container(
        width: double.infinity,
        height: 174,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _videoSelected
                  ? const Color(0xFF0D3B66)
                  : const Color(0xFFA0AEC0),
              width: _videoSelected ? 2 : 1),
        ),
        child: _isUploading
            ? _buildUploadingState()
            : (_videoSelected
                ? _buildVideoSelectedState()
                : _buildSelectVideoState()),
      ),
    );
  }

  Widget _buildSelectVideoState() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.file_upload_outlined,
          color: Color(0xFF0D3B66), size: 40),
      const SizedBox(height: 8),
      Text('Subí tu jugada y mostrá quién sos',
          style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
      const SizedBox(height: 8),
      Text('Este video puede ser visto por scouts',
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF444444))),
      const SizedBox(height: 6),
      Text('MP4, MOV, AVI. Máx 500MB',
          style:
              GoogleFonts.inter(fontSize: 12, color: const Color(0xFF718096))),
    ]);
  }

  Widget _buildUploadingState() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
              value: _uploadProgress > 0 ? _uploadProgress : null,
              color: const Color(0xFF0D3B66),
              strokeWidth: 3)),
      const SizedBox(height: 12),
      Text(_uploadStatus,
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF444444))),
      if (_uploadProgress > 0) ...[
        const SizedBox(height: 8),
        Text('${(_uploadProgress * 100).toInt()}%',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66)))
      ],
    ]);
  }

  Widget _buildVideoSelectedState() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle, color: Color(0xFF0D3B66), size: 40),
      const SizedBox(height: 8),
      Text('Video Seleccionado',
          style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
      const SizedBox(height: 8),
      GestureDetector(
          onTap: _isPublishing ? null : _pickAndUploadVideo,
          child: Text('Cambiar video',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF0D3B66),
                  decoration: TextDecoration.underline))),
    ]);
  }

  Widget _buildTextField(
      {required String label,
      required String hint,
      required TextEditingController controller,
      required FocusNode focusNode,
      int maxLines = 1,
      String? helperText}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 4 : 1,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF444444)),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(12),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFA0AEC0), width: 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0D3B66), width: 2)),
        ),
        style: GoogleFonts.inter(fontSize: 16, color: Colors.black),
      ),
      if (helperText != null) ...[
        const SizedBox(height: 4),
        Text(helperText,
            style:
                GoogleFonts.inter(fontSize: 12, color: const Color(0xFF444444)))
      ],
    ]);
  }

  Widget _buildPrivacySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Privacidad',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
      const SizedBox(height: 12),
      _buildPrivacyOption(
          title: 'Público',
          subtitle: 'Todos pueden ver este video, incluidos scouts.',
          isSelected: _isPublic,
          onTap: () => setState(() => _isPublic = true)),
      const SizedBox(height: 12),
      _buildPrivacyOption(
          title: 'Privado',
          subtitle: 'Solo tú puedes ver este video.',
          isSelected: !_isPublic,
          onTap: () => setState(() => _isPublic = false)),
    ]);
  }

  Widget _buildPrivacyOption(
      {required String title,
      required String subtitle,
      required bool isSelected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isSelected
                    ? const Color(0xFF0D3B66)
                    : const Color(0xFFA0AEC0),
                width: isSelected ? 2 : 1)),
        child: Row(children: [
          Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0D3B66)
                          : const Color(0xFFA0AEC0),
                      width: 2),
                  color: isSelected
                      ? const Color(0xFF0D3B66)
                      : Colors.transparent),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF444444))),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: const Color(0xFF666666)))
              ])),
        ]),
      ),
    );
  }

  Widget _buildPublishButton() {
    final bool canPublish = _videoSelected && !_isUploading && !_isPublishing;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: canPublish ? _publishVideo : null,
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D3B66),
            disabledBackgroundColor: const Color(0xFFA0AEC0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0),
        child: _isPublishing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text('Subir video',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
      ),
    );
  }
}
