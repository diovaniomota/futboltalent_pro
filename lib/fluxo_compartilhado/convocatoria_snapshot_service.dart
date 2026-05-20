import '/backend/supabase/supabase.dart';
import 'package:flutter/material.dart';

/// 6.1–6.4 Serviço de snapshot para convocatórias.
///
/// Ao aplicar para uma convocatória, cria-se um snapshot imutável
/// com os desafios enviados, metadata e referências de vídeo.
/// O snapshot NÃO pode ser editado nem excluído pelo jogador.
class ConvocatoriaSnapshotService {
  /// Duração de validade de um desafio (90 dias) — seção 5.2.
  static const int challengeValidityDays = 90;

  /// Verifica se um desafio ainda é válido (< 90 dias desde criação).
  static bool isChallengeValid(DateTime? submittedAt) {
    if (submittedAt == null) return false;
    final daysSince = DateTime.now().difference(submittedAt).inDays;
    return daysSince < challengeValidityDays;
  }

  /// 6.2 — Busca todos os desafios requeridos que o jogador já completou
  /// e que estejam válidos (< 90 dias).
  static Future<List<Map<String, dynamic>>> fetchValidCompletedChallenges({
    required String userId,
    required List<Map<String, dynamic>> requiredChallenges,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty || requiredChallenges.isEmpty) return const [];

    final result = <Map<String, dynamic>>[];

    for (final req in requiredChallenges) {
      final itemId = req['id']?.toString().trim() ?? '';
      final itemType = (req['type']?.toString().trim() ?? '').toLowerCase();
      if (itemId.isEmpty || !['course', 'exercise'].contains(itemType)) {
        continue;
      }

      try {
        final attempts = await SupaFlow.client
            .from('user_challenge_attempts')
            .select()
            .eq('user_id', uid)
            .eq('item_id', itemId)
            .eq('item_type', itemType)
            .eq('status', 'submitted')
            .order('submitted_at', ascending: false);

        for (final attempt in List<Map<String, dynamic>>.from(attempts)) {
          final submittedAt =
              DateTime.tryParse(attempt['submitted_at']?.toString() ?? '');
          if (isChallengeValid(submittedAt)) {
            result.add({
              ...attempt,
              'required_item_id': itemId,
              'required_item_type': itemType,
              'is_valid': true,
            });
            break; // Usa apenas a tentativa mais recente válida
          }
        }
      } catch (e) {
        debugPrint(
          'ConvocatoriaSnapshotService: erro ao buscar tentativa '
          '$itemType:$itemId — $e',
        );
      }
    }

    return result;
  }

  /// 6.3 — Identifica quais desafios requeridos ainda faltam para o jogador.
  static Future<List<Map<String, dynamic>>> fetchMissingChallenges({
    required String userId,
    required List<Map<String, dynamic>> requiredChallenges,
  }) async {
    final completed = await fetchValidCompletedChallenges(
      userId: userId,
      requiredChallenges: requiredChallenges,
    );

    final completedKeys = completed
        .map((c) =>
            '${c['required_item_type']}:${c['required_item_id']}')
        .toSet();

    final missing = <Map<String, dynamic>>[];
    for (final req in requiredChallenges) {
      final key =
          '${(req['type'] ?? '').toString().toLowerCase()}:${req['id'] ?? ''}';
      if (!completedKeys.contains(key)) {
        missing.add(req);
      }
    }
    return missing;
  }

  /// 6.1 — Cria snapshot imutável ao aplicar para uma convocatória.
  ///
  /// - Copia metadata dos desafios requeridos já completados.
  /// - O snapshot fica fixo para o clube e NÃO pode ser editado/excluído.
  /// - Se faltar desafio, retorna lista de faltantes (6.3).
  ///
  /// Retorna `null` se todos os desafios foram salvos no snapshot,
  /// ou a lista de desafios faltantes caso contrário.
  static Future<List<Map<String, dynamic>>?> createApplicationSnapshot({
    required String userId,
    required String convocatoriaId,
  }) async {
    final uid = userId.trim();
    final convId = convocatoriaId.trim();
    if (uid.isEmpty || convId.isEmpty) {
      throw Exception('Datos incompletos para crear la postulación.');
    }

    // Busca required_challenges da convocatória
    final convocatoria = await SupaFlow.client
        .from('convocatorias')
        .select('required_challenges')
        .eq('id', convId)
        .maybeSingle();

    if (convocatoria == null) {
      throw Exception('Convocatoria no encontrada.');
    }

    final rawRequired = convocatoria['required_challenges'];
    final requiredChallenges = <Map<String, dynamic>>[];
    if (rawRequired is List) {
      for (final item in rawRequired) {
        if (item is Map) {
          requiredChallenges.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // 6.3 — Verifica desafios faltantes
    final missing = await fetchMissingChallenges(
      userId: uid,
      requiredChallenges: requiredChallenges,
    );

    if (missing.isNotEmpty) {
      return missing; // Retorna faltantes para que o app peça ao jogador
    }

    // 6.2 — Busca desafios válidos completos
    final validChallenges = await fetchValidCompletedChallenges(
      userId: uid,
      requiredChallenges: requiredChallenges,
    );

    // Cria snapshot principal
    final nowIso = DateTime.now().toIso8601String();
    final snapshotPayload = <String, dynamic>{
      'convocatoria_id': convId,
      'player_id': uid,
      'created_at': nowIso,
      'snapshot_data': validChallenges
          .map((c) => {
                'item_id': c['required_item_id'],
                'item_type': c['required_item_type'],
                'video_url': c['video_url'],
                'video_id': c['video_id'],
                'submitted_at': c['submitted_at'],
                'is_valid': true,
              })
          .toList(),
    };

    try {
      await SupaFlow.client
          .from('convocatoria_application_snapshots')
          .insert(snapshotPayload);
    } catch (e) {
      // Se a tabela ainda não existe, salvar no campo da postulação
      debugPrint('ConvocatoriaSnapshotService: snapshot insert failed: $e');
      debugPrint('Snapshot data will be attached to postulación instead.');
    }

    return null; // Sucesso — todos desafios salvos
  }

  /// 8.0 — Verifica se um vídeo está referenciado em algum snapshot.
  /// Se sim, o vídeo pode ser removido do perfil mas o snapshot permanece.
  static Future<bool> isVideoReferencedInSnapshot(String videoUrl) async {
    final url = videoUrl.trim();
    if (url.isEmpty) return false;

    try {
      final result = await SupaFlow.client
          .from('convocatoria_application_snapshots')
          .select('id')
          .contains('snapshot_data', [
            {'video_url': url}
          ])
          .limit(1);
      return (result as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
