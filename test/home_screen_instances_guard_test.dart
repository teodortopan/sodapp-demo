import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sodapp_demo/widgets/onboarding/tutorial_controller.dart';

/// v85 «Instancias» — source guards for the mobile UI wiring (house
/// style: assert the load-bearing code shapes so refactors can't silently
/// drop a guard) + tutorial step registration.
void main() {
  late String homeSrc;
  late String rutaSrc;

  setUpAll(() {
    homeSrc = File('lib/screens/home_screen.dart').readAsStringSync();
    rutaSrc = File('lib/screens/ruta_screen.dart').readAsStringSync();
  });

  group('chronometer re-key — two days of one reparto can run at once', () {
    test('the in-memory map is keyed by (repartoId, day), not repartoId', () {
      expect(
        homeSrc,
        contains('final Map<String, _RecorridoState> _activeRecorridos'),
      );
      expect(
        homeSrc,
        isNot(contains('final Map<int, _RecorridoState> _activeRecorridos')),
        reason:
            'a reparto-keyed map collapses to ONE running day per reparto '
            '— the bug «Instancias» exists to fix',
      );
      expect(homeSrc, contains("String _rkey(int repartoId, int day)"));
    });

    test('start adopts an already-running (reparto, day) instead of '
        'restarting it (one recorrido per day, ever)', () {
      final idx = homeSrc.indexOf('Future<void> _startRecorridoAsync()');
      expect(idx, isNot(-1));
      final body = homeSrc.substring(idx, idx + 6500);
      expect(
        body,
        contains('if (existing != null && !_isEndedRecorridoEntry(existing))'),
        reason:
            'starting a day already running on another vista/phone must '
            'RESUME the session — a fresh start would reset the sibling\'s '
            'chronometer and re-key the day\'s fecha',
      );
      expect(body, contains('First-owner wins the attribution'));
    });

    test('cierre removes only the closed (reparto, day) key', () {
      // Formatting-insensitive: pin the semantic (remove keyed by
      // (repartoId, day)), not the line wrapping — a reformat broke the
      // old multi-line pin without any behavior change.
      expect(
        homeSrc,
        contains(
          '_activeRecorridos.remove(_rkey(repartoId, recorridoState.day))',
        ),
      );
    });

    test('the midnight reset in Ruta is day-scoped', () {
      expect(rutaSrc, contains('clearRecorridoForRepartoAndDay(rId, day)'));
    });
  });

  group('vista lifecycle safety', () {
    test('instance deletion is a soft registry edit — NO business-data '
        'deletion path is reachable from it', () {
      final idx = homeSrc.indexOf('Future<void> _confirmDeleteInstance');
      expect(idx, isNot(-1));
      final end = homeSrc.indexOf('// ─── v85', idx + 10);
      final body = homeSrc.substring(
        idx,
        end > idx ? end : (idx + 4000).clamp(0, homeSrc.length),
      );
      expect(body, contains("e['deleted'] = true;"));
      for (final forbidden in [
        'markPendingDeletion',
        'deleteReparto',
        'deleteResumen',
        'DELETE FROM',
        'deleteEntrega',
      ]) {
        expect(
          body,
          isNot(contains(forbidden)),
          reason:
              'deleting a vista must never touch entregas/pagos/resúmenes '
              '($forbidden found)',
        );
      }
      // And it must be blocked while THIS vista owns a running recorrido —
      // ownership by instanceId (Codex review ×2: a sibling vista running
      // the same day must NOT block, and a running vista must be caught
      // even if its registry day was switched mid-recorrido). The
      // configured-day check survives only as the fallback for entries
      // from older app versions that carry no instanceId.
      expect(body, contains('getActiveRecorridos()'));
      expect(body, contains('owner == instanceId'));
      expect(body, contains('owner.isEmpty &&'));
      expect(
        body,
        isNot(contains('getActiveRecorridoForRepartoAndDay')),
        reason:
            'day-only attribution misfires for sibling vistas — the '
            'guard must be owner-based',
      );
      expect(
        body,
        contains('Terminá el recorrido de esta vista antes de eliminarla.'),
      );
    });

    test('the default vista has no delete affordance', () {
      final idx = homeSrc.indexOf('_showInstancePicker');
      final body = homeSrc.substring(idx, idx + 9000);
      expect(body, contains('if (!isDefault)'));
    });

    test('reparto deletion purges its vistas (the ONLY all-instances '
        'removal path)', () {
      expect(homeSrc, contains('purgeInstancesForReparto(reparto.id)'));
    });

    test('non-default day picks persist to the synced registry entry', () {
      expect(homeSrc, contains('_persistInstanceDaySelection'));
      final idx = homeSrc.indexOf('Future<void> _persistInstanceDaySelection');
      final body = homeSrc.substring(idx, idx + 1200);
      expect(body, contains('if (_isDefaultInstanceId(instanceId)) return;'));
      expect(body, contains('mutateInstancesAtomic'));
    });

    test('the vista pointer is device-local (SharedPreferences), '
        'never synced', () {
      expect(homeSrc, contains("'instancia.actual.'"));
      expect(
        homeSrc,
        isNot(contains('instancia_actual')),
        reason:
            'no DB column for the pointer — two phones must be able to '
            'look at different vistas of the same account',
      );
    });
  });

  group('persist pass-through (merge safety)', () {
    test('_persistRecorridoState keeps entries it does not own', () {
      final idx = homeSrc.indexOf('Future<void> _persistRecorridoState()');
      final body = homeSrc.substring(idx, idx + 4200);
      expect(
        body,
        contains('Pass-through: ended entries'),
        reason:
            'dropping a sibling phone\'s running entry from the array '
            'would clobber it locally until the next merge',
      );
      expect(
        body,
        contains("'lastTouchMs': changed"),
        reason:
            'stamping a fresh clock on UNCHANGED state would let a mere '
            'lifecycle save out-arbitrate a sibling\'s fresher end/clear',
      );
    });
  });

  group('tutorial step registration', () {
    test('instancias step exists, lives on Inicio, and is manual', () {
      expect(GuidedStep.values, contains(GuidedStep.instancias));
      expect(GuidedStep.instancias.screen, GuidedScreen.inicio);
      expect(
        TutorialController.instance.isManual(GuidedStep.instancias),
        isTrue,
        reason: 'informational spotlight — advances via ›, no gate',
      );
    });

    test('the step has a spotlight view on the dropdown key', () {
      expect(homeSrc, contains('GuidedStep.instancias: GuidedStepView('));
      final idx = homeSrc.indexOf('GuidedStep.instancias: GuidedStepView(');
      final body = homeSrc.substring(idx, idx + 700);
      expect(body, contains('_kInstanceDropdown'));
      expect(body, contains('Varios días a la vez'));
    });
  });
}
