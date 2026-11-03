import 'dart:convert';
import 'dart:io';

import 'local_store.dart';

class AiClient {
  AiClient._();
  static final AiClient instance = AiClient._();

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o-mini';

  String get baseUrl => Store.instance.note('ai_base_url')?.trim() ?? defaultBaseUrl;
  String get apiKey => Store.instance.note('ai_api_key')?.trim() ?? '';
  String get model => Store.instance.note('ai_model')?.trim() ?? defaultModel;

  void saveConfig({String? baseUrl, String? apiKey, String? model}) {
    if (baseUrl != null) Store.instance.setNote('ai_base_url', baseUrl.trim());
    if (apiKey != null) Store.instance.setNote('ai_api_key', apiKey.trim());
    if (model != null) Store.instance.setNote('ai_model', model.trim());
  }

  /// Translates an exercise name to English and formats it strictly as lowercase kebab-case.
  /// If API is unconfigured or unavailable, safely falls back to a normalized slug.
  Future<String> slugifyExercise(String exerciseName) async {
    final cleanName = exerciseName.trim();
    if (cleanName.isEmpty) return 'exercise';

    final key = apiKey;
    final currentBase = baseUrl.isNotEmpty ? baseUrl : defaultBaseUrl;
    final currentModel = model.isNotEmpty ? model : defaultModel;

    if (key.isNotEmpty) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 12);

        final endpoint = currentBase.endsWith('/')
            ? '${currentBase}chat/completions'
            : '$currentBase/chat/completions';

        final request = await client.postUrl(Uri.parse(endpoint));
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');

        final payload = jsonEncode({
          'model': currentModel,
          'messages': [
            {
              'role': 'user',
              'content':
                  'Traduce el siguiente ejercicio al inglés y devuélvelo estrictamente en minúsculas y formato kebab-case (ej: sentadilla búlgara -> bulgarian-split-squat). Responde ÚNICAMENTE con la cadena formateada: $cleanName',
            }
          ],
          'temperature': 0.0,
        });

        request.add(utf8.encode(payload));
        final response = await request.close();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final first = choices.first as Map<String, dynamic>;
            final message = first['message'] as Map<String, dynamic>?;
            final content = message?['content'] as String? ?? '';
            final slug = _cleanSlug(content);
            if (slug.isNotEmpty) return slug;
          }
        }
      } catch (_) {
        // Fallback to local slugification on network or configuration errors
      }
    }

    return _fallbackSlug(cleanName);
  }

  /// Sends a conversation history and optional system prompt to an OpenAI-compatible endpoint.
  Future<String> chatCompletion({
    required List<Map<String, String>> messages,
    String? systemPrompt,
  }) async {
    final key = apiKey;
    final currentBase = baseUrl.isNotEmpty ? baseUrl : defaultBaseUrl;
    final currentModel = model.isNotEmpty ? model : defaultModel;

    if (key.isEmpty) {
      throw 'API Key no configurada. Pulsa el botón de configuración (engranaje) para introducir tu API Key.';
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 35);

    final endpoint = currentBase.endsWith('/')
        ? '${currentBase}chat/completions'
        : '$currentBase/chat/completions';

    final request = await client.postUrl(Uri.parse(endpoint));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');

    final fullMessages = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    final payload = jsonEncode({
      'model': currentModel,
      'messages': fullMessages,
      'temperature': 0.7,
    });

    request.add(utf8.encode(payload));
    final response = await request.close();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final first = choices.first as Map<String, dynamic>;
        final message = first['message'] as Map<String, dynamic>?;
        return (message?['content'] as String? ?? '').trim();
      }
      return 'Respuesta vacía del modelo.';
    } else {
      final body = await response.transform(utf8.decoder).join();
      throw 'Error API (${response.statusCode}): $body';
    }
  }

  static String _cleanSlug(String raw) {
    return raw
        .replaceAll(RegExp(r'''[`"'\[\]]'''), '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String _fallbackSlug(String text) {
    const accents = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
      'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u', 'Ü': 'u', 'Ñ': 'n',
    };
    var result = text.toLowerCase();
    accents.forEach((k, v) => result = result.replaceAll(k, v));
    return _cleanSlug(result);
  }
}
