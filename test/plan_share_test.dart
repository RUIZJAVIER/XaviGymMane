import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/services/exercise_match.dart';
import 'package:gymmane/services/plan_share.dart';
import 'package:gymmane/state/fit_state.dart';

void main() {
  group('lectura del JSON', () {
    test('lee una rutina simple', () {
      final plans = parsePlan('{"name":"Push","exercises":["Barbell Bench Press","Push-Up"]}');
      expect(plans.length, 1);
      expect(plans.first.name, 'Push');
      expect(plans.first.items.length, 2);
      expect(plans.first.items.first.sets, isNull);
    });

    test('lee series por ejercicio y varias rutinas', () {
      final plans = parsePlan(
          '{"routines":[{"name":"A","exercises":[{"name":"Squat","sets":5}]},'
          '{"title":"B","ejercicios":[{"exercise":"Deadlift"}]}]}');
      expect(plans.length, 2);
      expect(plans.first.items.single.sets, 5);
      expect(plans.last.name, 'B');
    });

    test('aguanta la prosa y las vallas de código de una IA', () {
      final plans = parsePlan('Sure! Here you go:\n```json\n'
          '{"name":"Full body","exercises":["Squat"]}\n```\nEnjoy.');
      expect(plans.single.name, 'Full body');
    });

    test('el mismo ejercicio repetido suma sus series con sus repeticiones', () {
      final plans = parsePlan('{"program":"Import Test","unit":"kg","routines":[{"name":"Different Rep Targets",'
          '"exercises":[{"name":"Lever Shoulder Press","sets":1,"reps":8},'
          '{"name":"Lever Shoulder Press","sets":2,"reps":12}]}]}');
      final item = plans.single.items.single;
      expect(item.sets, 3);
      expect([for (final p in item.plan) p.reps], [8, 12, 12]);
    });

    test('un archivo que no es un plan devuelve nada', () {
      expect(parsePlan('hola'), isEmpty);
      expect(parsePlan('{"name":"Push"}'), isEmpty);
    });

    test('una lista plana extrae el alias entre paréntesis', () {
      final plans = parsePlan('{"name":"Torso","exercises":["Remo con mancuerna (Dumbbell Row)"]}');
      final item = plans.single.items.single;
      expect(item.name, 'Remo con mancuerna');
      expect(item.aliases, ['Dumbbell Row']);
    });

    test('aguanta comas finales, mapa de ejercicios y lista resumida con comas', () {
      expect(parsePlan('{"name":"Torso","exercises":["Squat",],}').single.items.single.name, 'Squat');
      expect(parsePlan('{"name":"Torso","exercises":{"Remo con mancuerna":{"sets":3}}}').single.items.single.name,
          'Remo con mancuerna');
      final flat = parsePlan('Remo con mancuerna, Sentadilla búlgara, Press de banca');
      expect(flat.single.items.map((i) => i.name), ['Remo con mancuerna', 'Sentadilla búlgara', 'Press de banca']);
    });
  });

  group('inferencia de metadatos', () {
    test('reconoce músculo, categoría y alias en español', () {
      expect(guessMuscle('Remo con mancuerna'), 'back');
      expect(guessMuscle('Sentadilla búlgara'), 'quads');
      expect(guessKind('Correr en cinta'), 'cardio');
      expect(guessKind('Estiramiento de isquiotibiales'), 'stretch');
      expect(guessKind('Flexiones en el suelo'), 'calisthenics');
      expect(guessKind('Remo con mancuerna'), 'strength');
      expect(guessEnglishAlias('Remo con mancuerna'), 'Dumbbell Row');
    });
  });

  group('importar en el estado', () {
    setUp(() => fit.resetAllData());

    test('crea la rutina, empareja los nombres y guarda las series', () {
      final result = fit.importPlan(
          '{"name":"Empuje","exercises":[{"name":"Barbell Bench Press","sets":5},'
          '{"name":"no existe este ejercicio"}]}');
      expect(result.added, 2);
      expect(result.missed, isEmpty);
      expect(result.readable, isTrue);
      final routine = fit.routines.single;
      expect(routine.name, 'Empuje');
      expect(routine.exerciseIds.length, 2);
      expect(fit.routineSets(routine, routine.exerciseIds.first), 5);
      expect(fit.customExercises.single.name, 'no existe este ejercicio');
    });

    test('crea un ejercicio nuevo aunque no haya coincidencias', () {
      final result = fit.importPlan('{"name":"X","exercises":["zzzz qqqq"]}');
      expect(result.added, 1);
      expect(result.readable, isTrue);
      expect(result.missed, isEmpty);
      expect(fit.routines, hasLength(1));
      expect(fit.customExercises.single.name, 'zzzz qqqq');
    });

    test('una lista plana nunca descarta ejercicios', () {
      final result = fit.importPlan('{"name":"Torso","exercises":['
          '"Remo con mancuerna (Dumbbell Row)","Sentadilla búlgara con mancuernas"]}');
      expect(result.missed, isEmpty);
      expect(result.added, 2);
      expect(fit.routines.single.exerciseIds, hasLength(2));
    });

    test('importar por alias en español reutiliza el catálogo y no duplica', () {
      final result = fit.importPlan('{"name":"Torso","exercises":['
          '{"name":"Remo con mancuerna","aliases":["Dumbbell Row"],"target_muscle":"back",'
          '"equipment":"Dumbbell","category":"strength","level":"Beginner","steps":["Tira"],"mode":"","secondary":[]}]}');
      expect(result.missed, isEmpty);
      expect(fit.customExercises, isEmpty);
      expect(fit.routines.single.exerciseIds.length, 1);
    });

    test('un archivo ilegible se distingue de uno sin coincidencias', () {
      expect(fit.importPlan('no soy json').readable, isFalse);
    });

    test('crea ejercicios nuevos con los metadatos del JSON y reutiliza su ID', () {
      final first = fit.importPlan('{"name":"Nueva","exercises":['
          '{"name":"Zercher Squat con banda","sets":3,"reps":10,'
          '"aliases":["Band Zercher Squat","Sentadilla Zercher con banda"],'
          '"target_muscle":"quads","equipment":"Band","category":"strength",'
          '"level":"Intermediate","steps":["Pisa la banda con los pies","Haz sentadilla"],'
          '"mode":"","secondary":["glutes"]}]}');
      expect(first.missed, isEmpty);
      final ex = fit.customExercises.single;
      expect(ex.primary, 'quads');
      expect(ex.equipment, 'Band');
      expect(ex.kind, 'strength');
      expect(ex.difficulty, 'Intermediate');
      expect(ex.steps, ['Pisa la banda con los pies', 'Haz sentadilla']);
      expect(ex.secondary, ['glutes']);
      expect(ex.aliases, contains('Band Zercher Squat'));
      expect(fit.routines.single.exerciseIds, [ex.id]);

      final again = fit.importPlan('{"name":"Otra","exercises":['
          '{"name":"Zercher Squat con banda","sets":2}]}');
      expect(again.missed, isEmpty);
      expect(fit.customExercises.length, 1);
      final other = fit.routines.firstWhere((r) => r.name == 'Otra');
      expect(other.exerciseIds, [ex.id]);
    });
  });

  test('la lista para la IA lleva cabecera y ejercicios', () {
    final text = fit.planRequestText();
    expect(text.contains('GymMane'), isTrue);
    expect(text.contains('Barbell Bench Press'), isTrue);
    expect(text.split('\n').length, greaterThan(50));
  });
}
