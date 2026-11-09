import 'dart:convert';

class PlanSet {
  const PlanSet({this.reps, this.weightKg, this.kind = 0, this.sec, this.km});
  final int? reps;
  final double? weightKg;
  final int kind;
  final int? sec;
  final double? km;
}

class PlanItem {
  const PlanItem(
    this.name,
    this.sets, {
    this.id,
    this.reps,
    this.weightKg,
    this.restSec,
    this.superset = false,
    this.plan = const [],
    this.muscle,
    this.equipment,
    this.level,
    this.category,
    this.steps = const [],
    this.mode = '',
    this.secondary = const [],
    this.aliases = const [],
    this.ladder = const [],
  });
  final String name;
  final int? sets;
  final String? id;
  final int? reps;
  final double? weightKg;
  final int? restSec;
  final bool superset;
  final List<PlanSet> plan;
  final String? muscle;
  final List<String> secondary;
  final String? equipment;
  final String? level;
  final String? category;
  final List<String> steps;
  final String mode;
  final List<String> aliases;
  final List<String> ladder;
}

class PlanRoutine {
  const PlanRoutine(this.name, this.items, {this.group = '', this.days = const []});
  final String name;
  final List<PlanItem> items;
  final String group;
  final List<int> days;
}

const _nameKeys = ['name', 'routine', 'title', 'nombre', 'rutina', 'workout', 'day', 'dia'];
const _listKeys = ['exercises', 'items', 'ejercicios', 'movements', 'exercicios', 'esercizi', 'ubungen'];
const _routineListKeys = ['routines', 'rutinas', 'plan', 'days', 'workouts', 'sessions', 'dias'];
const _groupKeys = ['group', 'grupo', 'folder', 'program', 'programme', 'programa', 'split'];
const _weekKeys = ['weeks', 'semanas', 'mesocycle', 'blocks'];
const _dayKeys = ['days', 'dias', 'weekdays', 'schedule', 'on'];
const _setKeys = ['sets', 'series', 'setcount'];
const _repKeys = ['reps', 'repetitions', 'repeticiones', 'rep', 'repeticoes', 'ripetizioni'];
const _weightKeys = ['weight', 'weightkg', 'load', 'kg', 'peso', 'carga', 'lbs', 'lb'];
const _restKeys = ['rest', 'restseconds', 'restsec', 'descanso', 'pause', 'riposo'];
const _timeKeys = ['time', 'duration', 'seconds', 'sec', 'secs', 'tiempo', 'durationseconds'];
const _distanceKeys = ['distance', 'km', 'distancekm', 'distancia'];
const _itemNameKeys = ['name', 'exercise', 'ejercicio', 'movement', 'exercisename', 'title', 'nombre'];

const _weekdayNames = {
  1: ['monday', 'mon', 'lunes', 'lun', 'segunda', 'lunedi', 'montag', 'mo'],
  2: ['tuesday', 'tue', 'tues', 'martes', 'mar', 'terca', 'martedi', 'dienstag', 'di'],
  3: ['wednesday', 'wed', 'miercoles', 'mie', 'quarta', 'mercoledi', 'mittwoch', 'mi'],
  4: ['thursday', 'thu', 'thur', 'thurs', 'jueves', 'jue', 'quinta', 'giovedi', 'donnerstag', 'do'],
  5: ['friday', 'fri', 'viernes', 'vie', 'sexta', 'venerdi', 'freitag', 'fr'],
  6: ['saturday', 'sat', 'sabado', 'sab', 'sabato', 'samstag', 'sa'],
  7: ['sunday', 'sun', 'domingo', 'dom', 'domenica', 'sonntag', 'so'],
};

