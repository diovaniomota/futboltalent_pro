import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Localization audit (Bug 19)', () {
    test('contact decision labels are not left in Portuguese', () {
      final files = [
        File('lib/fluxo_jugador/perfil_jugador/perfil_jugador_widget.dart'),
        File(
          'lib/fluxo_compartilhado/notificacoes/activity_notifications_service.dart',
        ),
      ];
      final source = files.map((file) => file.readAsStringSync()).join('\n');

      expect(source, isNot(contains('Aprovar')));
      expect(source, isNot(contains('Recusar')));
      expect(source, isNot(contains('Cadastro incompleto')));
      expect(source, contains('Aprobar'));
      expect(source, contains('Rechazar'));
    });
  });
}
