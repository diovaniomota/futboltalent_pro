import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<String?> showGeoSelectionBottomSheet({
  required BuildContext context,
  required String title,
  required Iterable<String> options,
  String? selectedValue,
  String searchHint = 'Buscar...',
  String emptyText = 'Sin resultados',
}) {
  final normalizedOptions = _prepareOptions(options);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GeoSelectionSheet(
      title: title,
      options: normalizedOptions,
      selectedValue: selectedValue,
      searchHint: searchHint,
      emptyText: emptyText,
    ),
  );
}

List<String> _prepareOptions(Iterable<String> options) {
  final byKey = <String, String>{};
  for (final option in options) {
    final value = option.trim();
    if (value.isEmpty) continue;
    byKey.putIfAbsent(_lookupKey(value), () => value);
  }

  final prepared = byKey.values.toList()
    ..sort((a, b) => _lookupKey(a).compareTo(_lookupKey(b)));
  return prepared;
}

String _lookupKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[áàãâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòõôö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ç', 'c');
}

class _GeoSelectionSheet extends StatefulWidget {
  const _GeoSelectionSheet({
    required this.title,
    required this.options,
    required this.searchHint,
    required this.emptyText,
    this.selectedValue,
  });

  final String title;
  final List<String> options;
  final String searchHint;
  final String emptyText;
  final String? selectedValue;

  @override
  State<_GeoSelectionSheet> createState() => _GeoSelectionSheetState();
}

class _GeoSelectionSheetState extends State<_GeoSelectionSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets;
    final selectedKey = _lookupKey(widget.selectedValue ?? '');
    final filtered = _query.trim().isEmpty
        ? widget.options
        : widget.options
            .where((option) => _lookupKey(option).contains(_lookupKey(_query)))
            .toList();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.86,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D3B66),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF2B6CB0),
                            width: 1.3,
                          ),
                        ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                widget.emptyText,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : Scrollbar(
                            child: ListView.separated(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(
                                8,
                                0,
                                8,
                                16,
                              ),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                indent: 20,
                                endIndent: 20,
                                color: Color(0xFFE2E8F0),
                              ),
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final isSelected =
                                    _lookupKey(option) == selectedKey;

                                return ListTile(
                                  title: Text(
                                    option,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF2B6CB0),
                                        )
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  onTap: () =>
                                      Navigator.of(context).pop(option),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
