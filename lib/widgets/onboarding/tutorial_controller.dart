import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../database/app_database.dart';
import '../../demo/demo_mode.dart';

/// Which screen renders the overlay for a given step.
enum GuidedScreen {
  inicio,
  mas,
  profile,
  carga,
  gastos,
  ruta,
  cierre,
  clientes,
  etiquetas,
  resumenDiario,
  resumenAnual,
  config,
}

enum TutorialExitReason { completed, skipped }

/// The ordered steps of the cross-screen guided setup tutorial. Each belongs to
/// exactly one screen, which renders the spotlight (or a top banner) for it.
enum GuidedStep {
  // Inicio → Más
  gotoMas,
  // Más
  openProfile,
  // Perfil (informational tour)
  profilePhoto,
  profileReparto,
  profilePersonal,
  profileMP,
  profileFacturacion,
  // Perfil (gated on a reparto existing)
  createReparto,
  perfilBack,
  // Inicio
  gotoCarga,
  // Carga
  addProduct,
  setPrices,
  addQty,
  cargaBack,
  // Inicio
  selectDay,
  viewSummary,
  // v85 «Instancias»: informational spotlight on the vistas dropdown.
  instancias,
  gotoGastos,
  // Gastos
  registerGasto,
  gastosBack,
  // Inicio
  empezar,
  // Ruta (explanations + hands-on)
  rutaIntro,
  rutaMapa,
  rutaFiltros,
  rutaMarcar,
  rutaOrdenar,
  rutaCliente,
  rutaVender, // top banner, gated on an entrega
  rutaPago, // top banner, gated on a pago
  rutaEstado, // top banner, gated on a status
  rutaVolverInicio, // top banner, guide back to Inicio
  // Inicio
  terminar,
  // Cierre / resumen
  cierreSueldo,
  cierreCaja,
  cierreProductos,
  cierreGastos,
  cierreFinalizar,
  // Phase 2 — Más pages tour
  p2GotoMas,
  p2GotoClientes,
  p2Clientes,
  p2GotoEtiquetas,
  p2Etiquetas,
  p2GotoResDiario,
  p2ResDiario,
  p2GotoResAnual,
  p2ResAnual,
  p2GotoConfig,
  p2Config,
  tutorialDone,
}

extension GuidedStepInfo on GuidedStep {
  GuidedScreen get screen {
    switch (this) {
      case GuidedStep.gotoMas:
      case GuidedStep.gotoCarga:
      case GuidedStep.selectDay:
      case GuidedStep.viewSummary:
      case GuidedStep.instancias:
      case GuidedStep.gotoGastos:
      case GuidedStep.empezar:
      case GuidedStep.terminar:
      case GuidedStep.p2GotoMas:
        return GuidedScreen.inicio;
      case GuidedStep.openProfile:
      case GuidedStep.p2GotoClientes:
      case GuidedStep.p2GotoEtiquetas:
      case GuidedStep.p2GotoResDiario:
      case GuidedStep.p2GotoResAnual:
      case GuidedStep.p2GotoConfig:
      case GuidedStep.tutorialDone:
        return GuidedScreen.mas;
      case GuidedStep.p2Clientes:
        return GuidedScreen.clientes;
      case GuidedStep.p2Etiquetas:
        return GuidedScreen.etiquetas;
      case GuidedStep.p2ResDiario:
        return GuidedScreen.resumenDiario;
      case GuidedStep.p2ResAnual:
        return GuidedScreen.resumenAnual;
      case GuidedStep.p2Config:
        return GuidedScreen.config;
      case GuidedStep.profilePhoto:
      case GuidedStep.profileReparto:
      case GuidedStep.profilePersonal:
      case GuidedStep.profileMP:
      case GuidedStep.profileFacturacion:
      case GuidedStep.createReparto:
      case GuidedStep.perfilBack:
        return GuidedScreen.profile;
      case GuidedStep.addProduct:
      case GuidedStep.setPrices:
      case GuidedStep.addQty:
      case GuidedStep.cargaBack:
        return GuidedScreen.carga;
      case GuidedStep.registerGasto:
      case GuidedStep.gastosBack:
        return GuidedScreen.gastos;
      case GuidedStep.rutaIntro:
      case GuidedStep.rutaMapa:
      case GuidedStep.rutaFiltros:
      case GuidedStep.rutaMarcar:
      case GuidedStep.rutaOrdenar:
      case GuidedStep.rutaCliente:
      case GuidedStep.rutaVender:
      case GuidedStep.rutaPago:
      case GuidedStep.rutaEstado:
      case GuidedStep.rutaVolverInicio:
        return GuidedScreen.ruta;
      case GuidedStep.cierreSueldo:
      case GuidedStep.cierreCaja:
      case GuidedStep.cierreProductos:
      case GuidedStep.cierreGastos:
      case GuidedStep.cierreFinalizar:
        return GuidedScreen.cierre;
    }
  }
}

