import 'dart:convert';

import '/backend/supabase/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailService {
  static const String _guardianValidationFunction =
      'send-guardian-validation-email';

  /// Envia o email pela Supabase Edge Function.
  ///
  /// A chave da Resend deve ficar somente no backend.
  static Future<bool> sendGuardianValidationEmail({
    required String playerId,
    required String guardianEmail,
    required String playerName,
    required String approvalCode,
  }) async {
    final normalizedEmail = guardianEmail.trim().toLowerCase();
    final normalizedCode = approvalCode.trim().toUpperCase();
    final normalizedPlayerId = playerId.trim();

    if (normalizedPlayerId.isEmpty ||
        normalizedEmail.isEmpty ||
        !normalizedEmail.contains('@') ||
        normalizedCode.isEmpty) {
      debugPrint('EmailService: payload invalido para email de responsavel.');
      return false;
    }

    try {
      final accessToken =
          SupaFlow.client.auth.currentSession?.accessToken.trim() ?? '';
      if (accessToken.isEmpty) {
        debugPrint('EmailService: usuario sem sessao para funcao de email.');
        return false;
      }

      final response = await http.post(
        Uri.parse(
          '${SupaFlow.supabaseUrl}/functions/v1/$_guardianValidationFunction',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'apikey': SupaFlow.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'player_id': normalizedPlayerId,
          'guardian_email': normalizedEmail,
          'player_name':
              playerName.trim().isEmpty ? 'Jugador' : playerName.trim(),
          'approval_code': normalizedCode,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint(
          'Email de responsavel solicitado via Edge Function para $normalizedEmail',
        );
        return true;
      }

      debugPrint(
        'EmailService: falha Edge Function ${response.statusCode} - ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('EmailService: excecao ao enviar validacao: $e');
      return false;
    }
  }
}
