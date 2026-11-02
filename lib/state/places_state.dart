part of 'fit_state.dart';

const List<String> kPlacePresets = ['gym', 'home', 'outdoors'];

const Map<String, String> kHomeEquipment = {
  'Dumbbell': 'Mancuernas fijas',
  'Bench': 'Banco multiposición',
  'Band': 'Bandas de resistencia',
  'Weighted': 'Mochila con peso',
};

const Map<String, List<String>> kPlacePresetGear = {
  'gym': kEquipment,
  'home': ['Bodyweight', 'Dumbbell', 'Bench', 'Band', 'Weighted', 'Kettlebell'],
  'outdoors': ['Bodyweight', 'Band'],
};

mixin PlacesState on FitCore, LibraryState {
  String activePlaceId = '';
  int _placeSeq = 0;

  GymPlace? get activePlace {
    for (final p in places) {
      if (p.id == activePlaceId) return p;
    }
    return null;
  }

  Set<String> get gearHere {
    final place = activePlace;
    if (place == null) return {...kEquipment, 'Bench'};
    final gear = {...place.equipment, 'Bodyweight'};
    if (gear.contains('Barbell') || gear.contains('Machine')) {
      gear.add('Bench');
    }
    return gear;
  }

  static bool _requiresBench(Exercise ex) {
    final lower = ex.name.toLowerCase();
    return (lower.contains('bench') && !lower.contains('bodyweight')) ||
        lower.contains('incline dumbbell') ||
        lower.contains('decline dumbbell');
  }

  @override
  bool fitsHere(Exercise ex) {
    if (activePlace == null || isCustom(ex.id)) return true;
    if (!gearHere.contains(ex.equipment)) return false;
    if (_requiresBench(ex) && !gearHere.contains('Bench')) return false;
    return true;
  }

  String volumeRecommendation(int days) {
    switch (days) {
      case 2:
        return 'Objetivo: 14–16 series efectivas semanales por grupo muscular (Frecuencia 2).\n'
            '• Esquema: 2 días Full Body (ej. Martes y Viernes o Lunes y Jueves).\n'
            '• Volumen por sesión: ~7–8 series efectivas por grupo muscular en cada día de entreno.';
      case 4:
        return 'Objetivo: 14–16 series efectivas semanales por grupo muscular (Frecuencia 2).\n'
            '• Esquema: 4 días Torso / Pierna (Upper / Lower x2).\n'
            '• Volumen por sesión: 7–8 series efectivas por grupo muscular en cada uno de sus 2 días de estímulo semanal.';
      case 3:
      default:
        return 'Objetivo: 14–16 series efectivas semanales por grupo muscular (Frecuencia 2).\n'
            '• Esquema: 3 días Full Body alternado o Torso / Pierna / Full Body.\n'
            '• Volumen por sesión: ~5 series efectivas por músculo por sesión (en Full Body) o 7–8 series por músculo en esquema híbrido Frecuencia 2.';
    }
  }

  String get activePlaceVolumeRecommendation {
    final days = activePlace?.targetDaysPerWeek ?? 3;
    return volumeRecommendation(days);
  }

  void setPlaceTargetDays(String placeId, int days) {
    final i = places.indexWhere((p) => p.id == placeId);
    if (i < 0) return;
    final clamped = days.clamp(2, 4);
    places[i] = places[i].copyWith(targetDaysPerWeek: clamped);
    _persist();
    notifyListeners();
  }

  int placeExerciseCount(GymPlace place) {
    final gear = {...place.equipment, 'Bodyweight'};
    return allExercises.where((e) => gear.contains(e.equipment)).length;
  }

  List<Exercise> alternativesHere(Exercise ex, int n) {
    if (fitsHere(ex)) return const [];
    final pool = allExercises
        .where((e) => e.id != ex.id && e.primary == ex.primary && fitsHere(e))
        .toList();
    pool.sort((a, b) {
      int rank(Exercise e) {
        if (favorites[e.id] == true) return 0;
        return e.equipment == 'Bodyweight' ? 1 : 2;
      }

      return rank(a).compareTo(rank(b));
    });
    return pool.take(n).toList();
  }

  String addPlace(String name, {Set<String> equipment = const {'Bodyweight'}}) {
    final clean = name.trim();
    if (clean.isEmpty) return '';
    final id = 'p${DateTime.now().microsecondsSinceEpoch}-${_placeSeq++}';
    places.add(GymPlace(id: id, name: clean, equipment: {...equipment}));
    _persist();
    notifyListeners();
    return id;
  }

  String addPresetPlace(String preset) => addPlace(
        t.placePresetName(preset),
        equipment: (kPlacePresetGear[preset] ?? const ['Bodyweight']).toSet(),
      );

  void renamePlace(String id, String name) {
    final i = places.indexWhere((p) => p.id == id);
    final clean = name.trim();
    if (i < 0 || clean.isEmpty) return;
    places[i] = places[i].copyWith(name: clean);
    _persist();
    notifyListeners();
  }

  void togglePlaceGear(String id, String equipment) {
    final i = places.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final gear = {...places[i].equipment};
    gear.contains(equipment) ? gear.remove(equipment) : gear.add(equipment);
    places[i] = places[i].copyWith(equipment: gear);
    _persist();
    notifyListeners();
  }

  void deletePlace(String id) {
    places.removeWhere((p) => p.id == id);
    if (activePlaceId == id) activePlaceId = '';
    _persist();
    notifyListeners();
  }

  @override
  Map<double, int>? get plateStockKg {
    final p = activePlace;
    if (p == null || p.plates.isEmpty) return null;
    return p.plates;
  }

  @override
  double? get placeBarKg => activePlace?.bar;

  void setPlatePairs(String placeId, double kg, int pairs) {
    final i = places.indexWhere((p) => p.id == placeId);
    if (i < 0) return;
    final plates = {...places[i].plates};
    final key = _plateKey(plates, kg);
    if (pairs <= 0) {
      plates.remove(key);
    } else {
      plates[key] = pairs.clamp(1, 20);
    }
    places[i] = places[i].copyWith(plates: plates);
    _persist();
    notifyListeners();
  }

  void clearPlates(String placeId) {
    final i = places.indexWhere((p) => p.id == placeId);
    if (i < 0) return;
    places[i] = places[i].copyWith(plates: const {}, clearBar: true);
    _persist();
    notifyListeners();
  }

  void setPlaceBar(String placeId, double kg) {
    final i = places.indexWhere((p) => p.id == placeId);
    if (i < 0) return;
    places[i] = places[i].copyWith(bar: _round3(kg.clamp(1, 60)));
    _persist();
    notifyListeners();
  }

  int platePairs(GymPlace place, double kg) {
    for (final e in place.plates.entries) {
      if ((e.key - kg).abs() < 0.05) return e.value;
    }
    return 0;
  }

  double _plateKey(Map<double, int> plates, double kg) {
    for (final k in plates.keys) {
      if ((k - kg).abs() < 0.05) return k;
    }
    return _round3(kg);
  }

  void setActivePlace(String id) {
    activePlaceId = activePlaceId == id ? '' : id;
    _persist();
    notifyListeners();
  }

  bool exNoGearOnly = false;
  bool exMineOnly = false;

  void toggleNoGearFilter() {
    exNoGearOnly = !exNoGearOnly;
    if (exNoGearOnly) exEquipmentFilter = null;
    notifyListeners();
  }

  void toggleMineFilter() {
    exMineOnly = !exMineOnly;
    notifyListeners();
  }

  @override
  void setEquipmentFilter(String e) {
    exNoGearOnly = false;
    super.setEquipmentFilter(e);
  }

  @override
  List<Exercise> exercisesMatching(String query) => super
      .exercisesMatching(query)
      .where((ex) =>
          (!exNoGearOnly || isNoKit(ex)) && (!exMineOnly || isCustom(ex.id)) && fitsHere(ex))
      .toList();

  @override
  void clearExFilters() {
    exNoGearOnly = false;
    exMineOnly = false;
    super.clearExFilters();
  }

  void goPlaces() => pushRoute('places');

  void backFromPlaces() => popRoute(fallback: 'settings');
}