List<PlanRoutine> parsePlan(String raw) {
  final routineMatches = RegExp(r'<routine>([\s\S]*?)</routine>').allMatches(raw).toList();
  if (routineMatches.isNotEmpty) {
    final list = <PlanRoutine>[];
    for (final m in routineMatches) {
      final inner = m.group(1)?.trim();
      if (inner != null && inner.isNotEmpty) {
        list.addAll(parsePlan(inner));
      }
    }
    if (list.isNotEmpty) return list;
  }

  final data = _decode(raw);
  if (data == null) {
    final csv = _parseCsv(raw);
    return csv.isNotEmpty ? csv : _parseFlatList(raw);
  }
  final lb = data is Map<Object?, Object?> && _isLb(_value(data, ['unit', 'units', 'unidad']));
  final out = <PlanRoutine>[];

  void addRoutine(Map<Object?, Object?> map, String group) {
    final items = _items(_value(map, _listKeys), lb);
    if (items.isEmpty) return;
    final own = _string(_value(map, _groupKeys));
    out.add(PlanRoutine(
      _string(_value(map, _nameKeys)),
      items,
      group: own.isNotEmpty ? own : group,
      days: _days(_value(map, _dayKeys)),
    ));
  }

  void addRoutines(List<Object?> list, String group) {
    if (list.isNotEmpty && list.every((e) => e is String)) {
      final items = _items(list, lb);
      if (items.isNotEmpty) out.add(PlanRoutine('', items, group: group));
      return;
    }
    for (final r in list) {
      if (r is Map<Object?, Object?>) addRoutine(r, group);
    }
  }

  if (data is Map<Object?, Object?>) {
    final program = _string(_value(data, _groupKeys));
    final weeks = _value(data, _weekKeys);
    final nested = _routineList(data);
    if (weeks is List) {
      var n = 0;
      for (final w in weeks) {
        n++;
        if (w is! Map<Object?, Object?>) continue;
        final label = _string(_value(w, _nameKeys + ['week', 'semana']));
        final week = label.isNotEmpty ? label : 'Week $n';
        final group = program.isEmpty ? week : '$program · $week';
        final inner = _routineList(w);
        if (inner != null) addRoutines(inner, group);
      }
    } else if (nested != null) {
      final name = _string(_value(data, _nameKeys));
      addRoutines(nested, program.isNotEmpty ? program : (_listOfRoutines(nested) ? name : ''));
    } else {
      // Desenvuelve {"routine": {"name": ..., "exercises": [...]}} y equivalentes.
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is Map<Object?, Object?> && _value(v, _listKeys) is List) {
          addRoutine(v, program);
          if (out.isNotEmpty) return out;
        } else if (v is List &&
            const {'routine', 'workout', 'session', 'data', 'result'}.contains(_norm(entry.key))) {
          addRoutines(v, program);
          if (out.isNotEmpty) return out;
        }
      }
      addRoutine(data, '');
    }
  } else if (data is List) {
    addRoutines(data, '');
  }
  return out;
}

List<PlanRoutine> _parseFlatList(String raw) {
  final texts = <String>[];
  var name = '';
  for (final line in raw.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty)) {
    final bullet = RegExp(r'^(?:[-*•]|\d+[.)])\s+(.+)$').firstMatch(line);
    if (bullet != null) {
      final text = bullet.group(1)!.replaceAll(RegExp(r'[*`]'), '').trim();
      if (text.isNotEmpty) texts.add(text);
    } else if (name.isEmpty &&
        RegExp(r'^(rutina|d[ií]a|day|workout|sesi[oó]n)', caseSensitive: false).hasMatch(line)) {
      name = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
    }
  }
  if (texts.isEmpty) {
    final segments = raw
        .split(RegExp(r'[\n,;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && _looksLikeExercise(s))
        .toList();
    if (segments.length >= 2) texts.addAll(segments);
  }
  final items = _items(texts, false);
  return items.isEmpty ? const [] : [PlanRoutine(name, items)];
}

bool _looksLikeExercise(String s) {
  final t = _fold(s);
  if (t.length < 3 || t.length > 60) return false;
  const keys = [
    'remo', 'sentadilla', 'press', 'curl', 'squat', 'row', 'bench', 'deadlift',
    'mancuerna', 'plank', 'plancha', 'dominada', 'flexion', 'flexiones', 'zancada',
    'prensa', 'elevacion', 'elevaciones', 'jalon', 'jalones', 'fondos', 'puente',
    'thrust', 'calf', 'gemelo', 'biceps', 'triceps', 'hombro', 'pecho', 'espalda',
    'abdomen', 'abdominales', 'cardio', 'correr', 'caminar', 'bici', 'natacion',
    'boxeo', 'lunge', 'dip', 'pull', 'push', 'leg', 'hip',
  ];
  return keys.any(t.contains);
}

String _fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[àáâãä]'), 'a')
    .replaceAll(RegExp(r'[èéêë]'), 'e')
    .replaceAll(RegExp(r'[ìíîï]'), 'i')
    .replaceAll(RegExp(r'[òóôõö]'), 'o')
    .replaceAll(RegExp(r'[ùúûü]'), 'u')
    .replaceAll('ñ', 'n');

bool _listOfRoutines(List<Object?> list) =>
    list.isNotEmpty && list.every((e) => e is Map<Object?, Object?> && _value(e, _listKeys) is List);

List<Object?>? _routineList(Map<Object?, Object?> map) {
  for (final entry in map.entries) {
    final k = _norm(entry.key);
    final v = entry.value;
    if (!_routineListKeys.contains(k) || v is! List) continue;
    if (_dayKeys.contains(k) && !v.any((e) => e is Map)) continue;
    return v;
  }
  return null;
}

Object? _decode(String raw) {
  for (final text in _candidates(raw)) {
    for (final candidate in [text, _withoutTrailingCommas(text)]) {
      try {
        final data = jsonDecode(candidate);
        if (data is Map || data is List) return data;
      } catch (_) {
        continue;
      }
    }
  }
  return null;
}

String _withoutTrailingCommas(String text) => text.replaceAll(RegExp(r',\s*([}\]])'), r'$1');

List<String> _candidates(String raw) {
  final text = raw.trim();
  final out = [text];
  final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fenced != null) out.add(fenced.group(1)!.trim());
  for (final pair in [('{', '}'), ('[', ']')]) {
    final start = text.indexOf(pair.$1);
    final end = text.lastIndexOf(pair.$2);
    if (start >= 0 && end > start) out.add(text.substring(start, end + 1));
  }
  return out;
}