/// Central state machine for the hands-on, milestone-gated guided tutorial. One
/// global instance, mirroring `AppDatabase.instance`. Each screen renders the
/// overlay for the current step and fires explicit hooks when the user completes
/// an action. Gated advances are confirmed by re-querying the DB. The card has a
/// `‹ ›` control for re-reading explanations — `_frontier` tracks the furthest
/// step reached so `›` can never skip a gate. In-memory only.
class TutorialController extends ChangeNotifier {
  TutorialController._();
  static final TutorialController instance = TutorialController._();

  /// Test seam: override the database used for gate confirmation.
  AppDatabase? dbOverride;
  AppDatabase get _db => dbOverride ?? AppDatabase.instance;

  static const List<GuidedStep> _order = [
    GuidedStep.gotoMas,
    GuidedStep.openProfile,
    GuidedStep.profilePhoto,
    GuidedStep.profileReparto,
    GuidedStep.profilePersonal,
    GuidedStep.profileMP,
    GuidedStep.profileFacturacion,
    GuidedStep.createReparto,
    GuidedStep.perfilBack,
    GuidedStep.gotoCarga,
    GuidedStep.addProduct,
    GuidedStep.setPrices,
    GuidedStep.addQty,
    GuidedStep.cargaBack,
    GuidedStep.selectDay,
    GuidedStep.viewSummary,
    GuidedStep.instancias,
    GuidedStep.gotoGastos,
    GuidedStep.registerGasto,
    GuidedStep.gastosBack,
    GuidedStep.empezar,
    GuidedStep.rutaIntro,
    GuidedStep.rutaMapa,
    GuidedStep.rutaFiltros,
    GuidedStep.rutaMarcar,
    GuidedStep.rutaOrdenar,
    GuidedStep.rutaCliente,
    GuidedStep.rutaVender,
    GuidedStep.rutaPago,
    GuidedStep.rutaEstado,
    GuidedStep.rutaVolverInicio,
    GuidedStep.terminar,
    GuidedStep.cierreSueldo,
    GuidedStep.cierreCaja,
    GuidedStep.cierreProductos,
    GuidedStep.cierreGastos,
    GuidedStep.cierreFinalizar,
    GuidedStep.p2GotoMas,
    GuidedStep.p2GotoClientes,
    GuidedStep.p2Clientes,
    GuidedStep.p2GotoEtiquetas,
    GuidedStep.p2Etiquetas,
    GuidedStep.p2GotoResDiario,
    GuidedStep.p2ResDiario,
    GuidedStep.p2GotoResAnual,
    GuidedStep.p2ResAnual,
    GuidedStep.p2GotoConfig,
    GuidedStep.p2Config,
    GuidedStep.tutorialDone,
  ];

  /// Steps that advance via the `›` button (informational, not gated).
  static const Set<GuidedStep> _manualSteps = {
    GuidedStep.profilePhoto,
    GuidedStep.profileReparto,
    GuidedStep.profilePersonal,
    GuidedStep.profileMP,
    GuidedStep.profileFacturacion,
    GuidedStep.viewSummary,
    GuidedStep.instancias,
    GuidedStep.rutaIntro,
    GuidedStep.rutaMapa,
    GuidedStep.rutaFiltros,
    GuidedStep.rutaMarcar,
    GuidedStep.rutaOrdenar,
    GuidedStep.rutaCliente,
    GuidedStep.cierreSueldo,
    GuidedStep.cierreCaja,
    GuidedStep.cierreProductos,
    GuidedStep.cierreGastos,
    GuidedStep.p2Clientes,
    GuidedStep.p2Etiquetas,
    GuidedStep.p2ResDiario,
    GuidedStep.p2ResAnual,
    GuidedStep.p2Config,
    GuidedStep.tutorialDone,
  };

