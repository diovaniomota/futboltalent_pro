import '/backend/supabase/supabase.dart';
import '/flutter_flow/app_modals.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/fluxo_compartilhado/notificacoes/activity_notifications_service.dart';
import '/fluxo_compartilhado/convocatoria_snapshot_service.dart';
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
  Map<String, dynamic>? _playerEligibilityData;
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
            clubResponse ??= await SupaFlow.client
                  .from('users')
                  .select()
                  .eq('user_id', clubId)
                  .maybeSingle();
            _clubData = clubResponse;
          } catch (e) {
            debugPrint('Error al buscar club: $e');
          }
        }
        await _loadRequiredChallengesProgress();
        await _loadPlayerEligibilityData();
        await _checkIfApplied();
      }
    } catch (e) {
      debugPrint('❌ Error al cargar convocatoria: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfApplied() async {
    final userId = SupaFlow.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty || widget.convocatoriaId == null) {
      return;
    }

    try {
      final response = await SupaFlow.client
          .from('aplicaciones_convocatoria')
          .select('id')
          .eq('convocatoria_id', widget.convocatoriaId!)
          .eq('jugador_id', userId)
          .limit(1)
          .maybeSingle();
      var hasApplied = response != null;
      if (!hasApplied) {
        hasApplied = await _hasLegacyPostulacion(userId);
      }
      if (mounted) setState(() => _hasApplied = hasApplied);
    } catch (e) {
      try {
        final hasApplied = await _hasLegacyPostulacion(userId);
        if (mounted) setState(() => _hasApplied = hasApplied);
      } catch (_) {
        debugPrint('Error al verificar aplicación: $e');
      }
    }
  }

  Future<bool> _hasLegacyPostulacion(String userId) async {
    final convId = widget.convocatoriaId?.trim() ?? '';
    if (convId.isEmpty || userId.isEmpty) return false;

    Future<bool> existsByColumn(String column) async {
      try {
        final response = await SupaFlow.client
            .from('postulaciones')
            .select('id')
            .eq('convocatoria_id', convId)
            .eq(column, userId)
            .limit(1)
            .maybeSingle();
        return response != null;
      } catch (_) {
        return false;
      }
    }

    return await existsByColumn('player_id') ||
        await existsByColumn('jugador_id');
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

  Future<void> _loadPlayerEligibilityData() async {
    final userId = SupaFlow.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    final selects = [
      'user_id, birthday, birth_date, fecha_nacimiento, categoria, category, posicion, position',
      'user_id, birthday, birth_date, categoria, category, posicion, position',
      'user_id, birthday, birth_date, categoria, posicion',
      'user_id, birthday, birth_date',
    ];
    for (final fields in selects) {
      try {
        _playerEligibilityData = await SupaFlow.client
            .from('users')
            .select(fields)
            .eq('user_id', userId)
            .maybeSingle();
        if (_playerEligibilityData != null) return;
      } catch (e) {
        debugPrint('Error al cargar elegibilidad del jugador: $e');
      }
    }
  }

  int? _intFromValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  int? _ageFromRaw(dynamic raw) {
    final birthday = DateTime.tryParse(raw?.toString() ?? '');
    if (birthday == null) return null;
    final now = DateTime.now();
    var age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  String _normalizeEligibilityText(dynamic value) {
    var text = value?.toString().trim().toLowerCase() ?? '';
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    accents.forEach((from, to) => text = text.replaceAll(from, to));
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isOpenRequirement(dynamic value) {
    final normalized = _normalizeEligibilityText(value);
    return normalized.isEmpty ||
        normalized == 'todas' ||
        normalized == 'todos' ||
        normalized == 'todas las categorias' ||
        normalized == 'todas las posiciones' ||
        normalized == 'all' ||
        normalized == 'any' ||
        normalized == 'abierta' ||
        normalized == 'abierto' ||
        normalized == 'sin restriccion' ||
        normalized == 'sin restricciones';
  }

  List<String> get _eligibilityMessages {
    final messages = <String>[];
    final userId = SupaFlow.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return messages;

    final minAge =
        _intFromValue(_convocatoria?['min_age'] ?? _convocatoria?['edad_minima']);
    final maxAge =
        _intFromValue(_convocatoria?['max_age'] ?? _convocatoria?['edad_maxima']);
    if (minAge != null || maxAge != null) {
      final age = _ageFromRaw(
        _playerEligibilityData?['birthday'] ??
            _playerEligibilityData?['birth_date'] ??
            _playerEligibilityData?['fecha_nacimiento'],
      );
      if (age == null) {
        messages.add(
          'Completá tu fecha de nacimiento para validar la edad requerida.',
        );
      } else {
        if (minAge != null && age < minAge) {
          messages.add('Edad mínima requerida: $minAge años. Tu edad: $age.');
        }
        if (maxAge != null && age > maxAge) {
          messages.add('Edad máxima permitida: $maxAge años. Tu edad: $age.');
        }
      }
    }

    final requiredCategory = _firstNonEmptyText([
      _convocatoria?['categoria'],
      _convocatoria?['category'],
    ]);
    if (!_isOpenRequirement(requiredCategory)) {
      final playerCategory = _firstNonEmptyText([
        _playerEligibilityData?['categoria'],
        _playerEligibilityData?['category'],
      ]);
      if (playerCategory.isEmpty) {
        messages.add('Completá tu categoría para validar esta convocatoria.');
      } else if (_normalizeEligibilityText(playerCategory) !=
          _normalizeEligibilityText(requiredCategory)) {
        messages.add(
          'Categoría requerida: $requiredCategory. Tu categoría: $playerCategory.',
        );
      }
    }

    final requiredPosition = _firstNonEmptyText([
      _convocatoria?['posicion'],
      _convocatoria?['position'],
    ]);
    if (!_isOpenRequirement(requiredPosition)) {
      final playerPosition = _firstNonEmptyText([
        _playerEligibilityData?['posicion'],
        _playerEligibilityData?['position'],
      ]);
      if (playerPosition.isNotEmpty &&
          _normalizeEligibilityText(playerPosition) !=
              _normalizeEligibilityText(requiredPosition)) {
        messages.add(
          'Posición requerida: $requiredPosition. Tu posición: $playerPosition.',
        );
      }
    }

    return messages;
  }

  Widget _buildEligibilityMessagesSection(List<String> messages) {
    if (messages.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF97316)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF9A3412),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Elegibilidad pendiente',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9A3412),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• $message',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7C2D12),
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _persistRequiredChallengeCompletions(String userId) async {
    for (final challenge in _requiredChallenges) {
      if (!_isRequiredChallengeCompleted(challenge)) continue;
      final id = challenge['id']?.toString().trim() ?? '';
      final type = challenge['type']?.toString().trim().toLowerCase() ?? '';
      if (id.isEmpty) continue;

      if (type == 'course') {
        try {
          final existing = await SupaFlow.client
              .from('user_courses')
              .select('id')
              .eq('user_id', userId)
              .eq('course_id', id)
              .limit(1)
              .maybeSingle();
          final payload = {
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'progress_percent': 100,
          };
          if (existing != null) {
            await SupaFlow.client
                .from('user_courses')
                .update(payload)
                .eq('id', existing['id']);
          } else {
            await SupaFlow.client.from('user_courses').insert({
              'user_id': userId,
              'course_id': id,
              ...payload,
            });
          }
        } catch (_) {}
      } else if (type == 'exercise') {
        try {
          final existing = await SupaFlow.client
              .from('user_exercises')
              .select('id')
              .eq('user_id', userId)
              .eq('exercise_id', id)
              .limit(1)
              .maybeSingle();
          final payload = {
            'status': 'completed',
            'last_completed_at': DateTime.now().toIso8601String(),
          };
          if (existing != null) {
            await SupaFlow.client
                .from('user_exercises')
                .update(payload)
                .eq('id', existing['id']);
          } else {
            await SupaFlow.client.from('user_exercises').insert({
              'user_id': userId,
              'exercise_id': id,
              ...payload,
            });
          }
        } catch (_) {}
      }
    }
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
        debugPrint('Error al cargar progreso de cursos: $e');
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
        debugPrint('Error al cargar progreso de ejercicios: $e');
      }

      try {
        final challengeIds = [
          ...courseIds.map((id) => {'type': 'course', 'id': id}),
          ...exerciseIds.map((id) => {'type': 'exercise', 'id': id}),
        ];
        if (challengeIds.isNotEmpty) {
          final rows = await SupaFlow.client
              .from('user_challenge_attempts')
              .select('item_id, item_type, status')
              .eq('user_id', userId)
              .inFilter(
                'item_id',
                challengeIds.map((item) => item['id']!).toSet().toList(),
              );
          for (final row in List<Map<String, dynamic>>.from(rows as List)) {
            final id = row['item_id']?.toString().trim() ?? '';
            final type =
                row['item_type']?.toString().trim().toLowerCase() ?? '';
            final status = row['status']?.toString().trim().toLowerCase() ?? '';
            if (id.isEmpty || (type != 'course' && type != 'exercise')) {
              continue;
            }
            if (status == 'submitted' || status == 'completed') {
              _requiredChallengeCompletion['$type:$id'] = true;
            }
          }
        }
      } catch (e) {
        debugPrint('Error al cargar intentos de desafíos: $e');
      }
    }

    _requiredChallenges = requiredChallenges;
  }

  void _openRequiredChallenge(Map<String, dynamic> challenge) {
    final challengeId = challenge['id']?.toString().trim() ?? '';
    final challengeType =
        challenge['type']?.toString().trim().toLowerCase() ?? '';
    if (challengeId.isEmpty || challengeType.isEmpty) return;
    final convId = widget.convocatoriaId?.trim() ?? '';

    context.pushNamed(
      'cursos_ejercicios',
      queryParameters: {
        'challengeId': serializeParam(challengeId, ParamType.String),
        'challengeType': serializeParam(challengeType, ParamType.String),
        if (convId.isNotEmpty) 'returnTo': 'convocatoria',
        if (convId.isNotEmpty)
          'returnConvocatoriaId': serializeParam(convId, ParamType.String),
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
            '$_completedRequirementsCount/${_requiredChallenges.length} completos',
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

    final eligibilityMessages = _eligibilityMessages;
    if (eligibilityMessages.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eligibilityMessages.first),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isApplying = true);
    try {
      // 9.1 — Validação de idade para a convocatória
      final minAge =
          _intFromValue(_convocatoria?['min_age'] ?? _convocatoria?['edad_minima']);
      final maxAge =
          _intFromValue(_convocatoria?['max_age'] ?? _convocatoria?['edad_maxima']);
      if (minAge != null || maxAge != null) {
        try {
          final userData = await SupaFlow.client
              .from('users')
              .select('birthday, birth_date')
              .eq('user_id', userId)
              .maybeSingle();
          final birthdayRaw = userData?['birthday'] ?? userData?['birth_date'];
          if (birthdayRaw != null) {
            final birthday = DateTime.tryParse(birthdayRaw.toString());
            if (birthday != null) {
              final now = DateTime.now();
              int age = now.year - birthday.year;
              if (now.month < birthday.month ||
                  (now.month == birthday.month && now.day < birthday.day)) {
                age--;
              }
              if (minAge != null && age < minAge) {
                throw Exception(
                  'No cumpls con la edad mínima requerida ($minAge años).',
                );
              }
              if (maxAge != null && age > maxAge) {
                throw Exception(
                  'Superas la edad máxima permitida ($maxAge años).',
                );
              }
            }
          }
        } catch (e) {
          if (e is Exception && e.toString().contains('edad')) rethrow;
        }
      }

      await _persistRequiredChallengeCompletions(userId);

      final now = DateTime.now().toIso8601String();
      final message = _mensajeController.text.trim().isNotEmpty
          ? _mensajeController.text.trim()
          : null;
      final existing = await SupaFlow.client
          .from('aplicaciones_convocatoria')
          .select('id')
          .eq('convocatoria_id', widget.convocatoriaId!)
          .eq('jugador_id', userId)
          .limit(1)
          .maybeSingle();
      final payload = {
        'convocatoria_id': widget.convocatoriaId,
        'jugador_id': userId,
        'estado': 'pendiente',
        'mensaje': message,
        'updated_at': now,
      };
      if (existing != null) {
        await SupaFlow.client
            .from('aplicaciones_convocatoria')
            .update(payload)
            .eq('id', existing['id']);
      } else {
        await SupaFlow.client.from('aplicaciones_convocatoria').insert({
          ...payload,
          'created_at': now,
        });
      }

      await _mirrorLegacyPostulacion(
        userId: userId,
        createdAt: now,
        message: message,
      );

      // 6.1/6.2 — Criar snapshot imutável com desafios válidos
      try {
        await ConvocatoriaSnapshotService.createApplicationSnapshot(
          userId: userId,
          convocatoriaId: widget.convocatoriaId!,
        );
      } catch (snapshotError) {
        debugPrint('Snapshot creation failed (non-blocking): $snapshotError');
      }

      await _notifyApplicationSubmitted(userId);

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
      debugPrint('Error al aplicar: $e');
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos enviar tu postulación. Verifica tu conexión e intenta de nuevo.'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _mirrorLegacyPostulacion({
    required String userId,
    required String createdAt,
    String? message,
  }) async {
    final convId = widget.convocatoriaId?.trim() ?? '';
    if (convId.isEmpty || userId.isEmpty) return;
    try {
      final existing = await SupaFlow.client
          .from('postulaciones')
          .select('id')
          .eq('convocatoria_id', convId)
          .eq('jugador_id', userId)
          .limit(1)
          .maybeSingle();
      final payload = {
        'convocatoria_id': convId,
        'jugador_id': userId,
        'player_id': userId,
        'estado': 'pendiente',
        'mensaje': message,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (existing != null) {
        await SupaFlow.client
            .from('postulaciones')
            .update(payload)
            .eq('id', existing['id']);
      } else {
        await SupaFlow.client.from('postulaciones').insert({
          ...payload,
          'created_at': createdAt,
        });
      }
    } catch (_) {}
  }

  String _firstNonEmptyText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  Future<void> _notifyApplicationSubmitted(String userId) async {
    final convId = widget.convocatoriaId?.trim() ?? '';
    if (convId.isEmpty || userId.isEmpty) return;

    try {
      final title = _convocatoria?['titulo']?.toString() ?? 'Convocatoria';
      final clubName = _firstNonEmptyText([
        _clubData?['nombre'],
        _clubData?['club_name'],
        _clubData?['name'],
        _convocatoria?['club_name'],
        _convocatoria?['nombre_club'],
      ]);
      await ActivityNotificationsService.notifyPlayerApplicationSubmitted(
        playerId: userId,
        convocatoriaId: convId,
        convocatoriaTitle: title,
        clubName: clubName,
      );

      final clubUserId = _firstNonEmptyText([
        _clubData?['owner_id'],
        _clubData?['user_id'],
        _convocatoria?['club_id'],
      ]);
      if (clubUserId.isEmpty) return;

      String playerName = '';
      try {
        final player = await SupaFlow.client
            .from('users')
            .select('name, lastname')
            .eq('user_id', userId)
            .limit(1)
            .maybeSingle();
        playerName = _firstNonEmptyText([
          '${player?['name'] ?? ''} ${player?['lastname'] ?? ''}'.trim(),
          player?['name'],
        ]);
      } catch (_) {}

      await ActivityNotificationsService.notifyClubNewApplication(
        clubUserId: clubUserId,
        convocatoriaId: convId,
        convocatoriaTitle: title,
        playerId: userId,
        playerName: playerName,
      );
    } catch (_) {}
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
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: PlanPaywallCard(
              title: 'Convocatorias en el Plan Pro',
              message:
                  'Este detalle pertenece al módulo Pro. Si el modo piloto está activo, se libera sin restricciones.',
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
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

    final clubName = (_clubData?['name'] ??
            _clubData?['club_name'] ??
            _clubData?['nombre'] ??
            'Club')
        .toString();
    final clubImageUrl = (_clubData?['photo_url'] ??
            _clubData?['logo_url'] ??
            _clubData?['avatar_url'] ??
            '')
        .toString();
    final titulo = (_convocatoria!['titulo'] ?? 'Convocatoria').toString();
    final descripcion = (_convocatoria!['descripcion'] ?? '').toString();
    final categoria = (_convocatoria!['categoria'] ?? '').toString();
    final posicion = (_convocatoria!['posicion'] ?? '').toString();
    final edadMinima = _convocatoria!['edad_minima'] ?? _convocatoria!['min_age'];
    final edadMaxima = _convocatoria!['edad_maxima'] ?? _convocatoria!['max_age'];
    final fechaInicio = _formatDate(_convocatoria!['fecha_inicio']);
    final eligibilityMessages = _eligibilityMessages;

    String requisitos = titulo;
    if (categoria.isNotEmpty) {
      requisitos = 'Convocatoria para jugadores $categoria';
    }
    if (posicion.isNotEmpty && posicion != 'Todas') {
      requisitos += ' - Posición: $posicion';
    }
    if (edadMinima != null || edadMaxima != null) {
      if (edadMinima != null && edadMaxima != null) {
        requisitos += ' ($edadMinima-$edadMaxima años)';
      } else if (edadMinima != null)
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
                    onTap: () => context.safePop(),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            clubName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                if (eligibilityMessages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildEligibilityMessagesSection(eligibilityMessages),
                ],
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
                          const FaIcon(FontAwesomeIcons.solidClock,
                              color: Color(0xFF0D3B66), size: 20),
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
                    onPressed: _hasApplied ||
                            _isApplying ||
                            eligibilityMessages.isNotEmpty ||
                            !_canSubmitApplication
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
                                        : eligibilityMessages.isNotEmpty
                                            ? 'Requisitos pendientes'
                                            : !_canSubmitApplication
                                                ? 'Completa los desafíos'
                                                : 'Quiero participar',
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
