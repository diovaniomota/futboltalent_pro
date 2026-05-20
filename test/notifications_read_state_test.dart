import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification read state', () {
    test('player contact badge counts unread requests, not all pending', () {
      final source = File(
        'lib/fluxo_jugador/perfil_jugador/perfil_jugador_widget.dart',
      ).readAsStringSync();

      expect(source, contains('receiver_read_at'));
      expect(source, contains('_isUnreadContactRequest'));
      expect(source, contains('_markContactRequestAsRead'));
      expect(source, contains('_countUnreadContactRequests'));
    });

    test('scout profile refreshes unread activity notifications after opening',
        () {
      final source = File(
        'lib/fluxo_profesional/perfil_profesioanl/perfil_profesioanl_widget.dart',
      ).readAsStringSync();

      expect(source, contains('_unreadNotifications'));
      expect(source, contains('_refreshUnreadNotifications'));
      expect(source, contains('ActivityNotificationsService.unreadCount'));
    });
  });
}
