import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
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

  Future<void> _applyToConvocatoria() async {
    final userId = SupaFlow.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _showLoginRequired();
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
