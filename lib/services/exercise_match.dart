import '../catalog/exercise_aliases.dart';
import '../catalog/exercise_catalog.dart' show kFilterMuscles;
import '../models/exercise.dart';

const _stop = {
  'the', 'a', 'an', 'with', 'on', 'to', 'and', 'or', 'in', 'for', 'v', 'var',
  'con', 'de', 'del', 'la', 'el', 'los', 'las', 'en', 'para', 'por', 'y', 'o',
  'un', 'una', 'unos', 'unas', 'al', 'sin', 'sobre', 'desde', 'hasta', 'peso',
};

const _syn = {
  'lat': 'lateral', 'lats': 'lateral',
  'bicep': 'biceps', 'bicepts': 'biceps',
  'tricep': 'triceps', 'tricepts': 'triceps',
  'db': 'dumbbell', 'bb': 'barbell', 'kb': 'kettlebell', 'bw': 'bodyweight',
  'dumbell': 'dumbbell', 'dumbells': 'dumbbell', 'dumbbells': 'dumbbell',
  'barbells': 'barbell', 'cables': 'cable', 'machines': 'machine', 'bands': 'band',
  'ohp': 'overhead press',
  'pushup': 'push up', 'pushups': 'push up', 'pullup': 'pull up', 'pullups': 'pull up',
  'chinup': 'chin up', 'chinups': 'chin up', 'situp': 'sit up', 'situps': 'sit up',
  'curls': 'curl', 'rows': 'row', 'presses': 'press',
  'ups': 'up', 'downs': 'down', 'climbers': 'climber', 'crushers': 'crusher',
  'squats': 'squat', 'raises': 'raise', 'extensions': 'extension',
  'flyes': 'fly', 'flies': 'fly', 'flys': 'fly',
  'deadlifts': 'deadlift', 'lunges': 'lunge', 'dips': 'dip', 'pulldowns': 'pulldown',
  'calves': 'calf', 'calve': 'calf', 'legs': 'leg', 'arms': 'arm', 'abs': 'abdominal', 'delts': 'deltoid',
  'lever': 'machine', 'smith': 'machine', 'skullcrusher': 'lying triceps extension',
  'skullcrushers': 'lying triceps extension',
  'rdl': 'romanian deadlift', 'sldl': 'stiff leg deadlift',
  // Español
  'remo': 'row', 'remos': 'row',
  'mancuerna': 'dumbbell', 'mancuernas': 'dumbbell',
  'barra': 'barbell', 'barras': 'barbell',
  'sentadilla': 'squat', 'sentadillas': 'squat',
  'muerto': 'deadlift', 'rumano': 'romanian', 'rumana': 'romanian',
  'bulgara': 'bulgarian',
  'banca': 'bench',
  'militar': 'military',
  'elevacion': 'raise', 'elevaciones': 'raise',
  'frontal': 'front',
  'inclinado': 'incline', 'declinado': 'decline', 'sentado': 'seated',
  'extension': 'extension', 'extensiones': 'extension',
  'flexion': 'push up', 'flexiones': 'push up',
  'dominada': 'pull up', 'dominadas': 'pull up',
  'jalon': 'pulldown', 'jalones': 'pulldown',
  'polea': 'cable', 'poleas': 'cable',
  'banda': 'band', 'bandas': 'band',
  'cuerpo': 'bodyweight', 'corporal': 'bodyweight',
  'gemelo': 'calf', 'gemelos': 'calf',
  'talon': 'calf', 'talones': 'calf',
  'gluteo': 'glute', 'gluteos': 'glute',
  'puente': 'bridge',
  'cuadriceps': 'quad',
  'isquiotibial': 'hamstring', 'isquiotibiales': 'hamstring',
  'pierna': 'leg', 'piernas': 'leg',
  'brazo': 'arm', 'brazos': 'arm',
  'hombro': 'shoulder', 'hombros': 'shoulder',
  'lateral': 'lateral', 'laterales': 'lateral',
  'pecho': 'chest',
  'espalda': 'back',
  'biceps': 'biceps',
  'triceps': 'triceps',
  'antebrazo': 'forearm',
  'trapecio': 'trapezius',
  'abdominal': 'abdominal', 'abdominales': 'abdominal',
  'oblicuo': 'oblique', 'oblicuos': 'oblique',
  'lumbar': 'lower back',
  'hiperextension': 'hyperextension',
  'plancha': 'plank',
  'fondos': 'dip',
  'zancada': 'lunge', 'zancadas': 'lunge',
  'prensa': 'press',
  'apertura': 'fly', 'aperturas': 'fly',
  'encogimiento': 'shrug', 'encogimientos': 'shrug',
  'estiramiento': 'stretch', 'estiramientos': 'stretch',
  'movilidad': 'mobility',
  'correr': 'run', 'trotar': 'run', 'jogging': 'run', 'running': 'run',
  'caminar': 'walk', 'walking': 'walk',
  'bici': 'bike', 'bicicleta': 'bike', 'cicling': 'bike', 'cycling': 'bike',
  'cinta': 'treadmill', 'burpees': 'burpee', 'sprints': 'sprint',
  'natacion': 'swim', 'swimming': 'swim',
  'cuerda': 'rope',
  'saltar': 'jump', 'salto': 'jump',
  'boxeo': 'boxing',
  'deporte': 'sport',
  'baloncesto': 'basketball',
  'futbol': 'football',
  'tenis': 'tennis',
  'calistenia': 'calisthenics',
  'rodillo': 'foam roll',
};

