import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../models/workout.dart';
import '../services/ai_client.dart';
import '../services/local_store.dart';
import '../services/plan_share.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_notch.dart';
import '../widgets/ui_kit.dart';

class _Message {
  _Message({required this.role, required this.text, this.routines = const []});
  final String role;
  final String text;
  final List<PlanRoutine> routines;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
  factory _Message.fromJson(Map<String, dynamic> j) => _Message(
        role: j['role'] as String? ?? 'user',
        text: j['text'] as String? ?? '',
      );
}

class _ChatSession {
  _ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  final String id;
  String title;
  final DateTime createdAt;
  final List<_Message> messages;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory _ChatSession.fromJson(Map<String, dynamic> j) => _ChatSession(
        id: j['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: j['title'] as String? ?? 'Conversación',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        messages: ((j['messages'] as List?) ?? [])
            .map((m) => _Message.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Message> _messages = [];
  List<_ChatSession> _sessions = [];
  _ChatSession? _currentSession;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    final raw = Store.instance.note('ai_chat_sessions_v1');
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        _sessions = decoded
            .map((s) => _ChatSession.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList();
      } catch (_) {
        _sessions = [];
      }
    }
    final currentId = Store.instance.note('ai_chat_current_id');
    _currentSession = _sessions.where((s) => s.id == currentId).firstOrNull ?? _sessions.firstOrNull;

    if (_currentSession == null) {
      _initNewSession();
    } else {
      _messages.clear();
      _messages.addAll(_currentSession!.messages);
    }
  }

  void _initNewSession() {
    final place = fit.activePlace;
    final days = place?.targetDaysPerWeek ?? 3;
    final placeName = place?.name ?? 'General';
    final welcome = _Message(
      role: 'assistant',
      text: '¡Hola! Soy tu asistente de entrenamiento en GymMane.\n\n'
          '📍 Lugar activo: $placeName\n'
          '📅 Meta: $days días/semana (Frecuencia 2)\n'
          '🎒 Equipamiento: ${fit.gearHere.join(', ')}\n\n'
          '¿Qué deseas entrenar hoy o qué rutina te gustaría diseñar?',
    );
    final session = _ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Nueva conversación',
      createdAt: DateTime.now(),
      messages: [welcome],
    );
    _sessions.insert(0, session);
    _currentSession = session;
    _messages.clear();
    _messages.addAll(session.messages);
    _saveSessions();
  }

  void _saveSessions() {
    if (_currentSession != null) {
      _currentSession!.messages.clear();
      _currentSession!.messages.addAll(_messages);
      Store.instance.setNote('ai_chat_current_id', _currentSession!.id);
    }
    final payload = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    Store.instance.setNote('ai_chat_sessions_v1', payload);
  }

  void _startNewChat() {
    setState(() {
      _initNewSession();
    });
    _scrollToBottom();
    showNotchToast(context, 'Nueva conversación iniciada', icon: PhosphorIconsRegular.plus);
  }