  /// DEMO: short walkthrough only. The Inicio coachmark still explains the
  /// home page first; this guided order then shows Perfil/Reparto, day
  /// selection, Carga, Gastos, Ruta, one client profile entry point, and Más.
  /// Paywalled writes stay blocked, so demo steps are explanatory instead of
  /// gated on real actions.
  static const List<GuidedStep> _demoOrder = [
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
  ];

  static final List<GuidedStep> _steps = kDemoMode ? _demoOrder : _order;

  GuidedStep? _current;
  GuidedStep? _frontier; // furthest step reached
  GuidedStep?
  _stopAfter; // section boundary: stop once we advance past this step
  int? repartoId;
  int? newProductId;
  int? exampleClientId;
  int? loadedDay;
  String? loadedWeek;
  ValueChanged<TutorialExitReason>? onExit;
  ValueChanged<GuidedScreen>? onScreenRequested;

  GuidedStep? get current => _current;
  bool get active => _current != null;

  int get _curIdx => _current == null ? -1 : _steps.indexOf(_current!);
  int get _frontIdx => _frontier == null ? -1 : _steps.indexOf(_frontier!);

  /// 1-based position of the current step (for "n de N" display).
  int get stepNumber => _curIdx + 1;
  int get totalSteps => _steps.length;

  /// DEMO: every step is manual — the walkthrough advances only via `›`,
  /// never by requiring a (paywalled) real action.
  bool isManual(GuidedStep s) => kDemoMode || _manualSteps.contains(s);

  /// Start the guided flow. [from] is the first step (defaults to the very
  /// beginning); [stopAfter] is the last step of a section — once the flow would
  /// advance past it, the tutorial ends (used by the Más section picker). With
  /// both null this is the full 48-step flow.
  void start({int? repartoId, GuidedStep? from, GuidedStep? stopAfter}) {
    this.repartoId = repartoId;
    newProductId = null;
    exampleClientId = null;
    loadedDay = null;
    loadedWeek = null;
    _current = _includedStepAtOrBefore(from ?? GuidedStep.gotoMas);
    _frontier = _current;
    // DEMO: a section boundary that was filtered out of the demo order
    // (e.g. cierreFinalizar) would never match `_current == _stopAfter`
    // and the section would bleed into the next one. Remap it to the
    // nearest preceding step that still exists.
    var boundary = stopAfter;
    if (boundary != null && !_steps.contains(boundary)) {
      boundary = _includedStepAtOrBefore(boundary);
    }
    _stopAfter = boundary;
    notifyListeners();
  }

  GuidedStep? _includedStepAtOrBefore(GuidedStep step) {
    if (_steps.contains(step)) return step;
    var i = _order.indexOf(step);
    while (i > 0 && !_steps.contains(_order[i])) {
      i--;
    }
    return i >= 0 && _steps.contains(_order[i])
        ? _order[i]
        : (_steps.isNotEmpty ? _steps.first : null);
  }

  void skip() => _stop(TutorialExitReason.skipped);

  void _stop(TutorialExitReason reason) {
    final wasActive = _current != null;
    _current = null;
    _frontier = null;
    _stopAfter = null;
    repartoId = null;
    newProductId = null;
    exampleClientId = null;
    loadedDay = null;
    loadedWeek = null;
    notifyListeners();
    if (wasActive) onExit?.call(reason);
  }

  /// Advance the live flow one step (milestone or a manual `›` at the frontier).
  void _advance() {
    if (_current == null) return;
    // Section boundary: if this is the last step of the selected section, end
    // the tutorial instead of bleeding into the next section.
    if (_current == _stopAfter) {
      _stop(TutorialExitReason.completed);
      return;
    }
    final idx = _curIdx;
    if (idx < 0 || idx + 1 >= _steps.length) {
      _stop(TutorialExitReason.completed);
      return;
    }
    _current = _steps[idx + 1];
    if (_frontIdx < idx + 1) _frontier = _current;
    notifyListeners();
    _maybeSkipCurrent();
  }

  void _advanceTo(GuidedStep step) {
    _current = step;
    if (_frontIdx < _steps.indexOf(step)) _frontier = step;
    notifyListeners();
  }

  // ─── ‹ › re-reading / navigation ───

  bool get canGoBack {
    final idx = _curIdx;
    return idx > 0;
  }

