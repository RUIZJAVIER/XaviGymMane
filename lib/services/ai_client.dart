import 'dart:convert';
import 'dart:io';

import 'local_store.dart';

class AiClient {
  AiClient._();
  static final AiClient instance = AiClient._();

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o-mini';
  static const String defaultSystemPrompt = '''Eres el Asistente Experto de Entrenamiento y Sobrecarga Progresiva de GymMane.
Directrices:
1. Responde de forma concisa, motivadora y profesional en español.

REGLAS ESTRICTAS DE CREACIÓN:
1. AUDITORÍA DE EQUIPAMIENTO: Adapta los ejercicios estrictamente al equipo del usuario.
2. FRAGMENTACIÓN OBLIGATORIA: NUNCA agrupes toda la semana en una sola sesión. Crea sesiones reales de máximo 6 a 8 ejercicios.
3. CALENTAMIENTO Y APROXIMACIÓN: En el primer ejercicio compuesto o pesado de la sesión, añade 1 serie de calentamiento usando "warmup": 1.
4. FORMATO DE EXPORTACIÓN JSON: Por CADA sesión, debes imprimir un bloque oculto separado. Si la rutina es de 3 días, imprime TRES bloques <routine>.
5. ESTRUCTURA DEL JSON Y SERIES: Cada elemento de "exercises" DEBE ser un objeto con "name", "sets" (entero ej: 3 o 4), "reps" (entero o rango ej: 10 o "8-12"), opcionalmente "warmup": 1 (para aproximación previa), opcionalmente "rest" (descanso en segundos ej: 90) y opcionalmente "kind" ("normal", "warmup", "failure"). Incluye "name", "group" (ej. "Torso", "Pierna", "Full Body") y "days" (arreglo de números 1=Lun a 7=Dom).
Ejemplo exacto: 
<routine>{"name": "Día 1 - Torso", "group": "Torso", "days": [1, 4], "exercises": [{"name": "Dumbbell Bench Press", "sets": 3, "reps": "8-12", "warmup": 1, "rest": 90}, {"name": "One-Arm Dumbbell Row", "sets": 3, "reps": 10, "rest": 60}]}</routine>''';

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
    final key = apiKey.trim();
    final currentBase = baseUrl.trim().isNotEmpty ? baseUrl.trim() : defaultBaseUrl;
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

    final effectiveSystemPrompt = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? systemPrompt
        : defaultSystemPrompt;

    final fullMessages = <Map<String, String>>[
      if (effectiveSystemPrompt.isNotEmpty)
        {'role': 'system', 'content': effectiveSystemPrompt},
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

  Future<List<String>> fetchAvailableModels() async {
    final key = apiKey.trim();
    if (key.isEmpty) return [];
    final currentBase = baseUrl.trim().isNotEmpty ? baseUrl.trim() : defaultBaseUrl;
    final endpoint = currentBase.endsWith('/') ? '${currentBase}models' : '$currentBase/models';
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(endpoint));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final List models = data['data'] ?? [];
        return models.map((m) => m['id'].toString()).toList();
      } else {
        final body = await response.transform(utf8.decoder).join();
        print('TokenHarbor Error HTTP: ${response.statusCode} - $body');
      }
    } catch (e) {
      print('TokenHarbor Error Exception: $e');
    }
    return [];
  }

  Future<String> testConnection() async {
    try {
      return await chatCompletion(messages: [{'role': 'user', 'content': 'Di exactamente: "¡Hola! Conexión exitosa. Todo está configurado correctamente."'}]);
    } catch (e) {
      return 'Error de red o de clave: $e';
    }
  }

  static String _cleanSlug(String raw) {
    return raw
        .replaceAll(RegExp(r'''["'\[\]]'''), '')
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
