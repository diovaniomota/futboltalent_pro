import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/club_application_utils.dart';

void main() {
  group('club_application_utils', () {
    test('clubApplicationPlayerId respects fallback priority', () {
      expect(
        clubApplicationPlayerId({
          'jugador_id': 'player-1',
          'player_id': 'player-2',
          'user_id': 'player-3',
        }),
        'player-1',
      );
      expect(
        clubApplicationPlayerId({
          'player_id': 'player-2',
          'user_id': 'player-3',
        }),
        'player-2',
      );
      expect(
        clubApplicationPlayerId({
          'user_id': 'player-3',
        }),
        'player-3',
      );
    });

    test('clubApplicationCreatedAt parses date and falls back safely', () {
      expect(
        clubApplicationCreatedAt({'created_at': '2026-04-10T12:00:00Z'}),
        DateTime.parse('2026-04-10T12:00:00Z'),
      );
      expect(
        clubApplicationCreatedAt({'created_at': 'invalid'}),
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });

    test('normalizeClubApplicationRow fills legacy aliases and default status', () {
      final row = normalizeClubApplicationRow(
        {
          'id': '1',
          'jugador_id': 'player-1',
        },
        sourceTable: 'postulaciones',
      );

      expect(row['_source_table'], 'postulaciones');
      expect(row['player_id'], 'player-1');
      expect(row['jugador_id'], 'player-1');
      expect(row['estado'], 'pendiente');
    });

    test('mergeClubApplicationRows deduplicates by convocatoria and player using newest record', () {
      final merged = mergeClubApplicationRows([
        {
          'id': 'older',
          'convocatoria_id': 'conv-1',
          'jugador_id': 'player-1',
          'estado': 'pendiente',
          'created_at': '2026-04-10T10:00:00Z',
          '_source_table': 'postulaciones',
        },
        {
          'id': 'newer',
          'convocatoria_id': 'conv-1',
          'player_id': 'player-1',
          'estado': 'aceptado',
          'created_at': '2026-04-10T11:00:00Z',
          '_source_table': 'aplicaciones_convocatoria',
        },
        {
          'id': 'other-player',
          'convocatoria_id': 'conv-1',
          'jugador_id': 'player-2',
          'created_at': '2026-04-10T09:00:00Z',
          '_source_table': 'postulaciones',
        },
      ]);

      expect(merged, hasLength(2));
      expect(merged.first['id'], 'newer');
      expect(merged.first['estado'], 'aceptado');
      expect(merged.last['id'], 'other-player');
    });

    test('clubApplicationDedupKey falls back to source and id when player is missing', () {
      expect(
        clubApplicationDedupKey({
          'id': 'abc',
          '_source_table': 'postulaciones',
        }),
        'postulaciones::abc',
      );
    });
  });
}