  Future<void> _exportConversation() async {
    final gc = context.gc;
    if (_messages.isEmpty) {
      showNotchToast(context, 'No hay mensajes para exportar', accent: gc.warn);
      return;
    }
    try {
      showNotchToast(context, 'Preparando exportación...', icon: PhosphorIconsRegular.arrowsClockwise);
      final buffer = StringBuffer();
      final title = _currentSession?.title ?? 'Conversación GymMane';
      final date = DateTime.now().toLocal().toString().split('.').first;
      buffer.writeln('# $title');
      buffer.writeln('**Fecha de exportación:** $date');
      buffer.writeln('**Modelo IA:** ${fit.aiModel}');
      buffer.writeln('\n---\n');
      for (final m in _messages) {
        final sender = m.role == 'user' ? '👤 Tú' : '🤖 Entrenador GymMane';
        buffer.writeln('### $sender:\n');
        buffer.writeln('${m.text}\n');
      }
      final dir = await getTemporaryDirectory();
      final safeName = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${dir.path}/gymmane-chat-$safeName-${DateTime.now().millisecondsSinceEpoch}.md');
      await file.writeAsString(buffer.toString());
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/markdown')],
        subject: title,
      ));
    } catch (e) {
      if (mounted) {
        showNotchToast(context, 'Error al exportar: $e', accent: gc.warn);
      }
    }
  }

  void _openHistorySheet() {
    final gc = context.gc;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            padding: sheetPad(sheetCtx),
            decoration: sheetDecoration(gc),
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 16),
                Row(children: [
                  Icon(PhosphorIconsRegular.clockCounterClockwise, size: 20, color: gc.ember),
                  const SizedBox(width: 8),
                  Text('Historial de Conversaciones',
                      style: AppTheme.f(18, weight: FontWeight.w700, color: gc.text)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Selecciona una conversación anterior para continuarla o exportarla.',
                  style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sessions.length,
                    itemBuilder: (_, i) {
                      final s = _sessions[i];
                      final isCurrent = s.id == _currentSession?.id;
                      final dateStr = '${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isCurrent ? gc.emberSoft : gc.bgRaised2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isCurrent ? gc.ember.withValues(alpha: 0.4) : gc.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          title: Text(
                            s.title.isEmpty ? 'Conversación' : s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.f(14, weight: isCurrent ? FontWeight.w700 : FontWeight.w600, color: gc.text),
                          ),
                          subtitle: Text(
                            '$dateStr · ${s.messages.length} mensajes',
                            style: AppTheme.f(11.5, color: gc.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_sessions.length > 1)
                                IconButton(
                                  icon: Icon(PhosphorIconsRegular.trash, size: 18, color: gc.textTertiary),
                                  onPressed: () {
                                    setSheetState(() {
                                      _sessions.removeAt(i);
                                      if (isCurrent) {
                                        _currentSession = _sessions.firstOrNull;
                                        _messages.clear();
                                        if (_currentSession != null) {
                                          _messages.addAll(_currentSession!.messages);
                                        }
                                      }
                                      _saveSessions();
                                    });
                                    setState(() {});
                                  },
                                ),
                              Icon(
                                isCurrent ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.caretRight,
                                size: 18,
                                color: isCurrent ? gc.ember : gc.textTertiary,
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _currentSession = s;
                              _messages.clear();
                              _messages.addAll(s.messages);
                              _saveSessions();
                            });
                            Navigator.pop(sheetCtx);
                            _scrollToBottom();
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Nueva Conversación',
                  iconData: PhosphorIconsRegular.plus,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _startNewChat();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _buildSystemPrompt() {
    final place = fit.activePlace;
    final days = place?.targetDaysPerWeek ?? 3;
    final gear = fit.gearHere.join(', ');
    final volRec = fit.volumeRecommendation(days);

    return '''
# ROL Y PERSONALIDAD
Eres un entrenador personal experto, altamente cualificado en ciencias del deporte, pero con una gran empatía y vocación pedagógica. Tu especialidad es guiar a principiantes absolutos ("analfabetas del gym") que no conocen la terminología técnica del gimnasio y se sienten abrumados.
Tu tono debe ser cercano, motivador, paciente, claro y sin enredos innecesarios. Traduce siempre la ciencia dura a un lenguaje cotidiano usando analogías prácticas (por ejemplo, comparar el cuerpo con una casa en construcción).

# OBJETIVOS DE COMUNICACIÓN
1. Explica los conceptos fundamentales paso a paso sin saturar de información de golpe.
2. Reconoce las frustraciones del usuario y valora su disciplina por encima de la motivación pasajera.
3. Adapta siempre las explicaciones a un contexto de entrenamiento realista (ej. entrenamiento en casa con mancuernas ajustables/fijas y bandas de resistencia).

# LOS 6 PILARES FUNDAMENTALES QUE DEBES ENSEÑAR Y MANTENER EN CUENTA

## 1. La Mentalidad Inicial
- Motivación vs. Disciplina: La motivación es una chispa inconstante; la disciplina representa el 80% del éxito y es la que te hace cumplir la rutina en los días de pereza.
- Ganancias de Novato ("Rookie Gains"): Al ser principiantes, el cuerpo responde de forma acelerada ganando fuerza y masa muscular rápidamente los primeros meses.

## 2. Los 3 Pilares Indispensables (La Analogía de la Casa en Construcción)
- Entrenamiento (El Arquitecto): El estímulo que genera micro-rupturas en las fibras musculares.
- Alimentación (Los Ladrillos): Los nutrientes y proteínas necesarios para reparar y construir tejido nuevo.
- Descanso (Los Albañiles): El músculo no crece al levantar la pesa, sino casi en su totalidad durante el sueño profundo.

## 3. Diccionario del Gimnasio (Entrenamiento)
- Hipertrofia: Crecimiento del tamaño de las fibras musculares a través de tensión mecánica y estrés metabólico.
- Sobrecarga Progresiva: La regla de oro para no estancarse. Aplicarla añadiendo 1-2 repeticiones, bajando más lento en 3-4 segundos, o sumando bandas de resistencia.
- Ejercicios Compuestos vs. Aislados: Los compuestos (multiarticulares) van al inicio porque demandan más energía; los aislados pulen la estética de un solo músculo al final.
- Volumen y Frecuencia: 14 a 16 series efectivas semanales por grupo muscular, en Frecuencia 2 (entrenar cada músculo dos veces por semana).
- Intensidad (RIR y Fallo): El fallo es no poder completar una repetición más; el RIR ideal para novatos es RIR 1-2 para proteger articulaciones y sistema nervioso.
- Conexión Mente-Músculo: Concentrarse en sentir el estiramiento y la contracción del músculo con pausas de 1 segundo, evitando mover el peso por inercia.

## 4. Nutrición Básica
- Calorías, Déficit Calórico (~20% para quemar grasa) y Superávit Calórico (para ganar volumen si se es muy delgado).
- Proteínas: El material constructor. Peso corporal (kg) × 1.6 a 2.2 = gramos diarios recomendados (pollo, huevo, atún, legumbres).

## 5. El Descanso
- Recuperación de 48 a 72 horas por grupo muscular y una rigurosa higiene del sueño (7 a 9 horas en un cuarto fresco, oscuro y sin pantallas 30-60 minutos antes).

## 6. Suplementación Realista
- Enfoque basado en la ciencia y sin falsas promesas (creatina y proteína en polvo son herramientas de apoyo, no milagros).

# INSTRUCCIÓN DE BIENVENIDA
Cuando el usuario te salude o te pida empezar, adopta este rol de inmediato, salúdale con entusiasmo y pregúntale cuál es su mayor duda actual o en qué parte de su rutina o proceso de aprendizaje quiere que nos enfoquemos hoy.

---

# CONTEXTO ACTUAL DEL USUARIO (GymMane)
- Lugar de entrenamiento: ${place?.name ?? 'Sin lugar activo'}
- Días disponibles por semana: $days días
- Equipamiento disponible: $gear
- Pautas de volumen recomendadas:
$volRec

---

# REGLAS ESTRICTAS DE CREACIÓN DE RUTINAS
1. AUDITORÍA DE EQUIPAMIENTO: Adapta los ejercicios estrictamente al equipo del usuario.
2. FRAGMENTACIÓN OBLIGATORIA: NUNCA agrupes toda la semana en una sola sesión. Crea sesiones reales de máximo 6 a 8 ejercicios.
3. CALENTAMIENTO Y ACTIVACIÓN PROFESIONAL:
   - El PRIMER ejercicio de cada rutina DEBE ser de MOVILIDAD Y ACTIVACIÓN DINÁMICA enfocado al grupo muscular de esa sesión.
     * Torso/Empuje/Tirón: "Arm Circles", "Band Pull-Apart", "Yuri's Shoulder Band Warmup", "Shoulder Rolls".
     * Pierna/Full Body: "Bodyweight Squat", "Glute Bridge", "Hip Circle", "Leg Swing".
   - Este ejercicio de movilidad: 1-2 series × 10-15 reps, sin peso (rest: 30s).
   - En el ejercicio compuesto PRINCIPAL (siguiente al de movilidad), puedes añadir "warmup": 1 para una serie de aproximación ligera.
   - NUNCA pongas el mismo ejercicio pesado como calentamiento de sí mismo con las mismas repeticiones de trabajo.
4. FORMATO DE EXPORTACIÓN JSON: Por CADA sesión, imprime un bloque oculto separado. Si la rutina es de 3 días, imprime TRES bloques <routine>.
5. ESTRUCTURA DEL JSON Y SERIES: Cada elemento de "exercises" DEBE ser un objeto con:
   - "name" (obligatorio), "sets" (entero ej: 3), "reps" (entero o rango ej: "8-12")
   - "warmup": 1 (opcional, solo en el compuesto principal)
   - "rest" (segundos, ej: 90)
   - "kind" (opcional: "normal", "warmup", "failure")
   Incluye en el JSON raíz: "name", "group" (ej. "Torso", "Pierna", "Full Body") y "days" (arreglo 1=Lun … 7=Dom).
Ejemplo exacto: 
<routine>{"name": "Día 1 - Torso", "group": "Torso", "days": [1, 4], "exercises": [{"name": "Arm Circles", "sets": 2, "reps": 15, "rest": 30}, {"name": "Dumbbell Bench Press", "sets": 3, "reps": "8-12", "warmup": 1, "rest": 90}, {"name": "One-Arm Dumbbell Row", "sets": 3, "reps": 10, "rest": 60}]}</routine>''';
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;

    _input.clear();
    setState(() {
      _messages.add(_Message(role: 'user', text: text));
      _loading = true;
    });
    if (_currentSession != null &&
        (_currentSession!.title == 'Nueva conversación' || _currentSession!.title.isEmpty)) {
      _currentSession!.title = text.length > 28 ? '${text.substring(0, 28)}…' : text;
    }
    _saveSessions();
    _scrollToBottom();

    try {
      final history = [
        for (final m in _messages)
          if (m.role == 'user' || m.role == 'assistant')
            {'role': m.role, 'content': m.text},
      ];

      final reply = await AiClient.instance.chatCompletion(
        messages: history,
        systemPrompt: _buildSystemPrompt(),
      );

      final parsed = _extractRoutines(reply);

      if (mounted) {
        setState(() {
          _messages.add(_Message(role: 'assistant', text: reply, routines: parsed));
          _loading = false;
        });
        _saveSessions();
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(_Message(
            role: 'assistant',
            text: '⚠️ No se pudo conectar con la IA. Revisa tu conexión, API Key o URL base.',
          ));
          _loading = false;
        });
        _saveSessions();
        _scrollToBottom();
      }
    }
  }

  List<PlanRoutine> _extractRoutines(String text) {
    try {
      final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
      final match = codeBlock.firstMatch(text);
      final jsonCandidate = match != null ? match.group(1)! : text;
      final parsed = parsePlan(jsonCandidate);
      return parsed.where((p) => p.items.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  void _applyRoutine(List<PlanRoutine> routines) {
    final gc = context.gc;
    final res = fit.applyPlan(routines, schedule: true);
    showNotchToast(
      context,
      res.routines > 0 ? t.routinesAdded(res.routines) : t.nothingToImport,
      subtitle: res.routines > 0 ? t.exerciseCount(res.added) : null,
      icon: res.routines > 0 ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.warningCircle,
      accent: res.routines > 0 ? gc.sage : gc.warn,
    );
  }

  String _getFormattedRoutines() {
    final list = fit.activeRoutines.isNotEmpty ? fit.activeRoutines : fit.routines;
    if (list.isEmpty) {
      return 'No tengo rutinas guardadas aún.';
    }
    final buffer = StringBuffer('Por favor analiza mis rutinas actuales:\n\n');
    for (final r in list) {
      final names = [
        for (final id in r.exerciseIds)
          fit.exerciseById(id)?.name ?? id,
      ];
      final exText = names.isNotEmpty ? names.join(', ') : 'Sin ejercicios';
      buffer.writeln('- ${r.name}: $exText');
    }
    return buffer.toString().trimRight();
  }

  Future<void> _selectModel(BuildContext context, TextEditingController modelCtrl) async {
    final gc = context.gc;
    showNotchToast(context, 'Cargando modelos...', icon: PhosphorIconsRegular.cloudArrowDown);
    final models = await AiClient.instance.fetchAvailableModels();
    if (!context.mounted) return;
    if (models.isEmpty) {
      showNotchToast(context, 'Error al cargar modelos. Revisa tu API Key y URL.', accent: gc.warn);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: gc.bgRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 20),
        itemCount: models.length,
        itemBuilder: (c, i) => ListTile(
          title: Text(models[i], style: AppTheme.f(14, color: gc.text)),
          onTap: () {
            modelCtrl.text = models[i];
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _openConfigSheet() {
    final gc = context.gc;
    final urlController = TextEditingController(text: fit.aiBaseUrl);
    final keyController = TextEditingController(text: fit.aiApiKey);
    final modelController = TextEditingController(text: fit.aiModel);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: sheetPad(sheetCtx).add(EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom)),
        decoration: sheetDecoration(gc),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              Row(children: [
                Icon(PhosphorIconsRegular.gear, size: 20, color: gc.ember),
                const SizedBox(width: 8),
                Text('Configuración de API IA',
                    style: AppTheme.f(18, weight: FontWeight.w700, color: gc.text)),
              ]),
              const SizedBox(height: 6),
              Text(
                'Compatible con TokenHarbor, NVIDIA NIM, OpenAI, Groq, OpenRouter o cualquier API compatible.',
                style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              Text('URL Base', style: AppTheme.s(11, weight: FontWeight.w700, color: gc.textTertiary)),
              const SizedBox(height: 6),
              TextField(
                controller: urlController,
                style: AppTheme.f(13, weight: FontWeight.w500, color: gc.text),
                cursorColor: gc.accent,
                decoration: InputDecoration(
                  hintText: 'https://api.openai.com/v1',
                  hintStyle: AppTheme.f(13, color: gc.textTertiary),
                  filled: true,
                  fillColor: gc.bgRaised2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Text('API Key', style: AppTheme.s(11, weight: FontWeight.w700, color: gc.textTertiary)),
              const SizedBox(height: 6),
              TextField(
                controller: keyController,
                obscureText: true,
                style: AppTheme.f(13, weight: FontWeight.w500, color: gc.text),
                cursorColor: gc.accent,
                decoration: InputDecoration(
                  hintText: 'sk-...',
                  hintStyle: AppTheme.f(13, color: gc.textTertiary),
                  filled: true,
                  fillColor: gc.bgRaised2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Text('Modelo', style: AppTheme.s(11, weight: FontWeight.w700, color: gc.textTertiary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: modelController,
                      style: AppTheme.f(13, weight: FontWeight.w500, color: gc.text),
                      cursorColor: gc.accent,
                      decoration: InputDecoration(
                        hintText: 'gpt-4o-mini',
                        hintStyle: AppTheme.f(13, color: gc.textTertiary),
                        filled: true,
                        fillColor: gc.bgRaised2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _selectModel(context, modelController),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(12), border: Border.all(color: gc.border)),
                      child: Text('Obtener Modelos', style: AppTheme.f(13, weight: FontWeight.w600, color: gc.text)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('PRESETS RÁPIDOS', style: AppTheme.s(10, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetChip(gc, 'OpenAI', () {
                    urlController.text = 'https://api.openai.com/v1';
                    modelController.text = 'gpt-4o-mini';
                  }),
                  _presetChip(gc, 'NVIDIA NIM', () {
                    urlController.text = 'https://integrate.api.nvidia.com/v1';
                    modelController.text = 'meta/llama-3.1-70b-instruct';
                  }),
                  _presetChip(gc, 'TokenHarbor', () {
                    urlController.text = 'https://api.tokenharbor.com/v1';
                    modelController.text = 'gpt-4o-mini';
                  }),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  showNotchToast(context, 'Probando conexión...', icon: PhosphorIconsRegular.arrowsClockwise);
                  final result = await AiClient.instance.testConnection();
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: gc.bgRaised,
                      title: Text('Probar', style: AppTheme.f(16, weight: FontWeight.w700, color: gc.text)),
                      content: Text(result, style: AppTheme.f(14, color: gc.text)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cerrar', style: AppTheme.f(14, weight: FontWeight.w600, color: gc.ember)),
                        )
                      ],
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(100), border: Border.all(color: gc.border)),
                  alignment: Alignment.center,
                  child: Text('Probar Conexión', style: AppTheme.f(15, weight: FontWeight.w600, color: gc.text)),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Guardar',
                onTap: () {
                  fit.saveAiConfig(
                    baseUrl: urlController.text,
                    apiKey: keyController.text,
                    model: modelController.text,
                  );
                  Navigator.pop(sheetCtx);
                  showNotchToast(context, 'Configuración de IA guardada', icon: PhosphorIconsFill.checkCircle, accent: gc.sage);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetChip(GymColors gc, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: AppTheme.s(11.5, weight: FontWeight.w600, color: gc.accent)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: ScreenHeader(
              title: 'Asistente IA',
              subtitle: _currentSession?.title ?? fit.aiModel,
              onBack: fit.backFromAiPlan,
              titleSize: 22,
              actions: [
                RoundAction(
                  label: 'Nuevo Chat',
                  onTap: _startNewChat,
                  child: Icon(PhosphorIconsRegular.plus, size: 17, color: gc.text),
                ),
                RoundAction(
                  label: 'Historial',
                  onTap: _openHistorySheet,
                  child: Icon(PhosphorIconsRegular.clockCounterClockwise, size: 17, color: gc.text),
                ),
                RoundAction(
                  label: 'Exportar Conversación',
                  onTap: _exportConversation,
                  child: Icon(PhosphorIconsRegular.shareNetwork, size: 17, color: gc.text),
                ),
                RoundAction(
                  label: 'Configurar IA',
                  onTap: _openConfigSheet,
                  child: Icon(PhosphorIconsRegular.gear, size: 17, color: gc.text),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildBubble(gc, _messages[i]),
            ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: gc.ember)),
                  const SizedBox(width: 8),
                  Text('Entrenador pensando...', style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _input.text = _getFormattedRoutines();
                _input.selection = TextSelection.fromPosition(
                  TextPosition(offset: _input.text.length),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: gc.emberSoft,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: gc.ember.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '📋 Adjuntar mis rutinas para analizar',
                  style: AppTheme.f(12, weight: FontWeight.w600, color: gc.ember),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 10),
            decoration: BoxDecoration(
              color: gc.bgRaised,
              border: Border(top: BorderSide(color: gc.border.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: AppTheme.f(13.5, weight: FontWeight.w500, color: gc.text),
                    cursorColor: gc.accent,
                    decoration: InputDecoration(
                      hintText: 'Pide una rutina o consulta de sobrecarga...',
                      hintStyle: AppTheme.f(13, color: gc.textTertiary),
                      filled: true,
                      fillColor: gc.bgRaised2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _loading ? null : _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _loading ? gc.bgRaised2 : gc.ember,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(PhosphorIconsBold.paperPlaneTilt, size: 18, color: _loading ? gc.textTertiary : gc.onEmber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(GymColors gc, _Message msg) {
    final isUser = msg.role == 'user';
    final routineRegex = RegExp(r'<routine>([\s\S]*?)</routine>');
    final matches = routineRegex.allMatches(msg.text).toList();
    final cleanText = matches.isNotEmpty ? msg.text.replaceAll(routineRegex, '').trim() : msg.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: gc.emberSoft, shape: BoxShape.circle),
              child: Icon(PhosphorIconsRegular.sparkle, size: 16, color: gc.ember),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isUser ? gc.emberSoft : gc.bgRaised,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isUser ? gc.ember.withValues(alpha: 0.3) : gc.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    cleanText,
                    style: AppTheme.f(13.5,
                        weight: FontWeight.w500,
                        color: isUser ? gc.text : gc.text,
                        height: 1.45),
                  ),
                  if (matches.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: matches.length > 1
                          ? 'Añadir ${matches.length} Rutinas a mi Plan'
                          : 'Añadir Rutina a mi Plan',
                      iconData: PhosphorIconsRegular.downloadSimple,
                      height: 44,
                      bg: gc.ember,
                      fg: gc.onEmber,
                      onTap: () {
                        final rawBlocks = matches.map((m) => m.group(0)!).join('\n');
                        fit.importPlan(rawBlocks, schedule: true);
                        showNotchToast(
                          context,
                          matches.length > 1
                              ? '${matches.length} rutinas añadidas a tu plan con éxito'
                              : 'Rutina añadida a tu plan con éxito',
                          icon: PhosphorIconsFill.checkCircle,
                          accent: gc.sage,
                        );
                      },
                    ),
                  ] else if (msg.routines.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final r in msg.routines)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(PhosphorIconsRegular.barbell, size: 16, color: gc.ember),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(r.name.isEmpty ? 'Rutina Sugerida' : r.name,
                                    style: AppTheme.f(14, weight: FontWeight.w700, color: gc.text)),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text('${r.items.length} ejercicios planificados',
                                style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary)),
                            const SizedBox(height: 10),
                            PrimaryButton(
                              label: 'Guardar en mi Planificador',
                              bg: gc.ember,
                              fg: gc.onEmber,
                              onTap: () => _applyRoutine([r]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: gc.bgRaised2, shape: BoxShape.circle),
              child: Icon(PhosphorIconsRegular.user, size: 16, color: gc.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