String _norm(Object? key) => key.toString().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

Object? _value(Map<Object?, Object?> map, List<String> keys) {
  for (final key in keys) {
    for (final entry in map.entries) {
      if (_norm(entry.key) == key) return entry.value;
    }
  }
  return null;
}

String _string(Object? v) => v is String ? v.trim() : (v is num ? '$v' : '');

bool _isLb(Object? v) => v is String && RegExp(r'^\s*(lb|lbs|pounds?)\s*$', caseSensitive: false).hasMatch(v);

int? _int(Object? v) {
  if (v is num) return v.round();
  if (v is String) {
    final m = RegExp(r'\d+').firstMatch(v);
    return m == null ? null : int.parse(m.group(0)!);
  }
  return null;
}

int? _reps(Object? v) {
  if (v is num) return v.round();
  if (v is String) {
    final range = RegExp(r'(\d+)\s*(?:-|–|to|a)\s*(\d+)').firstMatch(v);
    if (range != null) {
      final low = int.parse(range.group(1)!);
      final high = int.parse(range.group(2)!);
      return ((low + high) / 2).round();
    }
    final m = RegExp(r'\d+').firstMatch(v);
    return m == null ? null : int.parse(m.group(0)!);
  }
  return null;
}

double? _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) {
    final m = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(v);
    return m == null ? null : double.tryParse(m.group(0)!.replaceAll(',', '.'));
  }
  return null;
}

double? _weight(Object? v, bool lb) {
  final n = _double(v);
  if (n == null) return null;
  final inLb = lb || (v is String && RegExp(r'lb', caseSensitive: false).hasMatch(v));
  return inLb ? n / 2.20462 : n;
}

int? _seconds(Object? v) {
  if (v is num) return v.round();
  if (v is! String) return null;
  final s = v.trim().toLowerCase();
  final clock = RegExp(r'^(\d+):(\d{1,2})(?::(\d{1,2}))?$').firstMatch(s);
  if (clock != null) {
    final a = int.parse(clock.group(1)!), b = int.parse(clock.group(2)!);
    final c = clock.group(3);
    return c == null ? a * 60 + b : a * 3600 + b * 60 + int.parse(c);
  }
  final n = _double(s);
  if (n == null) return null;
  if (s.contains('h')) return (n * 3600).round();
  if (s.contains('min') || RegExp(r'\d\s*m\b').hasMatch(s)) return (n * 60).round();
  return n.round();
}

int _kind(Object? v) {
  final s = _norm(v);
  if (s.startsWith('warm') || s.startsWith('calent') || s == 'w') return 1;
  if (s.startsWith('drop')) return 2;
  if (s.startsWith('fail') || s.startsWith('fallo') || s == 'amrap') return 3;
  if (s.startsWith('restpause') || s == 'rp') return 4;
  if (s.startsWith('cluster') || s == 'c') return 5;
  return 0;
}

