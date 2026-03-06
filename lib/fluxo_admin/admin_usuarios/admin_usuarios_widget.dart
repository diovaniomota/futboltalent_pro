import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
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
          .select(
              'user_id, name, lastname, userType, plan_id, banned_until, photo_url, full_profile, is_test_account, verification_status')
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

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    _filteredUsers = _allUsers.where((user) {
      final normalizedType = FFAppState.normalizeUserType(user['userType']);
      final matchesType =
          _selectedFilter == 'todos' || normalizedType == _selectedFilter;
      final name =
          '${user['name'] ?? ''} ${user['lastname'] ?? ''}'.toLowerCase();
      final matchesSearch = query.isEmpty || name.contains(query);
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

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
    );

    if (result != true) {
      nameController.dispose();
      lastnameController.dispose();
      userTypeController.dispose();
      planController.dispose();
      return;
    }

    try {
      final sanitizedType =
          FFAppState.normalizeUserType(userTypeController.text.trim());
      final parsedPlanId = _readPlanId(planController.text.trim(), fallback: 1);
      await SupaFlow.client.from('users').update({
        'name': nameController.text,
        'lastname': lastnameController.text,
        'userType': sanitizedType.isEmpty ? 'jugador' : sanitizedType,
        'plan_id': parsedPlanId,
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
  }

  @override
  Widget build(BuildContext context) {
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
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(typeLabel,
                  style: TextStyle(color: typeColor, fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ],
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
          ],
        ),
      ),
    );
  }
}
