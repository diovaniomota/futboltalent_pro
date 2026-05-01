import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestResponse extends Mock implements PostgrestResponse {}

// For maybeSingle() which returns Map<String, dynamic>?
class MockPostgrestFilterBuilderSingle extends Mock
    implements PostgrestFilterBuilder<Map<String, dynamic>?> {}

class MockPostgrestTransformBuilderSingle extends Mock
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {}

void setupMocks() {
  // Common registration for mocktail if needed
}