const _equipment = {
  'barbell', 'dumbbell', 'cable', 'machine', 'smith', 'kettlebell', 'band',
  'bodyweight', 'lever', 'sled', 'weighted', 'assisted', 'ez',
};

List<String> nameTokens(String raw) {
  final flat = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâãä]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôõö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll('ñ', 'n');
  final out = <String>[];
  for (final part in flat.split(RegExp(r'[^a-z0-9]+'))) {
    if (part.isEmpty || _stop.contains(part)) continue;
    final mapped = _syn[part] ?? part;
    out.addAll(mapped.split(' '));
  }
  return out;
}

String searchKey(String raw) => nameTokens(raw).join(' ');

String sortedKey(String raw) => (nameTokens(raw)..sort()).join(' ');

final Map<String, String> _keyCache = {};

String _keyOf(String name) => _keyCache.putIfAbsent(name, () => searchKey(name));

String _stem(String w) => w.length > 3 && w.endsWith('s') && !w.endsWith('ss') ? w.substring(0, w.length - 1) : w;

final Map<String, List<String>> _wordCache = {};

List<String> _wordsOf(String name) =>
    _wordCache.putIfAbsent(name, () => [for (final w in nameTokens(name)) _stem(w)]);

bool _hasWords(List<String> query, String name) {
  final words = _wordsOf(name);
  return query.every((q) => words.any((w) => w.startsWith(q)));
}

String _fold(String raw) => nameTokens(raw).join(' ');

final Map<String, String> _aliasIndex = {
  for (final entry in kExerciseAliases.entries)
    for (final alias in entry.value) sortedKey(alias): entry.key,
};

typedef ExerciseFilter = bool Function(Exercise);

ExerciseFilter exerciseSearch(String query) {
  final plain = query.trim().toLowerCase();
  if (plain.isEmpty) return (_) => true;
  final key = searchKey(query);
  final words = [for (final w in key.split(' ')) if (w.isNotEmpty) _stem(w)];
  final folded = _fold(query);
  final muscles = {
    for (final m in kFilterMuscles)
      if (folded.length > 2 && (_fold(muscleLabel(m)).startsWith(folded) || _fold(m).startsWith(folded))) m,
  };

  return (e) {
    if (muscles.contains(e.primary)) return true;
    final label = exerciseName(e);
    if (e.name.toLowerCase().contains(plain) || label.toLowerCase().contains(plain)) return true;
    if (e.aliases.any((a) => a.toLowerCase().contains(plain))) return true;
    if (key.isEmpty) return false;
    if (_keyOf(e.name).contains(key) || _keyOf(label).contains(key)) return true;
    if (e.aliases.any((a) => _keyOf(a).contains(key))) return true;
    if (kExerciseAliases[e.name]?.any((a) => _keyOf(a).contains(key)) ?? false) return true;
    if (words.isEmpty) return false;
    return _hasWords(words, e.name) || _hasWords(words, label) || e.aliases.any((a) => _hasWords(words, a));
  };
}