List<int> _days(Object? v) {
  final list = v is List
      ? v
      : (v is num
          ? [v]
          : (v is String ? v.split(RegExp(r'[,/;\s]+')) : const []));
  final out = <int>{};
  for (final d in list) {
    if (d is num && d >= 1 && d <= 7) out.add(d.toInt());
    if (d is String) {
      final k = d
          .toLowerCase()
          .replaceAll(RegExp(r'[áàâä]'), 'a')
          .replaceAll(RegExp(r'[éèêë]'), 'e')
          .replaceAll(RegExp(r'[íìîï]'), 'i')
          .replaceAll(RegExp(r'[óòôö]'), 'o')
          .replaceAll(RegExp(r'[úùûü]'), 'u')
          .replaceAll('ç', 'c')
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final n = int.tryParse(k);
      if (n != null && n >= 1 && n <= 7) {
        out.add(n);
        continue;
      }
      for (final e in _weekdayNames.entries) {
        if (e.value.contains(k) || (k.length > 3 && e.value.first.startsWith(k))) out.add(e.key);
      }
    }
  }
  return out.toList()..sort();
}

List<PlanSet> _planSets(Object? raw, bool lb) {
  if (raw is! List) return const [];
  final out = <PlanSet>[];
  for (final s in raw) {
    if (s is! Map<Object?, Object?>) continue;
    out.add(PlanSet(
      reps: _reps(_value(s, _repKeys)),
      weightKg: _weight(_value(s, _weightKeys), lb || _value(s, ['lbs', 'lb']) != null),
      kind: _kind(_value(s, ['type', 'kind', 'tipo', 'settype'])),
      sec: _seconds(_value(s, _timeKeys)),
      km: _double(_value(s, _distanceKeys)),
    ));
  }
  return out;
}

({String name, List<String> aliases}) _splitAliases(String raw) {
  final s = raw.trim();
  final m = RegExp(r'^(.*?)\s*[\(\[\{]([^)\]\}]+)[\)\]\}]\s*$').firstMatch(s);
  if (m == null) return (name: s, aliases: const <String>[]);
  final main = m.group(1)!.trim();
  final alias = m.group(2)!.trim();
  if (main.isEmpty || alias.isEmpty) return (name: s, aliases: const <String>[]);
  return (
    name: main,
    aliases: [
      for (final a in alias.split(RegExp(r'[,/;]')))
        if (a.trim().isNotEmpty) a.trim(),
    ],
  );
}

