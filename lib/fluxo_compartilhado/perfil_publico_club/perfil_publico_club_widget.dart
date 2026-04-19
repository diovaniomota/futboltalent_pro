import '/backend/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PerfilPublicoClubWidget extends StatefulWidget {
  const PerfilPublicoClubWidget({
    super.key,
    required this.clubRef,
    this.initialClubData,
  });

  final String clubRef;
  final Map<String, dynamic>? initialClubData;

  @override
  State<PerfilPublicoClubWidget> createState() =>
      _PerfilPublicoClubWidgetState();
}

class _PerfilPublicoClubWidgetState extends State<PerfilPublicoClubWidget> {
  Map<String, dynamic>? _clubData;
  List<Map<String, dynamic>> _convocatorias = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedTabKey = 'convocatorias';

  @override
  void initState() {
    super.initState();
    _clubData = widget.initialClubData == null
        ? null
        : Map<String, dynamic>.from(widget.initialClubData!);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final club = await _loadClub();
      final convocatorias = await _loadClubConvocatorias(club);
      if (!mounted) return;
      setState(() {
        _clubData = club;
        _convocatorias = convocatorias;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo abrir el perfil del club.';
      });
    }
  }

  Future<Map<String, dynamic>?> _loadClub() async {
    final ref = widget.clubRef.trim();
    if (ref.isEmpty) return _clubData;

    Map<String, dynamic>? club;

    try {
      club = await SupaFlow.client
          .from('clubs')
          .select()
          .eq('id', ref)
          .maybeSingle();
    } catch (_) {}

    if (club == null) {
      try {
        club = await SupaFlow.client
            .from('clubs')
            .select()
            .eq('owner_id', ref)
            .maybeSingle();
      } catch (_) {}
    }

    if (club == null) {
      try {
        club = await SupaFlow.client
            .from('clubs')
            .select()
            .eq('user_id', ref)
            .maybeSingle();
      } catch (_) {}
    }

    return club ?? _clubData;
  }

  Future<List<Map<String, dynamic>>> _loadClubConvocatorias(
    Map<String, dynamic>? club,
  ) async {
    final refs = <String>{
      widget.clubRef.trim(),
      club?['id']?.toString().trim() ?? '',
      club?['owner_id']?.toString().trim() ?? '',
      club?['user_id']?.toString().trim() ?? '',
    }..removeWhere((value) => value.isEmpty);

    if (refs.isEmpty) return [];

    try {
      final response = refs.length == 1
          ? await SupaFlow.client
              .from('convocatorias')
              .select('id, titulo, categoria, posicion, ubicacion, created_at')
              .eq('club_id', refs.first)
              .eq('is_active', true)
              .order('created_at', ascending: false)
              .limit(20)
          : await SupaFlow.client
              .from('convocatorias')
              .select('id, titulo, categoria, posicion, ubicacion, created_at')
              .inFilter('club_id', refs.toList())
              .eq('is_active', true)
              .order('created_at', ascending: false)
              .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return null;
  }

  bool _isVerifiedClub(Map<String, dynamic> club) {
    final direct = club['is_verified'];
    if (direct is bool) return direct;
    final directText = direct?.toString().trim().toLowerCase() ?? '';
    if (directText == 'true') return true;

    final status =
        club['verification_status']?.toString().trim().toLowerCase() ?? '';
    return status == 'verified' ||
        status == 'verificado' ||
        status == 'approved' ||
        status == 'aprobado';
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF60A5FA)),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    isLink ? const Color(0xFF60A5FA) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF151B28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF20293A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF60A5FA)),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF151B28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF20293A)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = const [
      ('convocatorias', 'Convocatorias'),
      ('cursos', 'Cursos'),
      ('sobre', 'Sobre Nosotros'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final selected = _selectedTabKey == tab.$1;
          return GestureDetector(
            onTap: () => setState(() => _selectedTabKey = tab.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 28),
              padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color:
                        selected ? const Color(0xFF1473E6) : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                tab.$2,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF8B96A8),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPanel(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C111B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1B2331)),
      ),
      child: child,
    );
  }

  Widget _buildConvocatoriaTile(Map<String, dynamic> convocatoria) {
    final title = _firstNonEmpty([
          convocatoria['titulo'],
          convocatoria['title'],
        ]) ??
        'Convocatoria';
    final subtitle = [
      convocatoria['categoria']?.toString() ?? '',
      convocatoria['posicion']?.toString() ?? '',
      convocatoria['ubicacion']?.toString() ?? '',
    ].where((item) => item.trim().isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF64B5F6),
                  Color(0xFF2E7D32),
                ],
              ),
            ),
            child: const Icon(
              Icons.sports_soccer_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(Map<String, dynamic> club) {
    final description = _firstNonEmpty([
      club['descripcion'],
      club['description'],
    ]);
    final website = _firstNonEmpty([
      club['sitio_web'],
      club['website'],
      club['site_url'],
    ]);
    final country = _firstNonEmpty([
      club['pais'],
      club['country'],
    ]);
    final league = _firstNonEmpty([
      club['liga'],
      club['league'],
    ]);

    switch (_selectedTabKey) {
      case 'cursos':
        return _buildPanel(
          Text(
            'Este club todavía no publicó cursos.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        );
      case 'sobre':
        final city = _firstNonEmpty([club['ciudad'], club['city']]);
        return _buildPanel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description ??
                    'Este club todavía no completó su presentación pública.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(height: 18),
              if (country != null) _buildInfoRow(Icons.public, 'País', country),
              if (city != null)
                _buildInfoRow(Icons.location_city, 'Ciudad', city),
              if (league != null)
                _buildInfoRow(Icons.emoji_events_outlined, 'Liga', league),
              if (website != null)
                _buildInfoRow(Icons.language, 'Sitio web', website,
                    isLink: true),
            ],
          ),
        );
      default:
        if (_convocatorias.isEmpty) {
          return _buildPanel(
            Text(
              'Este club no tiene convocatorias activas por ahora.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
              ),
            ),
          );
        }
        return Column(
          children: _convocatorias.map(_buildConvocatoriaTile).toList(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF050913),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1473E6)),
        ),
      );
    }

    if (_clubData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF050913),
        appBar: AppBar(
          backgroundColor: const Color(0xFF050913),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            _errorMessage ?? 'Club no encontrado.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    final club = _clubData!;
    final name = _firstNonEmpty([
          club['nombre'],
          club['name'],
          club['club_name'],
        ]) ??
        'Club';
    final coverUrl = _firstNonEmpty([
      club['cover_url'],
      club['banner_url'],
    ]);
    final logoUrl = _firstNonEmpty([
      club['logo_url'],
      club['photo_url'],
      club['avatar_url'],
    ]);
    final verified = _isVerifiedClub(club);
    final staffCapacity = club['max_staff']?.toString() ?? '0';
    final convocatoriasCap = club['max_convocatorias']?.toString() ?? '0';
    final city = _firstNonEmpty([club['ciudad'], club['city']]);
    final country = _firstNonEmpty([club['pais'], club['country']]);
    final league = _firstNonEmpty([club['liga'], club['league']]);
    final locationParts =
        [city, country].where((e) => e != null && e.trim().isNotEmpty).toList();
    final locationLabel =
        locationParts.isNotEmpty ? locationParts.join(', ') : null;

    return Scaffold(
      backgroundColor: const Color(0xFF050913),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050913),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Perfil del Club',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 210,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: const Color(0xFF0E1624),
                        image: coverUrl != null
                            ? DecorationImage(
                                image: NetworkImage(coverUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: coverUrl == null
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF3E7EC3),
                                    Color(0xFF123A18),
                                  ],
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -54,
                      child: Center(
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF4EDE2),
                            border: Border.all(
                              color: const Color(0xFF050913),
                              width: 5,
                            ),
                            image: logoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(logoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: logoUrl == null
                              ? const Icon(
                                  Icons.shield_rounded,
                                  size: 48,
                                  color: Color(0xFF0D3B66),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 72),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified_rounded,
                          size: 22,
                          color: Color(0xFF1D9BF0),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    verified ? 'Club Verificado' : 'Perfil público del club',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                if (locationLabel != null || league != null) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        if (locationLabel != null)
                          _buildInfoChip(
                              Icons.location_on_outlined, locationLabel),
                        if (league != null)
                          _buildInfoChip(Icons.emoji_events_outlined, league),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      _firstNonEmpty([
                            club['descripcion'],
                            club['description'],
                          ]) ??
                          'Este club todavía no completó su presentación pública.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _buildMetricCard(
                      value: '${_convocatorias.length}',
                      label: 'Convocatorias',
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      value: staffCapacity,
                      label: 'Capacidad Staff',
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      value: convocatoriasCap,
                      label: 'Capacidad Conv.',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTabs(),
                const SizedBox(height: 18),
                _buildTabContent(club),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