bool _sameEquipment(Set<String> q, Set<String> c) {
  final qe = q.intersection(_equipment);
  final ce = c.intersection(_equipment);
  if (qe.isEmpty || ce.isEmpty) return true;
  return qe.intersection(ce).isNotEmpty;
}

const _modifiers = {
  'one', 'single', 'arm', 'seated', 'sitted', 'standing', 'lying', 'alternate', 'alternating',
  'wide', 'close', 'narrow', 'grip', 'straight', 'bent', 'over', 'both', 'two', 'double', 'hand',
};

bool _fits(Set<String> qCore, Set<String> q, Set<String> c) {
  if (qCore.isNotEmpty && c.containsAll(qCore)) return true;
  final cMeaning = c.difference(_equipment);
  return cMeaning.length >= 2 && cMeaning.difference(_modifiers).isNotEmpty && q.containsAll(cMeaning);
}

const _legs = {'quads', 'glutes', 'hamstrings', 'calves'};

bool _sameMuscle(String? hint, Exercise e) =>
    hint == null ||
    e.primary == hint ||
    e.secondary.contains(hint) ||
    (_legs.contains(hint) && _legs.contains(e.primary)) ||
    (hint == 'lowerback' && (e.primary == 'hamstrings' || e.primary == 'glutes'));

int _score(Set<String> q, Set<String> c) {
  final shared = q.intersection(c);
  if (shared.difference(_equipment).isEmpty) return 0;
  return shared.length * 3 - c.difference(q).length - q.difference(c).length;
}

const _muscleHints = <List<String>, String>{
  ['hyperextension', 'back extension', 'superman', 'lower back', 'erector', 'deadlift']: 'lowerback',
  ['calf', 'calves', 'soleus']: 'calves',
  ['hamstring', 'leg curl', 'good morning', 'nordic']: 'hamstrings',
  ['glute', 'hip thrust', 'bridge', 'kickback']: 'glutes',
  ['quad', 'squat', 'leg press', 'leg extension', 'lunge', 'step up', 'hack']: 'quads',
  ['oblique', 'twist', 'side bend', 'wood chop', 'russian']: 'obliques',
  ['crunch', 'sit up', 'plank', 'abdominal', 'leg raise', 'hollow', 'v up']: 'abdomen',
  ['shrug', 'trap ', 'trapezius', 'upright row']: 'trapezius',
  ['forearm', 'wrist', 'farmer', 'gripper', 'hand grip']: 'forearm',
  ['triceps', 'pushdown', 'skullcrusher', 'kickback', 'dip']: 'triceps',
  ['biceps', 'curl', 'preacher', 'chin up']: 'biceps',
  ['lateral raise', 'shoulder', 'overhead press', 'military', 'arnold', 'face pull', 'delt', 'upright']:
      'shoulders',
  ['back', 'row', 'pulldown', 'pull up', 'pullover', 'lateral pull']: 'back',
  ['bench press', 'chest', 'fly', 'pec', 'push up', 'press']: 'chest',
};

String? guessMuscle(String name) {
  final tokens = nameTokens(name).toSet();
  for (final entry in _muscleHints.entries) {
    for (final needle in entry.key) {
      final parts = nameTokens(needle);
      if (parts.isNotEmpty && parts.every(tokens.contains)) return entry.value;
    }
  }
  return null;
}

String guessKind(String name) {
  final tokens = nameTokens(name).toSet();
  bool has(String phrase) => nameTokens(phrase).every(tokens.contains);
  if (has('cardio') || has('run') || has('walk') || has('bike') || has('treadmill') ||
      has('jump rope') || has('burpee') || has('sprint') || has('swim')) {
    return 'cardio';
  }
  if (has('stretch') || has('mobility') || has('yoga') || has('foam roll')) return 'stretch';
  if (has('push up') || has('pull up') || has('chin up') || has('dip') ||
      has('plank') || has('bodyweight') || has('calisthenics') || has('pistol') || has('hollow')) {
    return 'calisthenics';
  }
  if (has('sport') || has('boxing') || has('kickboxing') || has('basketball') ||
      has('football') || has('tennis')) {
    return 'sport';
  }
  return 'strength';
}