List<PlanItem> _items(Object? raw, bool lb) {
  // Un único objeto de ejercicio {"name":..., "sets":...} no es un mapa nombre→detalle.
  if (raw is Map<Object?, Object?> &&
      raw.entries.any((e) =>
          _itemNameKeys.contains(_norm(e.key)) ||
          _setKeys.contains(_norm(e.key)) ||
          _repKeys.contains(_norm(e.key)))) {
    raw = [raw];
  }
  final list = raw is List
      ? raw
      : raw is Map<Object?, Object?>
          ? [
              for (final e in raw.entries)
                if (e.value is Map<Object?, Object?>)
                  <Object?, Object?>{'name': e.key.toString(), ...(e.value as Map<Object?, Object?>)}
                else
                  <Object?, Object?>{'name': e.key.toString(), 'sets': e.value},
            ]
          : null;
  if (list == null) return const [];
  final out = <PlanItem>[];
  for (final entry in list) {
    if (entry is String) {
      final s = entry.trim();
      if (s.isEmpty) continue;
      final pattern = RegExp(r'[\(\[\s,-]+(\d+)\s*[xX×]\s*(\d+)(?:\s*[-–to|a]\s*(\d+))?[\)\]\s]*$');
      final match = pattern.firstMatch(s);
      if (match != null) {
        final cleanName = s.substring(0, match.start).replaceAll(RegExp(r'[\(\[\s,-]+$'), '').trim();
        final sets = int.tryParse(match.group(1)!);
        int? reps = int.tryParse(match.group(2)!);
        if (match.group(3) != null) {
          final high = int.tryParse(match.group(3)!);
          if (high != null && reps != null) {
            reps = ((reps + high) / 2).round();
          }
        }
        final plan = [
          for (var i = 0; i < (sets ?? 3); i++)
            PlanSet(reps: reps),
        ];
        final parsed = _splitAliases(cleanName.isNotEmpty ? cleanName : s);
        out.add(PlanItem(parsed.name, sets, reps: reps, plan: plan, aliases: parsed.aliases));
        continue;
      }
      final parsed = _splitAliases(s);
      out.add(PlanItem(parsed.name, null, aliases: parsed.aliases));
      continue;
    }
    if (entry is! Map<Object?, Object?>) continue;
    final rawName = _string(_value(entry, _itemNameKeys));
    final id = _string(_value(entry, ['id', 'exerciseid']));
    if (rawName.isEmpty && id.isEmpty) continue;
    final split = _splitAliases(rawName);
    final name = split.name;
    final itemLb = lb || _isLb(_value(entry, ['unit', 'units'])) || _value(entry, ['lbs', 'lb']) != null;
    final custom = _value(entry, ['custom', 'own', 'details', 'metadata', 'meta', 'attributes']);
    final info = custom is Map<Object?, Object?> ? custom : const <Object?, Object?>{};
    final meta = <Object?, Object?>{...entry, ...info};
    final stepsRaw = _value(meta, ['steps', 'howto', 'pasos', 'instructions']);
    final steps = switch (stepsRaw) {
      final List list => list.whereType<String>().toList(),
      final String s when s.trim().isNotEmpty => [s.trim()],
      _ => const <String>[],
    };
    final secondary = switch (_value(meta, ['secondary', 'secondarymuscles'])) {
      final List list => list.whereType<String>().toList(),
      final String s when s.trim().isNotEmpty => [
          for (final a in s.split(RegExp(r'[,/;]')))
            if (a.trim().isNotEmpty) a.trim(),
        ],
      _ => const <String>[],
    };
    final parsedAliases = switch (_value(meta, ['aliases', 'alias', 'alsoknownas', 'aka', 'altnames', 'nombresalternativos', 'tambinsellama'])) {
      final List list => list.whereType<String>().toList(),
      final String s when s.trim().isNotEmpty => [
          for (final a in s.split(RegExp(r'[,/;]')))
            if (a.trim().isNotEmpty) a.trim(),
        ],
      _ => const <String>[],
    };
    final superset = _value(entry, ['superset', 'supersetwithnext', 'linked', 'chain']);
    final sets = _int(_value(entry, _setKeys));
    final reps = _reps(_value(entry, _repKeys));
    final kindRaw = _value(entry, ['kind', 'type', 'settype', 'tipo']);
    final itemKind = kindRaw != null ? _kind(kindRaw) : 0;
    final warmupRaw = _value(entry, ['warmup', 'warmupsets', 'calentamiento']);
    final warmupCount = _int(warmupRaw) ?? (warmupRaw == true ? 1 : 0);
    var plan = _planSets(_value(entry, ['plan', 'setplan', 'setsplan', 'detail']), itemLb);
    if (plan.isEmpty && sets != null && sets > 0) {
      plan = [
        for (var i = 0; i < warmupCount; i++)
          PlanSet(reps: (reps != null && reps > 0) ? (reps + 2) : 12, kind: 1),
        for (var i = 0; i < sets; i++)
          PlanSet(reps: reps, kind: itemKind),
      ];
    }
    out.add(PlanItem(
      name.isEmpty ? id : name,
      sets,
      id: id.isEmpty ? null : id,
      reps: reps,
      weightKg: _weight(_value(entry, _weightKeys), itemLb),
      restSec: _seconds(_value(entry, _restKeys)),
      superset: superset == true || (superset is String && superset.toLowerCase() == 'true'),
      plan: plan,
      muscle: _string(_value(meta, ['muscle', 'primary', 'targetmuscle', 'musculo'])),
      equipment: _string(_value(meta, ['equipment', 'material', 'gear'])),
      level: _string(_value(meta, ['level', 'difficulty', 'nivel'])),
      category: _string(_value(meta, ['category', 'categoria'])),
      steps: steps,
      mode: _string(_value(meta, ['track', 'mode'])),
      secondary: secondary,
      aliases: [...split.aliases, ...parsedAliases],
      ladder: switch (_value(entry, ['progression', 'ladder', 'progresion', 'progressao', 'progressione'])) {
        final List list => [for (final s in list.whereType<String>()) if (s.trim().isNotEmpty) s.trim()],
        _ => const [],
      },
    ));
  }
  return _mergeRepeats(out);
}

List<PlanSet> _expanded(PlanItem item) {
  if (item.plan.isNotEmpty) {
    final working = item.plan.where((p) => p.kind != 1).length;
    return [
      for (final p in item.plan) PlanSet(reps: p.reps ?? item.reps, weightKg: p.weightKg ?? item.weightKg, kind: p.kind, sec: p.sec, km: p.km),
      for (var i = working; i < (item.sets ?? working); i++) PlanSet(reps: item.reps, weightKg: item.weightKg),
    ];
  }
  return [for (var i = 0; i < (item.sets ?? 1); i++) PlanSet(reps: item.reps, weightKg: item.weightKg)];
}

