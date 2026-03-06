import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'configuracin_model.dart';
export 'configuracin_model.dart';

class ConfiguracinWidget extends StatefulWidget {
  const ConfiguracinWidget({super.key});

  static String routeName = 'Configuracin';
  static String routePath = '/configuracin';

  @override
  State<ConfiguracinWidget> createState() => _ConfiguracinWidgetState();
}

class _ConfiguracinWidgetState extends State<ConfiguracinWidget> {
  late ConfiguracinModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _nombreCortoController = TextEditingController();
  final TextEditingController _paisController = TextEditingController();
  final TextEditingController _ligaController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _sitioWebController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _clubData;
  List<Map<String, dynamic>> _staffMembers = [];
  String? _logoUrl;
  String? _clubId;
  String? _currentUserId;

  int _convocatoriasActivas = 0;
  int _maxConvocatorias = 20;
  int _staffCount = 0;
  int _maxStaff = 10;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConfiguracinModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _model.dispose();
    _nombreController.dispose();
    _nombreCortoController.dispose();
    _paisController.dispose();
    _ligaController.dispose();
    _descripcionController.dispose();
    _sitioWebController.dispose();
    super.dispose();
  }

  // ============ HELPER METHODS ============
  double _responsive(BuildContext context,
      {required double mobile, double? tablet, double? desktop}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return desktop ?? tablet ?? mobile;
    if (width >= 600) return tablet ?? mobile;
    return mobile;
  }

  bool _isMediumScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;
  bool _isLargeScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  double _scaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 320) return 0.8;
    if (width < 360) return 0.9;
    if (width >= 1024) return 1.1;
    return 1.0;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '15/11/2025';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return '15/11/2025';
    }
  }

  // ============ DATA LOADING ============
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUserId = currentUserUid;

      if (_currentUserId == null || _currentUserId!.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Buscar o club pelo owner_id (auth UID)
      var clubResponse = await SupaFlow.client
          .from('clubs')
          .select()
          .eq('owner_id', _currentUserId!)
          .maybeSingle();

      // Se não encontrou, criar um club básico para este usuário
      if (clubResponse == null) {
        try {
          final userName = await SupaFlow.client
              .from('users')
              .select('name')
              .eq('user_id', _currentUserId!)
              .maybeSingle();
          final defaultName = userName?['name'] ?? 'Mi Club';

          await SupaFlow.client.from('clubs').insert({
            'nombre': 'Club de $defaultName',
            'owner_id': _currentUserId,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          clubResponse = await SupaFlow.client
              .from('clubs')
              .select()
              .eq('owner_id', _currentUserId!)
              .maybeSingle();
        } catch (e) {
          debugPrint('Error creando club: $e');
        }
      }

      if (clubResponse != null) {
        _clubData = clubResponse;
        _clubId = clubResponse['id']?.toString();
        _nombreController.text = clubResponse['nombre'] ?? '';
        _nombreCortoController.text = clubResponse['nombre_corto'] ?? '';
        _paisController.text = clubResponse['pais'] ?? '';
        _ligaController.text = clubResponse['liga'] ?? '';
        _descripcionController.text = clubResponse['descripcion'] ?? '';
        _sitioWebController.text = clubResponse['sitio_web'] ?? '';
        _logoUrl = clubResponse['logo_url'];

        // Stats usam auth UID (como convocatorias/listas usam auth UID como club_id)
        await _loadStats(_currentUserId!);
        // Staff usa o ID real do club na tabela clubs
        if (_clubId != null) {
          await _loadStaff(_clubId!);
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStaff(String clubId) async {
    try {
      final response = await SupaFlow.client
          .from('club_staff')
          .select('*, users!club_staff_user_id_fkey(*)')
          .eq('club_id', clubId)
          .order('created_at', ascending: true);
      _staffMembers = List<Map<String, dynamic>>.from(response);
      _staffCount = _staffMembers.length;
    } catch (e) {
      debugPrint('Error cargando staff con join: $e');
      // Fallback: buscar staff sem join
      try {
        final staffResponse = await SupaFlow.client
            .from('club_staff')
            .select()
            .eq('club_id', clubId);
        _staffMembers = List<Map<String, dynamic>>.from(staffResponse);
        _staffCount = _staffMembers.length;
      } catch (e2) {
        debugPrint('Error cargando staff fallback: $e2');
        _staffMembers = [];
        _staffCount = 0;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadStats(String authUid) async {
    try {
      // Convocatorias usam auth UID como club_id
      final convocatoriasResponse = await SupaFlow.client
          .from('convocatorias')
          .select('id')
          .eq('club_id', authUid)
          .eq('is_active', true);

      // Limites vêm do registro do club (usa _clubData que já foi carregado)
      if (mounted) {
        setState(() {
          _convocatoriasActivas = (convocatoriasResponse as List).length;
          if (_clubData != null) {
            _maxConvocatorias = _clubData!['max_convocatorias'] ?? 20;
            _maxStaff = _clubData!['max_staff'] ?? 10;
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando stats: $e');
    }
  }

  Future<void> _saveChanges() async {
    if (_clubData == null) return;
    setState(() => _isSaving = true);
    try {
      await SupaFlow.client.from('clubs').update({
        'nombre': _nombreController.text.trim(),
        'nombre_corto': _nombreCortoController.text.trim(),
        'pais': _paisController.text.trim(),
        'liga': _ligaController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'sitio_web': _sitioWebController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _clubData!['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cambios guardados'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _uploadLogo() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 500,
          maxHeight: 500,
          imageQuality: 85);
      if (image == null || _clubData == null) return;
      setState(() => _isSaving = true);
      final bytes = await image.readAsBytes();
      final fileName =
          'club_${_clubData!['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupaFlow.client.storage.from('logos clubs').uploadBinary(
          fileName, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final publicUrl =
          SupaFlow.client.storage.from('logos clubs').getPublicUrl(fileName);
      await SupaFlow.client
          .from('clubs')
          .update({'logo_url': publicUrl}).eq('id', _clubData!['id']);
      setState(() {
        _logoUrl = publicUrl;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Logo actualizado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al subir logo: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  // ============ DIALOGS ============
  void _showInviteDialog() {
    final usernameCtrl = TextEditingController();
    final cargoCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Invitar Nuevo Miembro'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'nombre_usuario',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: cargoCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Cargo',
                          hintText: 'Director Deportivo',
                          border: OutlineInputBorder())),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _inviteStaff(usernameCtrl.text, cargoCtrl.text);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3B66)),
                      child: const Text('Invitar',
                          style: TextStyle(color: Colors.white))),
                ]));
  }

  Future<void> _inviteStaff(String username, String cargo) async {
    if (username.trim().isEmpty || _clubData == null) return;
    if (_staffCount >= _maxStaff) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Límite de staff alcanzado'),
            backgroundColor: Colors.orange));
      }
      return;
    }
    setState(() => _isSaving = true);
    try {
      final userResponse = await SupaFlow.client
          .from('users')
          .select('user_id, name')
          .eq('username', username.trim())
          .maybeSingle();
      if (userResponse == null) throw 'Usuario no encontrado con ese username';
      final targetId = userResponse['user_id'];

      final existing = await SupaFlow.client
          .from('club_staff')
          .select('id')
          .eq('club_id', _clubData!['id'])
          .eq('user_id', targetId)
          .maybeSingle();
      if (existing != null) throw 'Este usuario ya es parte del staff';

      await SupaFlow.client.from('club_staff').insert({
        'club_id': _clubData!['id'],
        'user_id': targetId,
        'cargo': cargo.trim().isEmpty ? 'Staff' : cargo.trim(),
        'is_admin': false,
        'created_at': DateTime.now().toIso8601String()
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${userResponse['name']} añadido al staff'),
            backgroundColor: Colors.green));
        await _loadStaff(_clubData!['id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    final userData = staff['users'] ?? staff;
    final staffName = userData['name'] ?? 'Miembro';
    final cargoCtrl = TextEditingController(text: staff['cargo'] ?? '');
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Editar Staff'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staffName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                          controller: cargoCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Cargo',
                              border: OutlineInputBorder())),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  TextButton(
                      child: const Text('Eliminar',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _removeStaffMember(staff['id']);
                      }),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3B66)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _updateStaffRole(staff['id'], cargoCtrl.text);
                      },
                      child: const Text('Guardar',
                          style: TextStyle(color: Colors.white)))
                ]));
  }

  Future<void> _updateStaffRole(String staffId, String newCargo) async {
    setState(() => _isSaving = true);
    try {
      await SupaFlow.client.from('club_staff').update({
        'cargo': newCargo.trim(),
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', staffId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cargo actualizado'), backgroundColor: Colors.green));
        if (_clubData != null) await _loadStaff(_clubData!['id']);
      }
    } catch (e) {
      debugPrint('Error actualizando cargo: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _removeStaffMember(String staffId) async {
    setState(() => _isSaving = true);
    try {
      await SupaFlow.client.from('club_staff').delete().eq('id', staffId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Miembro eliminado'), backgroundColor: Colors.green));
        if (_clubData != null) await _loadStaff(_clubData!['id']);
      }
    } catch (e) {
      debugPrint('Error eliminando staff: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // ============ MENU ============
  void _showClubMenu(BuildContext ctx) {
    Navigator.of(ctx).push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              child: Container(
                width: MediaQuery.of(context).size.width *
                    _responsive(context,
                        mobile: 0.8, tablet: 0.5, desktop: 0.35),
                height: double.infinity,
                color: Colors.white,
                child: SafeArea(
                  child: Column(children: [
                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Color(0xFFE0E0E0)))),
                        child: Row(children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: const Color(0xFF0D3B66),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.settings,
                                  color: Colors.white)),
                          const SizedBox(width: 12),
                          const Text('Menu do Club',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D3B66))),
                          const Spacer(),
                          IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context))
                        ])),
                    Expanded(
                        child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: [
                          _buildDrawerItem(
                              context,
                              Icons.dashboard_outlined,
                              'Início',
                              false,
                              () => context
                                  .pushNamed(DashboardClubWidget.routeName)),
                          _buildDrawerItem(
                              context,
                              Icons.campaign_outlined,
                              'Convocatorias',
                              false,
                              () => context.pushNamed(
                                  ConvocatoriasClubWidget.routeName)),
                          _buildDrawerItem(
                              context,
                              Icons.people_outline,
                              'Postulaciones',
                              false,
                              () => context
                                  .pushNamed(PostulacionesWidget.routeName)),
                          _buildDrawerItem(
                              context,
                              Icons.list_alt_outlined,
                              'Listas',
                              false,
                              () => context
                                  .pushNamed(ListaYNotaWidget.routeName)),
                          const Divider(),
                          _buildDrawerItem(
                              context,
                              Icons.settings_outlined,
                              'Configuração',
                              true,
                              () => context
                                  .pushNamed(ConfiguracinWidget.routeName)),
                          const Divider(),
                          _buildDrawerItem(
                              context, Icons.logout, 'Cerrar Sesión', false,
                              () async {
                            debugPrint(
                                'Logout callback triggered in Configuracion');
                            try {
                              await authManager.signOut();
                              if (ctx.mounted) {
                                ctx.goNamed('login');
                              }
                            } catch (e) {
                              debugPrint('Error logout: $e');
                              if (ctx.mounted) {
                                ctx.goNamed('login');
                              }
                            }
                          })
                        ]))
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    ));
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String label,
      bool isSelected, Future Function() onTap) {
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFF0D3B66) : Colors.grey[600]),
      title: Text(label,
          style: GoogleFonts.inter(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? const Color(0xFF0D3B66) : Colors.grey[800])),
      trailing: isSelected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFF0D3B66), shape: BoxShape.circle))
          : null,
      onTap: () async {
        Navigator.of(context, rootNavigator: true).pop();
        if (!isSelected) {
          await Future.delayed(const Duration(milliseconds: 100));
          await onTap();
        }
      },
    );
  }

  // ============ UI BUILDER ============
  @override
  Widget build(BuildContext context) {
    final scale = _scaleFactor(context);
    final padding = _responsive(context, mobile: 16, tablet: 24, desktop: 32);
    final maxContentWidth = _responsive(context,
        mobile: double.infinity, tablet: 800, desktop: 900);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D3B66)))
              : Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(padding),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: maxContentWidth == double.infinity
                                ? double.infinity
                                : maxContentWidth),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(context),
                              SizedBox(height: 24 * scale),
                              if (_isLargeScreen(context))
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          flex: 3,
                                          child:
                                              _buildClubInfoSection(context)),
                                      SizedBox(width: 24 * scale),
                                      Expanded(
                                          flex: 2,
                                          child: Column(children: [
                                            _buildStaffSection(context),
                                            SizedBox(height: 24 * scale),
                                            _buildAccountStatusSection(context)
                                          ])),
                                    ])
                              else ...[
                                _buildClubInfoSection(context),
                                SizedBox(height: 24 * scale),
                                _buildStaffSection(context),
                                SizedBox(height: 24 * scale),
                                _buildAccountStatusSection(context),
                              ],
                              SizedBox(height: 24 * scale),
                              SizedBox(
                                  width: double.infinity,
                                  height: 50 * scale,
                                  child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF0D3B66),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      onPressed:
                                          _isSaving ? null : _saveChanges,
                                      child: _isSaving
                                          ? const CircularProgressIndicator(
                                              color: Colors.white)
                                          : Text('Guardar Cambios',
                                              style: GoogleFonts.inter(
                                                  fontSize: 16 * scale,
                                                  color: Colors.white)))),
                              SizedBox(height: 32 * scale),
                            ]),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scale = _scaleFactor(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
          onTap: () => _showClubMenu(context),
          child: Icon(Icons.menu, color: Colors.black, size: 24 * scale)),
      SizedBox(height: 16 * scale),
      Text('Configuração',
          style: GoogleFonts.inter(
              fontSize: 24 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black)),
      SizedBox(height: 8 * scale),
      Text('Gestiona la información de tu club',
          style:
              GoogleFonts.inter(fontSize: 14 * scale, color: Colors.grey[700])),
    ]);
  }

  Widget _buildClubInfoSection(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.shield_outlined),
          const SizedBox(width: 8),
          Text('Información del Club',
              style:
                  TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500))
        ]),
        SizedBox(height: 16 * scale),
        _buildLogoUpload(context),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Nombre', _nombreController),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Nombre Corto', _nombreCortoController),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'País', _paisController),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Liga', _ligaController),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Descripción', _descripcionController,
            maxLines: 4),
        SizedBox(height: 16 * scale),
        _buildTextField(context, 'Sitio Web', _sitioWebController),
      ]),
    );
  }

  Widget _buildLogoUpload(BuildContext context) {
    final scale = _scaleFactor(context);
    return GestureDetector(
        onTap: _uploadLogo,
        child: Row(children: [
          Container(
              width: 60 * scale,
              height: 60 * scale,
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: _logoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_logoUrl!), fit: BoxFit.cover)
                      : null),
              child: _logoUrl == null
                  ? const Icon(Icons.upload, color: Colors.grey)
                  : null),
          SizedBox(width: 12 * scale),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Escudo del Club',
                style: TextStyle(fontWeight: FontWeight.w500)),
            Text('Tap para subir',
                style: TextStyle(fontSize: 12, color: Colors.grey))
          ])
        ]));
  }

  Widget _buildTextField(
      BuildContext context, String label, TextEditingController ctrl,
      {int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.grey[700])),
      const SizedBox(height: 5),
      TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[100],
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
    ]);
  }

  Widget _buildStaffSection(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Gestión del Staff',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_staffMembers.isEmpty)
          const Text('No hay staff', style: TextStyle(color: Colors.grey)),
        ..._staffMembers.map((s) {
          final userData = s['users'];
          final name = userData?['name'] ?? 'Miembro';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE0E0E0),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(name),
            subtitle: Text(s['cargo'] ?? 'Staff'),
            trailing: TextButton(
                child: const Text('Editar'),
                onPressed: () => _showEditStaffDialog(s)),
          );
        }),
        const SizedBox(height: 10),
        OutlinedButton(
            onPressed: _showInviteDialog, child: const Text('Invitar Miembro'))
      ]),
    );
  }

  Widget _buildAccountStatusSection(BuildContext context) {
    final scale = _scaleFactor(context);
    return Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Estado de la Cuenta',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildStatusRow(
              context, 'Plan', _clubData?['subscription_plan'] ?? 'Básico'),
          _buildStatusRow(context, 'Convocatorias',
              '$_convocatoriasActivas/$_maxConvocatorias'),
          _buildStatusRow(context, 'Staff', '$_staffCount/$_maxStaff'),
          _buildStatusRow(
              context, 'Miembro desde', _formatDate(_clubData?['created_at'])),
        ]));
  }

  Widget _buildStatusRow(BuildContext context, String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
            ]));
  }
}
