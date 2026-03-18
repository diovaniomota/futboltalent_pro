import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'editar_perfil_model.dart';
export 'editar_perfil_model.dart';

class EditarPerfilWidget extends StatefulWidget {
  const EditarPerfilWidget({super.key});

  static String routeName = 'editar_perfil';
  static String routePath = '/editarPerfil';

  @override
  State<EditarPerfilWidget> createState() => _EditarPerfilWidgetState();
}

class _EditarPerfilWidgetState extends State<EditarPerfilWidget> {
  late EditarPerfilModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Controllers para os campos de texto
  TextEditingController? _nomeController;
  TextEditingController? _usernameController;
  TextEditingController? _posicaoController;
  TextEditingController? _pieDominanteController;
  TextEditingController? _lugarController;

  // Focus nodes
  FocusNode? _nomeFocusNode;
  FocusNode? _usernameFocusNode;
  FocusNode? _posicaoFocusNode;
  FocusNode? _pieDominanteFocusNode;
  FocusNode? _lugarFocusNode;

  // Estado
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isUploadingCover = false;
  Map<String, dynamic>? _userData;
  String? _errorMessage;

  // Opção selecionada (club ou sin club)
  bool _juegaEnClub = false;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // URLs das fotos (para atualizar localmente antes de salvar)
  String? _photoUrl;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditarPerfilModel());
    _nomeFocusNode = FocusNode();
    _usernameFocusNode = FocusNode();
    _posicaoFocusNode = FocusNode();
    _pieDominanteFocusNode = FocusNode();
    _lugarFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _nomeController?.dispose();
    _usernameController?.dispose();
    _posicaoController?.dispose();
    _pieDominanteController?.dispose();
    _lugarController?.dispose();
    _nomeFocusNode?.dispose();
    _usernameFocusNode?.dispose();
    _posicaoFocusNode?.dispose();
    _pieDominanteFocusNode?.dispose();
    _lugarFocusNode?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final uid = currentUserUid;
      if (uid.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Usuario no autenticado';
        });
        return;
      }

      final response = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response != null) {
        _userData = response;
        _nomeController = TextEditingController(text: response['name'] ?? '');
        _usernameController =
            TextEditingController(text: response['username'] ?? '');
        _posicaoController =
            TextEditingController(text: response['posicion'] ?? '');
        _pieDominanteController =
            TextEditingController(text: response['pie_dominante'] ?? '');
        _lugarController = TextEditingController(text: response['lugar'] ?? '');
        _juegaEnClub = response['juega_en_club'] ?? false;
        _photoUrl = response['photo_url'];
        _coverUrl = response['cover_url'];
      } else {
        _errorMessage = 'Usuario no encontrado';
      }
    } catch (e) {
      debugPrint('Error al cargar usuario: $e');
      _errorMessage = 'Error al cargar datos';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Mostrar opções para selecionar foto
  void _showPhotoOptions({required bool isProfilePhoto}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isProfilePhoto
                      ? 'Cambiar Foto de Perfil'
                      : 'Cambiar Foto de Portada',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B66).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF0D3B66),
                    ),
                  ),
                  title: Text(
                    'Tomar Foto',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Usar la cámara',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera,
                        isProfilePhoto: isProfilePhoto);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B66).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF0D3B66),
                    ),
                  ),
                  title: Text(
                    'Elegir de la Galería',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Seleccionar una foto existente',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery,
                        isProfilePhoto: isProfilePhoto);
                  },
                ),
                if (isProfilePhoto &&
                    _photoUrl != null &&
                    _photoUrl!.isNotEmpty)
                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                    ),
                    title: Text(
                      'Eliminar Foto',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: Text(
                      'Quitar la foto actual',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deletePhoto(isProfilePhoto: isProfilePhoto);
                    },
                  ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A202C),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Selecionar imagem
  Future<void> _pickImage(ImageSource source,
      {required bool isProfilePhoto}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: isProfilePhoto ? 500 : 1200,
        maxHeight: isProfilePhoto ? 500 : 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _uploadImage(pickedFile, isProfilePhoto: isProfilePhoto);
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Upload da imagem para Supabase Storage
  Future<void> _uploadImage(XFile imageFile,
      {required bool isProfilePhoto}) async {
    try {
      setState(() {
        if (isProfilePhoto) {
          _isUploadingPhoto = true;
        } else {
          _isUploadingCover = true;
        }
      });

      final uid = currentUserUid;
      // Gerar nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = imageFile.path.split('.').last;
      final fileName = isProfilePhoto
          ? 'profile_${uid}_$timestamp.$fileExtension'
          : 'cover_${uid}_$timestamp.$fileExtension';

      final storagePath = 'users/$uid/$fileName';

      // Ler bytes da imagem
      final bytes = await imageFile.readAsBytes();

      // Descobrir MIME type
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

      // Upload para Supabase Storage no bucket "Fotos"
      await SupaFlow.client.storage.from('Fotos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      // Obter URL pública
      final publicUrl =
          SupaFlow.client.storage.from('Fotos').getPublicUrl(storagePath);

      // Atualizar no banco de dados
      final updateData =
          isProfilePhoto ? {'photo_url': publicUrl} : {'cover_url': publicUrl};

      await SupaFlow.client.from('users').update(updateData).eq('user_id', uid);

      // Atualizar estado local
      setState(() {
        if (isProfilePhoto) {
          _photoUrl = publicUrl;
          _userData?['photo_url'] = publicUrl;
        } else {
          _coverUrl = publicUrl;
          _userData?['cover_url'] = publicUrl;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isProfilePhoto
                ? 'Foto de perfil actualizada'
                : 'Foto de portada actualizada'),
            backgroundColor: const Color(0xFF0D3B66),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al subir imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isProfilePhoto) {
            _isUploadingPhoto = false;
          } else {
            _isUploadingCover = false;
          }
        });
      }
    }
  }

  // Deletar foto
  Future<void> _deletePhoto({required bool isProfilePhoto}) async {
    try {
      setState(() {
        if (isProfilePhoto) {
          _isUploadingPhoto = true;
        } else {
          _isUploadingCover = true;
        }
      });

      final uid = currentUserUid;
      final updateData =
          isProfilePhoto ? {'photo_url': null} : {'cover_url': null};

      await SupaFlow.client.from('users').update(updateData).eq('user_id', uid);

      setState(() {
        if (isProfilePhoto) {
          _photoUrl = null;
          _userData?['photo_url'] = null;
        } else {
          _coverUrl = null;
          _userData?['cover_url'] = null;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isProfilePhoto
                ? 'Foto de perfil eliminada'
                : 'Foto de portada eliminada'),
            backgroundColor: const Color(0xFF0D3B66),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al eliminar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isProfilePhoto) {
            _isUploadingPhoto = false;
          } else {
            _isUploadingCover = false;
          }
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    try {
      setState(() => _isSaving = true);
      final uid = currentUserUid;

      await SupaFlow.client.from('users').update({
        'name': _nomeController?.text ?? '',
        'username': _usernameController?.text ?? '',
        'posicion': _posicaoController?.text ?? '',
        'pie_dominante': _pieDominanteController?.text ?? '',
        'lugar': _lugarController?.text ?? '',
        'juega_en_club': _juegaEnClub,
      }).eq('user_id', uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados correctamente'),
            backgroundColor: Color(0xFF0D3B66),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _buildInputDecoration(String hintText, {Widget? suffixIcon}) {
    return InputDecoration(
      isDense: false,
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF718096),
        fontSize: 16,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color(0xFF0D3B66),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController? controller,
    required FocusNode? focusNode,
    required String hintText,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            readOnly: readOnly,
            onTap: onTap,
            obscureText: false,
            decoration: _buildInputDecoration(hintText, suffixIcon: suffixIcon),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF1A202C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required String text,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: 56.0,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0D3B66)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0D3B66)
                        : const Color(0xFFCBD5E0),
                    width: 2,
                  ),
                  color: Colors.white,
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF0D3B66),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                text,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1A202C),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: Color(0xFF718096),
            ),
            const SizedBox(height: 8),
            Text(
              'Agregar portada',
              style: GoogleFonts.inter(
                color: const Color(0xFF718096),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF1A202C),
              size: 24,
            ),
            onPressed: () {
              context.safePop();
            },
          ),
          centerTitle: true,
          title: Text(
            'Editar Perfil',
            style: GoogleFonts.inter(
              color: const Color(0xFF1A202C),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D3B66)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66),
              ),
              child: const Text('Reintentar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header com imagem de capa e foto de perfil
          SizedBox(
            height: 220,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Imagem de capa (clicável)
                GestureDetector(
                  onTap: () => _showPhotoOptions(isProfilePhoto: false),
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFE2E8F0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _coverUrl != null && _coverUrl!.isNotEmpty
                              ? Image.network(
                                  _coverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildCoverPlaceholder();
                                  },
                                )
                              : _buildCoverPlaceholder(),
                          if (_isUploadingCover)
                            Container(
                              color: Colors.black.withOpacity(0.5),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                                color: Color(0xFF718096),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Foto de perfil com ícone de edição (clicável)
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _showPhotoOptions(isProfilePhoto: true),
                        child: Stack(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                              ),
                              child: ClipOval(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _photoUrl != null && _photoUrl!.isNotEmpty
                                        ? Image.network(
                                            _photoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person_outline,
                                                size: 50,
                                                color: Color(0xFF718096),
                                              );
                                            },
                                          )
                                        : const Icon(
                                            Icons.person_outline,
                                            size: 50,
                                            color: Color(0xFF718096),
                                          ),
                                    if (_isUploadingPhoto)
                                      Container(
                                        color: Colors.black.withOpacity(0.5),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D3B66),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Botão "Cambiar Foto de Perfil"
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: GestureDetector(
              onTap: () => _showPhotoOptions(isProfilePhoto: true),
              child: Text(
                'Cambiar Foto de Perfil',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D3B66),
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // Formulário
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  label: 'Nombre',
                  controller: _nomeController,
                  focusNode: _nomeFocusNode,
                  hintText: 'Nombre',
                ),
                _buildTextField(
                  label: 'Nombre de Usuario',
                  controller: _usernameController,
                  focusNode: _usernameFocusNode,
                  hintText: 'Usuario',
                ),
                _buildTextField(
                  label: 'Posición Principal',
                  controller: _posicaoController,
                  focusNode: _posicaoFocusNode,
                  hintText: 'Defensor Central',
                ),
                _buildTextField(
                  label: 'Pie Dominante',
                  controller: _pieDominanteController,
                  focusNode: _pieDominanteFocusNode,
                  hintText: 'Derecho',
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 28.0),
                  child: Text(
                    'Trayectoria Deportiva',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A202C),
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildRadioOption(
                  text: 'Juego en un Club',
                  isSelected: _juegaEnClub,
                  onPressed: () {
                    setState(() => _juegaEnClub = true);
                  },
                ),
                _buildRadioOption(
                  text: 'Sin club',
                  isSelected: !_juegaEnClub,
                  onPressed: () {
                    setState(() => _juegaEnClub = false);
                  },
                ),
                _buildTextField(
                  label: 'Lugar donde jugas',
                  controller: _lugarController,
                  focusNode: _lugarFocusNode,
                  hintText: 'Potrero "El Barrio"',
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 32.0, bottom: 40.0),
                  child: GestureDetector(
                    onTap: _isSaving ? null : _saveChanges,
                    child: Container(
                      width: double.infinity,
                      height: 56.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D3B66),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Guardar Cambios',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
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