List<PlanItem> _mergeRepeats(List<PlanItem> items) {
  String key(PlanItem i) => (i.id ?? i.name).trim().toLowerCase();
  final seen = <String, int>{};
  final out = <PlanItem>[];
  for (final item in items) {
    final at = seen[key(item)];
    if (at == null) {
      seen[key(item)] = out.length;
      out.add(item);
      continue;
    }
    final first = out[at];
    final plan = [..._expanded(first), ..._expanded(item)];
    out[at] = PlanItem(
      first.name,
      plan.where((p) => p.kind != 1).length,
      id: first.id,
      reps: first.reps ?? item.reps,
      weightKg: first.weightKg ?? item.weightKg,
      restSec: first.restSec ?? item.restSec,
      superset: first.superset || item.superset,
      plan: plan,
      muscle: first.muscle ?? item.muscle,
      equipment: first.equipment ?? item.equipment,
      level: first.level ?? item.level,
      category: first.category ?? item.category,
      steps: first.steps.isNotEmpty ? first.steps : item.steps,
      mode: first.mode.isNotEmpty ? first.mode : item.mode,
      secondary: first.secondary.isNotEmpty ? first.secondary : item.secondary,
      aliases: [...first.aliases, ...item.aliases],
      ladder: first.ladder.isNotEmpty ? first.ladder : item.ladder,
    );
  }
  return out;
}

List<List<String>> _rows(String raw) {
  final lines = raw.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) return const [];
  final first = lines.first;
  final sep = [';', '\t', ','].reduce((a, b) => first.split(a).length >= first.split(b).length ? a : b);
  List<String> split(String line) {
    final cells = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        quoted = !quoted;
      } else if (c == sep && !quoted) {
        cells.add(cell.toString().trim());
        cell.clear();
      } else {
        cell.write(c);
      }
    }
    cells.add(cell.toString().trim());
    return cells;
  }

  return lines.map(split).where((r) => r.length >= 2).toList();
}

List<PlanRoutine> _parseCsv(String raw) {
  final rows = _rows(raw);
  if (rows.isEmpty) return const [];
  final head = rows.first.map(_norm).toList();
  int col(List<String> keys) => head.indexWhere(keys.contains);
  var exercise = col(['exercise', 'ejercicio', 'exercisename', 'movement', 'name']);
  var routine = col(['routine', 'rutina', 'workout', 'day', 'dia', 'session']);
  var sets = col(_setKeys);
  var reps = col(_repKeys);
  var weight = col(_weightKeys);
  final group = col(['week', 'semana', 'group', 'grupo', 'program']);
  final rest = col(_restKeys);
  final days = col(['weekday', 'weekdays', 'schedule']);
  final lb = head.any((h) => h == 'lbs' || h == 'lb' || h == 'weightlbs');
  var body = rows.skip(1).toList();
  if (exercise < 0) {
    final probe = rows.first;
    if (probe.length < 3 || _int(probe[1]) != null || _int(probe[2]) == null) return const [];
    body = rows;
    routine = 0;
    exercise = 1;
    sets = 2;
    reps = 3;
    weight = 4;
  }
  String cell(List<String> r, int i) => i >= 0 && i < r.length ? r[i] : '';

  final order = <String>[];
  final grouped = <String, List<PlanItem>>{};
  final groups = <String, String>{};
  final schedule = <String, List<int>>{};
  for (final r in body) {
    final name = cell(r, exercise);
    if (name.isEmpty || _int(name) != null) continue;
    final g = cell(r, group);
    final key = '$g|${cell(r, routine)}';
    if (!grouped.containsKey(key)) {
      order.add(key);
      grouped[key] = [];
      groups[key] = g;
      schedule[key] = _days(cell(r, days));
    }
    grouped[key]!.add(PlanItem(
      name,
      _int(cell(r, sets)),
      reps: _int(cell(r, reps)),
      weightKg: _weight(cell(r, weight), lb),
      restSec: _seconds(cell(r, rest)),
    ));
  }
  return [
    for (final key in order)
      PlanRoutine(key.split('|').last, grouped[key]!, group: groups[key]!, days: schedule[key]!),
  ];
}

String encodePlan(Map<String, Object?> plan) => const JsonEncoder.withIndent('  ').convert(plan);
