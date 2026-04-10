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
  State<PerfilPublicoClubWidget> createState() => _PerfilPublicoClubWidgetState();
}

class _PerfilPublicoClubWidgetState extends State<PerfilPublicoClubWidget> {
  Map<String, dynamic>? _clubData;
  List<Map<String, dynamic>> _convocatorias = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedTabKey = 'perfil';

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
    } catch (e) {
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
      club = await SupaFlow.client.from('clubs').select().eq('id', ref).maybeSingle();
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
              .select()
              .eq('club_id', refs.first)
              .eq('is_active', true)
              .order('created_at', ascending: false)
              .limit(20)
          : await SupaFlow.client
              .from('convocatorias')
              .select()
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0D3B66)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    final tabs = const [
      {'key': 'perfil', 'label': 'Perfil'},
      {'key': 'convocatorias', 'label': 'Convocatorias'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _selectedTabKey == tab['key'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTabKey = tab['key']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? const Color(0xFF0D3B66) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tab['label']!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProfileTab(String? description, String? website) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Descripción',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
        if (website != null) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 18, color: Color(0xFF0D3B66)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      website,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (description == null && website == null) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              'Este club todavía no completó su presentación pública.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConvocatoriasTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Convocatorias activas',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        if (_convocatorias.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              'Este club no tiene convocatorias activas por ahora.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
          )
        else
          ..._convocatorias.map(
            (conv) => Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv['titulo']?.toString() ?? 'Convocatoria',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      conv['posicion']?.toString() ?? '',
                      conv['categoria']?.toString() ?? '',
                      conv['ubicacion']?.toString() ?? '',
                    ].where((value) => value.trim().isNotEmpty).join(' • '),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0D3B66)),
        ),
      );
    }

    if (_clubData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0D3B66),
          elevation: 0,
        ),
        body: Center(
          child: Text(
            _errorMessage ?? 'Club no encontrado.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF475569),
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
    final shortName = _firstNonEmpty([
      club['nombre_corto'],
      club['short_name'],
    ]);
    final description = _firstNonEmpty([
      club['descripcion'],
      club['description'],
    ]);
    final league = _firstNonEmpty([
      club['liga'],
      club['league'],
      club['league_name'],
    ]);
    final country = _firstNonEmpty([
      club['pais'],
      club['country'],
      club['country_name'],
    ]);
    final city = _firstNonEmpty([
      club['city'],
      club['ciudad'],
      club['localidad'],
      club['ubicacion'],
    ]);
    final website = _firstNonEmpty([
      club['sitio_web'],
      club['website'],
      club['site_url'],
    ]);
    final coverUrl = _firstNonEmpty([
      club['cover_url'],
      club['banner_url'],
    ]);
    final logoUrl = _firstNonEmpty([
      club['logo_url'],
      club['photo_url'],
      club['avatar_url'],
    ]);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D3B66),
        title: Text(
          'Club',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D3B66),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 170,
                  width: double.infinity,
                  color: const Color(0xFFE2E8F0),
                  child: coverUrl != null && coverUrl.startsWith('http')
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        )
                      : null,
                ),
                Positioned(
                  left: 20,
                  bottom: -38,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      image: logoUrl != null && logoUrl.startsWith('http')
                          ? DecorationImage(
                              image: NetworkImage(logoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: logoUrl == null || !logoUrl.startsWith('http')
                        ? const Icon(
                            Icons.shield_outlined,
                            size: 42,
                            color: Color(0xFF0D3B66),
                          )
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            if (shortName != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Text(
                  shortName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (league != null) _buildInfoChip(Icons.emoji_events_outlined, league),
                  if (city != null) _buildInfoChip(Icons.location_city_outlined, city),
                  if (country != null) _buildInfoChip(Icons.flag_outlined, country),
                  _buildInfoChip(Icons.campaign_outlined, '${_convocatorias.length} convocatorias'),
                ],
              ),
            ),
            _buildTabSelector(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_selectedTabKey),
                child: _selectedTabKey == 'convocatorias'
                    ? _buildConvocatoriasTab()
                    : _buildProfileTab(description, website),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
