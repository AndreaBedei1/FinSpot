import 'package:seawatch/services/core/api_client.dart';

class ChatbotReply {
  const ChatbotReply({
    required this.answer,
    this.conversationId,
    this.contextSpecies,
  });

  final String answer;
  final String? conversationId;
  final String? contextSpecies;
}

class ChatbotService {
  ChatbotService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<bool> isAvailable() {
    return _api.isBackendReachable();
  }

  Future<ChatbotReply> sendMessage({
    required String message,
    String? conversationId,
    String? speciesHint,
    int? sightingId,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw const ApiException('Messaggio vuoto.');
    }

    final payload = <String, dynamic>{
      'message': trimmedMessage,
    };

    final normalizedConversationId = conversationId?.trim();
    if (normalizedConversationId != null &&
        normalizedConversationId.isNotEmpty) {
      payload['conversationId'] = normalizedConversationId;
    }

    final normalizedSpeciesHint = speciesHint?.trim();
    if (normalizedSpeciesHint != null && normalizedSpeciesHint.isNotEmpty) {
      payload['speciesHint'] = normalizedSpeciesHint;
    }

    if (sightingId != null) {
      payload['sightingId'] = sightingId;
    }

    final response = await _api.postJson('/chatbot/message', body: payload);
    final answer = response['answer']?.toString().trim() ?? '';
    if (answer.isEmpty) {
      throw const ApiException('Risposta chatbot non valida.');
    }

    final returnedConversationId =
        response['conversationId']?.toString().trim();
    final returnedContextSpecies =
        response['contextSpecies']?.toString().trim();

    return ChatbotReply(
      answer: answer,
      conversationId:
          (returnedConversationId == null || returnedConversationId.isEmpty)
              ? null
              : returnedConversationId,
      contextSpecies:
          (returnedContextSpecies == null || returnedContextSpecies.isEmpty)
              ? null
              : returnedContextSpecies,
    );
  }

  Future<void> resetConversation({String? conversationId}) async {
    final body = <String, dynamic>{};
    final normalizedConversationId = conversationId?.trim();
    if (normalizedConversationId != null &&
        normalizedConversationId.isNotEmpty) {
      body['conversationId'] = normalizedConversationId;
    }

    await _api.postJson('/chatbot/reset', body: body);
  }

  bool isNetworkError(ApiException error) {
    final lower = error.message.toLowerCase();
    return lower.contains('timeout') ||
        lower.contains('connessione') ||
        lower.contains('connection') ||
        lower.contains('network');
  }
}
