import '/admin/admin_user_management_service.dart';
import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'admin_usuarios_model.dart';
export 'admin_usuarios_model.dart';

class AdminUsuariosWidget extends StatefulWidget {
  const AdminUsuariosWidget({super.key});

  static String routeName = 'admin_usuarios';
  static String routePath = '/adminUsuarios';

  @override
  State<AdminUsuariosWidget> createState() => _AdminUsuariosWidgetState();
}

class _AdminUsuariosWidgetState extends State<AdminUsuariosWidget> {
  late AdminUsuariosModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String _selectedFilter = 'todos';
  AdminUserManagementCapabilities? _capabilities;

  bool get _canCreateAuthUsers =>
      _capabilities?.canCreateAuthUsers == true;

  bool get _canDeleteAuthUsers =>
      _capabilities?.canDeleteAuthUsers == true;

  bool get _isAdminValidated =>
      _capabilities?.isAdmin == true || FFAppState().isAdminSession;

  int _readPlanId(dynamic value, {int fallback = 1}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _isVerifiedStatus(dynamic rawStatus) {
    final status = rawStatus?.toString().toLowerCase().trim() ?? '';
    return status == 'verified' ||
        status == 'verificado' ||
        status == 'approved' ||
        status == 'aprobado' ||
        status == 'active' ||
        status == 'ativo';
  }

  bool _isVerifiedUser(Map<String, dynamic> user) {
    final direct = user['is_verified'];
    if (direct is bool) return direct;
    return _isVerifiedStatus(user['verification_status']);
  }

  bool _hasFullCapabilities(Map<String, dynamic> user) {
    final planId = _readPlanId(user['plan_id']);
    return planId >= 2 ||
        user['full_profile'] == true ||
        user['is_test_account'] == true ||
        _isVerifiedStatus(user['verification_status']);
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminUsuariosModel());
    _loadCapabilities();
    _loadUsers();
  }

