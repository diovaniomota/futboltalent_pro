import '/backend/supabase/supabase.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'registro_club_model.dart';
export 'registro_club_model.dart';

class RegistroClubWidget extends StatefulWidget {
  const RegistroClubWidget({super.key});

  static String routeName = 'registro_club';
  static String routePath = '/registro_club';

  @override
  State<RegistroClubWidget> createState() => _RegistroClubWidgetState();
}

class _RegistroClubWidgetState extends State<RegistroClubWidget> {
  late RegistroClubModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers Etapa 1
  final _clubNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  Uint8List? _logoBytes;
  String? _logoUrl;
  List<Map<String, dynamic>> _countries = [];
  String? _selectedCountryId;

  // Controllers Etapa 2
  final _aboutClubController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _websiteController = TextEditingController();
  final _otherUrlController = TextEditingController();

  // Controllers Etapa 3
  final _linkStaffController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dniController = TextEditingController();
  final _leagueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RegistroClubModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _loadCountries();
  }

  @override
  void dispose() {
    _model.dispose();
    _clubNameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _aboutClubController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _websiteController.dispose();
    _otherUrlController.dispose();
    _linkStaffController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dniController.dispose();
    _leagueController.dispose();
    super.dispose();
  }

  // ============ LOGIC ============
  Future<void> _loadCountries() async {
    try {
      final response =
          await SupaFlow.client.from('countrys').select().order('name');
      if (mounted) {
        setState(
            () => _countries = List<Map<String, dynamic>>.from(response ?? []));
      }
    } catch (e) {
      debugPrint('Erro ao carregar países: $e');
    }
  }

  Future<void> _pickLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _logoBytes = bytes);
        await _uploadLogo(bytes, image.name);
      }
    } catch (e) {
      _showError('Error al seleccionar imagen');
    }
  }

  Future<void> _uploadLogo(Uint8List bytes, String fileName) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${currentUserUid}_$timestamp.jpg';
      await SupaFlow.client.storage.from('logos clubs').uploadBinary(
          filePath, bytes,
          fileOptions: const FileOptions(
              cacheControl: '3600', upsert: true, contentType: 'image/jpeg'));
      final publicUrl =
          SupaFlow.client.storage.from('logos clubs').getPublicUrl(filePath);
      setState(() => _logoUrl = publicUrl);
      _showSuccess('Logo enviado con éxito!');
    } catch (e) {
      _showError('Error al subir el logo');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  bool _validateStep1() {
    if (_clubNameController.text.trim().isEmpty) {
      _showError('Por favor, ingresa el nombre del club');
      return false;
    }
    if (_countryController.text.trim().isEmpty && _selectedCountryId == null) {
      _showError('Por favor, selecciona el país');
      return false;
    }
    if (_cityController.text.trim().isEmpty) {
      _showError('Por favor, ingresa la ciudad');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_emailController.text.trim().isEmpty) {
      _showError('Por favor, ingresa un email de contacto');
      return false;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showError('Por favor, ingresa un teléfono de contacto');
      return false;
    }
    return true;
  }

  Future<void> _saveClub() async {
    if (!_validateStep3()) return;
    setState(() => _isLoading = true);
    try {
      final sitioWeb = _websiteController.text.isNotEmpty
          ? _websiteController.text
          : _otherUrlController.text;

      // Update User
      final existingUser = await SupaFlow.client
          .from('users')
          .select()
          .eq('user_id', currentUserUid)
          .maybeSingle();
      final userData = {
        'name': _clubNameController.text,
        'city': _cityController.text,
        'country_id': _selectedCountryId != null
            ? int.tryParse(_selectedCountryId!)
            : null,
        'userType': 'club',
        'photo_url': _logoUrl,
        'role_id': 2,
      };
      if (existingUser != null) {
        await SupaFlow.client
            .from('users')
            .update(userData)
            .eq('user_id', currentUserUid);
      } else {
        userData['user_id'] = currentUserUid;
        userData['username'] = _clubNameController.text
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll(RegExp(r'[^a-z0-9_]'), '');
        userData['created_at'] = DateTime.now().toIso8601String();
        try {
          await SupaFlow.client.from('users').insert(userData);
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('users_pkey') || msg.contains('duplicate key')) {
            final updatePayload = Map<String, dynamic>.from(userData)
              ..remove('created_at');
            try {
              await SupaFlow.client
                  .from('users')
                  .update(updatePayload)
                  .eq('user_id', currentUserUid);
            } catch (_) {
              await SupaFlow.client
                  .from('users')
                  .update(updatePayload)
                  .eq('id', currentUserUid);
            }
          } else {
            rethrow;
          }
        }
      }

      // Update Club
      final existingClub = await SupaFlow.client
          .from('clubes')
          .select()
          .eq('id', currentUserUid)
          .maybeSingle();
      final clubData = {
        'email': _emailController.text,
        'telephone': _phoneController.text,
        'dni': _dniController.text.isNotEmpty
            ? int.tryParse(_dniController.text)
            : null,
        'nombre_corto': _clubNameController.text,
        'is_approved': false,
        'about_club': _aboutClubController.text.isNotEmpty
            ? _aboutClubController.text
            : 'Sin descripción',
        'liga': _leagueController.text.isNotEmpty ? _leagueController.text : '',
        'sitio_web': sitioWeb.isNotEmpty ? sitioWeb : '',
      };
      if (existingClub != null) {
        await SupaFlow.client
            .from('clubes')
            .update(clubData)
            .eq('id', currentUserUid);
      } else {
        clubData['id'] = currentUserUid;
        clubData['created_at'] = DateTime.now().toIso8601String();
        await SupaFlow.client.from('clubes').insert(clubData);
      }

      // Also create/update in 'clubs' table (used by all club screens)
      final existingClubs = await SupaFlow.client
          .from('clubs')
          .select()
          .eq('owner_id', currentUserUid)
          .maybeSingle();
      final clubsData = {
        'nombre': _clubNameController.text,
        'nombre_corto': _clubNameController.text,
        'pais': _countryController.text,
        'liga': _leagueController.text.isNotEmpty ? _leagueController.text : '',
        'descripcion': _aboutClubController.text.isNotEmpty
            ? _aboutClubController.text
            : '',
        'sitio_web': sitioWeb.isNotEmpty ? sitioWeb : '',
        'logo_url': _logoUrl,
        'owner_id': currentUserUid,
      };
      if (existingClubs != null) {
        await SupaFlow.client
            .from('clubs')
            .update(clubsData)
            .eq('owner_id', currentUserUid);
      } else {
        await SupaFlow.client.from('clubs').insert(clubsData);
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _ValidationPendingDialog(
            onContinue: () {
              Navigator.pop(context);
              context.goNamed('dashboard_club');
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar clube: $e');
      _showError('Error al guardar: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ UI ============
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(),
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentStep + 1) / 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                  color: const Color(0xFFEBF4FF),
                  borderRadius: BorderRadius.circular(20)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFF2B6CB0),
                        borderRadius: BorderRadius.circular(20))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(children: [
      Text('Crea el perfil de tu Club',
          style: GoogleFonts.inter(
              color: const Color(0xFF0D3B66),
              fontSize: 28,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 30),
      GestureDetector(
        onTap: _pickLogo,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(60),
              border: Border.all(color: const Color(0xFFA0AEC0))),
          child: _logoBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Image.memory(_logoBytes!, fit: BoxFit.cover))
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Icon(Icons.add_a_photo, color: Color(0xFF718096)),
                      Text('Add Logo',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF718096)))
                    ]),
        ),
      ),
      const SizedBox(height: 30),
      _buildLabel('Nombre del club'),
      _buildTextField(_clubNameController, 'Ingresa el nombre del club'),
      const SizedBox(height: 20),
      _buildLabel('País'),
      _buildCountryDropdown(),
      const SizedBox(height: 20),
      _buildLabel('Ciudad'),
      _buildTextField(_cityController, 'Selecciona la ciudad'),
    ]);
  }

  Widget _buildStep2() {
    return Column(children: [
      Text('Contanos sobre el Club',
          style: GoogleFonts.inter(
              color: const Color(0xFF0D3B66),
              fontSize: 28,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 30),
      _buildLabel('Sobre el Club'),
      TextField(
          controller: _aboutClubController,
          maxLines: 4,
          decoration: _inputDecoration('Historia del club')),
      const SizedBox(height: 20),
      _buildLabel('Links'),
      _buildSocialField(_instagramController, 'Instagram', Icons.camera_alt),
      const SizedBox(height: 10),
      _buildSocialField(_facebookController, 'Facebook', Icons.facebook),
      const SizedBox(height: 10),
      _buildSocialField(_websiteController, 'Sitio web', Icons.language),
      const SizedBox(height: 10),
      _buildSocialField(_otherUrlController, 'Otros', Icons.link),
    ]);
  }

  Widget _buildStep3() {
    return Column(children: [
      Text('Contacto y Verificación',
          style: GoogleFonts.inter(
              color: const Color(0xFF0D3B66),
              fontSize: 28,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 30),
      _buildLabel('Email de contacto *'),
      _buildTextField(_emailController, 'Ingresa email',
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 20),
      _buildLabel('Teléfono de contacto *'),
      _buildTextField(_phoneController, 'Ingresa teléfono',
          keyboardType: TextInputType.phone),
      const SizedBox(height: 20),
      _buildLabel('DNI/CUIT'),
      _buildTextField(_dniController, 'Ingresa DNI/CUIT',
          keyboardType: TextInputType.number),
      const SizedBox(height: 20),
      _buildLabel('Liga/Asociación'),
      _buildTextField(_leagueController, 'Ingresa liga'),
    ]);
  }

  Widget _buildLabel(String text) {
    return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF0D3B66), fontWeight: FontWeight.w500))));
  }

  Widget _buildTextField(TextEditingController ctrl, String hint,
      {TextInputType? keyboardType}) {
    return TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: _inputDecoration(hint));
  }

  Widget _buildSocialField(
      TextEditingController ctrl, String label, IconData icon) {
    return TextField(
        controller: ctrl,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(15))));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(16));
  }

  Widget _buildCountryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
        value: _selectedCountryId,
        hint: const Text('Selecciona país'),
        isExpanded: true,
        items: _countries
            .map((c) => DropdownMenuItem(
                value: c['id'].toString(), child: Text(c['name'])))
            .toList(),
        onChanged: (v) => setState(() {
          _selectedCountryId = v;
          _countryController.text =
              _countries.firstWhere((c) => c['id'].toString() == v)['name'];
        }),
      )),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        if (_currentStep > 0)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ElevatedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B6CB0)),
                      child: const Text('Anterior',
                          style: TextStyle(color: Colors.white))))),
        Expanded(
            child: Padding(
                padding: EdgeInsets.only(left: _currentStep > 0 ? 10 : 0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D3B66)),
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_currentStep == 0 && _validateStep1()) {
                            setState(() => _currentStep++);
                          } else if (_currentStep == 1)
                            setState(() => _currentStep++);
                          else if (_currentStep == 2) _saveClub();
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_currentStep == 2 ? 'Finalizar' : 'Siguiente',
                          style: const TextStyle(color: Colors.white)),
                ))),
      ]),
    );
  }
}

// ===== DIALOG DE VALIDAÇÃO PENDENTE =====
class _ValidationPendingDialog extends StatelessWidget {
  final VoidCallback onContinue;

  const _ValidationPendingDialog({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEBF4FF),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.hourglass_empty,
                  size: 40, color: Color(0xFF0D3B66)),
            ),
            const SizedBox(height: 20),
            Text(
              'Validación Pendiente',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tu registro está siendo revisado por nuestro equipo. Te notificaremos cuando sea aprobado.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF718096),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  minimumSize: const Size(0, 43),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Continuar',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
