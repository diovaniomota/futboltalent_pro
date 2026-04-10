import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/fluxo_compartilhado/club_identity_utils.dart';
import '/fluxo_compartilhado/perfil_publico_club/perfil_publico_club_widget.dart';
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
  bool _isEditingClubProfile = false;
  Map<String, dynamic>? _clubData;
  Map<String, dynamic>? _currentUserData;
  List<Map<String, dynamic>> _staffMembers = [];
  String? _logoUrl;
  String? _clubId;
  String? _currentUserId;
  Set<String> _clubRefs = <String>{};

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

  String _firstNonEmptyText(Iterable<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return fallback;
  }

  Map<String, dynamic> _mergeClubWithUserFallback(
    Map<String, dynamic>? club,
    Map<String, dynamic>? user,
  ) {
    final merged = <String, dynamic>{...?club};

    merged['id'] = _firstNonEmptyText([
      club?['id'],
    ]);
    merged['owner_id'] = _firstNonEmptyText([
      club?['owner_id'],
      user?['user_id'],
      _currentUserId,
    ]);
    merged['user_id'] = _firstNonEmptyText([
      club?['user_id'],
      user?['user_id'],
      _currentUserId,
    ]);
    merged['nombre'] = _firstNonEmptyText([
      club?['nombre'],
      club?['name'],
      club?['club_name'],
      user?['club_name'],
      user?['name'],
      'Mi Club',
    ]);
    merged['nombre_corto'] = _firstNonEmptyText([
      club?['nombre_corto'],
      user?['nombre_corto'],
      user?['short_name'],
    ]);
    merged['pais'] = _firstNonEmptyText([
      club?['pais'],
      club?['country'],
      user?['pais'],
      user?['country'],
      user?['country_name'],
    ]);
    merged['liga'] = _firstNonEmptyText([
      club?['liga'],
      user?['liga'],
      user?['league'],
      user?['organization'],
    ]);
    merged['descripcion'] = _firstNonEmptyText([
      club?['descripcion'],
      club?['description'],
      user?['descripcion'],
      user?['bio'],
      user?['description'],
    ]);
    merged['sitio_web'] = _firstNonEmptyText([
      club?['sitio_web'],
      club?['website'],
      user?['sitio_web'],
      user?['website'],
      user?['web'],
    ]);
    merged['logo_url'] = _firstNonEmptyText([
      club?['logo_url'],
      user?['logo_url'],
      user?['photo_url'],
      user?['avatar_url'],
    ]);

    return merged;
  }

  void _populateClubControllers(Map<String, dynamic>? clubData) {
    _nombreController.text = _firstNonEmptyText([
      clubData?['nombre'],
      clubData?['name'],
    ]);
    _nombreCortoController.text = _firstNonEmptyText([
      clubData?['nombre_corto'],
    ]);
    _paisController.text = _firstNonEmptyText([
      clubData?['pais'],
      clubData?['country'],
    ]);
    _ligaController.text = _firstNonEmptyText([
      clubData?['liga'],
      clubData?['league'],
    ]);
    _descripcionController.text = _firstNonEmptyText([
      clubData?['descripcion'],
      clubData?['bio'],
      clubData?['description'],
    ]);
    _sitioWebController.text = _firstNonEmptyText([
      clubData?['sitio_web'],
      clubData?['website'],
      clubData?['web'],
    ]);
    final logoUrl = _firstNonEmptyText([
      clubData?['logo_url'],
      clubData?['photo_url'],
      clubData?['avatar_url'],
    ]);
    _logoUrl = logoUrl.isEmpty ? null : logoUrl;
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

      try {
        _currentUserData = await SupaFlow.client
            .from('users')
            .select()
            .eq('user_id', _currentUserId!)
            .maybeSingle();
      } catch (_) {
        _currentUserData = null;
      }

      _clubRefs = await resolveClubRefsForUser(_currentUserId!);
      var clubResponse = await resolveCurrentClubForUser(_currentUserId!);

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

          clubResponse = await resolveCurrentClubForUser(_currentUserId!);
          _clubRefs = await resolveClubRefsForUser(_currentUserId!);
        } catch (e) {
          debugPrint('Error creando club: $e');
        }
      }

      final mergedClub = _mergeClubWithUserFallback(clubResponse, _currentUserData);
      if (mergedClub.isNotEmpty) {
        _clubData = mergedClub;
        _clubId = _firstNonEmptyText([
          mergedClub['id'],
        ]);
        _populateClubControllers(mergedClub);

        await _loadStats();
        // Staff usa o ID real do club na tabela clubs
        if (_clubId != null && _clubId!.isNotEmpty) {
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

  Future<void> _loadStats() async {
    try {
      if (_clubRefs.isEmpty && _currentUserId != null && _currentUserId!.isNotEmpty) {
        _clubRefs = await resolveClubRefsForUser(_currentUserId!);
      }
      if (_clubRefs.isEmpty && _currentUserId != null && _currentUserId!.isNotEmpty) {
        _clubRefs = {_currentUserId!};
      }

      final convocatoriasResponse = _clubRefs.length == 1
          ? await SupaFlow.client
              .from('convocatorias')
              .select('id')
              .eq('club_id', _clubRefs.first)
              .eq('is_active', true)
          : await SupaFlow.client
              .from('convocatorias')
              .select('id')
              .inFilter('club_id', _clubRefs.toList())
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
      final updatedAt = DateTime.now().toIso8601String();
      final payload = {
        'nombre': _nombreController.text.trim(),
        'nombre_corto': _nombreCortoController.text.trim(),
        'pais': _paisController.text.trim(),
        'liga': _ligaController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'sitio_web': _sitioWebController.text.trim(),
        'updated_at': updatedAt,
      };
      final currentClubId = _clubData?['id']?.toString().trim() ?? '';

      Map<String, dynamic>? persistedClub;
      if (currentClubId.isNotEmpty) {
        await SupaFlow.client.from('clubs').update(payload).eq('id', currentClubId);
        persistedClub = {
          ...?_clubData,
          ...payload,
          'id': currentClubId,
        };
      } else {
        final inserted = await SupaFlow.client.from('clubs').insert({
          ...payload,
          'owner_id': _firstNonEmptyText([
            _clubData?['owner_id'],
            _currentUserId,
          ]),
          'user_id': _firstNonEmptyText([
            _clubData?['user_id'],
            _currentUserId,
          ]),
          'is_active': true,
          'created_at': updatedAt,
        }).select().maybeSingle();
        persistedClub = inserted == null
            ? {
                ...?_clubData,
                ...payload,
              }
            : Map<String, dynamic>.from(inserted);
        _clubRefs = await resolveClubRefsForUser(_currentUserId ?? '');
      }

      _clubData = _mergeClubWithUserFallback(persistedClub, _currentUserData);
      _clubId = _firstNonEmptyText([_clubData?['id']]);
      _populateClubControllers(_clubData);
      await _loadStats();
      if (_clubId != null && _clubId!.isNotEmpty) {
        await _loadStaff(_clubId!);
      }
      if (mounted) {
        setState(() {
          _isEditingClubProfile = false;
        });
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
                          const Text('Menú del club',
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
                              'Dashboard',
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
                              'Jugadores',
                              false,
                              () => context
                                  .pushNamed(PostulacionesWidget.routeName)),
                          _buildDrawerItem(
                              context,
                              Icons.list_alt_outlined,
                              'Scouting',
                              false,
                              () => context
                                  .pushNamed(ListaYNotaWidget.routeName)),
                          const Divider(),
                          _buildDrawerItem(
                              context,
                              Icons.settings_outlined,
                              'Club',
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
                              _buildClubProfileSummarySection(context),
                              SizedBox(height: 24 * scale),
                              if (_isEditingClubProfile) ...[
                                _buildClubInfoSection(context),
                                SizedBox(height: 24 * scale),
                              ],
                              if (_isLargeScreen(context))
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildStaffSection(context)),
                                    SizedBox(width: 24 * scale),
                                    Expanded(
                                        child:
                                            _buildAccountStatusSection(context)),
                                  ],
                                )
                              else ...[
                                _buildStaffSection(context),
                                SizedBox(height: 24 * scale),
                                _buildAccountStatusSection(context),
                              ],
                              SizedBox(height: 24 * scale),
                              _isMediumScreen(context)
                                  ? Wrap(
                                      spacing: 12 * scale,
                                      runSpacing: 12 * scale,
                                      children: [
                                        if (_clubData != null)
                                          SizedBox(
                                            width: 220 * scale,
                                            child: SizedBox(
                                              height: 50 * scale,
                                              child: _buildPublicProfileButton(
                                                context,
                                                scale,
                                              ),
                                            ),
                                          ),
                                        if (!_isEditingClubProfile)
                                          SizedBox(
                                            width: 220 * scale,
                                            child: SizedBox(
                                              height: 50 * scale,
                                              child: _buildEditClubButton(
                                                context,
                                                scale,
                                              ),
                                            ),
                                          ),
                                        if (_isEditingClubProfile) ...[
                                          SizedBox(
                                            width: 190 * scale,
                                            child: SizedBox(
                                              height: 50 * scale,
                                              child:
                                                  _buildCancelEditClubButton(
                                                context,
                                                scale,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 220 * scale,
                                            child: SizedBox(
                                              height: 50 * scale,
                                              child: _buildSaveClubButton(
                                                context,
                                                scale,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (_clubData != null)
                                          SizedBox(
                                            height: 50 * scale,
                                            child: _buildPublicProfileButton(
                                              context,
                                              scale,
                                            ),
                                          ),
                                        if (_clubData != null)
                                          SizedBox(height: 12 * scale),
                                        if (!_isEditingClubProfile)
                                          SizedBox(
                                            height: 50 * scale,
                                            child: _buildEditClubButton(
                                              context,
                                              scale,
                                            ),
                                          ),
                                        if (_isEditingClubProfile) ...[
                                          SizedBox(
                                            height: 50 * scale,
                                            child: _buildCancelEditClubButton(
                                              context,
                                              scale,
                                            ),
                                          ),
                                          SizedBox(height: 12 * scale),
                                          SizedBox(
                                            height: 50 * scale,
                                            child: _buildSaveClubButton(
                                              context,
                                              scale,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
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
      Text('Club',
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

  Widget _buildPrimaryActionLabel(
    String text,
    BuildContext context, {
    Color color = Colors.white,
  }) {
    final scale = _scaleFactor(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: GoogleFonts.inter(
          fontSize: 15 * scale,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildClubProfileSummarySection(BuildContext context) {
    final scale = _scaleFactor(context);
    final clubName = _nombreController.text.trim().isNotEmpty
        ? _nombreController.text.trim()
        : (_clubData?['nombre']?.toString().trim().isNotEmpty ?? false)
            ? _clubData!['nombre'].toString().trim()
            : 'Mi Club';
    final shortName = _nombreCortoController.text.trim();
    final country = _paisController.text.trim();
    final league = _ligaController.text.trim();
    final description = _descripcionController.text.trim();
    final site = _sitioWebController.text.trim();

    Widget infoTile({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Container(
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34 * scale,
              height: 34 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18 * scale, color: const Color(0xFF0D3B66)),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12 * scale,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 3 * scale),
                  Text(
                    value.isEmpty ? 'Sin completar' : value,
                    style: GoogleFonts.inter(
                      fontSize: 13 * scale,
                      color: const Color(0xFF0F172A),
                      fontWeight:
                          value.isEmpty ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0D3B66),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74 * scale,
                height: 74 * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(18),
                  image: _logoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_logoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _logoUrl == null
                    ? Icon(
                        Icons.shield_outlined,
                        color: const Color(0xFF0D3B66),
                        size: 34 * scale,
                      )
                    : null,
              ),
              SizedBox(width: 14 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfil del club',
                      style: GoogleFonts.inter(
                        fontSize: 12 * scale,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      clubName,
                      style: GoogleFonts.inter(
                        fontSize: 22 * scale,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (shortName.isNotEmpty) ...[
                      SizedBox(height: 4 * scale),
                      Text(
                        shortName,
                        style: GoogleFonts.inter(
                          fontSize: 13 * scale,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: 8 * scale),
                    Wrap(
                      spacing: 8 * scale,
                      runSpacing: 8 * scale,
                      children: [
                        if (country.isNotEmpty)
                          _buildInfoChip(country, scale),
                        if (league.isNotEmpty) _buildInfoChip(league, scale),
                        _buildInfoChip(
                          'Plan ${(_clubData?['subscription_plan'] ?? 'free').toString()}',
                          scale,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          infoTile(
            icon: Icons.public_rounded,
            label: 'País',
            value: country,
          ),
          SizedBox(height: 10 * scale),
          infoTile(
            icon: Icons.emoji_events_outlined,
            label: 'Liga',
            value: league,
          ),
          SizedBox(height: 10 * scale),
          infoTile(
            icon: Icons.language_rounded,
            label: 'Sitio web',
            value: site,
          ),
          SizedBox(height: 10 * scale),
          infoTile(
            icon: Icons.description_outlined,
            label: 'Descripción',
            value: description,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.5 * scale,
          color: const Color(0xFF334155),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPublicProfileButton(BuildContext context, double scale) {
    return OutlinedButton(
      onPressed: () {
        final clubRef = (_clubData!['id']?.toString().trim().isNotEmpty ?? false)
            ? _clubData!['id'].toString().trim()
            : (_clubData!['owner_id']?.toString().trim().isNotEmpty ?? false)
                ? _clubData!['owner_id'].toString().trim()
                : _currentUserId!;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PerfilPublicoClubWidget(
              clubRef: clubRef,
              initialClubData: _clubData,
            ),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF0D3B66)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 12 * scale,
        ),
      ),
      child: _buildPrimaryActionLabel(
        'Ver perfil público',
        context,
        color: const Color(0xFF0D3B66),
      ),
    );
  }

  Widget _buildEditClubButton(BuildContext context, double scale) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D3B66),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 12 * scale,
        ),
      ),
      onPressed: () {
        setState(() => _isEditingClubProfile = true);
      },
      icon: const Icon(Icons.edit_outlined),
      label: _buildPrimaryActionLabel(
        'Editar datos del club',
        context,
      ),
    );
  }

  Widget _buildCancelEditClubButton(BuildContext context, double scale) {
    return OutlinedButton(
      onPressed: _isSaving
          ? null
          : () {
              setState(() {
                _isEditingClubProfile = false;
                _populateClubControllers(_clubData);
              });
            },
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF0D3B66)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 12 * scale,
        ),
      ),
      child: _buildPrimaryActionLabel(
        'Cancelar edición',
        context,
        color: const Color(0xFF0D3B66),
      ),
    );
  }

  Widget _buildSaveClubButton(BuildContext context, double scale) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D3B66),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 12 * scale,
        ),
      ),
      onPressed: _isSaving ? null : _saveChanges,
      child: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.2,
              ),
            )
          : _buildPrimaryActionLabel(
              'Guardar cambios',
              context,
            ),
    );
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
          const Icon(Icons.edit_outlined),
          const SizedBox(width: 8),
          Text('Editar datos del club',
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
            Text('Toca para subir',
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