  bool get canGoForward {
    final idx = _curIdx;
    if (idx < 0) return false;
    if (idx < _frontIdx) return true;
    return isManual(_current!); // manual frontier can advance the flow
  }

  void back() {
    if (!canGoBack) return;
    final fromScreen = _current!.screen;
    _current = _steps[_curIdx - 1];
    notifyListeners();
    _requestScreenIfChanged(fromScreen);
  }

  /// The `›` button: re-read forward within the screen, or advance a manual
  /// frontier step (which may cross to the next screen as the live flow).
  void forwardManual() {
    final idx = _curIdx;
    if (idx < 0) return;
    final fromScreen = _current!.screen;
    if (idx < _frontIdx) {
      _current = _steps[idx + 1];
      notifyListeners();
      _requestScreenIfChanged(fromScreen);
    } else if (isManual(_current!)) {
      _advance();
      _requestScreenIfChanged(fromScreen);
    }
  }

  void _requestScreenIfChanged(GuidedScreen fromScreen) {
    final target = _current?.screen;
    if (target != null && target != fromScreen) onScreenRequested?.call(target);
  }

  // ─── Auto-skip already-satisfied steps (replay) ───

  Future<void> _maybeSkipCurrent() async {
    // DEMO: never auto-skip — each step stays visible as a brief
    // explanation, even when the demo seed already satisfies it.
    if (kDemoMode) return;
    switch (_current) {
      case GuidedStep.createReparto:
        if (repartoId != null) _advance();
        break;
      case GuidedStep.addProduct:
        await _maybeAdoptProduct();
        break;
      default:
        break;
    }
  }

  // ─── Hooks fired by screens at confirmed local actions ───

  void onMasOpened() {
    if (_current == GuidedStep.gotoMas || _current == GuidedStep.p2GotoMas) {
      _advance();
    }
  }

  void onProfileOpened() {
    if (_current == GuidedStep.openProfile) _advance();
  }

  void onRepartoCreated(int id, {int? exampleClientId}) {
    if (_current != GuidedStep.createReparto) return;
    repartoId ??= id;
    this.exampleClientId ??= exampleClientId;
    _advance();
  }

  void onReturnedFromProfile() {
    if (_current == GuidedStep.perfilBack) {
      _advance();
    } else if (_current != null && _current!.screen == GuidedScreen.profile) {
      _stop(TutorialExitReason.skipped);
    }
  }

  void onCargaOpened() {
    if (_current == GuidedStep.gotoCarga) _advance();
  }

  void onProductCreated(int id) {
    if (_current == GuidedStep.addProduct) {
      newProductId = id;
      unawaited(_attachExampleClientProduct(id));
      _advance();
    }
  }

  Future<void> onPriceChanged() async {
    if (_current != GuidedStep.setPrices) return;
    if (await _pricesSatisfied()) _advance();
  }

  Future<void> onCargaChanged(int day, String week) async {
    if (_current != GuidedStep.addQty) return;
    if (await _cargaSatisfied(day, week)) {
      await _moveExampleClientToDay(day);
      loadedDay = day;
      loadedWeek = week;
      _advance();
    }
  }

  void onReturnedFromCarga() {
    if (_current == GuidedStep.cargaBack) {
      _advance();
    } else if (_current != null && _current!.screen == GuidedScreen.carga) {
      _stop(TutorialExitReason.skipped);
    }
  }

  void onDaySelected(int day) {
    if (_current != GuidedStep.selectDay) return;
    if (loadedDay == null || day == loadedDay) _advance();
  }

  void onGastosOpened() {
    if (_current == GuidedStep.gotoGastos) _advance();
  }

  void onGastoSaved() {
    if (_current == GuidedStep.registerGasto) _advance();
  }

  void onReturnedFromGastos() {
    if (_current == GuidedStep.gastosBack) {
      _advance();
    } else if (_current != null && _current!.screen == GuidedScreen.gastos) {
      _stop(TutorialExitReason.skipped);
    }
  }

  /// Recorrido started → continue into the Ruta walkthrough.
  void onRecorridoStarted() {
    if (_current == GuidedStep.empezar) _advance();
  }

