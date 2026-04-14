import 'package:flutter_test/flutter_test.dart';
import 'package:futboltalent_pro/fluxo_compartilhado/club_identity_utils.dart';

void main() {
  group('club_identity_utils', () {
    test('firstNonEmptyClubValue skips null, blank and literal null', () {
      expect(
        firstNonEmptyClubValue([null, '', 'null', ' Club Norte ']),
        'Club Norte',
      );
    });

    test('clubRefFromMap respects id, owner_id, user_id and club_id priority', () {
      expect(
        clubRefFromMap({
          'id': 'club-id',
          'owner_id': 'owner-id',
          'user_id': 'user-id',
        }),
        'club-id',
      );

      expect(
        clubRefFromMap({
          'owner_id': 'owner-id',
          'user_id': 'user-id',
          'club_id': 'legacy-id',
        }),
        'owner-id',
      );

      expect(
        clubRefFromMap({
          'user_id': 'user-id',
          'club_id': 'legacy-id',
        }),
        'user-id',
      );

      expect(
        clubRefFromMap({
          'club_id': 'legacy-id',
        }),
        'legacy-id',
      );
    });
  });
}