// shortcut: traducción solo para ejercicios comunes; la IA debe aportar aliases para el resto.
const _englishAliases = {
  'Remo con mancuerna': 'Dumbbell Row',
  'Remo con mancuerna a una mano': 'One-Arm Dumbbell Row',
  'Remo con barra': 'Barbell Row',
  'Press de banca': 'Bench Press',
  'Press de banca con barra': 'Barbell Bench Press',
  'Press de banca con mancuernas': 'Dumbbell Bench Press',
  'Press militar': 'Military Press',
  'Sentadilla': 'Squat',
  'Sentadilla con barra': 'Barbell Squat',
  'Sentadilla bulgara': 'Bulgarian Split Squat',
  'Sentadilla goblet': 'Goblet Squat',
  'Peso muerto': 'Deadlift',
  'Peso muerto rumano': 'Romanian Deadlift',
  'Curl de biceps': 'Biceps Curl',
  'Extension de triceps': 'Triceps Extension',
  'Elevacion lateral': 'Lateral Raise',
  'Elevacion frontal': 'Front Raise',
  'Circulos de brazos': 'Arm Circles',
  'Dominada': 'Pull Up',
  'Flexion': 'Push Up',
  'Plancha': 'Plank',
  'Jalon al pecho': 'Lat Pulldown',
  'Zancada': 'Lunge',
  'Puente de gluteo': 'Glute Bridge',
  'Prensa de piernas': 'Leg Press',
  'Apertura con mancuernas': 'Dumbbell Fly',
  'Encogimiento de hombros': 'Shrug',
  'Fondos': 'Dip',
};

final Map<String, String> _englishAliasIndex = {
  for (final entry in _englishAliases.entries) sortedKey(entry.key): entry.value,
};

String? guessEnglishAlias(String name) {
  final direct = _englishAliasIndex[sortedKey(name)];
  if (direct != null) return direct;
  final core = (nameTokens(name).where((t) => !_equipment.contains(t)).toList()..sort()).join(' ');
  return _englishAliasIndex[core];
}

final Map<String, String> _spanishNameIndex = {
  for (final entry in _englishAliases.entries) sortedKey(entry.value): entry.key,
};

String? guessSpanishName(String name) {
  final direct = _spanishNameIndex[sortedKey(name)];
  if (direct != null) return direct;
  final core = (nameTokens(name).where((t) => !_equipment.contains(t)).toList()..sort()).join(' ');
  return _spanishNameIndex[core];
}

Exercise? matchExercise(String name, Iterable<Exercise> pool) {
  final key = searchKey(name);
  if (key.isEmpty) return null;

  for (final e in pool) {
    if (_keyOf(e.name) == key) return e;
  }

  for (final e in pool) {
    if (e.aliases.any((a) => _keyOf(a) == key)) return e;
  }

  final alias = _aliasIndex[sortedKey(name)];
  if (alias != null) {
    final wanted = searchKey(alias);
    for (final e in pool) {
      if (searchKey(e.name) == wanted) return e;
    }
  }

  for (final e in pool) {
    final label = exerciseName(e);
    if (label != e.name && _keyOf(label) == key) return e;
  }

  final q = key.split(' ').toSet();
  final qMeaning = q.difference(_equipment);
  if (qMeaning.isEmpty) return null;
  final qCore = qMeaning.difference(_modifiers);
  final hint = guessMuscle(name);

  Exercise? exact;
  var exactExtra = 1 << 30;
  Exercise? loose;
  var looseScore = 0;

  for (final e in pool) {
    final c = nameTokens(e.name).toSet();
    if (c.isEmpty || !_sameEquipment(q, c) || !_sameMuscle(hint, e)) continue;
    if (c.containsAll(qMeaning)) {
      final extra = c.difference(q).length;
      if (extra < exactExtra) {
        exact = e;
        exactExtra = extra;
      }
    } else if (_fits(qCore, q, c)) {
      final s = _score(q, c);
      if (s > looseScore) {
        loose = e;
        looseScore = s;
      }
    }
  }
  return exact ?? (looseScore >= 3 ? loose : null);
}