  // Opening a client's detail sheet (tapping the number badge) on the
  // "atendé el ejemplo" step advances straight into the hands-on sell step in
  // the real app. Demo waits until the sheet closes so the user can look
  // around the read-only profile first.
  void onClientDetailOpened() {
    if (kDemoMode) return;
    if (_current == GuidedStep.rutaCliente) _advance();
  }

  void onClientDetailClosed() {
    if (!kDemoMode) return;
    if (_current == GuidedStep.rutaCliente) _advance();
  }

  // ─── Ruta hands-on gates (an action on ANY client counts) ───
  void onEntregaRecorded() {
    if (_current == GuidedStep.rutaVender) _advance();
  }

  void onPagoRecorded() {
    if (_current == GuidedStep.rutaPago) _advance();
  }

  void onEstadoSet() {
    if (_current == GuidedStep.rutaEstado) _advance();
  }

  void onBackToInicio() {
    if (_current == GuidedStep.rutaVolverInicio) _advance();
  }

  // ─── Cierre ───
  void onCierreOpened() {
    if (_current == GuidedStep.terminar) _advance();
  }

  void onResumenSaved() {
    if (_current == GuidedStep.cierreFinalizar) _advance(); // → Phase 2
  }

  // ─── Phase 2 — Más pages tour ───

  /// A Phase-2 page mounted. Advances the matching "goto" step (whose next step
  /// lives on [pageScreen]).
  void onP2Open(GuidedScreen pageScreen) {
    final idx = _curIdx;
    if (idx < 0 || idx + 1 >= _steps.length) return;
    if (_current!.screen == GuidedScreen.mas &&
        _steps[idx + 1].screen == pageScreen) {
      _advance();
    }
  }

  /// A Phase-2 page popped back to Más.
  void onP2Return(GuidedScreen pageScreen) {
    if (_current != null && _current!.screen == pageScreen) _advance();
  }

  // ─── Satisfied-aware re-query gates ───

  Future<bool> _pricesSatisfied() async {
    final pid = newProductId;
    final rid = repartoId;
    if (pid == null || rid == null) return false;
    final products = await _db.getAllProducts(rid);
    final match = products.where((p) => p.id == pid);
    if (match.isEmpty || match.first.precio <= 0) return false;
    final precios = await _db.getAllProductoPrecios(rid);
    return precios.any((pp) => pp.productoId == pid && pp.precio > 0);
  }

  Future<bool> _cargaSatisfied(int day, String week) async {
    final pid = newProductId;
    final rid = repartoId;
    if (pid == null || rid == null) return false;
    final carga = await _db.getCargaForDayWithRemanente(rid, day, week);
    final entry = carga[pid];
    return entry != null && entry.cantidad > 0;
  }

  Future<void> _maybeAdoptProduct() async {
    try {
      final rid = repartoId;
      if (rid == null) return;
      final products = await _db.getAllProducts(rid);
      if (products.isEmpty) return;
      if (_current != GuidedStep.addProduct) return;
      products.sort((a, b) => b.id.compareTo(a.id));
      newProductId = products.first.id;
      if (await _pricesSatisfied()) {
        _advanceTo(GuidedStep.addQty);
      } else {
        _advanceTo(GuidedStep.setPrices);
      }
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _attachExampleClientProduct(int productId) async {
    if (kDemoMode) return;
    final cid = exampleClientId;
    if (cid == null) return;
    try {
      await _db.setClienteProducto(cid, productId, 1);
    } catch (_) {
      // Best-effort: the product still appears as an additional product in Ruta.
    }
  }

  Future<void> _moveExampleClientToDay(int day) async {
    if (kDemoMode) return;
    final cid = exampleClientId;
    if (cid == null) return;
    try {
      await _db.updateCliente(cid, diaSemana: day);
    } catch (_) {
      // Best-effort: if this fails, the user can still add/move clients normally.
    }
  }

  /// Test seam: jump to a given step (and set the frontier to it) without the DB.
  @visibleForTesting
  void debugSetCurrent(
    GuidedStep? step, {
    int? repartoId,
    int? newProductId,
    int? exampleClientId,
    int? loadedDay,
  }) {
    _current = step;
    _frontier = step;
    if (repartoId != null) this.repartoId = repartoId;
    if (newProductId != null) this.newProductId = newProductId;
    if (exampleClientId != null) this.exampleClientId = exampleClientId;
    if (loadedDay != null) this.loadedDay = loadedDay;
    notifyListeners();
  }
}