  @override
  void dispose() {
    _model.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupaFlow.client
          .from('users')
          .select()
          .order('name', ascending: true);

      if (mounted) {
        final users = List<Map<String, dynamic>>.from(response as List)
            .map((u) => {
                  ...u,
                  'userType': FFAppState.normalizeUserType(u['userType']),
                })
            .toList();
        setState(() {
          _allUsers = users;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCapabilities() async {
    try {
      final capabilities =
          await AdminUserManagementService.loadCapabilities();
      if (!mounted) return;
      setState(() => _capabilities = capabilities);
    } catch (e) {
      debugPrint('Error loading admin capabilities: $e');
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    _filteredUsers = _allUsers.where((user) {
      final normalizedType = FFAppState.normalizeUserType(user['userType']);
      final matchesType =
          _selectedFilter == 'todos' || normalizedType == _selectedFilter;
      final searchable = [
        user['name'],
        user['lastname'],
        user['username'],
        user['city'],
        user['country'],
        user['pais'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      final matchesSearch = query.isEmpty || searchable.contains(query);
      return matchesType && matchesSearch;
    }).toList();
  }

  Future<void> _togglePlan(Map<String, dynamic> user) async {
    final currentPlanId = _readPlanId(user['plan_id']);
    final newPlanId = currentPlanId == 1 ? 2 : 1;
    final newPlanName = newPlanId == 1 ? 'FREE' : 'PRO';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar Plan'),
        content: Text('Cambiar a plan $newPlanName?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(newPlanName)),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupaFlow.client
          .from('users')
          .update({'plan_id': newPlanId}).eq('user_id', user['user_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan cambiado a $newPlanName')),
        );
        if (currentUserUid == (user['user_id'] ?? '').toString()) {
          await FFAppState().syncUserType();
        }
        _loadUsers();
      }
    } catch (e) {
      debugPrint('Error updating plan: $e');
    }
  }

  Future<void> _toggleSuspend(Map<String, dynamic> user) async {
    final isSuspended = user['banned_until'] != null &&
        DateTime.tryParse(user['banned_until'].toString())
                ?.isAfter(DateTime.now()) ==
            true;

    final action = isSuspended ? 'Reactivar' : 'Suspender';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Usuario'),
        content: Text('$action a ${user['name'] ?? 'este usuario'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action,
                style:
                    TextStyle(color: isSuspended ? Colors.green : Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final newBannedUntil = isSuspended
          ? null
          : DateTime.now().add(const Duration(days: 36500)).toIso8601String();

      await SupaFlow.client.from('users').update(
          {'banned_until': newBannedUntil}).eq('user_id', user['user_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isSuspended ? 'Usuario reactivado' : 'Usuario suspendido')),
        );
        _loadUsers();
      }
    } catch (e) {
      debugPrint('Error toggling suspension: $e');
    }
  }

  Future<void> _toggleFullCapabilities(Map<String, dynamic> user) async {
    final hasFull = _hasFullCapabilities(user);
    final enable = !hasFull;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(enable ? 'Activar perfil FULL' : 'Remover perfil FULL'),
        content: Text(enable
            ? 'Este usuario tendrá acceso premium completo para testear.'
            : 'Se removerá el acceso premium completo de este usuario.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(enable ? 'Activar' : 'Remover'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final userId = user['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;

    try {
      if (enable) {
        try {
          await SupaFlow.client.from('users').update({
            'plan_id': 2,
            'full_profile': true,
            'is_test_account': true,
            'verification_status': 'verified',
          }).eq('user_id', userId);
        } catch (_) {
          await SupaFlow.client
              .from('users')
              .update({'plan_id': 2}).eq('user_id', userId);
        }
      } else {
        try {
          await SupaFlow.client.from('users').update({
            'plan_id': 1,
            'full_profile': false,
            'is_test_account': false,
            'verification_status': 'pending',
          }).eq('user_id', userId);
        } catch (_) {
          await SupaFlow.client
              .from('users')
              .update({'plan_id': 1}).eq('user_id', userId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enable
                ? 'Perfil FULL activado para pruebas'
                : 'Perfil FULL removido'),
          ),
        );
        if (currentUserUid == userId) {
          await FFAppState().syncUserType();
        }
        _loadUsers();
      }
    } catch (e) {
      debugPrint('Error toggling full capabilities: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el acceso FULL')),
        );
      }
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name'] ?? '');
    final lastnameController =
        TextEditingController(text: user['lastname'] ?? '');
    final userTypeController = TextEditingController(
      text: FFAppState.normalizeUserType(user['userType']),
    );
    final planController = TextEditingController(
      text: _readPlanId(user['plan_id']).toString(),
    );
    final cityController = TextEditingController(text: user['city'] ?? '');
    final countryController =
        TextEditingController(text: user['country'] ?? user['pais'] ?? '');
    final positionController =
        TextEditingController(text: user['posicion'] ?? user['position'] ?? '');
    final categoryController =
        TextEditingController(text: user['categoria'] ?? user['category'] ?? '');
    final ageController = TextEditingController();
    final currentBirthday = user['birthday'] ?? user['birth_date'];
    if (currentBirthday != null) {
      final parsed = DateTime.tryParse(currentBirthday.toString());
      if (parsed != null) {
        final now = DateTime.now();
        int age = now.year - parsed.year;
        if (now.month < parsed.month ||
            (now.month == parsed.month && now.day < parsed.day)) {
          age--;
        }
        ageController.text = age.toString();
      }
    }
    bool isVerified = _isVerifiedUser(user);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Editar Usuario'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastnameController,
                decoration: const InputDecoration(labelText: 'Apellido'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: userTypeController,
                decoration: const InputDecoration(
                  labelText: 'Tipo (jugador, profesional, club, admin)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: planController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Plan ID (1=FREE, 2=PRO)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Edad'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: positionController,
                decoration: const InputDecoration(labelText: 'Posición'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(labelText: 'País'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'Ciudad'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: isVerified,
                onChanged: (value) =>
                    setDialogState(() => isVerified = value ?? false),
                title: const Text('Scout verificado'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
      ),
    );

    if (result != true) {
      nameController.dispose();
      lastnameController.dispose();
      userTypeController.dispose();
      planController.dispose();
      cityController.dispose();
      countryController.dispose();
      positionController.dispose();
      categoryController.dispose();
      ageController.dispose();
      return;
    }

    try {
      final sanitizedType =
          FFAppState.normalizeUserType(userTypeController.text.trim());
      final parsedPlanId = _readPlanId(planController.text.trim(), fallback: 1);
      String? birthdayIso;
      final ageValue = int.tryParse(ageController.text.trim());
      if (ageValue != null && ageValue > 0 && ageValue < 120) {
        final now = DateTime.now();
        final birthday = DateTime(now.year - ageValue, now.month, now.day);
        birthdayIso = birthday.toIso8601String();
      }
      await SupaFlow.client.from('users').update({
        'name': nameController.text,
        'lastname': lastnameController.text,
        'userType': sanitizedType.isEmpty ? 'jugador' : sanitizedType,
        'plan_id': parsedPlanId,
        'posicion': positionController.text.trim().isEmpty
            ? null
            : positionController.text.trim(),
        'categoria': categoryController.text.trim().isEmpty
            ? null
            : categoryController.text.trim(),
        'country': countryController.text.trim().isEmpty
            ? null
            : countryController.text.trim(),
        'pais': countryController.text.trim().isEmpty
            ? null
            : countryController.text.trim(),
        'city': cityController.text.trim().isEmpty
            ? null
            : cityController.text.trim(),
        if (birthdayIso != null) 'birthday': birthdayIso,
        'verification_status': isVerified ? 'verified' : 'pending',
        'is_verified': isVerified,
      }).eq('user_id', user['user_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario actualizado')),
        );
        _loadUsers();
      }
    } catch (e) {
      debugPrint('Error editing user: $e');
    }

    nameController.dispose();
    lastnameController.dispose();
    userTypeController.dispose();
    planController.dispose();
    cityController.dispose();
    countryController.dispose();
    positionController.dispose();
    categoryController.dispose();
    ageController.dispose();
  }

  Future<void> _toggleScoutVerification(Map<String, dynamic> user) async {
    final userId = user['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    final nextVerified = !_isVerifiedUser(user);
    try {
      await SupaFlow.client.from('users').update({
        'verification_status': nextVerified ? 'verified' : 'pending',
        'is_verified': nextVerified,
      }).eq('user_id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextVerified ? 'Scout marcado como verificado' : 'Scout desverificado',
            ),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      debugPrint('Error updating verification: $e');
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final userId = user['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    bool deleteAuthAccount = _canDeleteAuthUsers;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Eliminar usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eliminar a ${user['name'] ?? 'este usuario'}?'),
                const SizedBox(height: 12),
                if (_canDeleteAuthUsers)
                  SwitchListTile(
                    value: deleteAuthAccount,
                    onChanged: (value) =>
                        setDialogState(() => deleteAuthAccount = value),
                    title: const Text('Eliminar tambien el acceso/login'),
                    subtitle: const Text(
                      'Usa esta opcion para una baja completa sin depender del dev.',
                    ),
                    contentPadding: EdgeInsets.zero,
                  )
                else
                  const Text(
                    'En este ambiente solo esta disponible la eliminacion del perfil publico.',
                    style: TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    try {
      final result = await AdminUserManagementService.deleteUser(
        userId: userId,
        deleteAuthAccount: deleteAuthAccount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        _loadUsers();
        _loadCapabilities();
      }
    } catch (e) {
      debugPrint('Error deleting user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  DateTime? _birthdayFromAge(String rawAge) {
    final ageValue = int.tryParse(rawAge.trim());
    if (ageValue == null || ageValue <= 0 || ageValue >= 120) {
      return null;
    }
    final now = DateTime.now();
    return DateTime(now.year - ageValue, now.month, now.day);
  }

  Future<void> _createUser() async {
    final nameController = TextEditingController();
    final lastnameController = TextEditingController();
    final userTypeController = TextEditingController(text: 'jugador');
    final planController = TextEditingController(text: '1');
    final cityController = TextEditingController();
    final countryController = TextEditingController();
    final positionController = TextEditingController();
    final categoryController = TextEditingController();
    final ageController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isVerified = false;
    bool createAuthAccount = _canCreateAuthUsers;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Crear usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canCreateAuthUsers)
                  SwitchListTile(
                    value: createAuthAccount,
                    onChanged: (value) =>
                        setDialogState(() => createAuthAccount = value),
                    title: const Text('Crear cuenta con acceso al app'),
                    subtitle: Text(
                      createAuthAccount
                          ? 'El usuario recibira login y password administrados.'
                          : 'Solo se creara un perfil operativo.',
                    ),
                    contentPadding: EdgeInsets.zero,
                  )
                else
                  const Text(
                    'Este ambiente solo permite alta de perfiles operativos, sin login.',
                    style: TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 10),
                if (createAuthAccount) ...[
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contrasena'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirmar contrasena'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: lastnameController,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: userTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo (jugador, profesional, club)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: planController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Plan ID (1=FREE, 2=PRO)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Edad'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(labelText: 'Posición'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: countryController,
                  decoration: const InputDecoration(labelText: 'País'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'Ciudad'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isVerified,
                  onChanged: (value) =>
                      setDialogState(() => isVerified = value ?? false),
                  title: const Text('Scout verificado'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (created != true) {
      nameController.dispose();
      lastnameController.dispose();
      userTypeController.dispose();
      planController.dispose();
      cityController.dispose();
      countryController.dispose();
      positionController.dispose();
      categoryController.dispose();
      ageController.dispose();
      emailController.dispose();
      passwordController.dispose();
      confirmPasswordController.dispose();
      return;
    }

    if (createAuthAccount &&
        passwordController.text.trim() !=
            confirmPasswordController.text.trim()) {
      nameController.dispose();
      lastnameController.dispose();
      userTypeController.dispose();
      planController.dispose();
      cityController.dispose();
      countryController.dispose();
      positionController.dispose();
      categoryController.dispose();
      ageController.dispose();
      emailController.dispose();
      passwordController.dispose();
      confirmPasswordController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las contrasenas no coinciden')),
        );
      }
      return;
    }

    try {
      final result = await AdminUserManagementService.createUser(
        AdminCreateManagedUserInput(
          name: nameController.text,
          lastname: lastnameController.text,
          userType: userTypeController.text,
          planId: _readPlanId(planController.text.trim(), fallback: 1),
          city: cityController.text,
          country: countryController.text,
          position: positionController.text,
          category: categoryController.text,
          isVerified: isVerified,
          createAuthAccount: createAuthAccount,
          email: emailController.text,
          password: passwordController.text,
          birthday: _birthdayFromAge(ageController.text),
        ),
      );

      nameController.dispose();
      lastnameController.dispose();
      userTypeController.dispose();
      planController.dispose();
      cityController.dispose();
      countryController.dispose();
      positionController.dispose();
      categoryController.dispose();
      ageController.dispose();
      emailController.dispose();
      passwordController.dispose();
      confirmPasswordController.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        _loadUsers();
        _loadCapabilities();
      }
      return;
    } catch (e) {
      nameController.dispose();
      lastnameController.dispose();
      userTypeController.dispose();
      planController.dispose();
      cityController.dispose();
      countryController.dispose();
      positionController.dispose();
      categoryController.dispose();
      ageController.dispose();
      emailController.dispose();
      passwordController.dispose();
      confirmPasswordController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }

    final userId = const Uuid().v4();
    final sanitizedType =
        FFAppState.normalizeUserType(userTypeController.text.trim());
    final parsedPlanId = _readPlanId(planController.text.trim(), fallback: 1);
    String? birthdayIso;
    final ageValue = int.tryParse(ageController.text.trim());
    if (ageValue != null && ageValue > 0 && ageValue < 120) {
      final now = DateTime.now();
      final birthday = DateTime(now.year - ageValue, now.month, now.day);
      birthdayIso = birthday.toIso8601String();
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'name': nameController.text.trim().isEmpty
          ? 'Usuario'
          : nameController.text.trim(),
      'lastname': lastnameController.text.trim(),
      'username': nameController.text.trim(),
      'userType': sanitizedType.isEmpty ? 'jugador' : sanitizedType,
      'plan_id': parsedPlanId,
      'role_id': 1,
      'country_id': 1,
      'created_at': DateTime.now().toIso8601String(),
      'posicion': positionController.text.trim().isEmpty
          ? null
          : positionController.text.trim(),
      'categoria': categoryController.text.trim().isEmpty
          ? null
          : categoryController.text.trim(),
      'country': countryController.text.trim().isEmpty
          ? null
          : countryController.text.trim(),
      'pais': countryController.text.trim().isEmpty
          ? null
          : countryController.text.trim(),
      'city': cityController.text.trim().isEmpty
          ? null
          : cityController.text.trim(),
      'verification_status': isVerified ? 'verified' : 'pending',
      'is_verified': isVerified,
      'is_test_account': true,
    };
    if (birthdayIso != null) {
      payload['birthday'] = birthdayIso;
    }

    final fallbackPayload = Map<String, dynamic>.from(payload)
      ..remove('posicion')
      ..remove('categoria')
      ..remove('country')
      ..remove('pais')
      ..remove('city');

    try {
      await SupaFlow.client.from('users').insert(payload);
    } catch (_) {
      await SupaFlow.client.from('users').insert(fallbackPayload);
    }

    try {
      if (payload['userType'] == 'jugador') {
        await SupaFlow.client.from('players').insert({
          'id': userId,
          'created_at': DateTime.now().toIso8601String(),
          'position_id': null,
        });
      } else if (payload['userType'] == 'profesional') {
        await SupaFlow.client.from('scouts').insert({
          'id': userId,
          'created_at': DateTime.now().toIso8601String(),
          'telephone': '',
          'club': '',
        });
      } else if (payload['userType'] == 'club') {
        await SupaFlow.client.from('clubs').insert({
          'owner_id': userId,
          'nombre': payload['name'] ?? 'Club',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario creado')),
      );
      _loadUsers();
    }

    nameController.dispose();
    lastnameController.dispose();
    userTypeController.dispose();
    planController.dispose();
    cityController.dispose();
    countryController.dispose();
    positionController.dispose();
    categoryController.dispose();
    ageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdminValidated) {
      return _buildAdminAccessDenied();
    }

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        title: Text(
          'Usuarios',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                fontFamily: 'Poppins',
                color: Colors.white,
                letterSpacing: 0.0,
              ),
        ),
        centerTitle: true,
        elevation: 2.0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Crear usuario',
            onPressed: _createUser,
            icon: const Icon(Icons.person_add, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
              ),
              onChanged: (_) => setState(() => _applyFilters()),
            ),
          ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Todos', 'todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Jugadores', 'jugador'),
                const SizedBox(width: 8),
                _buildFilterChip('Scouts', 'profesional'),
                const SizedBox(width: 8),
                _buildFilterChip('Clubes', 'club'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCapabilitiesCard(),
          ),
          const SizedBox(height: 8),
          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(child: Text('No se encontraron usuarios'))
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) =>
                              _buildUserCard(_filteredUsers[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAccessDenied() {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Usuarios',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                fontFamily: 'Poppins',
                color: Colors.white,
                letterSpacing: 0.0,
              ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Acesso restrito ao perfil admin.',
                style: FlutterFlowTheme.of(context).headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Validamos a sessao antes de liberar criacao, edicao ou exclusao de usuarios.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapabilitiesCard() {
    final capabilities = _capabilities;
    if (capabilities == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Validando capacidades del admin...'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Capacidades del admin',
                    style: FlutterFlowTheme.of(context).titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCapabilityChip(
                  label: 'Alta',
                  enabled: capabilities.canCreateUsers,
                ),
                _buildCapabilityChip(
                  label: 'Edicion',
                  enabled: capabilities.canEditUsers,
                ),
                _buildCapabilityChip(
                  label: 'Exclusion',
                  enabled: capabilities.canDeleteUsers,
                ),
                _buildCapabilityChip(
                  label: 'Alta con login',
                  enabled: capabilities.canCreateAuthUsers,
                ),
                _buildCapabilityChip(
                  label: 'Baja completa',
                  enabled: capabilities.canDeleteAuthUsers,
                ),
                _buildCapabilityChip(
                  label: 'Settings',
                  enabled: capabilities.canManageAdminSettings,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              capabilities.hasFullLifecycle
                  ? 'El admin ya puede gestionar usuarios de punta a punta sin depender del desarrollador.'
                  : 'El admin puede editar perfiles y operar el catalogo, pero la capa de login aun depende de la migracion de ciclo de vida admin.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityChip({
    required String label,
    required bool enabled,
  }) {
    final color = enabled ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${enabled ? "OK" : "PEND"}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
          _applyFilters();
        });
      },
      selectedColor:
          FlutterFlowTheme.of(context).primary.withValues(alpha: 0.2),
      checkmarkColor: FlutterFlowTheme.of(context).primary,
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isSuspended = user['banned_until'] != null &&
        DateTime.tryParse(user['banned_until'].toString())
                ?.isAfter(DateTime.now()) ==
            true;
    final planId = _readPlanId(user['plan_id']);
    final planLabel = planId == 2 ? 'PRO' : 'FREE';
    final hasFullCapabilities = _hasFullCapabilities(user);
    final userType = FFAppState.normalizeUserType(user['userType']);
    final isVerified = _isVerifiedUser(user);

    String typeLabel;
    Color typeColor;
    switch (userType) {
      case 'jugador':
        typeLabel = 'Jugador';
        typeColor = Colors.green;
        break;
      case 'profesional':
        typeLabel = 'Scout';
        typeColor = Colors.orange;
        break;
      case 'club':
        typeLabel = 'Club';
        typeColor = Colors.purple;
        break;
      default:
        typeLabel = userType;
        typeColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user['photo_url'] != null &&
                  user['photo_url'].toString().isNotEmpty
              ? NetworkImage(user['photo_url'])
              : null,
          child:
              user['photo_url'] == null || user['photo_url'].toString().isEmpty
                  ? const Icon(Icons.person)
                  : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${user['name'] ?? ''} ${user['lastname'] ?? ''}'.trim(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSuspended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('SUSPENDIDO',
                    style: TextStyle(color: Colors.red, fontSize: 10)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(typeLabel,
                    style: TextStyle(color: typeColor, fontSize: 11)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: planId == 2
                      ? Colors.amber.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  planLabel,
                  style: TextStyle(
                    color: planId == 2 ? Colors.amber.shade800 : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasFullCapabilities
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasFullCapabilities ? 'FULL' : 'LIMITADO',
                  style: TextStyle(
                    color: hasFullCapabilities ? Colors.blue : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (userType == 'profesional')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isVerified ? 'VERIFICADO' : 'NO VERIFICADO',
                    style: TextStyle(
                      color: isVerified ? Colors.green : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editUser(user);
                break;
              case 'plan':
                _togglePlan(user);
                break;
              case 'suspend':
                _toggleSuspend(user);
                break;
              case 'full':
                _toggleFullCapabilities(user);
                break;
              case 'verify':
                _toggleScoutVerification(user);
                break;
              case 'delete':
                _deleteUser(user);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar datos')),
            PopupMenuItem(
              value: 'plan',
              child: Text('Cambiar a ${planId == 2 ? "FREE" : "PRO"}'),
            ),
            PopupMenuItem(
              value: 'suspend',
              child: Text(
                isSuspended ? 'Reactivar' : 'Suspender',
                style:
                    TextStyle(color: isSuspended ? Colors.green : Colors.red),
              ),
            ),
            PopupMenuItem(
              value: 'full',
              child: Text(
                hasFullCapabilities
                    ? 'Remover perfil FULL'
                    : 'Activar perfil FULL',
              ),
            ),
            if (userType == 'profesional')
              PopupMenuItem(
                value: 'verify',
                child: Text(isVerified ? 'Desverificar scout' : 'Verificar scout'),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text(
                'Eliminar usuario',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
