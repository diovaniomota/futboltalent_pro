import '/backend/supabase/supabase.dart';
import '/flutter_flow/app_modals.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'detalles_de_la_convocatoria_model.dart';
export 'detalles_de_la_convocatoria_model.dart';

class DetallesDeLaConvocatoriaWidget extends StatefulWidget {
  const DetallesDeLaConvocatoriaWidget({
    super.key,
    required this.convocatoriaId,
  });

  final String? convocatoriaId;

  static String routeName = 'Detalles_de_la_convocatoria';
  static String routePath = '/detallesDeLaConvocatoria';

  @override
  State<DetallesDeLaConvocatoriaWidget> createState() =>
      _DetallesDeLaConvocatoriaWidgetState();
}

class _DetallesDeLaConvocatoriaWidgetState
    extends State<DetallesDeLaConvocatoriaWidget> {
  late DetallesDeLaConvocatoriaModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _mensajeController = TextEditingController();
  final FocusNode _mensajeFocusNode = FocusNode();

  Map<String, dynamic>? _convocatoria;
  Map<String, dynamic>? _clubData;
  bool _isLoading = true;
  bool _hasApplied = false;
  bool _isApplying = false;
  List<Map<String, dynamic>> _requiredChallenges = [];
  final Map<String, bool> _requiredChallengeCompletion = {};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DetallesDeLaConvocatoriaModel());
    _loadConvocatoria();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    _mensajeController.dispose();
    _mensajeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadConvocatoria() async {
    final convId = widget.convocatoriaId;
    if (convId == null || convId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await SupaFlow.client
          .from('convocatorias')
          .select()
          .eq('id', convId)
          .maybeSingle();

      if (response != null) {
        _convocatoria = response;
        final clubId = response['club_id']?.toString() ?? '';
        if (clubId.isNotEmpty) {
          try {
            var clubResponse = await SupaFlow.client
                .from('clubs')
                .select()
                .eq('id', clubId)
                .maybeSingle();
            if (clubResponse == null) {
              clubResponse = await SupaFlow.client
                  .from('users')
                  .select()
                  .eq('user_id', clubId)
                  .maybeSingle();
            }
            _clubData = clubResponse;
          } catch (e) {
            debugPrint('Erro buscar clube: $e');
          }
        }
        await _loadRequiredChallengesProgress();
        await _checkIfApplied();
      }
    } catch (e) {
      debugPrint('❌ Erro carregar convocatoria: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfApplied() async {
    final userId = SupaFlow.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty || widget.convocatoriaId == null)
      return;

    try {
      final response = await SupaFlow.client
          .from('aplicaciones_convocatoria')
          .select('id')
          .eq('convocatoria_id', widget.convocatoriaId!)
          .eq('jugador_id', userId)
          .maybeSingle();
      if (mounted) setState(() => _hasApplied = response != null);
    } catch (e) {
      debugPrint('Erro verificar aplicación: $e');
    }
  }

  List<Map<String, dynamic>> _parseRequiredChallenges(dynamic raw) {
    dynamic source = raw;
    if (source is String) {
      final trimmed = source.trim();
      if (trimmed.isEmpty) return const [];
      try {
        source = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }

    if (source is! List) return const [];

    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final entry in source) {
      final map = entry is Map<String, dynamic>
          ? Map<String, dynamic>.from(entry)
          : entry is Map
              ? Map<String, dynamic>.from(entry)
              : null;
      if (map == null) continue;

      final id = map['id']?.toString().trim() ?? '';
      final type = map['type']?.toString().trim().toLowerCase() ?? '';
      if (id.isEmpty || (type != 'course' && type != 'exercise')) continue;

      final key = '$type:$id';
      if (!seen.add(key)) continue;
      result.add({
        ...map,
        'id': id,
        'type': type,
        'title': map['title']?.toString().trim() ?? '',
      });
    }
    return result;
  }

  String _requiredChallengeKey(Map<String, dynamic> challenge) {
    final type = challenge['type']?.toString().trim().toLowerCase() ?? '';
    final id = challenge['id']?.toString().trim() ?? '';
    return '$type:$id';
  }

  bool _isRequiredChallengeCompleted(Map<String, dynamic> challenge) {
    return _requiredChallengeCompletion[_requiredChallengeKey(challenge)] ==
        true;
  }

  int get _completedRequirementsCount => _requiredChallenges
      .where((challenge) => _isRequiredChallengeCompleted(challenge))
      .length;

  bool get _canSubmitApplication {
    if (_requiredChallenges.isEmpty) return true;
    if ((SupaFlow.client.auth.currentUser?.id ?? '').isEmpty) return true;
    return _requiredChallenges.every(_isRequiredChallengeCompleted);
  }

  Future<void> _loadRequiredChallengesProgress() async {
    final requiredChallenges =
        _parseRequiredChallenges(_convocatoria?['required_challenges']);
    _requiredChallengeCompletion.clear();

    final userId = SupaFlow.client.auth.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      final courseIds = requiredChallenges
          .where((item) => item['type'] == 'course')
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final exerciseIds = requiredChallenges
          .where((item) => item['type'] == 'exercise')
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      try {
        if (courseIds.isNotEmpty) {
          final rows = await SupaFlow.client
              .from('user_courses')
              .select('course_id, status')
              .eq('user_id', userId)
              .inFilter('course_id', courseIds);
          for (final row in List<Map<String, dynamic>>.from(rows as List)) {
            final id = row['course_id']?.toString().trim() ?? '';
            final status = row['status']?.toString().trim().toLowerCase() ?? '';
            if (id.isNotEmpty && status == 'completed') {
              _requiredChallengeCompletion['course:$id'] = true;
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar progresso de cursos: $e');
      }

      try {
        if (exerciseIds.isNotEmpty) {
          final rows = await SupaFlow.client
              .from('user_exercises')
              .select('exercise_id, status')
              .eq('user_id', userId)
              .inFilter('exercise_id', exerciseIds);
          for (final row in List<Map<String, dynamic>>.from(rows as List)) {
            final id = row['exercise_id']?.toString().trim() ?? '';
            final status = row['status']?.toString().trim().toLowerCase() ?? '';
            if (id.isNotEmpty && status == 'completed') {
              _requiredChallengeCompletion['exercise:$id'] = true;
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar progresso de exercícios: $e');
      }
    }

    _requiredChallenges = requiredChallenges;
  }

  void _openRequiredChallenge(Map<String, dynamic> challenge) {
    final challengeId = challenge['id']?.toString().trim() ?? '';
    final challengeType =
        challenge['type']?.toString().trim().toLowerCase() ?? '';
    if (challengeId.isEmpty || challengeType.isEmpty) return;

    context.pushNamed(
      'cursos_ejercicios',
      queryParameters: {
        'initialChallengeId': serializeParam(challengeId, ParamType.String),
        'initialChallengeType': serializeParam(challengeType, ParamType.String),
      }.withoutNulls,
    );
  }

  Widget _buildRequiredChallengesSection() {
    final missingCount =
        _requiredChallenges.length - _completedRequirementsCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA0AEC0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Desafíos requeridos',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_completedRequirementsCount}/${_requiredChallenges.length} completos',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0D3B66),
            ),
          ),
          const SizedBox(height: 10),
          ..._requiredChallenges.map((challenge) {
            final isCompleted = _isRequiredChallengeCompleted(challenge);
            final challengeTitle = challenge['title']?.toString().trim() ?? '';
            final title = challengeTitle.isNotEmpty
                ? challengeTitle
                : (challenge['type'] == 'course' ? 'Curso' : 'Desafío');
            final typeLabel =
                challenge['type'] == 'course' ? 'Curso' : 'Desafío';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCD34D),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: isCompleted
                        ? const Color(0xFF15803D)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$typeLabel · ${isCompleted ? 'Completo' : 'Pendiente'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? const Color(0xFF15803D)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => _openRequiredChallenge(challenge),
                    child: const Text('Abrir'),
                  ),
                ],
              ),
            );
          }),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: missingCount == 0
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              missingCount == 0
                  ? 'Todo listo. Ya podés enviar tu postulación.'
                  : 'Te faltan $missingCount desafío(s) para habilitar la postulación.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: missingCount == 0
                    ? const Color(0xFF15803D)
                    : const Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyToConvocatoria() async {
    final userId = SupaFlow.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _showLoginRequired();
      return;
    }

    if (!_canSubmitApplication) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes completar todos los desafíos requeridos antes de enviar tu postulación.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isApplying = true);
    try {
      await SupaFlow.client.from('aplicaciones_convocatoria').insert({
        'convocatoria_id': widget.convocatoriaId,
        'jugador_id': userId,
        'estado': 'pendiente',
        'mensaje': _mensajeController.text.trim().isNotEmpty
            ? _mensajeController.text.trim()
            : null,
      });

      if (mounted) {
        setState(() {
          _hasApplied = true;
          _isApplying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('¡Solicitud enviada exitosamente!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Erro aplicar: $e');
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al enviar solicitud: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Iniciar sesión requerido',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
            'Debes iniciar sesión para solicitar acceso a esta convocatoria.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar',
                  style: GoogleFonts.inter(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.goNamed('login');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B66),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text('Iniciar sesión',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getClubInitials(String name) {
    if (name.isEmpty) return '??';
    final words = name.split(' ');
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre'
      ];
      return '${date.day} de ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FFAppState().isFeatureEnabled('convocatorias') &&
        !FFAppState().canAccessFeature('convocatorias')) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PlanPaywallCard(
              title: 'Convocatórias no Plano Pro',
              message:
                  'Esse detalhe pertence ao módulo Pro. Se o modo piloto estiver ON, ele fica aberto sem restrições.',
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
          backgroundColor: Colors.white,
          body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D3B66))));
    }

    if (_convocatoria == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Convocatoria no encontrada',
                  style: GoogleFonts.inter(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: Text('Volver',
                    style: GoogleFonts.inter(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final clubName = _clubData?['name'] ??
        _clubData?['club_name'] ??
        _clubData?['nombre'] ??
        'Club';
    final clubImageUrl = _clubData?['photo_url'] ??
        _clubData?['logo_url'] ??
        _clubData?['avatar_url'] ??
        '';
    final titulo = _convocatoria!['titulo'] ?? 'Convocatoria';
    final descripcion = _convocatoria!['descripcion'] ?? '';
    final categoria = _convocatoria!['categoria'] ?? '';
    final posicion = _convocatoria!['posicion'] ?? '';
    final edadMinima = _convocatoria!['edad_minima'];
    final edadMaxima = _convocatoria!['edad_maxima'];
    final fechaInicio = _formatDate(_convocatoria!['fecha_inicio']);

    String requisitos = titulo;
    if (categoria.isNotEmpty)
      requisitos = 'Convocatoria para jugadores $categoria';
    if (posicion.isNotEmpty && posicion != 'Todas')
      requisitos += ' - Posición: $posicion';
    if (edadMinima != null || edadMaxima != null) {
      if (edadMinima != null && edadMaxima != null)
        requisitos += ' ($edadMinima-$edadMaxima años)';
      else if (edadMinima != null)
        requisitos += ' (mínimo $edadMinima años)';
      else
        requisitos += ' (máximo $edadMaxima años)';
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.black, size: 24)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          shape: BoxShape.circle,
                          image: clubImageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(clubImageUrl),
                                  fit: BoxFit.cover)
                              : null),
                      child: clubImageUrl.isEmpty
                          ? Center(
                              child: Text(_getClubInitials(clubName),
                                  style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54)))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text(clubName,
                            style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black))),
                  ],
                ),
                const SizedBox(height: 20),
                if (fechaInicio.isNotEmpty) ...[
                  _buildInfoRow(
                      icon: Icons.calendar_today,
                      title: 'Fecha',
                      subtitle: fechaInicio),
                  const SizedBox(height: 16)
                ],
                _buildInfoRow(
                    icon: Icons.group,
                    title: 'Requisitos',
                    subtitle: requisitos),
                const SizedBox(height: 20),
                Text('Descripción',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 8),
                Text(
                    descripcion.isNotEmpty
                        ? descripcion
                        : 'Esta convocatoria busca talentos con pasión...',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        height: 1.5)),
                if (_requiredChallenges.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildRequiredChallengesSection(),
                ],
                const SizedBox(height: 20),
                if (!_hasApplied) ...[
                  Text('Mensaje Personalizado (Opcional)',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _mensajeController,
                    focusNode: _mensajeFocusNode,
                    maxLines: 6,
                    minLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Añade un mensaje para el club...',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.grey[500], fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFA0AEC0), width: 1)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF0D3B66), width: 2)),
                    ),
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFA0AEC0), width: 1)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          FaIcon(FontAwesomeIcons.solidClock,
                              color: const Color(0xFF0D3B66), size: 20),
                          const SizedBox(width: 12),
                          Text('Proceso de Aprobación',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF444444)))
                        ]),
                        const SizedBox(height: 12),
                        Text(
                            _hasApplied
                                ? 'Tu solicitud ha sido enviada...'
                                : 'Tu solicitud será revisada...',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF444444),
                                height: 1.4)),
                      ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _hasApplied || _isApplying
                        ? null
                        : _applyToConvocatoria,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _hasApplied
                            ? Colors.green
                            : const Color(0xFF0D3B66),
                        disabledBackgroundColor:
                            _hasApplied ? Colors.green : Colors.grey,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0),
                    child: _isApplying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                if (_hasApplied) ...[
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8)
                                ],
                                Text(
                                    _hasApplied
                                        ? 'Solicitud Enviada'
                                        : 'Solicitar Acceso',
                                    style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white))
                              ]),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: const Color(0xFF0D3B66),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 20)),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF444444))),
        const SizedBox(height: 2),
        Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF444444)))
      ]))
    ]);
  }
}
