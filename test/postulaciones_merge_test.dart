import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/club_application_utils.dart';

void main() {
  group('Club Application Merge Logic (Bug 1 & 2)', () {
    test('mergeClubApplicationRows should deduplicate by convocatoria_id and player_id', () {
      final rows = [
        {
          'id': '1',
          'convocatoria_id': 'conv_1',
          'jugador_id': 'player_A',
          'created_at': '2026-04-30T10:00:00Z',
          'estado': 'pendiente',
          '_source_table': 'postulaciones'
        },
        {
          'id': '2',
          'convocatoria_id': 'conv_1',
          'player_id': 'player_A', // different key name
          'created_at': '2026-04-30T11:00:00Z', // newer
          'estado': 'aceptado',
          '_source_table': 'aplicaciones_convocatoria'
        },
        {
          'id': '3',
          'convocatoria_id': 'conv_2',
          'jugador_id': 'player_B',
          'created_at': '2026-04-30T10:00:00Z',
          'estado': 'pendiente',
          '_source_table': 'postulaciones'
        },
      ];

      final merged = mergeClubApplicationRows(rows);

      // Should have 2 entries (player_A for conv_1 and player_B for conv_2)
      expect(merged.length, 2);
      
      // player_A should have the newer state (aceptado)
      final playerA = merged.firstWhere((r) => clubApplicationPlayerId(r) == 'player_A');
      expect(playerA['estado'], 'aceptado');
      expect(playerA['id'], '2');
    });

    test('normalizeClubApplicationRow should handle both jugador_id and player_id', () {
      final row1 = {'jugador_id': 'A', 'convocatoria_id': 'C'};
      final normalized1 = normalizeClubApplicationRow(row1, sourceTable: 'test');
      expect(normalized1['player_id'], 'A');

      final row2 = {'player_id': 'B', 'convocatoria_id': 'C'};
      final normalized2 = normalizeClubApplicationRow(row2, sourceTable: 'test');
      expect(normalized2['jugador_id'], 'B');
    });

    test('clubApplicationDedupKey should return consistent keys', () {
      final row1 = {'convocatoria_id': 'C1', 'player_id': 'P1'};
      final row2 = {'convocatoria_id': 'C1', 'jugador_id': 'P1'};
      
      expect(clubApplicationDedupKey(row1), clubApplicationDedupKey(row2));
    });
  });
}
