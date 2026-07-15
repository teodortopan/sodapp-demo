import 'package:flutter_test/flutter_test.dart';
import 'package:sodapp_demo/demo/demo_mode.dart';
import 'package:sodapp_demo/widgets/onboarding/tutorial_controller.dart';

void main() {
  final c = TutorialController.instance;

  setUp(() {
    c.onExit = null;
    c.onScreenRequested = null;
    c.skip(); // reset the singleton to inactive between tests
  });

  tearDown(() {
    c.onExit = null;
    c.onScreenRequested = null;
    c.skip();
  });

  test(
    'full happy path advances through every step in order',
    () {
      c.debugSetCurrent(GuidedStep.gotoMas);

      c.onMasOpened();
      expect(c.current, GuidedStep.openProfile);

      c.onProfileOpened();
      expect(c.current, GuidedStep.profilePhoto);

      c.forwardManual();
      expect(c.current, GuidedStep.profileReparto);
      c.forwardManual();
      c.forwardManual();
      c.forwardManual();
      expect(c.current, GuidedStep.profileFacturacion);
      c.forwardManual();
      expect(c.current, GuidedStep.createReparto); // new user → gated

      c.onRepartoCreated(7);
      expect(c.repartoId, 7);
      expect(c.current, GuidedStep.perfilBack);

      c.onReturnedFromProfile();
      expect(c.current, GuidedStep.gotoCarga);

      // DB-gated carga steps — jump past them.
      c.debugSetCurrent(GuidedStep.addProduct);
      c.onProductCreated(42);
      expect(c.current, GuidedStep.setPrices);

      c.debugSetCurrent(GuidedStep.cargaBack);
      c.onReturnedFromCarga();
      expect(c.current, GuidedStep.selectDay);

      c.onDaySelected(2);
      expect(c.current, GuidedStep.viewSummary);
      c.forwardManual();
      // v85 «Instancias»: informational vista-dropdown step (manual).
      expect(c.current, GuidedStep.instancias);
      c.forwardManual();
      expect(c.current, GuidedStep.gotoGastos);

      c.onGastosOpened();
      c.onGastoSaved();
      expect(c.current, GuidedStep.gastosBack);
      c.onReturnedFromGastos();
      expect(c.current, GuidedStep.empezar);

      // Phase 1 — recorrido start now continues into Ruta.
      c.onRecorridoStarted();
      expect(c.current, GuidedStep.rutaIntro);

      c.forwardManual(); // rutaIntro → rutaMapa
      c.forwardManual();
      c.forwardManual();
      c.forwardManual();
      c.forwardManual();
      expect(c.current, GuidedStep.rutaCliente);
      c.forwardManual(); // rutaCliente (manual) → rutaVender (gated)
      expect(c.current, GuidedStep.rutaVender);

      c.onEntregaRecorded();
      expect(c.current, GuidedStep.rutaPago);
      c.onPagoRecorded();
      expect(c.current, GuidedStep.rutaEstado);
      c.onEstadoSet();
      expect(c.current, GuidedStep.rutaVolverInicio);

      c.onBackToInicio();
      expect(c.current, GuidedStep.terminar);

      c.onCierreOpened();
      expect(c.current, GuidedStep.cierreSueldo);
      c.forwardManual(); // sueldo → caja
      c.forwardManual(); // caja → productos
      c.forwardManual(); // productos → gastos
      c.forwardManual(); // gastos → finalizar
      expect(c.current, GuidedStep.cierreFinalizar);

      c.onResumenSaved();
      expect(c.current, GuidedStep.p2GotoMas); // → Phase 2

      c.onMasOpened();
      expect(c.current, GuidedStep.p2GotoClientes);
      c.onP2Open(GuidedScreen.clientes);
      expect(c.current, GuidedStep.p2Clientes);
      c.onP2Return(GuidedScreen.clientes);
      expect(c.current, GuidedStep.p2GotoEtiquetas);
      c.onP2Open(GuidedScreen.etiquetas);
      c.onP2Return(GuidedScreen.etiquetas);
      c.onP2Open(GuidedScreen.resumenDiario);
      c.onP2Return(GuidedScreen.resumenDiario);
      c.onP2Open(GuidedScreen.resumenAnual);
      c.onP2Return(GuidedScreen.resumenAnual);
      expect(c.current, GuidedStep.p2GotoConfig);
      c.onP2Open(GuidedScreen.config);
      c.onP2Return(GuidedScreen.config);
      expect(c.current, GuidedStep.tutorialDone);

      c.forwardManual(); // tutorialDone → done
      expect(c.active, isFalse);
    },
    skip: kDemoMode
        ? 'Production tutorial flow is replaced in demo mode.'
        : false,
  );

  test(
    'demo walkthrough is short, arrow-driven, and skips unreachable paid work',
    () {
      if (!kDemoMode) return;

      c.start();
      expect(c.current, GuidedStep.gotoMas);

      final visited = <GuidedStep>[];
      while (c.active) {
        final step = c.current!;
        visited.add(step);
        expect(step.screen, isNot(GuidedScreen.cierre));
        expect(c.canGoForward, isTrue);
        c.forwardManual();
      }

      expect(visited, [
        GuidedStep.gotoMas,
        GuidedStep.openProfile,
        GuidedStep.profilePhoto,
        GuidedStep.profileReparto,
        GuidedStep.profilePersonal,
        GuidedStep.profileMP,
        GuidedStep.profileFacturacion,
        GuidedStep.createReparto,
        GuidedStep.perfilBack,
        GuidedStep.selectDay,
        GuidedStep.viewSummary,
        GuidedStep.gotoCarga,
        GuidedStep.addQty,
        GuidedStep.cargaBack,
        GuidedStep.gotoGastos,
        GuidedStep.registerGasto,
        GuidedStep.gastosBack,
        GuidedStep.rutaIntro,
        GuidedStep.rutaMapa,
        GuidedStep.rutaCliente,
        GuidedStep.p2GotoMas,
        GuidedStep.tutorialDone,
      ]);
    },
    skip: kDemoMode ? false : 'Demo-only tutorial behavior.',
  );

  test(
    '‹ › re-reads through reached steps and can cross screens',
    () {
      // Reach cierreGastos as the frontier by advancing the live flow.
      c.debugSetCurrent(GuidedStep.cierreSueldo);
      c.forwardManual(); // → cierreCaja (frontier moves)
      c.forwardManual(); // → cierreProductos
      expect(c.current, GuidedStep.cierreProductos);
      expect(c.canGoForward, isTrue); // manual frontier can advance

      c.back(); // → cierreCaja (re-read)
      expect(c.current, GuidedStep.cierreCaja);
      expect(c.canGoForward, isTrue); // behind frontier → can go forward
      c.back(); // → cierreSueldo
      expect(c.current, GuidedStep.cierreSueldo);
      expect(c.canGoBack, isTrue);

      GuidedScreen? requested;
      c.onScreenRequested = (screen) => requested = screen;
      c.back(); // → terminar, crossing back to Inicio
      expect(c.current, GuidedStep.terminar);
      expect(requested, GuidedScreen.inicio);

      c.forwardManual(); // re-read forward → cierreSueldo, crossing into Cierre
      expect(c.current, GuidedStep.cierreSueldo);
      expect(requested, GuidedScreen.cierre);
    },
    skip: kDemoMode
        ? 'Cierre tutorial steps are unreachable in demo mode.'
        : false,
  );

  test('opening a client detail advances rutaCliente → rutaVender', () {
    c.debugSetCurrent(GuidedStep.rutaCliente);
    c.onClientDetailOpened();
    expect(
      c.current,
      kDemoMode ? GuidedStep.rutaCliente : GuidedStep.rutaVender,
    );
    c.onClientDetailClosed();
    if (kDemoMode) {
      expect(c.current, GuidedStep.p2GotoMas);
    }
  });

  test('onClientDetailOpened is a no-op outside rutaCliente', () {
    c.debugSetCurrent(GuidedStep.rutaVender);
    c.onClientDetailOpened();
    expect(c.current, GuidedStep.rutaVender);
  });

  test(
    '› cannot skip a gated frontier step',
    () {
      c.debugSetCurrent(GuidedStep.rutaVender); // gated, at frontier
      expect(c.canGoForward, isFalse);
      c.forwardManual();
      expect(c.current, GuidedStep.rutaVender); // unchanged
    },
    skip: kDemoMode ? 'Demo tutorial steps are all arrow-driven.' : false,
  );

  test(
    'createReparto auto-skips when a reparto already exists (replay)',
    () {
      c.debugSetCurrent(GuidedStep.profileFacturacion, repartoId: 5);
      c.forwardManual();
      expect(c.current, GuidedStep.perfilBack);
    },
    skip: kDemoMode
        ? 'Demo tutorial never auto-skips explanatory steps.'
        : false,
  );

  test('created reparto can track the tutorial example client', () {
    c.debugSetCurrent(GuidedStep.createReparto);
    c.onRepartoCreated(7, exampleClientId: 99);

    expect(c.repartoId, 7);
    expect(c.exampleClientId, 99);
    expect(c.current, GuidedStep.perfilBack);
  });

  test('reparto creation is ignored outside the create step', () {
    c.onRepartoCreated(7, exampleClientId: 99);

    expect(c.repartoId, isNull);
    expect(c.exampleClientId, isNull);
  });

  test('leaving Perfil before finishing ends the tutorial', () {
    c.debugSetCurrent(GuidedStep.profilePersonal);
    c.onReturnedFromProfile();
    expect(c.active, isFalse);
  });

  test('day-select gate requires the loaded day', () {
    c.debugSetCurrent(GuidedStep.selectDay, loadedDay: 3);
    c.onDaySelected(1);
    expect(c.current, GuidedStep.selectDay);
    c.onDaySelected(3);
    expect(c.current, GuidedStep.viewSummary);
  });

  test('skip ends the flow and clears state', () {
    c.debugSetCurrent(
      GuidedStep.empezar,
      repartoId: 1,
      newProductId: 7,
      exampleClientId: 3,
    );
    c.skip();
    expect(c.active, isFalse);
    expect(c.current, isNull);
    expect(c.exampleClientId, isNull);
  });

  test('skip reports a skipped exit', () {
    TutorialExitReason? reason;
    c.onExit = (r) => reason = r;
    c.debugSetCurrent(GuidedStep.empezar);

    c.skip();

    expect(reason, TutorialExitReason.skipped);
  });

  test('finishing the final step reports a completed exit', () {
    TutorialExitReason? reason;
    c.onExit = (r) => reason = r;
    c.debugSetCurrent(GuidedStep.tutorialDone);

    c.forwardManual();

    expect(reason, TutorialExitReason.completed);
    expect(c.active, isFalse);
  });

  test('GuidedStep.screen maps the new steps to the right host', () {
    expect(GuidedStep.rutaIntro.screen, GuidedScreen.ruta);
    expect(GuidedStep.rutaVender.screen, GuidedScreen.ruta);
    expect(GuidedStep.terminar.screen, GuidedScreen.inicio);
    expect(GuidedStep.cierreSueldo.screen, GuidedScreen.cierre);
    expect(GuidedStep.cierreFinalizar.screen, GuidedScreen.cierre);
  });

  // ─── Section picker: bounded start ───

  test('plain start() still begins the full flow at gotoMas', () {
    c.start();
    expect(c.current, GuidedStep.gotoMas);
    expect(c.active, isTrue);
  });

  test('start(from:) begins the section at the chosen step', () {
    c.start(from: GuidedStep.openProfile, stopAfter: GuidedStep.perfilBack);
    expect(c.current, GuidedStep.openProfile);

    c.start(
      from: GuidedStep.p2GotoClientes,
      stopAfter: GuidedStep.tutorialDone,
    );
    expect(
      c.current,
      kDemoMode ? GuidedStep.p2GotoMas : GuidedStep.p2GotoClientes,
    );
  });

  test(
    'a section ends (completed) when advancing past stopAfter',
    () {
      TutorialExitReason? reason;
      c.onExit = (r) => reason = r;
      // One-step section: current == stopAfter == empezar.
      c.start(from: GuidedStep.empezar, stopAfter: GuidedStep.empezar);
      expect(c.current, GuidedStep.empezar);
      c.onRecorridoStarted(); // would advance to rutaIntro, but the boundary stops
      expect(c.active, isFalse);
      expect(reason, TutorialExitReason.completed);
    },
    skip: kDemoMode ? 'Demo order no longer includes recorrido start.' : false,
  );

  test(
    'carga/ruta section stops after cierreFinalizar (does not enter Más)',
    () {
      c.start(
        from: GuidedStep.gotoCarga,
        stopAfter: GuidedStep.cierreFinalizar,
      );
      c.debugSetCurrent(GuidedStep.cierreFinalizar); // preserves _stopAfter
      c.onResumenSaved(); // would advance to p2GotoMas, but the boundary stops
      expect(c.active, isFalse);
      expect(c.current, isNull);
    },
  );

  test('perfil section stops after perfilBack (does not enter gotoCarga)', () {
    c.start(from: GuidedStep.openProfile, stopAfter: GuidedStep.perfilBack);
    c.debugSetCurrent(GuidedStep.perfilBack);
    c.onReturnedFromProfile(); // would advance to gotoCarga, but the boundary stops
    expect(c.active, isFalse);
  });

  test(
    'a fresh start() clears a prior section boundary',
    () {
      c.start(from: GuidedStep.empezar, stopAfter: GuidedStep.empezar);
      c.start(); // full flow again
      c.debugSetCurrent(GuidedStep.empezar);
      c.onRecorridoStarted();
      expect(c.current, GuidedStep.rutaIntro); // advances normally, no boundary
    },
    skip: kDemoMode ? 'Demo order no longer includes recorrido start.' : false,
  );
}
